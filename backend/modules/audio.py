# ==========================================
# 📄 File: backend/modules/audio.py
# 🌟 原生 pulsectl 驱动 (纯净静默版 · 彻底拔除高频刷屏日志)
# ==========================================
import time
import asyncio
import threading
from typing import Optional

import pulsectl
from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class AudioModule(BaseModule):
    """基于 pulsectl 的高性能事件驱动音频模块
    
    架构设计:
      1. PulseMonitorWorker: 独占一条长连接，事件中断无轮询监听系统音量突变。
      2. PulseCommandWorker: 独占一条常驻指令长连接，配合原子邮箱机制，
         将毫秒级高频调音（滚轮/滑条拖动）自动合并，彻底根除高频建立线程与连接的问题。
    """

    def __init__(self, backend, state: IslandState):
        super().__init__(backend, state)
        self._running = False
        
        # 1. 监听线程
        self._monitor_thread: Optional[threading.Thread] = None

        # 2. 常驻控制线程与状态折叠邮箱
        self._cmd_thread: Optional[threading.Thread] = None
        self._cmd_event = threading.Event()
        self._cmd_lock = threading.Lock()
        
        # 待同步的目标硬件状态缓存 (None 表示该字段暂无变更)
        self._target_sink_volume: Optional[int] = None
        self._target_sink_mute: Optional[bool] = None
        self._target_source_mute: Optional[bool] = None

    async def start(self) -> None:
        self._running = True

        # 启动常驻事件监听线程
        self._monitor_thread = threading.Thread(
            target=self._pulse_monitor_worker,
            daemon=True,
            name="PulseMonitorWorker"
        )
        self._monitor_thread.start()

        # 启动常驻硬件指令执行工作线程
        self._cmd_thread = threading.Thread(
            target=self._pulse_cmd_worker,
            daemon=True,
            name="PulseCommandWorker"
        )
        self._cmd_thread.start()

        app_logger.info("✅ 原生 pulsectl 音频引擎就绪 (纯净静默模式)")

    async def stop(self) -> None:
        self._running = False
        self._cmd_event.set()

    # =========================================================================
    # 1. 监听通道 (Monitor Pipeline)
    # =========================================================================
    def _sync_state_locked(self, pulse: pulsectl.Pulse):
        """同步真实硬件状态到单一事实源 (SSOT)"""
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
                    # 🚀 彻底清除了这里的【音量日志触发点 1】
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
        """后台常驻监听守护线程：利用 PulseLoopStop 事件中断代替盲目轮询"""
        while self._running:
            try:
                with pulsectl.Pulse('alcove-island-monitor') as pulse:
                    self._sync_state_locked(pulse)

                    def callback(ev):
                        raise pulsectl.PulseLoopStop()

                    pulse.event_mask_set('sink', 'source', 'server')
                    pulse.event_callback_set(callback)

                    while self._running:
                        try:
                            pulse.event_listen(timeout=2.0)
                        except pulsectl.PulseLoopStop:
                            self._sync_state_locked(pulse)
            except Exception as e:
                if self._running:
                    app_logger.warning(f"PulseAudio 监听通道异常断开，2秒后尝试重连: {e}")
                    time.sleep(2)

    # =========================================================================
    # 2. 指令通道 (Command Pipeline - 单一常驻 + 折叠合并)
    # =========================================================================
    def _pulse_cmd_worker(self):
        """后台常驻指令下发线程：维护独立的长连接，顺序消费折叠后的硬件请求"""
        while self._running:
            try:
                with pulsectl.Pulse('alcove-island-cmd') as pulse:
                    while self._running:
                        self._cmd_event.wait(timeout=1.0)
                        if not self._running:
                            break

                        if not self._cmd_event.is_set():
                            continue

                        # 🔒 原子取出并重置目标状态
                        with self._cmd_lock:
                            self._cmd_event.clear()
                            target_vol = self._target_sink_volume
                            target_sink_mute = self._target_sink_mute
                            target_src_mute = self._target_source_mute
                            self._target_sink_volume = None
                            self._target_sink_mute = None
                            self._target_source_mute = None

                        try:
                            server_info = pulse.server_info()

                            if (target_vol is not None or target_sink_mute is not None) and server_info.default_sink_name:
                                sink = pulse.get_sink_by_name(server_info.default_sink_name)
                                if target_vol is not None:
                                    pulse.volume_set_all_chans(sink, target_vol / 100.0)
                                if target_sink_mute is not None:
                                    pulse.mute(sink, target_sink_mute)

                            if target_src_mute is not None and server_info.default_source_name:
                                source = pulse.get_source_by_name(server_info.default_source_name)
                                pulse.mute(source, target_src_mute)

                        except Exception as cmd_err:
                            app_logger.error(f"[AudioModule] 执行底层硬件指令异常: {cmd_err}")

            except Exception as conn_err:
                if self._running:
                    app_logger.warning(f"[AudioModule] 指令通道断开，1秒后重建连接: {conn_err}")
                    time.sleep(1)

    # =========================================================================
    # 3. 对外业务接口 (保持完全异步契约与乐观响应)
    # =========================================================================
    async def set_volume(self, target_percent: int) -> None:
        target = max(0, min(100, int(target_percent)))

        # 🚀 彻底清除了这里的【音量日志触发点 2】
        
        # 1. 乐观更新内存事实源与 GUI（零输入延迟）
        self.state.volume = target
        self.state.is_muted = False
        self.notify("VOLUME_UPDATE")

        # 2. 状态投递并折叠进命令管道
        with self._cmd_lock:
            self._target_sink_volume = target
            self._target_sink_mute = False
            self._cmd_event.set()

    async def set_delta(self, delta_percent: int) -> None:
        # 🚀 彻底清除了这里的【音量日志触发点 3】
        await self.set_volume(self.state.volume + delta_percent)

    async def toggle_mute(self) -> None:
        self.state.is_muted = not self.state.is_muted
        # 🚀 彻底清除了这里的【音量日志触发点 4】
        self.notify("VOLUME_UPDATE")

        with self._cmd_lock:
            self._target_sink_mute = self.state.is_muted
            self._cmd_event.set()

    async def toggle_mic_mute(self) -> None:
        self.state.is_mic_muted = not self.state.is_mic_muted
        self.notify("MIC_UPDATE")

        with self._cmd_lock:
            self._target_source_mute = self.state.is_mic_muted
            self._cmd_event.set()