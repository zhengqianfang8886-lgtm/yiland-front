# ==========================================
# 📄 File: backend/modules/system.py
# 🌟 原生内核 Netlink STATS64 + 结构化网速输出引擎
# ==========================================
import os
import glob
import time
import socket
import struct
import asyncio
import collections
from typing import Optional, List, Tuple, Dict, Any

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState

RTM_GETLINK = 18
RTM_NEWLINK = 16
NLM_F_REQUEST = 1
IFLA_STATS64 = 23


def format_speed_structured(bytes_per_sec: float) -> Dict[str, str]:
    """
    🚀 结构化格式化：
    同时输出全量字符串、纯数值、纯单位与微缩显式标签。
    前端无需任何正则与字符串切片即可直接绑定。
    """
    if bytes_per_sec < 256:
        return {
            "full": "0 B/s",
            "val": "0",
            "unit": "B/s",
            "compact": "0B"
        }
    elif bytes_per_sec < 1024:
        val_str = str(int(bytes_per_sec))
        return {
            "full": f"{val_str} B/s",
            "val": val_str,
            "unit": "B/s",
            "compact": f"{val_str}B"
        }
    elif bytes_per_sec < 1048576:
        kb = bytes_per_sec / 1024.0
        val_str = f"{int(kb)}" if kb >= 100 else f"{kb:.1f}"
        return {
            "full": f"{kb:.1f} KB/s",
            "val": val_str,
            "unit": "K/s",
            "compact": f"{val_str}K"
        }
    elif bytes_per_sec < 1073741824:
        mb = bytes_per_sec / 1048576.0
        val_str = f"{mb:.1f}"
        return {
            "full": f"{mb:.1f} MB/s",
            "val": val_str,
            "unit": "M/s",
            "compact": f"{val_str}M"
        }
    else:
        gb = bytes_per_sec / 1073741824.0
        val_str = f"{gb:.1f}"
        return {
            "full": f"{gb:.2f} GB/s",
            "val": val_str,
            "unit": "G/s",
            "compact": f"{val_str}G"
        }


class NetlinkSpeedSampler:
    def __init__(self, window_span_sec: float = 1.0):
        self.window_span = window_span_sec
        self.samples = collections.deque()
        self.last_iface = ""
        self.ifindex = 0
        self.sock: Optional[socket.socket] = None
        self._init_socket()

    def _init_socket(self):
        try:
            self.sock = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, socket.NETLINK_ROUTE)
            self.sock.settimeout(0.08)
        except OSError as e:
            app_logger.debug(f"[SystemModule] 初始化 Netlink 套接字失败: {e}")
            self.sock = None

    def close(self):
        if self.sock:
            try:
                self.sock.close()
            except OSError:
                pass
            self.sock = None

    @staticmethod
    def get_default_interface() -> str:
        try:
            with open("/proc/net/route", "r", encoding="ascii") as f:
                for line in f:
                    parts = line.split()
                    if len(parts) >= 2 and parts[1] == "00000000":
                        return parts[0]
        except OSError:
            pass
        return ""

    def _query_stats64(self, ifindex: int) -> Optional[Tuple[int, int]]:
        if not self.sock or ifindex <= 0:
            return None

        nlmsg_len = 32
        req = struct.pack("=IHHII B B H i I I",
                          nlmsg_len, RTM_GETLINK, NLM_F_REQUEST, 1, 0,
                          0, 0, 0, ifindex, 0, 0)
        try:
            self.sock.send(req)
            data = self.sock.recv(4096)
        except OSError:
            return None

        offset = 0
        data_len = len(data)
        while offset + 16 <= data_len:
            msg_len, msg_type, _, _, _ = struct.unpack_from("=IHHII", data, offset)
            if msg_type == RTM_NEWLINK and offset + 32 <= data_len:
                rta_offset = offset + 32
                payload_len = msg_len - 32
                while payload_len >= 4:
                    rta_len, rta_type = struct.unpack_from("=HH", data, rta_offset)
                    if rta_len < 4 or rta_len > payload_len:
                        break

                    if rta_type == IFLA_STATS64 and rta_len >= 4 + 32:
                        rx_bytes, tx_bytes = struct.unpack_from("=QQ", data, rta_offset + 4 + 16)
                        return rx_bytes, tx_bytes

                    aligned_len = (rta_len + 3) & ~3
                    rta_offset += aligned_len
                    payload_len -= aligned_len

            aligned_msg_len = (msg_len + 3) & ~3
            offset += aligned_msg_len

        return None

    def tick(self) -> Tuple[float, float]:
        cur_iface = self.get_default_interface()
        if not cur_iface:
            self.samples.clear()
            return 0.0, 0.0

        if cur_iface != self.last_iface:
            try:
                self.ifindex = socket.if_nametoindex(cur_iface)
                self.last_iface = cur_iface
            except OSError:
                self.ifindex = 0
            self.samples.clear()

        stats = self._query_stats64(self.ifindex)
        if not stats:
            return 0.0, 0.0

        rx, tx = stats
        now = time.monotonic()
        self.samples.append((now, rx, tx))

        while len(self.samples) > 2:
            if now - self.samples[0][0] > self.window_span:
                self.samples.popleft()
            else:
                break

        if len(self.samples) >= 2:
            oldest = self.samples[0]
            newest = self.samples[-1]
            dt = newest[0] - oldest[0]
            if dt > 0.05 and newest[1] >= oldest[1] and newest[2] >= oldest[2]:
                rx_rate = (newest[1] - oldest[1]) / dt
                tx_rate = (newest[2] - oldest[2]) / dt
                return rx_rate, tx_rate

        return 0.0, 0.0


