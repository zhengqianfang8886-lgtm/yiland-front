# ==========================================
# 📄 File: backend/modules/timer.py
# 🌟 原生异步双轨独立计时引擎 (双轨完全并发保活版)
# ==========================================
import asyncio
from typing import Optional, List, Dict, Any
from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class TimerModule(BaseModule):
    def __init__(self, backend, state: IslandState):
        super().__init__(backend, state)
        self._ticker_task: Optional[asyncio.Task] = None

        # 1. 倒计时 (Countdown / Pomodoro) 独立状态
        self.cd_running: bool = False
        self.cd_paused: bool = False
        self.cd_completed: bool = False
        self.cd_overtime: bool = False
        self.cd_overtime_sec: int = 0
        self.cd_remaining_sec: int = 1500
        self.cd_total_sec: int = 1500
        self.cd_mode: str = "focus"

        # 2. 正向秒表 (Stopwatch) 独立状态
        self.sw_running: bool = False
        self.sw_paused: bool = False
        self.sw_elapsed_sec: int = 0
        self.sw_laps: List[Dict[str, Any]] = []

        # 当前在卡片中正在查阅的页面: "countdown" 或 "stopwatch"
        self.active_type: str = "countdown"

    async def start(self) -> None:
        self._sync_to_state()
        app_logger.info("✅ 原生双轨异步计时引擎就绪 (支持胶囊端两轨并存展示)")

    async def stop(self) -> None:
        if self._ticker_task and not self._ticker_task.done():
            self._ticker_task.cancel()
        self._ticker_task = None

    def _ensure_ticker(self):
        """只要倒计时或秒表任意一个在跑，就维持后台心跳"""
        any_running = self.cd_running or self.sw_running
        if any_running:
            if self._ticker_task is None or self._ticker_task.done():
                self._ticker_task = asyncio.create_task(self._tick_loop())
        else:
            if self._ticker_task and not self._ticker_task.done():
                self._ticker_task.cancel()
            self._ticker_task = None

    async def _tick_loop(self):
        try:
            while self.cd_running or self.sw_running:
                await asyncio.sleep(1.0)

                # 1. 秒表正向累加
                if self.sw_running:
                    self.sw_elapsed_sec += 1

                # 2. 倒计时推进
                if self.cd_running:
                    if self.cd_overtime:
                        self.cd_overtime_sec += 1
                        if self.cd_overtime_sec >= 7200:  # 超时 2 小时自动挂起保护
                            self.cd_running = False
                            self.cd_paused = True
                    else:
                        if self.cd_remaining_sec > 1:
                            self.cd_remaining_sec -= 1
                        else:
                            self.cd_remaining_sec = 0
                            self.cd_overtime = True
                            self.cd_overtime_sec = 0
                            self.trigger_overlay(
                                key="ALERT",
                                title="休息结束" if self.cd_mode == "break" else "专注时间到",
                                subtitle="已自动开启超时追溯，可随时完成",
                                icon="⏰",
                                duration_ms=4500,
                                priority=45
                            )

                self._sync_to_state()
                self.notify("TIMER_UPDATE")
        except asyncio.CancelledError:
            pass
        finally:
            self._ensure_ticker()

    def _sync_to_state(self):
        """
        🚀 核心改动：同时灌入双轨数据！
        既同步兼容字段（服务于大卡片），又同步双轨独立字段（服务于胶囊双并存）
        """
        # 1. 同步独立倒计时状态
        self.state.cd_is_running = self.cd_running
        self.state.cd_is_paused = self.cd_paused
        self.state.cd_is_completed = self.cd_completed
        self.state.cd_is_overtime = self.cd_overtime
        self.state.cd_overtime_sec = self.cd_overtime_sec
        self.state.cd_remaining_sec = self.cd_remaining_sec
        self.state.cd_total_sec = self.cd_total_sec
        self.state.cd_mode = self.cd_mode

        # 2. 同步独立秒表状态
        self.state.sw_is_running = self.sw_running
        self.state.sw_is_paused = self.sw_paused
        self.state.sw_elapsed_sec = self.sw_elapsed_sec
        self.state.sw_laps = self.sw_laps

        # 3. 同步大卡片正在查看的活跃轨兼容字段
        if self.active_type == "countdown":
            self.state.timer_type = "countdown"
            self.state.timer_is_running = self.cd_running
            self.state.timer_is_paused = self.cd_paused
            self.state.timer_is_completed = self.cd_completed
            self.state.timer_is_overtime = self.cd_overtime
            self.state.timer_overtime_sec = self.cd_overtime_sec
            self.state.timer_remaining_sec = self.cd_remaining_sec
            self.state.timer_total_sec = self.cd_total_sec
            self.state.timer_mode = self.cd_mode
            self.state.timer_elapsed_sec = 0
            self.state.timer_laps = []
        else:
            self.state.timer_type = "stopwatch"
            self.state.timer_is_running = self.sw_running
            self.state.timer_is_paused = self.sw_paused
            self.state.timer_is_completed = False
            self.state.timer_is_overtime = False
            self.state.timer_overtime_sec = 0
            self.state.timer_remaining_sec = 0
            self.state.timer_total_sec = 0
            self.state.timer_mode = "stopwatch"
            self.state.timer_elapsed_sec = self.sw_elapsed_sec
            self.state.timer_laps = self.sw_laps

    # =========================================================================
    # 业务接口
    # =========================================================================
    async def switch_type(self, timer_type: str):
        if timer_type in ("countdown", "stopwatch") and self.active_type != timer_type:
            self.active_type = timer_type
            self._sync_to_state()
            self.notify("TIMER_UPDATE")

    async def toggle_pause(self):
        if self.active_type == "countdown":
            if not self.cd_running and not self.cd_paused:
                self.cd_running = True
                self.cd_paused = False
            elif self.cd_running:
                self.cd_running = False
                self.cd_paused = True
            elif self.cd_paused:
                self.cd_running = True
                self.cd_paused = False
        else:
            if not self.sw_running and not self.sw_paused:
                self.sw_running = True
                self.sw_paused = False
            elif self.sw_running:
                self.sw_running = False
                self.sw_paused = True
            elif self.sw_paused:
                self.sw_running = True
                self.sw_paused = False

        self._ensure_ticker()
        self._sync_to_state()
        self.notify("TIMER_UPDATE")

    async def start_preset(self, seconds: int, mode: str):
        self.active_type = "countdown"
        self.cd_total_sec = seconds
        self.cd_remaining_sec = seconds
        self.cd_mode = mode
        self.cd_completed = False
        self.cd_overtime = False
        self.cd_overtime_sec = 0
        self.cd_paused = False
        self.cd_running = True

        self._ensure_ticker()
        self._sync_to_state()
        self.notify("TIMER_UPDATE")

    async def adjust_time(self, delta_sec: int):
        if self.active_type != "countdown" or self.cd_running:
            return

        self.cd_completed = False
        self.cd_overtime = False
        self.cd_overtime_sec = 0

        target = max(0, self.cd_remaining_sec + delta_sec)
        self.cd_remaining_sec = target
        self.cd_total_sec = max(target, 1)
        self.cd_mode = "custom"

        self._sync_to_state()
        self.notify("TIMER_UPDATE")

    async def record_lap(self):
        if self.active_type != "stopwatch" or not self.sw_running:
            return
        s = self.sw_elapsed_sec
        h, rem = divmod(s, 3600)
        m, sec = divmod(rem, 60)
        time_str = f"{h:02d}:{m:02d}:{sec:02d}" if h > 0 else f"{m:02d}:{sec:02d}"

        self.sw_laps.insert(0, {
            "id": len(self.sw_laps) + 1,
            "time": time_str
        })
        if len(self.sw_laps) > 4:
            self.sw_laps.pop()

        self._sync_to_state()
        self.notify("TIMER_UPDATE")

    async def reset(self):
        """重置当前活跃页面对应的那一轨"""
        if self.active_type == "countdown":
            self.cd_running = False
            self.cd_paused = False
            self.cd_completed = False
            self.cd_overtime = False
            self.cd_overtime_sec = 0
            self.cd_remaining_sec = self.cd_total_sec
        else:
            self.sw_running = False
            self.sw_paused = False
            self.sw_elapsed_sec = 0
            self.sw_laps.clear()

        self._ensure_ticker()
        self._sync_to_state()
        self.notify("TIMER_UPDATE")

    async def reset_specific(self, track_type: str):
        """🚀 单独重置指定的一轨 (countdown / stopwatch)"""
        if track_type == "countdown":
            self.cd_running = False
            self.cd_paused = False
            self.cd_completed = False
            self.cd_overtime = False
            self.cd_overtime_sec = 0
            self.cd_remaining_sec = self.cd_total_sec
        elif track_type == "stopwatch":
            self.sw_running = False
            self.sw_paused = False
            self.sw_elapsed_sec = 0
            self.sw_laps.clear()

        self._ensure_ticker()
        self._sync_to_state()
        self.notify("TIMER_UPDATE")