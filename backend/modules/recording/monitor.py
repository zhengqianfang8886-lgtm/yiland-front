# ==========================================
# 📄 File: backend/modules/recording/monitor.py
# 🌟 原生音频录制/采音流监听器 (物理线程隔离 · 纯事件驱动)
# ==========================================
import time
import threading
from typing import Callable, List, Dict, Any, Optional
import pulsectl
from backend.logger import app_logger


class AudioCaptureMonitor:
    """独占后台连接监听 PulseAudio / PipeWire 的 source_output 流，与 D-Bus 彻底解耦"""

    def __init__(self, on_streams_changed: Callable[[List[Dict[str, Any]]], None]):
        self._callback = on_streams_changed
        self._running = False
        self._thread: Optional[threading.Thread] = None

    def start(self):
        self._running = True
        self._thread = threading.Thread(target=self._worker, daemon=True, name="AudioCaptureMonitor")
        self._thread.start()

    def stop(self):
        self._running = False

    def _decode(self, val: Any) -> str:
        if isinstance(val, bytes):
            return val.decode("utf-8", errors="ignore")
        return str(val) if val is not None else ""

    def _extract_safe_streams(self, pulse: pulsectl.Pulse) -> List[Dict[str, Any]]:
        streams = []
        try:
            for out in pulse.source_output_list():
                props = getattr(out, "proplist", {}) or {}
                app_name = self._decode(props.get("application.name", "")).lower()
                binary = self._decode(props.get("application.process.binary", "")).lower()
                portal = self._decode(props.get("pipewire.access.portal.app_id", "")).lower()
                media_name = self._decode(props.get("media.name", ""))
                is_capture_sink = (self._decode(props.get("stream.capture.sink", "")).lower() == "true")

                # 排除自身监听探针与常见内省工具
                if any(x in binary or x in app_name for x in ("cava", "alcove", "pavucontrol", "pulsectl")):
                    continue

                is_obs = any(x in binary or x in app_name or x in portal for x in ("obs", "obs64", "com.obsproject.studio"))
                media_lower = media_name.lower()

                if any(k in media_name or k in media_lower for k in ("麦克风", "aux", "mic", "input", "辅助音频")):
                    s_type, s_title, s_icon = "mic", "麦克风", "🎙️"
                elif is_capture_sink or any(k in media_name or k in media_lower for k in ("桌面", "desktop", "monitor", "音频输出采集")):
                    s_type, s_title, s_icon = "desktop", "桌面音频 / 屏幕", "🖥️"
                else:
                    s_type, s_title, s_icon = "mic", media_name or "音频采集", "🎙️"

                streams.append({
                    "id": getattr(out, "index", 0),
                    "title": s_title,
                    "subtitle": "OBS Studio" if is_obs else (self._decode(props.get("application.name", "")) or "系统采音"),
                    "type": s_type,
                    "icon": s_icon,
                    "is_obs": is_obs
                })
        except Exception as e:
            app_logger.debug(f"[AudioCaptureMonitor] 提取流异常: {e}")
        return streams

    def _worker(self):
        while self._running:
            try:
                with pulsectl.Pulse('alcove-rec-mon') as pulse:
                    self._callback(self._extract_safe_streams(pulse))

                    def _event_cb(ev):
                        if ev.facility in ('source_output', 'server'):
                            raise pulsectl.PulseLoopStop()

                    pulse.event_mask_set('source_output', 'server')
                    pulse.event_callback_set(_event_cb)

                    while self._running:
                        try:
                            pulse.event_listen(timeout=2.0)
                        except pulsectl.PulseLoopStop:
                            self._callback(self._extract_safe_streams(pulse))
            except Exception:
                if self._running:
                    time.sleep(2.0)