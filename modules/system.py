# ==========================================
# 📄 File: modules/system.py (零系统调用开销版)
# ==========================================
import os
import glob
import time
import socket
import asyncio
from typing import Optional, List
try:
    from loguru import logger
except ImportError:
    from logger import app_logger as logger

from core.state import IslandState


def format_speed(bytes_per_sec: float) -> tuple[str, str]:
    if bytes_per_sec < 1024:
        return f"{int(bytes_per_sec)} B/s", f"{int(bytes_per_sec)}B"
    elif bytes_per_sec < 1048576:
        kb = bytes_per_sec / 1024.0
        return f"{kb:.1f} KB/s", f"{int(kb)}K" if kb >= 100 else f"{kb:.1f}K"
    else:
        mb = bytes_per_sec / 1048576.0
        return f"{mb:.1f} MB/s", f"{mb:.1f}M"


class SystemModule:
    def __init__(self, state: IslandState, dispatcher):
        self.state = state
        self.dispatcher = dispatcher
        self.log = logger.bind(module="SYSTEM")

        self._running = False
        self._task: Optional[asyncio.Task] = None

        self._caps_paths: List[str] = []
        self._num_paths: List[str] = []
        self._bat_capacity_path: Optional[str] = None
        self._bat_status_path: Optional[str] = None

        self._last_net_bytes = (0, 0)
        self._last_net_time = 0.0

        # 持久化文件句柄，减少系统调用频度
        self._proc_net_dev = None
        self._proc_meminfo = None

    async def init(self):
        self._running = True
        self._refresh_hw_paths()
        self.state.local_ip = self._get_local_ip()

        try:
            self._proc_net_dev = open("/proc/net/dev", "r", encoding="ascii", errors="ignore")
            self._proc_meminfo = open("/proc/meminfo", "r", encoding="ascii", errors="ignore")
        except Exception:
            pass

        self._last_net_bytes = self._read_net_bytes()
        self._last_net_time = time.monotonic()

        self._task = asyncio.create_task(self._monitor_loop())
        self.log.success("系统硬件与网络监视引擎 (句柄常驻低占用版) 已就绪")

    async def close(self):
        self._running = False
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass

        for fp in [self._proc_net_dev, self._proc_meminfo]:
            if fp:
                try:
                    fp.close()
                except Exception:
                    pass

    def _refresh_hw_paths(self):
        self._caps_paths = glob.glob("/sys/class/leds/*capslock*/brightness")
        self._num_paths = glob.glob("/sys/class/leds/*numlock*/brightness")
        bats = glob.glob("/sys/class/power_supply/BAT*")
        if bats:
            self._bat_capacity_path = os.path.join(bats[0], "capacity")
            self._bat_status_path = os.path.join(bats[0], "status")

    def _read_net_bytes(self) -> tuple[int, int]:
        if not self._proc_net_dev:
            return 0, 0
        try:
            self._proc_net_dev.seek(0)
            lines = self._proc_net_dev.readlines()[2:]
            rx_total, tx_total = 0, 0
            for line in lines:
                parts = line.split(":")
                if len(parts) < 2:
                    continue
                iface = parts[0].strip()
                if iface == "lo" or iface.startswith(("virbr", "docker", "veth")):
                    continue
                data = parts[1].split()
                rx_total += int(data[0])
                tx_total += int(data[8])
            return rx_total, tx_total
        except Exception:
            return 0, 0

    def _get_local_ip(self) -> str:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect(("8.8.8.8", 80))
                return s.getsockname()[0]
        except Exception:
            return "127.0.0.1"

    async def _monitor_loop(self):
        tick = 0
        while self._running:
            try:
                # 1. 键盘锁 (每 500ms 检查一次)
                caps_on = False
                for p in self._caps_paths:
                    try:
                        with open(p, "r", encoding="ascii") as fp:
                            if fp.read(1) != "0":
                                caps_on = True
                                break
                    except Exception:
                        pass

                num_on = False
                for p in self._num_paths:
                    try:
                        with open(p, "r", encoding="ascii") as fp:
                            if fp.read(1) != "0":
                                num_on = True
                                break
                    except Exception:
                        pass

                if self.state.is_caps_lock != caps_on or self.state.is_num_lock != num_on:
                    self.state.is_caps_lock = caps_on
                    self.state.is_num_lock = num_on
                    self.dispatcher.broadcast("KEYBOARD_LOCK_UPDATE")

                tick += 1

                # 2. 网速采样 (每 1000ms)
                if tick % 2 == 0:
                    now = time.monotonic()
                    dt = now - self._last_net_time
                    if dt >= 0.5:
                        rx, tx = self._read_net_bytes()
                        drx = max(0, rx - self._last_net_bytes[0]) / dt
                        dtx = max(0, tx - self._last_net_bytes[1]) / dt
                        self._last_net_bytes = (rx, tx)
                        self._last_net_time = now

                        down_s, down_c = format_speed(drx)
                        up_s, up_c = format_speed(dtx)
                        if self.state.net_down_compact != down_c or self.state.net_up_compact != up_c:
                            self.state.net_down_speed, self.state.net_down_compact = down_s, down_c
                            self.state.net_up_speed, self.state.net_up_compact = up_s, up_c
                            self.dispatcher.broadcast("NET_SPEED_UPDATE")

                # 3. 内存与电池 (每 3000ms)
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
                                    self.dispatcher.broadcast("MEMORY_UPDATE")
                        except Exception:
                            pass

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
                                self.dispatcher.broadcast("BATTERY_UPDATE")
                        except Exception:
                            pass

                await asyncio.sleep(0.5)

            except asyncio.CancelledError:
                break
            except Exception as e:
                self.log.debug(f"系统指标采样异常: {e}")
                await asyncio.sleep(1.0)