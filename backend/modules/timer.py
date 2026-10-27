# ==========================================
# 📄 File: backend/modules/timer.py
# 🌟 原生异步专注计时器驱动 (支持超时正向追溯计时)
# ==========================================
import asyncio
from typing import Optional

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class TimerModule(BaseModule):
    def __init__(self, backend, state: IslandState):
        super().__init__(backend, state)
        self._ticker_task: Optional[asyncio.Task] = None

    async def start(self) -> None:
        app_logger.info("✅ 原生异步后台计时引擎已挂载 (支持超时正向追溯)")

    async def stop(self) -> None:
        self._stop_ticker()

    def _start_ticker(self):
        if self._ticker_task is None or self._ticker_task.done():
            self._ticker_task = asyncio.create_task(self._tick_loop())

    def _stop_ticker(self):
        if self._ticker_task and not self._ticker_task.done():
            self._ticker_task.cancel()
        self._ticker_task = None

    async def _tick_loop(self):
        try:
            while self.state.timer_is_running:
                await asyncio.sleep(1.0)
                if not self.state.timer_is_running:
                    break

                # 1. 秒表正向计时
                if self.state.timer_type == "stopwatch":
                    self.state.timer_elapsed_sec += 1
                    self.notify("TIMER_UPDATE")

                # 2. 🚀 超时正向追溯阶段 (连续累加)
                elif self.state.timer_is_overtime:
                    self.state.timer_overtime_sec += 1
                    # 保护阈值：超时超过 2 小时自动挂起保护
                    if self.state.timer_overtime_sec >= 7200:
                        self.state.timer_is_running = False
                        self.state.timer_is_paused = True
                    self.notify("TIMER_UPDATE")

                # 3. 正常倒计时阶段
                else:
                    if self.state.timer_remaining_sec > 1:
                        self.state.timer_remaining_sec -= 1
                        self.notify("TIMER_UPDATE")
                    else:
                        # 🚀 临界到达 00:00：无缝切入超时正向模式，绝不停机！
                        self.state.timer_remaining_sec = 0
                        self.state.timer_is_overtime = True
                        self.state.timer_overtime_sec = 0
                        self.notify("TIMER_UPDATE")

                        # 触发一次轻量级系统打断通知
                        if self.state.timer_mode == "break":
                            self.trigger_overlay(
                                key="ALERT",
                                title="休息结束",
                                subtitle="精力充沛，准备开启下一次专注吧 🚀",
                                icon="⏰",
                                duration_ms=4500,
                                priority=45
                            )
                        else:
                            self.trigger_overlay(
                                key="ALERT",
                                title="专注时间到",
                                subtitle="已自动开启超时追溯，随时收尾结束",
                                icon="⏰",
                                duration_ms=4500,
                                priority=45
                            )
                        # 继续循环，让下一次 tick 进入超时累加！
        except asyncio.CancelledError:
            pass
        finally:
            self._ticker_task = None

    async def switch_type(self, timer_type: str):
        if self.state.timer_is_running:
            return
        await self.reset()
        self.state.timer_type = timer_type
        self.notify("TIMER_UPDATE")

    async def toggle_pause(self):
        # 处于超时或运行中时支持随时暂停与继续
        if not self.state.timer_is_running and not self.state.timer_is_paused:
            self.state.timer_is_paused = False
            self.state.timer_is_running = True
            self._start_ticker()
        elif self.state.timer_is_running:
            self.state.timer_is_paused = True
            self.state.timer_is_running = False
            self._stop_ticker()
        elif self.state.timer_is_paused:
            self.state.timer_is_running = True
            self.state.timer_is_paused = False
            self._start_ticker()

        self.notify("TIMER_UPDATE")

    async def start_preset(self, seconds: int, mode: str):
        if self.state.timer_is_running:
            return
        self.state.timer_type = "countdown"
        self.state.timer_total_sec = seconds
        self.state.timer_remaining_sec = seconds
        self.state.timer_mode = mode
        self.state.timer_is_completed = False
        self.state.timer_is_overtime = False
        self.state.timer_overtime_sec = 0
        self.state.timer_is_paused = False
        self.state.timer_is_running = True
        self._start_ticker()
        self.notify("TIMER_UPDATE")

    async def adjust_time(self, delta_sec: int):
        if self.state.timer_is_running or self.state.timer_type == "stopwatch":
            return
        self.state.timer_is_completed = False
        self.state.timer_is_overtime = False
        self.state.timer_overtime_sec = 0
        target = max(0, self.state.timer_remaining_sec + delta_sec)
        self.state.timer_remaining_sec = target
        self.state.timer_total_sec = max(target, 1)
        self.state.timer_mode = "custom"
        self.notify("TIMER_UPDATE")

    async def record_lap(self):
        if not self.state.timer_is_running or self.state.timer_type != "stopwatch":
            return
        s = self.state.timer_elapsed_sec
        h, rem = divmod(s, 3600)
        m, sec = divmod(rem, 60)
        time_str = f"{h:02d}:{m:02d}:{sec:02d}" if h > 0 else f"{m:02d}:{sec:02d}"

        self.state.timer_laps.insert(0, {
            "id": len(self.state.timer_laps) + 1,
            "time": time_str
        })
        if len(self.state.timer_laps) > 3:
            self.state.timer_laps.pop()
        self.notify("TIMER_UPDATE")

    async def reset(self):
        self._stop_ticker()
        self.state.timer_is_running = False
        self.state.timer_is_paused = False
        self.state.timer_is_completed = False
        self.state.timer_is_overtime = False
        self.state.timer_overtime_sec = 0
        if self.state.timer_type == "stopwatch":
            self.state.timer_elapsed_sec = 0
            self.state.timer_laps = []
        else:
            self.state.timer_remaining_sec = self.state.timer_total_sec
        self.notify("TIMER_UPDATE")