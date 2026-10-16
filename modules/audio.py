# ==========================================
# 📄 File: modules/audio.py (零开销·退火休眠事件驱动版)
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
    自适应休眠音频驱动：
    - 常态静默（5秒超长探针或等待信号）
    - 操作时激活 20Hz 极速响应，并在 1.2 秒内对数退火至休眠，杜绝无意义的 CPU 轮询消耗。
    """
    def __init__(self, state: IslandState, dispatcher):
        self.state = state
        self.dispatcher = dispatcher
        self.log = logger.bind(module="AUDIO")

        self.wpctl_bin: Optional[str] = None
        self._poller_task: Optional[asyncio.Task] = None
        self._running = False
        self._active_burst_ticks = 0

    async def init(self) -> None:
        self.wpctl_bin = shutil.which("wpctl")
        if not self.wpctl_bin:
            self.log.error("未检测到 wpctl 命令！")
            return

        self._running = True
        await self._poll_hardware_once(query_source=True)
        self._poller_task = asyncio.create_task(self._adaptive_poller_loop())
        self.log.success(f"音频模块零开销引擎就绪 | 初始音量: {self.state.volume}%")

    async def close(self) -> None:
        self._running = False
        if self._poller_task and not self._poller_task.done():
            self._poller_task.cancel()
            try:
                await self._poller_task
            except asyncio.CancelledError:
                pass

    def _activate_burst(self, ticks: int = 12):
        """激发短周期高频捕获（用于外部音量旋钮操作或 UI 滑动）"""
        self._active_burst_ticks = max(self._active_burst_ticks, ticks)

    async def set_volume(self, target_percent: int) -> None:
        target = max(0, min(100, int(target_percent)))
        if self.state.volume == target and not self.state.is_muted:
            return

        self.state.volume = target
        self.state.is_muted = False
        self.dispatcher.broadcast("VOLUME_UPDATE")

        self._activate_burst(10)
        val = f"{target / 100.0:.2f}"
        asyncio.create_task(self._exec_wpctl("set-volume", "--limit", "1.0", "@DEFAULT_AUDIO_SINK@", val))
        asyncio.create_task(self._exec_wpctl("set-mute", "@DEFAULT_AUDIO_SINK@", "0"))

    async def set_delta(self, delta_percent: int) -> None:
        await self.set_volume(self.state.volume + delta_percent)

    async def toggle_mute(self) -> None:
        self.state.is_muted = not self.state.is_muted
        self.dispatcher.broadcast("VOLUME_UPDATE")
        self._activate_burst(8)
        mute_arg = "1" if self.state.is_muted else "0"
        asyncio.create_task(self._exec_wpctl("set-mute", "@DEFAULT_AUDIO_SINK@", mute_arg))

    async def set_mic_volume(self, target_percent: int) -> None:
        target = max(0, min(100, int(target_percent)))
        if self.state.mic_volume == target and not self.state.is_mic_muted:
            return

        self.state.mic_volume = target
        self.state.is_mic_muted = False
        self.dispatcher.broadcast("MIC_UPDATE")
        self._activate_burst(10)
        val = f"{target / 100.0:.2f}"
        asyncio.create_task(self._exec_wpctl("set-volume", "--limit", "1.0", "@DEFAULT_AUDIO_SOURCE@", val))
        asyncio.create_task(self._exec_wpctl("set-mute", "@DEFAULT_AUDIO_SOURCE@", "0"))

    async def set_mic_delta(self, delta_percent: int) -> None:
        await self.set_mic_volume(self.state.mic_volume + delta_percent)

    async def toggle_mic_mute(self) -> None:
        self.state.is_mic_muted = not self.state.is_mic_muted
        self.dispatcher.broadcast("MIC_UPDATE")
        self._activate_burst(8)
        mute_arg = "1" if self.state.is_mic_muted else "0"
        asyncio.create_task(self._exec_wpctl("set-mute", "@DEFAULT_AUDIO_SOURCE@", mute_arg))

    async def _exec_wpctl(self, *args: str) -> str:
        try:
            proc = await asyncio.create_subprocess_exec(
                self.wpctl_bin, *args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            )
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=0.25)
            return stdout.decode(errors="ignore").strip()
        except Exception:
            return ""

    async def _poll_hardware_once(self, query_source: bool = False) -> bool:
        sink_out = await self._exec_wpctl("get-volume", "@DEFAULT_AUDIO_SINK@")
        changed = False

        if sink_out:
            if m := re.search(r"Volume:\s+([0-9.]+)", sink_out):
                cur_vol = min(100, int(round(float(m.group(1)) * 100)))
                cur_mute = "[MUTED]" in sink_out
                if self.state.volume != cur_vol or self.state.is_muted != cur_mute:
                    self.state.volume = cur_vol
                    self.state.is_muted = cur_mute
                    self.dispatcher.broadcast("VOLUME_UPDATE")
                    changed = True

        if query_source:
            source_out = await self._exec_wpctl("get-volume", "@DEFAULT_AUDIO_SOURCE@")
            if source_out:
                if m := re.search(r"Volume:\s+([0-9.]+)", source_out):
                    cur_mic_vol = min(100, int(round(float(m.group(1)) * 100)))
                    cur_mic_mute = "[MUTED]" in source_out
                    if self.state.mic_volume != cur_mic_vol or self.state.is_mic_muted != cur_mic_mute:
                        self.state.mic_volume = cur_mic_vol
                        self.state.is_mic_muted = cur_mic_mute
                        self.dispatcher.broadcast("MIC_UPDATE")
                        changed = True

        return changed

    async def _adaptive_poller_loop(self) -> None:
        """根据动态负载退火休眠，低负载时 4000ms 查询一次，高频操作时 80ms 跟踪"""
        while self._running:
            try:
                if self._active_burst_ticks > 0:
                    self._active_burst_ticks -= 1
                    await self._poll_hardware_once(query_source=True)
                    await asyncio.sleep(0.08)
                else:
                    await asyncio.sleep(4.0)
                    changed = await self._poll_hardware_once(query_source=False)
                    if changed:
                        self._activate_burst(8)
            except asyncio.CancelledError:
                break
            except Exception:
                await asyncio.sleep(4.0)