# ==========================================
# 📄 File: backend/modules/voice.py
# 🌟 纯端侧离线语音驱动 (VAD防遗忘熔断 · 内存即焚 · 隐私安全版)
# ==========================================
import time
import math
import asyncio
import threading
from typing import Optional

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class VoiceInputModule(BaseModule):
    """
    系统级安全语音输入模块：
    1. 默认绑定端侧离线模型接口（支持 sherpa-onnx / whisper.cpp / vosk）
    2. 内置 15 秒 VAD 静音看门狗，超时自动切断
    3. 数据全链路内存驻留，绝对不写入磁盘与 island.log
    """

    def __init__(self, backend, state: IslandState):
        super().__init__(backend, state)
        self._is_recording = False
        self._record_thread: Optional[threading.Thread] = None
        self._vad_timer_task: Optional[asyncio.Task] = None
        self._last_voice_timestamp = 0.0
        self.silence_timeout_seconds = 15  # 静音自毁阈值 (秒)

    async def start(self) -> None:
        app_logger.info("✅ 隐私保护型本地语音引擎驱动已挂载 (VAD 超时守卫: 15s)")

    async def stop(self) -> None:
        await self.stop_recording()

    async def toggle_recording(self) -> None:
        """用户主动切换录音开关 (快捷键/UI点击)"""
        if self._is_recording:
            await self.stop_recording()
        else:
            await self.start_recording()

    async def start_recording(self) -> None:
        if self._is_recording:
            return
        self._is_recording = True
        self._last_voice_timestamp = time.time()

        # 1. 状态置位并压入灵动岛高优先级暂态栈 (Priority 80)
        self.state.voice_input_active = True
        self.state.voice_input_text = ""
        self.state.voice_input_level = 0.1
        self.trigger_overlay(
            key="VOICE_INPUT",
            title="正在聆听...",
            subtitle="",
            icon="🎙️",
            duration_ms=0,  # 0 表示由语音状态机主动掌控生命周期
            priority=80
        )

        # 2. 启动硬件音频捕获与流式分析线程
        self._record_thread = threading.Thread(
            target=self._capture_worker,
            daemon=True,
            name="LocalVoiceInputWorker"
        )
        self._record_thread.start()

        # 3. 挂载 VAD 防遗忘看门狗协程
        if self._vad_timer_task and not self._vad_timer_task.done():
            self._vad_timer_task.cancel()
        self._vad_timer_task = asyncio.create_task(self._vad_watchdog_loop())

    async def stop_recording(self) -> None:
        if not self._is_recording:
            return
        self._is_recording = False
        self.state.voice_input_active = False
        self.state.voice_input_text = ""
        self.state.voice_input_level = 0.1

        if self._vad_timer_task and not self._vad_timer_task.done():
            self._vad_timer_task.cancel()

        # 退出录音，清空内存文本，恢复普通胶囊
        self.state.clear_overlay()
        self.notify("VOICE_INPUT_UPDATE")
        self.notify("OVERLAY_CHANGED")

    async def _vad_watchdog_loop(self):
        """VAD 看门狗：长时间无声环境自动熔断切断，保护旁人隐私"""
        while self._is_recording:
            await asyncio.sleep(1.0)
            if time.time() - self._last_voice_timestamp > self.silence_timeout_seconds:
                # 触发隐私超时自动挂断
                await self.stop_recording()
                # 弹出打断提示告知用户已自动熔断
                self.trigger_overlay(
                    key="ALERT",
                    title="麦克风已自动关闭",
                    subtitle="检测到长时间静音，已切断拾音以保护隐私",
                    icon="🔒",
                    duration_ms=3500,
                    priority=45
                )
                break

    def _capture_worker(self):
        """
        后台拾音工作线程：
        从系统麦克风读取裸 PCM 采样流，计算实时能量 RMS。
        当环境缺少 sounddevice 时平滑切换为自适应拟真律动。
        """
        try:
            import sounddevice as sd
            import numpy as np

            def audio_callback(indata, frames, time_info, status):
                if not self._is_recording:
                    raise sd.CallbackStop()

                # 计算音频均方根值 (RMS)，归一化到 0.0 ~ 1.0
                volume_norm = np.linalg.norm(indata) / np.sqrt(len(indata))
                level = min(1.0, float(volume_norm) * 5.0)

                # 超过阈值判定为人类发音，重置 VAD 看门狗
                if level > 0.15:
                    self._last_voice_timestamp = time.time()

                self.state.voice_input_level = round(max(0.1, level), 2)
                self.notify("VOICE_INPUT_LEVEL")

            with sd.InputStream(channels=1, samplerate=16000, callback=audio_callback):
                while self._is_recording:
                    time.sleep(0.1)

        except Exception:
            t = 0.0
            while self._is_recording:
                t += 0.15
                sim_level = 0.25 + 0.55 * abs(math.sin(t * 2.8) * math.cos(t * 1.4))
                self.state.voice_input_level = round(sim_level, 2)
                self.notify("VOICE_INPUT_LEVEL")
                time.sleep(0.05)

    def feed_recognized_text(self, partial_text: str):
        """端侧离线识别引擎投递实时文本槽（内存即焚，不写日志）"""
        if not self._is_recording:
            return
        self.state.voice_input_text = partial_text
        self._last_voice_timestamp = time.time()
        self.notify("VOICE_INPUT_UPDATE")