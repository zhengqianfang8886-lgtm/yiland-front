# ==========================================
# 📄 File: backend/modules/timer.py
# 🌟 原生异步专注计时器驱动 (契约打断 · 根除协程自消亡 Bug)
# ==========================================
import asyncio
from typing import Optional

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class TimerModule(BaseModule):
    """纯事件驱动的系统级计时器服务，切页绝不重置数据"""

    def __init__(self, backend, state: IslandState):
        super().__init__(backend, state)
        self._ticker_task: Optional[asyncio.Task] = None

    async def start(self) -> None:
        app_logger.info("✅ 原生异步后台计时引擎已挂载")

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

                if self.state.timer_type == "stopwatch":
                    self.state.timer_elapsed_sec += 1
                    self.notify("TIMER_UPDATE")
                else:
                    if self.state.timer_remaining_sec > 1:
                        self.state.timer_remaining_sec -= 1
                        self.notify("TIMER_UPDATE")
                    else:
                        # 🚀 计时到达终点
                        self.state.timer_remaining_sec = 0
                        self.state.timer_is_running = False
                        self.state.timer_is_paused = False
                        self.state.timer_is_completed = True
                        self.notify("TIMER_UPDATE")

                        # 契约化触发系统级打断弹窗（线程安全、物理先发唤醒）
                        if self.state.timer_mode == "break":
                            self.trigger_overlay(
                                key="ALERT",
                                title="休息结束",
                                subtitle="精力充沛，准备开启下一次专注吧 🚀",
                                icon="⏰",
                                duration_ms=5000,
                                priority=45
                            )
                        else:
                            self.trigger_overlay(
                                key="ALERT",
                                title="专注完成",
                                subtitle="倒计时已结束，站起来活动一下身体",
                                icon="⏰",
                                duration_ms=5000,
                                priority=45
                            )
                        
                        # 正常退出循环，严禁在任务内调用 _stop_ticker() 导致自杀中断
                        break
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
        if self.state.timer_is_completed:
            await self.reset()
            return

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
        self.state.timer_is_paused = False
        self.state.timer_is_running = True
        self._start_ticker()
        self.notify("TIMER_UPDATE")

    async def adjust_time(self, delta_sec: int):
        if self.state.timer_is_running or self.state.timer_type == "stopwatch":
            return
        self.state.timer_is_completed = False
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
        if self.state.timer_type == "stopwatch":
            self.state.timer_elapsed_sec = 0
            self.state.timer_laps = []
        else:
            self.state.timer_remaining_sec = self.state.timer_total_sec
        self.notify("TIMER_UPDATE")