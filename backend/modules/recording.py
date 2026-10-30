# ==========================================
# 📄 File: backend/modules/recording.py
# 🌟 原生录音与 OBS 录屏状态事件驱动模块 (零轮询·高内聚版)
# ==========================================
import time
import asyncio
import threading
from typing import Optional, List, Dict, Tuple

import pulsectl
from dbus_next.aio import MessageBus

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class RecordingModule(BaseModule):
    """
    系统级隐私与录制指示器驱动模块：
    1. 零轮询监听 PulseAudio/PipeWire 的 source_output (输入流创建/销毁)；
    2. 精准识别 OBS Studio 录屏、推流、麦克风占用；
    3. 支持通用会议与录音软件（Discord、Chrome、Teams、Audacity）；
    4. 提供一键唤醒并聚焦录制应用窗口的能力。
    """

    def __init__(self, backend, state: IslandState, bus: Optional[MessageBus] = None):
        super().__init__(backend, state)
        self.bus = bus
        self._running = False
        self._monitor_thread: Optional[threading.Thread] = None

    async def start(self) -> None:
        self._running = True
        self._monitor_thread = threading.Thread(
            target=self._recording_monitor_worker,
            daemon=True,
            name="RecordingStreamMonitor"
        )
        self._monitor_thread.start()
        app_logger.info("✅ 隐私录制与 OBS 嗅探驱动已就绪 (PipeWire/PulseAudio 事件驱动)")

    async def stop(self) -> None:
        self._running = False

    def _sync_recording_streams(self, pulse: pulsectl.Pulse):
        """同步当前系统所有录音与采集流状态"""
        try:
            source_outputs = pulse.source_output_list()
            active_recorders: List[Dict[str, str]] = []

            for output in source_outputs:
                props = output.proplist or {}
                app_name = str(props.get("application.name", "")).strip()
                binary = str(props.get("application.process.binary", "")).lower().strip()
                media_name = str(props.get("media.name", "")).lower().strip()

                # 过滤系统自身的静音回放或监视流
                if "alcove" in binary or "cava" in binary:
                    continue

                recorder_type = "mic"
                icon_hint = "mic"

                # 1. 深度指纹匹配 OBS Studio
                if "obs" in binary or "obs" in app_name.lower():
                    app_name = "OBS Studio"
                    icon_hint = "obs"
                    recorder_type = "screen" if ("desktop" in media_name or "monitor" in media_name) else "stream"
                elif "discord" in binary:
                    app_name = "Discord"
                    icon_hint = "mic"
                elif "chrome" in binary or "chromium" in binary:
                    app_name = "浏览器录音"
                    icon_hint = "web"
                elif "teams" in binary:
                    app_name = "Teams 通话"
                    icon_hint = "call"
                elif not app_name:
                    app_name = binary.capitalize() or "系统音频录制"

                active_recorders.append({
                    "name": app_name,
                    "binary": binary,
                    "icon": icon_hint,
                    "type": recorder_type
                })

            # OBS 优先仲裁：如果列表中包含 OBS，置于首位展示
            active_recorders.sort(key=lambda r: 0 if r["icon"] == "obs" else 1)

            is_active = len(active_recorders) > 0
            current_app = active_recorders[0]["name"] if is_active else ""
            current_bin = active_recorders[0]["binary"] if is_active else ""
            current_icon = active_recorders[0]["icon"] if is_active else ""
            current_type = active_recorders[0]["type"] if is_active else "mic"

            # 仅当状态突变时原子提交单一事实源并广播
            if (self.state.recording_active != is_active or 
                self.state.recording_app_name != current_app or 
                self.state.recording_app_icon != current_icon):
                
                self.state.batch_update(
                    recording_active=is_active,
                    recording_app_name=current_app,
                    recording_app_binary=current_bin,
                    recording_app_icon=current_icon,
                    recording_type=current_type
                )
                self.notify("RECORDING_UPDATE")

        except Exception as e:
            app_logger.debug(f"[RecordingModule] 嗅探流异常: {e}")

    def _recording_monitor_worker(self):
        """后台长连接守护线程：捕获 source_output 事件中断，绝不轮询"""
        while self._running:
            try:
                with pulsectl.Pulse('alcove-island-recorder') as pulse:
                    self._sync_recording_streams(pulse)

                    def callback(ev):
                        # 仅关注输入流的挂载、卸载与服务端变化
                        if ev.facility in ('source_output', 'server'):
                            raise pulsectl.PulseLoopStop()

                    pulse.event_mask_set('source_output', 'server')
                    pulse.event_callback_set(callback)

                    while self._running:
                        try:
                            pulse.event_listen(timeout=2.0)
                        except pulsectl.PulseLoopStop:
                            self._sync_recording_streams(pulse)
            except Exception as e:
                if self._running:
                    time.sleep(2)

    async def focus_recording_app(self) -> bool:
        """一键呼出并聚焦正在录制的应用窗口 (如 OBS Studio)"""
        target_bin = self.state.recording_app_binary or "obs"
        target_name = self.state.recording_app_name or "OBS"
        
        if hasattr(self.backend.bridge, "wm") and hasattr(self.backend.bridge.wm, "platform"):
            return self.backend.bridge.wm.platform.focus_application_window(
                class_pattern=target_bin,
                title_pattern=target_name
            )
        return False