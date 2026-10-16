# ==========================================
# 📄 File: backend/modules/audio.py
# 🌟 原生 pulsectl 驱动 (0延迟 · 完美融入 KDE)
# ==========================================
import asyncio
import threading
import pulsectl
from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class AudioModule(BaseModule):
    """基于 pulsectl 的纯事件驱动音频模块，杜绝一切命令行调用与延迟"""

    def __init__(self, backend, state: IslandState):
        super().__init__(backend, state)
        self._running = False
        self._monitor_thread = None

    async def start(self) -> None:
        self._running = True
        self._monitor_thread = threading.Thread(
            target=self._pulse_monitor_worker,
            daemon=True,
            name="PulseMonitorWorker"
        )
        self._monitor_thread.start()
        app_logger.info("✅ 原生 pulsectl 音频驱动引擎已挂载 (与 KDE 完美同步)")

    async def stop(self) -> None:
        self._running = False

    def _sync_state_locked(self, pulse: pulsectl.Pulse):
        """同步真实硬件状态到系统内存"""
        try:
            server_info = pulse.server_info()
            default_sink_name = server_info.default_sink_name
            default_source_name = server_info.default_source_name

            # 1. 同步扬声器
            if default_sink_name:
                sink = pulse.get_sink_by_name(default_sink_name)
                vol = int(round(sink.volume.value_flat * 100))
                muted = bool(sink.mute)
                if self.state.volume != vol or self.state.is_muted != muted:
                    self.state.volume = max(0, min(100, vol))
                    self.state.is_muted = muted
                    self.notify("VOLUME_UPDATE")

            # 2. 同步麦克风
            if default_source_name:
                source = pulse.get_source_by_name(default_source_name)
                vol = int(round(source.volume.value_flat * 100))
                muted = bool(source.mute)
                if self.state.mic_volume != vol or self.state.is_mic_muted != muted:
                    self.state.mic_volume = max(0, min(100, vol))
                    self.state.is_mic_muted = muted
                    self.notify("MIC_UPDATE")
        except Exception:
            pass

    def _pulse_monitor_worker(self):
        """后台驻留的守护线程：利用事件中断代替轮询"""
        while self._running:
            try:
                # 专用监控实例
                with pulsectl.Pulse('alcove-island-monitor') as pulse:
                    self._sync_state_locked(pulse)

                    # 当硬件产生变化时，中断监听循环
                    def callback(ev):
                        raise pulsectl.PulseLoopStop()

                    pulse.event_mask_set('sink', 'source', 'server')
                    pulse.event_callback_set(callback)

                    while self._running:
                        try:
                            # 挂起线程，直到音频硬件发生变化
                            pulse.event_listen(timeout=2.0)
                        except pulsectl.PulseLoopStop:
                            # 触发变化，立刻同步最新状态！
                            self._sync_state_locked(pulse)
            except Exception as e:
                app_logger.warning(f"PulseAudio 监听断开，2秒后重试: {e}")
                import time
                time.sleep(2)

    async def set_volume(self, target_percent: int) -> None:
        target = max(0, min(100, int(target_percent)))
        
        # 🚀 乐观更新：立刻通知前端，消灭 UI 延迟感
        self.state.volume = target
        self.state.is_muted = False
        self.notify("VOLUME_UPDATE")
        
        # 独立线程发指令，绝不阻塞 asyncio
        def _do_set():
            try:
                with pulsectl.Pulse('alcove-island-cmd') as pulse:
                    sink_name = pulse.server_info().default_sink_name
                    sink = pulse.get_sink_by_name(sink_name)
                    pulse.volume_set_all_chans(sink, target / 100.0)
                    pulse.mute(sink, False)
            except Exception as e:
                app_logger.error(f"设置音量失败: {e}")
        
        threading.Thread(target=_do_set, daemon=True).start()

    async def set_delta(self, delta_percent: int) -> None:
        await self.set_volume(self.state.volume + delta_percent)

    async def toggle_mute(self) -> None:
        self.state.is_muted = not self.state.is_muted
        self.notify("VOLUME_UPDATE")

        def _do_mute():
            try:
                with pulsectl.Pulse('alcove-island-cmd') as pulse:
                    sink_name = pulse.server_info().default_sink_name
                    sink = pulse.get_sink_by_name(sink_name)
                    pulse.mute(sink, self.state.is_muted)
            except Exception:
                pass
        threading.Thread(target=_do_mute, daemon=True).start()

    async def toggle_mic_mute(self) -> None:
        self.state.is_mic_muted = not self.state.is_mic_muted
        self.notify("MIC_UPDATE")

        def _do_mute():
            try:
                with pulsectl.Pulse('alcove-island-cmd') as pulse:
                    src_name = pulse.server_info().default_source_name
                    src = pulse.get_source_by_name(src_name)
                    pulse.mute(src, self.state.is_mic_muted)
            except Exception:
                pass
        threading.Thread(target=_do_mute, daemon=True).start()
