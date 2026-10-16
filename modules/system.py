# ==========================================
# 📄 File: modules/system.py
# 🌟 原生系统硬件状态监视模块（内存/电池/键盘锁/网速/本地IP）
# ==========================================
import os
import glob
import time
import socket
import asyncio
from typing import Optional
try:
    from loguru import logger
except ImportError:
    from logger import app_logger as logger

from core.state import IslandState


def format_speed(bytes_per_sec: float) -> tuple[str, str]:
    """返回 (全量字符串, 紧凑两字符格式)"""
    if bytes_per_sec < 1024:
        return f"{int(bytes_per_sec)} B/s", f"{int(bytes_per_sec)}B"
    elif bytes_per_sec < 1024 * 1024:
        kb = bytes_per_sec / 1024.0
        return f"{kb:.1f} KB/s", f"{int(kb)}K" if kb >= 100 else f"{kb:.1f}K"
    else:
        mb = bytes_per_sec / (1024.0 * 1024.0)
        return f"{mb:.1f} MB/s", f"{mb:.1f}M"


class SystemModule:
    """纯协程系统监视器，无额外进程开销"""

    def __init__(self, state: IslandState, dispatcher):
        self.state = state
        self.dispatcher = dispatcher
        self.log = logger.bind(module="SYSTEM")

        self._running = False
        self._task: Optional[asyncio.Task] = None

        # 锁键节点缓存
        self._caps_paths = []
        self._num_paths = []

        # 电池节点缓存
        self._bat_capacity_path = None
        self._bat_status_path = None

        # 流量算差基准
        self._last_net_bytes = (0, 0)
        self._last_net_time = 0.0

    async def init(self):
        self._running = True
        self._refresh_hw_paths()
        self.state.local_ip = self._get_local_ip()
        self._last_net_bytes = self._read_net_bytes()
        self._last_net_time = time.monotonic()

        self._task = asyncio.create_task(self._monitor_loop())
        self.log.success("系统硬件与网络监视引擎已就绪")

    async def close(self):
        self._running = False
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass

    def _refresh_hw_paths(self):
        try:
            self._caps_paths = glob.glob("/sys/class/leds/*capslock*/brightness")
            self._num_paths = glob.glob("/sys/class/leds/*numlock*/brightness")
        except Exception:
            self._caps_paths, self._num_paths = [], []

        bats = glob.glob("/sys/class/power_supply/BAT*")
        if bats:
            self._bat_capacity_path = os.path.join(bats[0], "capacity")
            self._bat_status_path = os.path.join(bats[0], "status")

    def _read_net_bytes(self) -> tuple[int, int]:
        rx_total, tx_total = 0, 0
        try:
            with open("/proc/net/dev", "r") as f:
                lines = f.readlines()[2:]
                for line in lines:
                    parts = line.split(":")
                    if len(parts) < 2:
                        continue
                    iface = parts[0].strip()
                    if iface == "lo" or iface.startswith("virbr") or iface.startswith("docker"):
                        continue
                    data = parts[1].split()
                    rx_total += int(data[0])
                    tx_total += int(data[8])
        except Exception:
            pass
        return rx_total, tx_total

    def _get_local_ip(self) -> str:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "127.0.0.1"

    async def _monitor_loop(self):
        sec_counter = 0

        while self._running:
            try:
                # 1. 高频（200ms）检测键盘锁状态
                caps_on = False
                for p in self._caps_paths:
                    try:
                        with open(p, "r") as fp:
                            if int(fp.read().strip() or "0") > 0:
                                caps_on = True
                                break
                    except Exception:
                        continue

                num_on = False
                for p in self._num_paths:
                    try:
                        with open(p, "r") as fp:
                            if int(fp.read().strip() or "0") > 0:
                                num_on = True
                                break
                    except Exception:
                        continue

                lock_changed = (self.state.is_caps_lock != caps_on or self.state.is_num_lock != num_on)
                if lock_changed:
                    self.state.is_caps_lock = caps_on
                    self.state.is_num_lock = num_on
                    self.dispatcher.broadcast("KEYBOARD_LOCK_UPDATE")

                # 2. 1秒周期：计算实时网速
                sec_counter += 1
                if sec_counter % 5 == 0:
                    now = time.monotonic()
                    dt = now - self._last_net_time
                    if dt > 0.1:
                        rx, tx = self._read_net_bytes()
                        drx = max(0, rx - self._last_net_bytes[0]) / dt
                        dtx = max(0, tx - self._last_net_bytes[1]) / dt
                        self._last_net_bytes = (rx, tx)
                        self._last_net_time = now

                        self.state.net_down_speed, self.state.net_down_compact = format_speed(drx)
                        self.state.net_up_speed, self.state.net_up_compact = format_speed(dtx)
                        self.dispatcher.broadcast("NET_SPEED_UPDATE")

                # 3. 2秒周期：读取内存与电池状态
                if sec_counter % 10 == 0:
                    # 内存计算
                    try:
                        total_kb, avail_kb = 0, 0
                        with open("/proc/meminfo", "r") as f:
                            for line in f:
                                if line.startswith("MemTotal:"):
                                    total_kb = int(line.split()[1])
                                elif line.startswith("MemAvailable:"):
                                    avail_kb = int(line.split()[1])
                                if total_kb and avail_kb:
                                    break
                        if total_kb > 0:
                            used_kb = max(0, total_kb - avail_kb)
                            self.state.memory_percent = int(round((used_kb / total_kb) * 100))
                            self.state.memory_used_gb = f"{used_kb / 1048576:.1f}G"
                            self.state.memory_total_gb = f"{total_kb / 1048576:.1f}G"
                            self.dispatcher.broadcast("MEMORY_UPDATE")
                    except Exception:
                        pass

                    # 电池计算
                    if self._bat_capacity_path and os.path.exists(self._bat_capacity_path):
                        try:
                            with open(self._bat_capacity_path, "r") as f:
                                self.state.battery_pct = int(f.read().strip())
                            if self._bat_status_path and os.path.exists(self._bat_status_path):
                                with open(self._bat_status_path, "r") as f:
                                    self.state.battery_charging = f.read().strip().lower() in ("charging", "full")
                            self.dispatcher.broadcast("BATTERY_UPDATE")
                        except Exception:
                            pass

                await asyncio.sleep(0.2)

            except asyncio.CancelledError:
                break
            except Exception as e:
                self.log.debug(f"系统指标采样异常: {e}")
                await asyncio.sleep(1.0)