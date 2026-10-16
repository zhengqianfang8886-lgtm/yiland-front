# ==========================================
# 📄 File: modules/audio.py (优化版：0子进程轰炸·极低能耗)
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
    def __init__(self, state: IslandState, dispatcher):
        self.state = state
        self.dispatcher = dispatcher
        self.log = logger.bind(module="AUDIO")

        self.wpctl_bin: Optional[str] = None
        self._poller_task: Optional[asyncio.Task] = None
        self._running = False
        self._fast_ticks = 0

    async def init(self) -> None:
        self.wpctl_bin = shutil.which("wpctl")
        if not self.wpctl_bin:
            self.log.error("未检测到 wpctl 命令！")
            return

        self._running = True
        await self._poll_hardware_once()
        self._poller_task = asyncio.create_task(self._adaptive_poller_loop())
        self.log.success(f"音频模块就绪 (低功耗模式) | 初始音量: {self.state.volume}%")

    async def close(self) -> None:
        self._running = False
        if self._poller_task and not self._poller_task.done():
            self._poller_task.cancel()
            try:
                await self._poller_task
            except asyncio.CancelledError:
                pass

    # 用户主动操作时，开启 1.5 秒极速跟手模式
    def _wake_fast_polling(self, ticks: int = 15):
        self._fast_ticks = max(self._fast_ticks, ticks)

    async def set_volume(self, target_percent: int) -> None:
        target = max(0, min(100, int(target_percent)))
        self.state.volume = target
        if self.state.is_muted:
            self.state.is_muted = False
        self.dispatcher.broadcast("VOLUME_UPDATE")

        self._wake_fast_polling(15)
        val = round(target / 100.0, 2)
        asyncio.create_task(self._exec_wpctl("set-volume", "--limit", "1.0", "@DEFAULT_AUDIO_SINK@", str(val)))
        asyncio.create_task(self._exec_wpctl("set-mute", "@DEFAULT_AUDIO_SINK@", "0"))

    async def set_delta(self, delta_percent: int) -> None:
        await self.set_volume(self.state.volume + delta_percent)

    async def toggle_mute(self) -> None:
        self.state.is_muted = not self.state.is_muted
        self.dispatcher.broadcast("VOLUME_UPDATE")
        self._wake_fast_polling(10)
        mute_arg = "1" if self.state.is_muted else "0"
        asyncio.create_task(self._exec_wpctl("set-mute", "@DEFAULT_AUDIO_SINK@", mute_arg))

    async def set_mic_volume(self, target_percent: int) -> None:
        target = max(0, min(100, int(target_percent)))
        self.state.mic_volume = target
        if self.state.is_mic_muted:
            self.state.is_mic_muted = False
        self.dispatcher.broadcast("MIC_UPDATE")
        self._wake_fast_polling(15)
        val = round(target / 100.0, 2)
        asyncio.create_task(self._exec_wpctl("set-volume", "--limit", "1.0", "@DEFAULT_AUDIO_SOURCE@", str(val)))
        asyncio.create_task(self._exec_wpctl("set-mute", "@DEFAULT_AUDIO_SOURCE@", "0"))

    async def set_mic_delta(self, delta_percent: int) -> None:
        await self.set_mic_volume(self.state.mic_volume + delta_percent)

    async def toggle_mic_mute(self) -> None:
        self.state.is_mic_muted = not self.state.is_mic_muted
        self.dispatcher.broadcast("MIC_UPDATE")
        self._wake_fast_polling(10)
        mute_arg = "1" if self.state.is_mic_muted else "0"
        asyncio.create_task(self._exec_wpctl("set-mute", "@DEFAULT_AUDIO_SOURCE@", mute_arg))

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

    async def _poll_hardware_once(self) -> bool:
        sink_out = await self._exec_wpctl("get-volume", "@DEFAULT_AUDIO_SINK@")
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

        # 麦克风仅在有快轮询需求时才查，降低一半子进程开销
        if self._fast_ticks > 0:
            source_out = await self._exec_wpctl("get-volume", "@DEFAULT_AUDIO_SOURCE@")
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
        while self._running:
            try:
                changed = await self._poll_hardware_once()
                if changed:
                    self._fast_ticks = 15

                if self._fast_ticks > 0:
                    self._fast_ticks -= 1
                    await asyncio.sleep(0.08) # 响应实体快捷键调音量时极速跟手
                else:
                    # 🚀 核心优化：空闲时从 0.25 秒延长至 2.5 秒，彻底释放 CPU！
                    await asyncio.sleep(2.5)

            except asyncio.CancelledError:
                break
            except Exception as e:
                self.log.debug(f"采样异常: {e}")
                await asyncio.sleep(2.5)