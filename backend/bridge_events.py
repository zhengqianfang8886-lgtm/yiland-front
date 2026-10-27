# ==========================================
# 📄 File: backend/bridge_events.py
# 🌟 后端事件到 Qt 信号注册表派发器 (开机防抖无敌帧加固版)
# ==========================================
import time


class BridgeEventDispatcher:
    """统一解耦 _handle_inproc_event 的庞大多分支函数"""

    def __init__(self, bridge):
        self.b = bridge
        self._startup_time = time.time()  # 👈 记录引擎启动时间
        
        self._handlers = {
            "GRID_STATE_CHANGED": self._on_grid,
            "VOICE_INPUT_LEVEL": self._on_voice_level,
            "VOICE_INPUT_UPDATE": self._on_voice_state,
            "OVERLAY_CHANGED": self._on_overlay,
            "MEDIA_UPDATE": self._on_media_update,
            "MEDIA_PROGRESS": self._on_media_progress,
            "MEDIA_TICK": self._on_media_progress,
            "WORKSPACE_CHANGED": self._on_workspace,
            "VOLUME_UPDATE": lambda s: self._on_volume(s, trigger_osd=True),
            "BRIGHTNESS_UPDATE": lambda s: self._on_brightness(s, trigger_osd=True),
            "KEYBOARD_LOCK_UPDATE": self._on_keyboard,
            "MEMORY_UPDATE": self._on_memory,
            "NET_SPEED_UPDATE": self._on_net_speed,
            "BATTERY_UPDATE": self._on_battery,
            "TIMER_UPDATE": self._on_timer,
            "IME_UPDATE": self._on_ime,
            "TEAMS_CALL_INCOMING": self._on_teams_call_incoming,
            "TEAMS_CALL_ENDED": self._on_teams_call_ended,
            "TEAMS_NOTIFICATION": self._on_teams_notification,
            "FULL_SYNC": self._on_full_sync,
        }

    def dispatch(self, event_type: str, s):
        handler = self._handlers.get(event_type)
        if handler:
            handler(s)

    def _on_grid(self, s):
        self.b.gridActiveChanged.emit(s.is_desktop_grid_active)
        if s.is_desktop_grid_active:
            self.b.setPassthrough()

    def _on_voice_level(self, s):
        self.b.voiceInputLevelChanged.emit(s.voice_input_level)

    def _on_voice_state(self, s):
        self.b.voiceInputStateChanged.emit(s.voice_input_active, s.voice_input_text)

    def _on_overlay(self, s):
        overlay = s.get_overlay_dict()
        if overlay.get("key"):
            self.b.view.raise_()
        self.b.overlayChanged.emit()
        if overlay.get("key") == "ALERT":
            self.b.alertTriggered.emit(
                overlay.get("icon") or "🔔",
                overlay.get("title") or "",
                overlay.get("subtitle") or "",
                overlay.get("duration") or 3500,
                overlay.get("avatar") or ""
            )

    def _on_media_update(self, s):
        art = s.art_url
        if art and art.startswith("/") and not art.startswith("file://"):
            art = "file://" + art
        self.b.mediaUpdated.emit(s.title, s.artist, s.playback_status, art, s.position, s.duration)
        self.b.dominantColorUpdated.emit(s.dominant_color)

    def _on_media_progress(self, s):
        prog = (s.position / s.duration) if s.duration > 0 else 0.0
        self.b.progressUpdated.emit(s.position, s.duration, prog)

    def _on_workspace(self, s):
        self.b.workspaceTriggered.emit(s.workspace_index, s.workspace_total, s.workspace_name)
        self.b.workspaceListUpdated.emit(s.workspaces)

    def _on_volume(self, s, trigger_osd: bool = False):
        self.b.volumeChanged.emit(s.volume)
        self.b.hardwareMuteStateChanged.emit(s.is_muted, s.is_mic_muted)
        
        # 🚀【核心修复】：开机前 2 秒的底层硬件异步探针延后送达，绝对拦截，严禁闪现弹窗！
        if trigger_osd and (time.time() - self._startup_time > 2.0):
            icon = "🔇" if s.is_muted else ("🔈" if s.volume == 0 else "🔊")
            self.b.osdTriggered.emit(icon, "Volume", s.volume)

    def _on_brightness(self, s, trigger_osd: bool = False):
        self.b.brightnessChanged.emit(s.brightness)
        # 🚀 同理拦截屏幕亮度的开机异步探针
        if trigger_osd and (time.time() - self._startup_time > 2.0):
            self.b.osdTriggered.emit("☀️", "Display", s.brightness)

    def _on_keyboard(self, s):
        self.b.capsLockChanged.emit(s.is_caps_lock)
        self.b.numLockChanged.emit(s.is_num_lock)

    def _on_memory(self, s):
        self.b.memoryUpdated.emit(s.memory_percent, s.memory_used_gb, s.memory_total_gb)

    def _on_net_speed(self, s):
        self.b.netSpeedUpdated.emit(
            s.net_down_val, s.net_down_unit,
            s.net_up_val, s.net_up_unit,
            s.net_down_compact, s.net_up_compact
        )

    def _on_battery(self, s):
        self.b.batteryUpdated.emit(s.battery_pct, s.battery_charging)

    def _on_timer(self, s):
        self.b.timerUpdated.emit()

    def _on_ime(self, s):
        self.b.imeUpdated.emit(
            bool(getattr(s, "ime_active", False)),
            str(getattr(s, "ime_label", "英")),
            str(getattr(s, "ime_name", "")),
            str(getattr(s, "ime_icon_url", ""))
        )

    def _on_teams_call_incoming(self, s):
        self.b.callIncomingTriggered.emit(
            s.last_notify_title or "Teams 来电",
            s.last_notify_content or "正在呼叫...",
            s.last_notify_avatar
        )
        self.b.view.raise_()

    def _on_teams_call_ended(self, s):
        self.b.callEndedTriggered.emit()

    def _on_teams_notification(self, s):
        t_title = s.last_notify_title.strip() or "新消息"
        t_sub = s.last_notify_content.strip()
        avatar = s.last_notify_avatar
        self.b._notif_model.add_notification({
            "id": int(time.time() * 1000), "icon": s.last_notify_icon or "💬",
            "title": t_title, "content": t_sub, "avatar": avatar, "time": time.strftime("%H:%M"), "read": False
        })
        is_dnd = getattr(self.b.config, "dndEnabled", False) if self.b.config else False
        if not is_dnd:
            self.b.alertTriggered.emit(s.last_notify_icon or "💬", t_title, t_sub, 3500, avatar)

    def _on_full_sync(self, s):
        self._on_grid(s)
        self._on_media_update(s)
        self._on_workspace(s)
        self._on_volume(s, trigger_osd=False)
        self._on_brightness(s, trigger_osd=False)
        self._on_keyboard(s)
        self._on_memory(s)
        self._on_net_speed(s)
        self._on_battery(s)
        self._on_timer(s)
        self._on_ime(s)