# ==========================================
# 📄 File: backend/modules/recording/monitor.py
# 🌟 原生音频录制/采音流监听器 (内核PID存活硬校验 · 2.0s自愈对账版)
# ==========================================
import os
import time
import threading
from typing import Callable, List, Dict, Any, Optional
import pulsectl
from backend.logger import app_logger


class AudioCaptureMonitor:
    """独占后台连接监听 PulseAudio / PipeWire 的 source_output 流，与 D-Bus 解耦"""

    def __init__(self, on_streams_changed: Callable[[List[Dict[str, Any]]], None]):
        self._callback = on_streams_changed
        self._running = False
        self._thread: Optional[threading.Thread] = None
        self._last_stream_signature: str = ""

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

    def _is_pid_alive(self, pid_val: Any) -> bool:
        """🚀【架构关键 1】：直通 Linux 内核验证 PID 是否依然存活"""
        try:
            pid = int(pid_val)
            if pid <= 0:
                return False
            # 发送信号 0 探测进程是否存在
            os.kill(pid, 0)
            return True
        except (OSError, ValueError, TypeError):
            return False

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
                raw_pid = props.get("application.process.id")

                # 排除自身监听探针与系统常见内省工具
                if any(x in binary or x in app_name for x in ("cava", "alcove", "pavucontrol", "pulsectl")):
                    continue

                is_obs = any(x in binary or x in app_name or x in portal for x in ("obs", "obs64", "com.obsproject.studio"))

                # 🚀【架构关键 2】：PipeWire 僵尸节点过滤
                # 如果是 OBS 相关的流，但其归属的进程在 Linux 进程表里已经蒸发，直接视为残留垃圾剔除！
                if is_obs and raw_pid is not None:
                    if not self._is_pid_alive(raw_pid):
                        app_logger.info(f"🛡️ [AudioMonitor::ZOMBIE] 成功过滤 PipeWire 残留的 OBS 僵尸音频流 (PID: {raw_pid})")
                        continue

                media_lower = media_name.lower()
                if any(k in media_name or k in media_lower for k in ("麦克风", "aux", "mic", "input", "辅助音频")):
                    s_type, s_title, s_icon = "mic", "麦克风", "🎙️"
                elif is_capture_sink or any(k in media_name or k in media_lower for k in ("桌面", "desktop", "monitor", "音频输出采集")):
                    s_type, s_title, s_icon = "desktop", "桌面音频 / 屏幕", "🖥️"
                else:
                    s_type, s_title, s_icon = "mic", media_name or "音频采集", "🎙️"

                streams.append({
                    "id": getattr(out, "index", 0),
                    "pid": raw_pid,
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
                    current_streams = self._extract_safe_streams(pulse)
                    self._last_stream_signature = self._calc_signature(current_streams)
                    self._callback(current_streams)

                    def _event_cb(ev):
                        if ev.facility in ('source_output', 'server'):
                            raise pulsectl.PulseLoopStop()

                    pulse.event_mask_set('source_output', 'server')
                    pulse.event_callback_set(_event_cb)

                    while self._running:
                        try:
                            # 监听阻塞，最长 2.0s
                            pulse.event_listen(timeout=2.0)
                            
                            # 🚀【架构关键 3】：超时主动对账机制 (Reconciliation)
                            # 如果 2.0s 内没有收到中断，主动抽检当前流，防止中断信号偶发丢失导致状态悬挂
                            active_now = self._extract_safe_streams(pulse)
                            sig_now = self._calc_signature(active_now)
                            if sig_now != self._last_stream_signature:
                                app_logger.debug("[AudioMonitor::Reconcile] 超时轮询检测到流状态不一致，主动校准收敛")
                                self._last_stream_signature = sig_now
                                self._callback(active_now)

                        except pulsectl.PulseLoopStop:
                            # 正常中断命中
                            active_now = self._extract_safe_streams(pulse)
                            self._last_stream_signature = self._calc_signature(active_now)
                            self._callback(active_now)

            except Exception as e:
                if self._running:
                    app_logger.warning(f"[AudioCaptureMonitor] 连接中断，2秒后尝试重连: {e}")
                    time.sleep(2.0)

    @staticmethod
    def _calc_signature(streams: List[Dict[str, Any]]) -> str:
        return "|".join(f"{s.get('id')}:{s.get('is_obs')}:{s.get('pid')}" for s in streams)