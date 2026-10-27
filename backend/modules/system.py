# ==========================================
# 📄 File: backend/modules/system.py
# 🌟 原生系统硬件监视驱动 (消除冗余实现 · 原子提交加固版)
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
        self._net_sampler = NetlinkSpeedSampler(window_span_sec=1.0, socket_timeout=0.08)

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

                # 1. 键盘锁 (每 500ms 采样一次)
                caps_on = any(self._read_led(p) for p in self._caps_paths)
                num_on = any(self._read_led(p) for p in self._num_paths)
                if self.state.is_caps_lock != caps_on or self.state.is_num_lock != num_on:
                    self.state.batch_update(is_caps_lock=caps_on, is_num_lock=num_on)
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
                        
                        self.state.batch_update(
                            net_down_speed=d_meta["full"],
                            net_down_val=d_meta["val"],
                            net_down_unit=d_meta["unit"],
                            net_down_compact=d_meta["compact"],
                            net_up_speed=u_meta["full"],
                            net_up_val=u_meta["val"],
                            net_up_unit=u_meta["unit"],
                            net_up_compact=u_meta["compact"]
                        )
                        self.notify("NET_SPEED_UPDATE")

                # 3. 内存与电池 (每 3 秒更新)
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
                    self.state.batch_update(
                        memory_percent=mem_pct,
                        memory_used_gb=f"{used_kb / 1048576:.1f}G",
                        memory_total_gb=f"{total_kb / 1048576:.1f}G"
                    )
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
                self.state.batch_update(battery_pct=cur_bat, battery_charging=charging)
                self.notify("BATTERY_UPDATE")
        except Exception:
            pass