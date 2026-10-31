# ==========================================
# 📄 File: backend/modules/system.py
# 🌟 原生系统硬件监视驱动 (btop 同款 CPU 算法版)
# ==========================================
import os
import glob
import socket
import asyncio
from typing import Optional, List

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState
from backend.modules.netlink_speed import NetlinkSpeedSampler, format_speed_structured


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

        self._net_sampler: Optional[NetlinkSpeedSampler] = None

        # 🚀 CPU 采样差值缓存
        self._last_cpu_total = 0
        self._last_cpu_idle = 0

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
        self._net_sampler = NetlinkSpeedSampler(window_span_sec=1.0, socket_timeout=0.08)

        self._wake_event.set()
        self._task = asyncio.create_task(self._monitor_loop())
        app_logger.info("✅ 系统硬件与 btop 级 CPU 监视引擎已就绪")

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

                caps_on = any(self._read_led(p) for p in self._caps_paths)
                num_on = any(self._read_led(p) for p in self._num_paths)
                if self.state.is_caps_lock != caps_on or self.state.is_num_lock != num_on:
                    self.state.batch_update(is_caps_lock=caps_on, is_num_lock=num_on)
                    self.notify("KEYBOARD_LOCK_UPDATE")

                tick += 1

                if tick % 2 == 0 and self._net_sampler:
                    rx_rate, tx_rate = self._net_sampler.tick()
                    d_meta = format_speed_structured(rx_rate)
                    u_meta = format_speed_structured(tx_rate)

                    if (self.state.net_down_compact != d_meta["compact"] or 
                        self.state.net_up_compact != u_meta["compact"]):
                        self.state.batch_update(
                            net_down_speed=d_meta["full"], net_down_val=d_meta["val"], net_down_unit=d_meta["unit"], net_down_compact=d_meta["compact"],
                            net_up_speed=u_meta["full"], net_up_val=u_meta["val"], net_up_unit=u_meta["unit"], net_up_compact=u_meta["compact"]
                        )
                        self.notify("NET_SPEED_UPDATE")

                # 🚀 每 1.0 秒执行 CPU 高精度采样
                if tick % 2 == 0:
                    self._poll_cpu()

                if tick % 6 == 0:
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

    def _poll_cpu(self):
        """🚀 btop 同款算法：直接从 /proc/stat 算差值，0 额外开销"""
        try:
            with open("/proc/stat", "r", encoding="ascii") as f:
                line = f.readline()
                if not line.startswith("cpu "):
                    return
                parts = line.split()[1:]
                if len(parts) < 4:
                    return

                user, nice, sys, idle = map(int, parts[:4])
                iowait = int(parts[4]) if len(parts) > 4 else 0
                irq = int(parts[5]) if len(parts) > 5 else 0
                softirq = int(parts[6]) if len(parts) > 6 else 0
                steal = int(parts[7]) if len(parts) > 7 else 0

                idle_time = idle + iowait
                non_idle_time = user + nice + sys + irq + softirq + steal
                total_time = idle_time + non_idle_time

                if self._last_cpu_total > 0:
                    total_delta = total_time - self._last_cpu_total
                    idle_delta = idle_time - self._last_cpu_idle
                    if total_delta > 0:
                        cpu_pct = int(((total_delta - idle_delta) / total_delta) * 100.0)
                        cpu_pct = max(0, min(100, cpu_pct))
                        if self.state.cpu_percent != cpu_pct:
                            self.state.cpu_percent = cpu_pct
                            self.notify("CPU_UPDATE")

                self._last_cpu_total = total_time
                self._last_cpu_idle = idle_time
        except Exception:
            pass

    def _poll_battery(self):
        if not self._bat_capacity_path: return
        try:
            with open(self._bat_capacity_path, "r", encoding="ascii") as f: cur_bat = int(f.read().strip())
            charging = False
            if self._bat_status_path:
                with open(self._bat_status_path, "r", encoding="ascii") as f: charging = f.read(1).lower() in ("c", "f")
            if self.state.battery_pct != cur_bat or self.state.battery_charging != charging:
                self.state.batch_update(battery_pct=cur_bat, battery_charging=charging)
                self.notify("BATTERY_UPDATE")
        except Exception:
            pass