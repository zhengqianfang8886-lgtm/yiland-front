# ==========================================
# 📄 File: backend/bridge_events.py
# 🌟 声明式事件路由派发器
# ==========================================
import time

class BridgeEventDispatcher:
    def __init__(self, bridge):
        self.b = bridge

        self._declarative_events = {
            "VOLUME_UPDATE": lambda s: (
                self.b.volumeChanged.emit(s.volume),
                self.b.hardwareMuteStateChanged.emit(s.is_muted, s.is_mic_muted)
            ),
            "BRIGHTNESS_UPDATE": lambda s: self.b.brightnessChanged.emit(s.brightness),
            "KEYBOARD_LOCK_UPDATE": lambda s: (
                self.b.capsLockChanged.emit(s.is_caps_lock),
                self.b.numLockChanged.emit(s.is_num_lock)
            ),
            
            # 🚀 CPU 更新
            "CPU_UPDATE": lambda s: self.b.cpuUpdated.emit(s.cpu_percent),
            
            "NET_SPEED_UPDATE": lambda s: self.b.netSpeedUpdated.emit(
                s.net_down_val, s.net_down_unit, s.net_up_val, s.net_up_unit, s.net_down_compact, s.net_up_compact
            ),
            "BATTERY_UPDATE": lambda s: self.b.batteryUpdated.emit(s.battery_pct, s.battery_charging),
            "TIMER_UPDATE": lambda s: self.b.timerUpdated.emit(),
            "VOICE_INPUT_LEVEL": lambda s: self.b.voiceInputLevelChanged.emit(s.voice_input_level),
            "VOICE_INPUT_UPDATE": lambda s: self.b.voiceInputStateChanged.emit(s.voice_input_active, s.voice_input_text),
            "IME_UPDATE": lambda s: (
                self.b.imeUpdated.emit(bool(getattr(s, "ime_active", False)), str(getattr(s, "ime_label", "英")),
                                       str(getattr(s, "ime_name", "")), str(getattr(s, "ime_icon_url", ""))),
                self.b.imeMenuUpdated.emit(getattr(s, "ime_menu_items", []))
            ),
            "RECORDING_UPDATE": lambda s: self.b.recordingUpdated.emit(),
            "TEAMS_CALL_ENDED": lambda s: self.b.callEndedTriggered.emit(),
        }

        self._complex_handlers = {
            "GRID_STATE_CHANGED": self._on_grid,
            "OVERLAY_CHANGED": self._on_overlay,
            "MEDIA_UPDATE": self._on_media_update,
            "MEDIA_PROGRESS": self._on_media_progress,
            "MEDIA_TICK": self._on_media_progress,
            "WORKSPACE_CHANGED": self._on_workspace,
            "TEAMS_CALL_INCOMING": self._on_teams_call_incoming,
            "TEAMS_NOTIFICATION": self._on_teams_notification,
            "FULL_SYNC": self._on_full_sync,
        }

    def dispatch(self, event_type: str, s):
        if event_type == "GENERIC_MODULE_UPDATE":
            mod_name = s.get("module", "")
            mod_data = s.get("data", {})
            self.b.moduleUpdated.emit(mod_name, mod_data)
            return

        direct_action = self._declarative_events.get(event_type)
        if direct_action:
            direct_action(s)
            return

        handler = self._complex_handlers.get(event_type)
        if handler:
            handler(s)

    def _on_grid(self, s):
        self.b.gridActiveChanged.emit(s.is_desktop_grid_active)
        if s.is_desktop_grid_active:
            self.b.setPassthrough()

    def _on_overlay(self, s):
        overlay = s.get_overlay_dict()
        if overlay.get("key"):
            self.b.view.raise_()
        self.b.overlayChanged.emit()
        if overlay.get("key") == "ALERT":
            self.b.alertTriggered.emit(
                overlay.get("icon") or "🔔", overlay.get("title") or "",
                overlay.get("subtitle") or "", overlay.get("duration") or 3500,
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

    def _on_teams_call_incoming(self, s):
        self.b.callIncomingTriggered.emit(
            s.last_notify_title or "Teams 来电",
            s.last_notify_content or "正在呼叫...",
            s.last_notify_avatar
        )
        self.b.view.raise_()

    def _on_teams_notification(self, s):
        t_title = s.last_notify_title.strip() or "新消息"
        t_sub = s.last_notify_content.strip()
        avatar = s.last_notify_avatar
        self.b._notif_model.add_notification({
            "id": int(time.time() * 1000), "icon": s.last_notify_icon or "💬",
            "title": t_title, "content": t_sub, "avatar": avatar,
            "time": time.strftime("%H:%M"), "read": False
        })
        is_dnd = getattr(self.b.config, "dndEnabled", False) if self.b.config else False
        if not is_dnd:
            self.b.alertTriggered.emit(s.last_notify_icon or "💬", t_title, t_sub, 3500, avatar)

    def _on_full_sync(self, s):
        self._on_grid(s)
        self._on_media_update(s)
        self._on_workspace(s)
        for ev, action in self._declarative_events.items():
            if ev != "TEAMS_CALL_ENDED":
                try:
                    action(s)
                except Exception:
                    pass