class SystemModule(BaseModule):
    def __init__(self, backend, state: IslandState):
        super().__init__(backend, state)
        self._running = False
        self._task: Optional[asyncio.Task] = None
        self._wake_event = asyncio.Event()

        self._caps_paths: List[str] = []
        self._num_paths: List[str] = []
        self._bat_capacity_path: Optional[str] = None
        self._bat_status_path: Optional[str] = None

        self._proc_meminfo = None
        self._net_sampler: Optional[NetlinkSpeedSampler] = None

    def set_active(self, active: bool) -> None:
        super().set_active(active)
        if active:
            if not self._wake_event.is_set():
                self._wake_event.set()
        else:
            if self._wake_event.is_set():
                self._wake_event.clear()

    async def start(self) -> None:
        self._running = True
        self._refresh_hw_paths()
        self.state.local_ip = self._get_local_ip()
        self._net_sampler = NetlinkSpeedSampler(window_span_sec=1.0)

        try:
            self._proc_meminfo = open("/proc/meminfo", "r", encoding="ascii", errors="ignore")
        except OSError:
            pass

        self._wake_event.set()
        self._task = asyncio.create_task(self._monitor_loop())
        app_logger.info("✅ 系统硬件与结构化 Netlink 网速监视引擎已就绪")

    async def stop(self) -> None:
        self._running = False
        self._wake_event.set()
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass

        if self._net_sampler:
            self._net_sampler.close()
            self._net_sampler = None

        if self._proc_meminfo:
            try:
                self._proc_meminfo.close()
            except OSError:
                pass

    def _refresh_hw_paths(self):
        self._caps_paths = glob.glob("/sys/class/leds/*capslock*/brightness")
        self._num_paths = glob.glob("/sys/class/leds/*numlock*/brightness")
        bats = glob.glob("/sys/class/power_supply/BAT*")
        if bats:
            self._bat_capacity_path = os.path.join(bats[0], "capacity")
            self._bat_status_path = os.path.join(bats[0], "status")

    def _get_local_ip(self) -> str:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect(("8.8.8.8", 80))
                return s.getsockname()[0]
        except OSError:
            return "127.0.0.1"

    async def _monitor_loop(self):
        tick = 0
        while self._running:
            try:
                await self._wake_event.wait()
                if not self._running:
                    break

                # 1. 键盘锁 (每 500ms)
                caps_on = any(self._read_led(p) for p in self._caps_paths)
                num_on = any(self._read_led(p) for p in self._num_paths)
                if self.state.is_caps_lock != caps_on or self.state.is_num_lock != num_on:
                    self.state.is_caps_lock = caps_on
                    self.state.is_num_lock = num_on
                    self.notify("KEYBOARD_LOCK_UPDATE")

                tick += 1

                # 2. 内核 Netlink STATS64 平滑采样 (严格每 1.0 秒更新)
                if tick % 2 == 0 and self._net_sampler:
                    rx_rate, tx_rate = self._net_sampler.tick()
                    d_meta = format_speed_structured(rx_rate)
                    u_meta = format_speed_structured(tx_rate)

                    # 判断是否有必要推流
                    if (self.state.net_down_compact != d_meta["compact"] or 
                        self.state.net_up_compact != u_meta["compact"]):
                        
                        self.state.net_down_speed = d_meta["full"]
                        self.state.net_down_val = d_meta["val"]
                        self.state.net_down_unit = d_meta["unit"]
                        self.state.net_down_compact = d_meta["compact"]

                        self.state.net_up_speed = u_meta["full"]
                        self.state.net_up_val = u_meta["val"]
                        self.state.net_up_unit = u_meta["unit"]
                        self.state.net_up_compact = u_meta["compact"]

                        self.notify("NET_SPEED_UPDATE")

                # 3. 内存与电池 (每 3 秒)
                if tick % 6 == 0:
                    self._poll_memory()
                    self._poll_battery()

                await asyncio.sleep(0.5)

            except asyncio.CancelledError:
                break
            except Exception as e:
                app_logger.warning(f"[SystemModule] 监控异常: {e}")
                await asyncio.sleep(1.0)

    def _read_led(self, path: str) -> bool:
        try:
            with open(path, "r", encoding="ascii") as fp:
                return fp.read(1) != "0"
        except OSError:
            return False

    def _poll_memory(self):
        if not self._proc_meminfo:
            return
        try:
            self._proc_meminfo.seek(0)
            total_kb, avail_kb = 0, 0
            for line in self._proc_meminfo:
                if line.startswith("MemTotal:"):
                    total_kb = int(line.split()[1])
                elif line.startswith("MemAvailable:"):
                    avail_kb = int(line.split()[1])
                    break
            if total_kb > 0:
                used_kb = total_kb - avail_kb
                mem_pct = int((used_kb / total_kb) * 100)
                if abs(self.state.memory_percent - mem_pct) >= 1:
                    self.state.memory_percent = mem_pct
                    self.state.memory_used_gb = f"{used_kb / 1048576:.1f}G"
                    self.state.memory_total_gb = f"{total_kb / 1048576:.1f}G"
                    self.notify("MEMORY_UPDATE")
        except Exception:
            pass

    def _poll_battery(self):
        if not self._bat_capacity_path:
            return
        try:
            with open(self._bat_capacity_path, "r", encoding="ascii") as f:
                cur_bat = int(f.read().strip())
            charging = False
            if self._bat_status_path:
                with open(self._bat_status_path, "r", encoding="ascii") as f:
                    charging = f.read(1).lower() in ("c", "f")

            if self.state.battery_pct != cur_bat or self.state.battery_charging != charging:
                self.state.battery_pct = cur_bat
                self.state.battery_charging = charging
                self.notify("BATTERY_UPDATE")
        except Exception:
            pass