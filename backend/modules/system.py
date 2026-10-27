# ==========================================
# 📄 File: backend/modules/system.py
# 🌟 原生内核 Netlink STATS64 + 1.0s 平滑控频网速引擎
# ==========================================
import os
import glob
import time
import socket
import struct
import asyncio
import collections
from typing import Optional, List, Tuple

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState

RTM_GETLINK = 18
RTM_NEWLINK = 16
NLM_F_REQUEST = 1
IFLA_STATS64 = 23


def format_speed(bytes_per_sec: float) -> Tuple[str, str]:
    """格式化速率：增加死区滤波，消除后台零星杂音的个位抖动"""
    # 🚀 过滤掉小于 256 B/s 的微小心跳包，空闲时沉稳显示 0B
    if bytes_per_sec < 256:
        return "0 B/s", "0B"
    elif bytes_per_sec < 1024:
        return f"{int(bytes_per_sec)} B/s", f"{int(bytes_per_sec)}B"
    elif bytes_per_sec < 1048576:
        kb = bytes_per_sec / 1024.0
        return f"{kb:.1f} KB/s", f"{int(kb)}K" if kb >= 100 else f"{kb:.1f}K"
    elif bytes_per_sec < 1073741824:
        mb = bytes_per_sec / 1048576.0
        return f"{mb:.1f} MB/s", f"{mb:.1f}M"
    else:
        gb = bytes_per_sec / 1073741824.0
        return f"{gb:.2f} GB/s", f"{gb:.1f}G"


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
                app_logger.debug("[SystemModule] 唤醒系统状态监控循环")
        else:
            if self._wake_event.is_set():
                self._wake_event.clear()
                app_logger.debug("[SystemModule] UI 已隐藏，系统监控循环挂起休眠 (0% CPU)")

    async def start(self) -> None:
        self._running = True
        self._refresh_hw_paths()
        self.state.local_ip = self._get_local_ip()

        self._net_sampler = NetlinkSpeedSampler(window_span_sec=1.0)

        try:
            self._proc_meminfo = open("/proc/meminfo", "r", encoding="ascii", errors="ignore")
        except OSError as e:
            app_logger.warning(f"[SystemModule] 无法打开 /proc/meminfo 监视句柄: {e}")

        self._wake_event.set()
        self._task = asyncio.create_task(self._monitor_loop())
        app_logger.info("✅ 系统硬件、内存与内核 Netlink STATS64 平滑网速监视引擎已挂载")

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

                # 1. 键盘锁状态 (每 500ms 检查)
                caps_on = False
                for p in self._caps_paths:
                    try:
                        with open(p, "r", encoding="ascii") as fp:
                            if fp.read(1) != "0":
                                caps_on = True
                                break
                    except OSError:
                        pass

                num_on = False
                for p in self._num_paths:
                    try:
                        with open(p, "r", encoding="ascii") as fp:
                            if fp.read(1) != "0":
                                num_on = True
                                break
                    except OSError:
                        pass

                if self.state.is_caps_lock != caps_on or self.state.is_num_lock != num_on:
                    self.state.is_caps_lock = caps_on
                    self.state.is_num_lock = num_on
                    self.notify("KEYBOARD_LOCK_UPDATE")

                tick += 1

                # 🚀 2. 内核 Netlink STATS64 平滑采样：严格控制为每 1.0 秒更新一次 (tick % 2 == 0)
                if tick % 2 == 0 and self._net_sampler:
                    rx_rate, tx_rate = self._net_sampler.tick()
                    down_s, down_c = format_speed(rx_rate)
                    up_s, up_c = format_speed(tx_rate)
                    if self.state.net_down_compact != down_c or self.state.net_up_compact != up_c:
                        self.state.net_down_speed = down_s
                        self.state.net_down_compact = down_c
                        self.state.net_up_speed = up_s
                        self.state.net_up_compact = up_c
                        self.notify("NET_SPEED_UPDATE")

                # 3. 内存与电池 (每 3 秒检查一次)
                if tick % 6 == 0:
                    if self._proc_meminfo:
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
                        except (ValueError, IndexError, OSError) as e:
                            app_logger.debug(f"[SystemModule] 内存读取异常: {e}")

                    if self._bat_capacity_path:
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
                        except (ValueError, OSError) as e:
                            app_logger.debug(f"[SystemModule] 电池读取异常: {e}")

                await asyncio.sleep(0.5)

            except asyncio.CancelledError:
                break
            except Exception as e:
                app_logger.warning(f"[SystemModule] 监控循环未知异常: {e}")
                await asyncio.sleep(1.0)