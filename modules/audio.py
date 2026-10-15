# ==========================================
# 📄 File: modules/audio.py
# 🌟 原生 PipeWire / WirePlumber 音频直通模块
# ==========================================
import re
import shutil
import asyncio
from typing import Optional
try:
    from loguru import logger
except ImportError:
    from logger import app_logger as logger

from core.state import IslandState


class AudioModule:
    """
    针对现代 PipeWire / WirePlumber 的直通音频驱动：
    1. 原生对齐 wpctl，完美识别实体多媒体键与外部改动
    2. 自适应微采样：变动时 80ms 极速跟手，静止时 250ms 静默，极低 CPU 消耗
    3. 乐观更新（Optimistic UI）：前端滑动零延迟立刻响应
    """

    def __init__(self, state: IslandState, dispatcher):
        self.state = state
        self.dispatcher = dispatcher
        self.log = logger.bind(module="AUDIO")

        self.wpctl_bin: Optional[str] = None
        self._poller_task: Optional[asyncio.Task] = None
        self._running = False

    async def init(self) -> None:
        self.wpctl_bin = shutil.which("wpctl")
        if not self.wpctl_bin:
            self.log.error("未检测到 wpctl 命令！请确认系统是否为 PipeWire 环境")
            return

        self._running = True
        await self._poll_hardware_once()
        self._poller_task = asyncio.create_task(self._adaptive_poller_loop())

        self.log.success(
            f"音频模块就绪 (WirePlumber 直通架构) | 初始音量: {self.state.volume}% (静音: {self.state.is_muted}) | "
            f"麦克风: {self.state.mic_volume}% (闭麦: {self.state.is_mic_muted})"
        )

    async def close(self) -> None:
        self._running = False
        if self._poller_task and not self._poller_task.done():
            self._poller_task.cancel()
            try:
                await self._poller_task
            except asyncio.CancelledError:
                pass

    # =========================================================================
    # 主动调节 API (Optimistic UI 零延迟直通)
    # =========================================================================
    async def set_volume(self, target_percent: int) -> None:
        target = max(0, min(100, int(target_percent)))
        self.state.volume = target
        if self.state.is_muted:
            self.state.is_muted = False
        self.dispatcher.broadcast("VOLUME_UPDATE")

        val = round(target / 100.0, 2)
        asyncio.create_task(self._exec_wpctl("set-volume", "--limit", "1.0", "@DEFAULT_AUDIO_SINK@", str(val)))
        asyncio.create_task(self._exec_wpctl("set-mute", "@DEFAULT_AUDIO_SINK@", "0"))

    async def set_delta(self, delta_percent: int) -> None:
        await self.set_volume(self.state.volume + delta_percent)

    async def toggle_mute(self) -> None:
        self.state.is_muted = not self.state.is_muted
        self.dispatcher.broadcast("VOLUME_UPDATE")

        mute_arg = "1" if self.state.is_muted else "0"
        asyncio.create_task(self._exec_wpctl("set-mute", "@DEFAULT_AUDIO_SINK@", mute_arg))

    async def set_mic_volume(self, target_percent: int) -> None:
        target = max(0, min(100, int(target_percent)))
        self.state.mic_volume = target
        if self.state.is_mic_muted:
            self.state.is_mic_muted = False
        self.dispatcher.broadcast("MIC_UPDATE")

        val = round(target / 100.0, 2)
        asyncio.create_task(self._exec_wpctl("set-volume", "--limit", "1.0", "@DEFAULT_AUDIO_SOURCE@", str(val)))
        asyncio.create_task(self._exec_wpctl("set-mute", "@DEFAULT_AUDIO_SOURCE@", "0"))

    async def set_mic_delta(self, delta_percent: int) -> None:
        await self.set_mic_volume(self.state.mic_volume + delta_percent)

    async def toggle_mic_mute(self) -> None:
        self.state.is_mic_muted = not self.state.is_mic_muted
        self.dispatcher.broadcast("MIC_UPDATE")

        mute_arg = "1" if self.state.is_mic_muted else "0"
        asyncio.create_task(self._exec_wpctl("set-mute", "@DEFAULT_AUDIO_SOURCE@", mute_arg))

    # =========================================================================
    # 底层指令异步执行
    # =========================================================================
    async def _exec_wpctl(self, *args: str) -> str:
        try:
            proc = await asyncio.create_subprocess_exec(
                self.wpctl_bin, *args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=0.3)
            return stdout.decode(errors="ignore").strip()
        except Exception:
            return ""

    # =========================================================================
    # 硬件采样与自适应动态调度
    # =========================================================================
    async def _poll_hardware_once(self) -> bool:
        sink_task = self._exec_wpctl("get-volume", "@DEFAULT_AUDIO_SINK@")
        source_task = self._exec_wpctl("get-volume", "@DEFAULT_AUDIO_SOURCE@")

        sink_out, source_out = await asyncio.gather(sink_task, source_task)
        any_changed = False

        if sink_out:
            if m := re.search(r"Volume:\s+([0-9.]+)", sink_out):
                cur_vol = min(100, int(round(float(m.group(1)) * 100)))
                cur_mute = "[MUTED]" in sink_out

                if (self.state.volume != cur_vol) or (self.state.is_muted != cur_mute):
                    self.state.volume = cur_vol
                    self.state.is_muted = cur_mute
                    self.dispatcher.broadcast("VOLUME_UPDATE")
                    any_changed = True

        if source_out:
            if m := re.search(r"Volume:\s+([0-9.]+)", source_out):
                cur_mic_vol = min(100, int(round(float(m.group(1)) * 100)))
                cur_mic_mute = "[MUTED]" in source_out

                if (self.state.mic_volume != cur_mic_vol) or (self.state.is_mic_muted != cur_mic_mute):
                    self.state.mic_volume = cur_mic_vol
                    self.state.is_mic_muted = cur_mic_mute
                    self.dispatcher.broadcast("MIC_UPDATE")
                    any_changed = True

        return any_changed

    async def _adaptive_poller_loop(self) -> None:
        fast_ticks_remaining = 0

        while self._running:
            try:
                changed = await self._poll_hardware_once()
                if changed:
                    fast_ticks_remaining = 15

                if fast_ticks_remaining > 0:
                    fast_ticks_remaining -= 1
                    await asyncio.sleep(0.08)
                else:
                    await asyncio.sleep(0.25)

            except asyncio.CancelledError:
                break
            except Exception as e:
                self.log.debug(f"采样轮询异常: {e}")
                await asyncio.sleep(0.5)