# ==========================================
# 📄 File: backend/bridge.py
# 🌟 Qt / QML 统一交互中枢 (集成 Wayland 外部失焦收回事件)
# ==========================================
import time
import atexit
import asyncio
from concurrent.futures import ThreadPoolExecutor

from PySide6.QtCore import QObject, Signal, Slot, Property, Qt, QEvent
from backend.logger import app_logger
from backend.models import NotificationListModel, BluetoothListModel
from backend.window import WindowManagerService
from backend.utils import get_world_time, get_tz_offset_str


class WindowEventFilter(QObject):
    """专门监听窗口激活与失焦的轻量级事件过滤器"""
    def __init__(self, bridge):
        super().__init__()
        self.bridge = bridge

    def eventFilter(self, watched, event):
        # 🚀【核心】：检测到用户点击了外部任意程序/桌面，窗口失去激活状态
        if event.type() == QEvent.Type.WindowDeactivate:
            self.bridge.windowDeactivated.emit()
        return super().eventFilter(watched, event)


class IslandBridge(QObject):
    @Slot(bool)
    def setUiActive(self, active: bool):
        if self._backend:
            self._backend.set_ui_active(active)

    mediaUpdated = Signal(str, str, str, str, float, float)
    progressUpdated = Signal(float, float, float)
    audioSpectrumUpdated = Signal(float, float, float, float)
    dominantColorUpdated = Signal(str)

    osdTriggered = Signal(str, str, int)
    hardwareMuteStateChanged = Signal(bool, bool)
    volumeChanged = Signal(int)
    brightnessChanged = Signal(int)
    capsLockChanged = Signal(bool)
    numLockChanged = Signal(bool)
    clipboardTriggered = Signal(str, str, str, int)

    workspaceTriggered = Signal(int, int, str)
    workspaceListUpdated = Signal("QVariantList")
    alertTriggered = Signal(str, str, str, int, str)
    callIncomingTriggered = Signal(str, str, str)
    callEndedTriggered = Signal()
    unreadCountChanged = Signal(int)

    memoryUpdated = Signal(int, str, str)
    netSpeedUpdated = Signal(str, str, str, str)
    batteryUpdated = Signal(int, bool)

    timerUpdated = Signal()
    overlayChanged = Signal()

    voiceInputLevelChanged = Signal(float)
    voiceInputStateChanged = Signal(bool, str)

    # 🚀 点击外部失焦信号
    windowDeactivated = Signal()

    _sig_inproc_event = Signal(str, object)
    _sig_spectrum_event = Signal(float, float, float, float)

    def __init__(self, view, config=None):
        super().__init__()
        self.view = view
        self.config = config
        self._pool = ThreadPoolExecutor(max_workers=2, thread_name_prefix="BridgeWorker")

        self._backend = None
        self._async_loop = None

        self._notif_model = NotificationListModel(self)
        self._bt_model = BluetoothListModel(self)

        self._notif_model.unreadCountChanged.connect(self.unreadCountChanged.emit)

        self.wm = WindowManagerService(self.view, self._pool, self.config, self)

        self._sig_inproc_event.connect(self._handle_inproc_event, Qt.ConnectionType.QueuedConnection)
        self._sig_spectrum_event.connect(self.audioSpectrumUpdated.emit, Qt.ConnectionType.QueuedConnection)

        # 挂载窗口事件过滤器
        self._event_filter = WindowEventFilter(self)
        self.view.installEventFilter(self._event_filter)

        atexit.register(self.cleanup)

    def set_backend(self, backend, loop):
        self._backend = backend
        self._async_loop = loop

    def run_async(self, coro):
        if self._async_loop and self._async_loop.is_running():
            asyncio.run_coroutine_threadsafe(coro, self._async_loop)

    def cleanup(self):
        if hasattr(self, "_notif_model"):
            self._notif_model.clearAll()
        self._pool.shutdown(wait=False, cancel_futures=True)

    @Property("QVariantMap", notify=overlayChanged)
    def activeOverlay(self):
        if self._backend:
            return self._backend.state.get_overlay_dict()
        return {}

    @Slot()
    def dismissOverlay(self):
        if self._backend:
            self._backend.state.clear_overlay()
            self.overlayChanged.emit()

    @Property(bool, notify=voiceInputStateChanged)
    def voiceInputActive(self):
        return self._backend.state.voice_input_active if self._backend else False

    @Property(str, notify=voiceInputStateChanged)
    def voiceInputText(self):
        return self._backend.state.voice_input_text if self._backend else ""

    @Property(float, notify=voiceInputLevelChanged)
    def voiceInputLevel(self):
        return self._backend.state.voice_input_level if self._backend else 0.1

    @Slot()
    def toggleVoiceInput(self):
        if self._backend and self._backend.voice:
            self.run_async(self._backend.voice.toggle_recording())

    @Slot()
    def stopVoiceInput(self):
        if self._backend and self._backend.voice:
            self.run_async(self._backend.voice.stop_recording())

    @Property(QObject, constant=True)
    def notificationModel(self): return self._notif_model

    @Property(int, notify=unreadCountChanged)
    def unreadCount(self): return self._notif_model.unreadCount

    @Property(str, notify=unreadCountChanged)
    def latestNotificationAvatar(self): return self._notif_model.latestAvatar

    @Property(QObject, constant=True)
    def bluetoothModel(self): return self._bt_model

    @Property(int, notify=volumeChanged)
    def currentVolume(self):
        return self._backend.state.volume if self._backend else 50

    @Property(int, notify=brightnessChanged)
    def currentBrightness(self):
        return self._backend.state.brightness if self._backend else 100

    @Property(bool, notify=capsLockChanged)
    def isCapsLock(self):
        return self._backend.state.is_caps_lock if self._backend else False

    @Property(bool, notify=numLockChanged)
    def isNumLock(self):
        return self._backend.state.is_num_lock if self._backend else False

    @Property(int, notify=batteryUpdated)
    def systemBattery(self):
        return self._backend.state.battery_pct if self._backend else 100

    @Property(bool, notify=batteryUpdated)
    def isSystemCharging(self):
        return self._backend.state.battery_charging if self._backend else False

    @Property(str, notify=timerUpdated)
    def timerType(self): return self._backend.state.timer_type if self._backend else "countdown"

    @Property(bool, notify=timerUpdated)
    def timerIsRunning(self): return self._backend.state.timer_is_running if self._backend else False

    @Property(bool, notify=timerUpdated)
    def timerIsPaused(self): return self._backend.state.timer_is_paused if self._backend else False

    @Property(bool, notify=timerUpdated)
    def timerIsCompleted(self): return self._backend.state.timer_is_completed if self._backend else False

    @Property(int, notify=timerUpdated)
    def timerRemainingSec(self): return self._backend.state.timer_remaining_sec if self._backend else 1500

    @Property(int, notify=timerUpdated)
    def timerTotalSec(self): return self._backend.state.timer_total_sec if self._backend else 1500

    @Property(int, notify=timerUpdated)
    def timerElapsedSec(self): return self._backend.state.timer_elapsed_sec if self._backend else 0

    @Property(str, notify=timerUpdated)
    def timerMode(self): return self._backend.state.timer_mode if self._backend else "focus"

    @Property(list, notify=timerUpdated)
    def timerLaps(self): return self._backend.state.timer_laps if self._backend else []

    @Slot(str)
    def switchTimerType(self, t_type: str):
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.switch_type(t_type))

    @Slot()
    def toggleTimerPause(self):
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.toggle_pause())

    @Slot(int, str)
    def startTimerPreset(self, sec: int, mode: str):
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.start_preset(sec, mode))

    @Slot(int)
    def adjustTimerTime(self, delta_sec: int):
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.adjust_time(delta_sec))

    @Slot()
    def recordTimerLap(self):
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.record_lap())

    @Slot()
    def resetTimer(self):
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.reset())

    @Slot(result="QVariantList")
    def getHabits(self):
        if self._backend and self._backend.habits:
            return self._backend.habits.get_habits()
        return []

    @Slot(str, str, result="QVariantList")
    def addHabit(self, name: str, icon: str = "📌"):
        if self._backend and self._backend.habits:
            return self._backend.habits.add_habit(name, icon)
        return []

    @Slot(str, result="QVariantList")
    def deleteHabit(self, habit_id: str):
        if self._backend and self._backend.habits:
            return self._backend.habits.delete_habit(habit_id)
        return []

    @Slot(str, int, int, result="QVariantMap")
    def getMonthRecords(self, habit_id: str, year: int, month: int):
        if self._backend and self._backend.habits:
            return self._backend.habits.get_month_records(habit_id, year, month)
        return {}

    @Slot(str, str, result=bool)
    def toggleHabitRecord(self, habit_id: str, date_str: str):
        if self._backend and self._backend.habits:
            return self._backend.habits.toggle_record(habit_id, date_str)
        return False

    @Slot(int, int)
    def adjustHardware(self, mode: int, delta: int):
        if not self._backend: return
        if mode == 0 and self._backend.audio:
            self.run_async(self._backend.audio.set_delta(delta))
        elif mode == 1 and self._backend.brightness:
            self.run_async(self._backend.brightness.set_delta(delta))

    @Slot(int)
    def toggleHardwareMute(self, mode: int):
        if not self._backend or not self._backend.audio: return
        if mode == 0:
            self.run_async(self._backend.audio.toggle_mute())
        elif mode == 2:
            self.run_async(self._backend.audio.toggle_mic_mute())

    @Slot(str)
    def sendMediaCmd(self, action: str):
        if not self._backend or not self._backend.mpris: return
        action_map = {
            "MEDIA_PLAY_PAUSE": "PlayPause",
            "MEDIA_NEXT": "Next",
            "MEDIA_PREV": "Previous"
        }
        cmd = action_map.get(action, action)
        self.run_async(self._backend.mpris.control(cmd))

    @Slot(str, str)
    def focusMediaWindow(self, title="", artist=""):
        if self._backend and self._backend.mpris:
            self.run_async(self._backend.mpris.raise_player())

    @Slot(int)
    @Slot(str)
    def switchWorkspace(self, target):
        if self._backend and self._backend.workspace:
            self.run_async(self._backend.workspace.switch_workspace(target))

    @Slot()
    def switchWorkspacePrev(self):
        if self._backend and self._backend.workspace:
            self.run_async(self._backend.workspace.switch_workspace("prev"))

    @Slot()
    def switchWorkspaceNext(self):
        if self._backend and self._backend.workspace:
            self.run_async(self._backend.workspace.switch_workspace("next"))

    @Slot()
    def answerTeamsCall(self):
        if self._backend and self._backend.notifications:
            self.run_async(self._backend.notifications.answer_call())

    @Slot()
    def rejectTeamsCall(self):
        if self._backend and self._backend.notifications:
            self.run_async(self._backend.notifications.reject_call())

    @Slot()
    def focusTeamsWindow(self):
        if self._backend and self._backend.notifications:
            self.run_async(self._backend.notifications.focus_teams())

    @Slot()
    def openSystemMonitor(self): self.wm.open_system_monitor()

    @Slot()
    def forceRaise(self): self.view.raise_()

    @Slot()
    def openFullCorridorForMotion(self): self.wm.clear_mask()

    @Slot(int, int, int, int)
    def applySettledMask(self, x: int, y: int, w: int, h: int):
        self.wm.set_precise_bounding_mask(x, y, w, h)

    @Slot()
    def setPassthrough(self): self.wm.set_passthrough()

    @Slot(str, bool, result=dict)
    def getWorldTime(self, tz_name, is_24h=True): return get_world_time(tz_name, is_24h)

    @Slot(str, result=str)
    def getTzOffsetStr(self, tz_name): return get_tz_offset_str(tz_name)

    # 🚀 焦点控制
    @Slot()
    def requestWindowFocus(self):
        if hasattr(self.wm.platform, "acquire_interaction_focus"):
            self.wm.platform.acquire_interaction_focus(self.view)
        else:
            self.view.requestActivate()

    @Slot()
    def restorePreviousFocus(self):
        if hasattr(self.wm.platform, "restore_previous_focus"):
            self.wm.platform.restore_previous_focus(self.view)

    def post_inproc_event(self, event_type: str, state_obj):
        try:
            self._sig_inproc_event.emit(event_type, state_obj)
        except RuntimeError:
            pass

    def post_spectrum_event(self, s1: float, s2: float, s3: float, s4: float):
        try:
            self._sig_spectrum_event.emit(s1, s2, s3, s4)
        except RuntimeError:
            pass

    @Slot(str, object)
    def _handle_inproc_event(self, event_type: str, s):
        if event_type == "VOICE_INPUT_LEVEL":
            self.voiceInputLevelChanged.emit(s.voice_input_level)
            return
        elif event_type == "VOICE_INPUT_UPDATE":
            self.voiceInputStateChanged.emit(s.voice_input_active, s.voice_input_text)

        if event_type == "OVERLAY_CHANGED":
            overlay = s.get_overlay_dict()
            if overlay.get("key"):
                self.view.raise_()
                self.wm.clear_mask()
            self.overlayChanged.emit()
            if overlay.get("key") == "ALERT":
                self.alertTriggered.emit(
                    overlay.get("icon") or "🔔",
                    overlay.get("title") or "",
                    overlay.get("subtitle") or "",
                    overlay.get("duration") or 3500,
                    overlay.get("avatar") or ""
                )

        if event_type in ("MEDIA_UPDATE", "FULL_SYNC"):
            art = s.art_url
            if art and art.startswith("/") and not art.startswith("file://"):
                art = "file://" + art
            self.mediaUpdated.emit(s.title, s.artist, s.playback_status, art, s.position, s.duration)
            self.dominantColorUpdated.emit(s.dominant_color)
        elif event_type in ("MEDIA_PROGRESS", "MEDIA_TICK"):
            prog = (s.position / s.duration) if s.duration > 0 else 0.0
            self.progressUpdated.emit(s.position, s.duration, prog)

        if event_type in ("WORKSPACE_CHANGED", "FULL_SYNC"):
            self.workspaceTriggered.emit(s.workspace_index, s.workspace_total, s.workspace_name)
            self.workspaceListUpdated.emit(s.workspaces)

        if event_type in ("VOLUME_UPDATE", "FULL_SYNC"):
            self.volumeChanged.emit(s.volume)
            self.hardwareMuteStateChanged.emit(s.is_muted, s.is_mic_muted)
            if event_type == "VOLUME_UPDATE":
                icon = "🔇" if s.is_muted else ("🔈" if s.volume == 0 else "🔊")
                self.osdTriggered.emit(icon, "Volume", s.volume)

        if event_type in ("BRIGHTNESS_UPDATE", "FULL_SYNC"):
            self.brightnessChanged.emit(s.brightness)
            if event_type == "BRIGHTNESS_UPDATE":
                self.osdTriggered.emit("☀️", "Display", s.brightness)

        if event_type in ("KEYBOARD_LOCK_UPDATE", "FULL_SYNC"):
            self.capsLockChanged.emit(s.is_caps_lock)
            self.numLockChanged.emit(s.is_num_lock)

        if event_type in ("MEMORY_UPDATE", "FULL_SYNC"):
            self.memoryUpdated.emit(s.memory_percent, s.memory_used_gb, s.memory_total_gb)

        if event_type in ("NET_SPEED_UPDATE", "FULL_SYNC"):
            self.netSpeedUpdated.emit(s.net_down_speed, s.net_up_speed, s.net_down_compact, s.net_up_compact)

        if event_type in ("BATTERY_UPDATE", "FULL_SYNC"):
            self.batteryUpdated.emit(s.battery_pct, s.battery_charging)

        if event_type in ("TIMER_UPDATE", "FULL_SYNC"):
            self.timerUpdated.emit()

        if event_type == "TEAMS_CALL_INCOMING":
            self.callIncomingTriggered.emit(
                s.last_notify_title or "Teams 来电",
                s.last_notify_content or "正在呼叫...",
                s.last_notify_avatar
            )
            self.view.raise_()
        elif event_type == "TEAMS_CALL_ENDED":
            self.callEndedTriggered.emit()
        elif event_type == "TEAMS_NOTIFICATION":
            t_title = s.last_notify_title.strip() or "新消息"
            t_sub = s.last_notify_content.strip()
            avatar = s.last_notify_avatar
            
            self._notif_model.add_notification({
                "id": int(time.time() * 1000), "icon": s.last_notify_icon or "💬",
                "title": t_title, "content": t_sub, "avatar": avatar, "time": time.strftime("%H:%M"), "read": False
            })

            is_dnd = getattr(self.config, "dndEnabled", False) if self.config else False
            if not is_dnd:
                self.alertTriggered.emit(s.last_notify_icon or "💬", t_title, t_sub, 3500, avatar)