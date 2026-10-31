# ==========================================
# 📄 File: backend/bridge.py
# 🌟 Qt/QML 统一交互中枢门面
# ==========================================
from PySide6.QtCore import QObject, Signal, Slot, Property, Qt
from backend.bridge_core import BridgeCore, WindowEventFilter
from backend.bridge_events import BridgeEventDispatcher
from backend.utils import get_world_time, get_tz_offset_str


class IslandBridge(BridgeCore):
    # 媒体与声学
    mediaUpdated = Signal(str, str, str, str, float, float)
    progressUpdated = Signal(float, float, float)
    audioSpectrumUpdated = Signal(float, float, float, float)
    dominantColorUpdated = Signal(str)

    # 硬件与键盘
    hardwareMuteStateChanged = Signal(bool, bool)
    volumeChanged = Signal(int)
    brightnessChanged = Signal(int)
    capsLockChanged = Signal(bool)
    numLockChanged = Signal(bool)

    # 工作区、通知与通话
    workspaceTriggered = Signal(int, int, str)
    workspaceListUpdated = Signal("QVariantList")
    alertTriggered = Signal(str, str, str, int, str)
    callIncomingTriggered = Signal(str, str, str)
    callEndedTriggered = Signal()
    unreadCountChanged = Signal(int)
    gridActiveChanged = Signal(bool)

    # 负载、网速、计时与暂态
    cpuUpdated = Signal(int)  # 🚀 CPU 专属信号
    netSpeedUpdated = Signal(str, str, str, str, str, str)
    batteryUpdated = Signal(int, bool)
    timerUpdated = Signal()
    overlayChanged = Signal()

    voiceInputLevelChanged = Signal(float)
    voiceInputStateChanged = Signal(bool, str)

    imeUpdated = Signal(bool, str, str, str)
    imeMenuUpdated = Signal("QVariantList")

    recordingUpdated = Signal()

    def __init__(self, view, config=None):
        super().__init__(view, config)
        self._notif_model.unreadCountChanged.connect(self.unreadCountChanged.emit)
        self._dispatcher = BridgeEventDispatcher(self)
        self._sig_inproc_event.connect(self._handle_inproc_event, Qt.ConnectionType.QueuedConnection)
        self._sig_spectrum_event.connect(self.audioSpectrumUpdated.emit, Qt.ConnectionType.QueuedConnection)

    @Slot(str, object)
    def _handle_inproc_event(self, event_type: str, s):
        self._dispatcher.dispatch(event_type, s)

    # --- Properties ---
    @Property(bool, notify=recordingUpdated)
    def isRecordingActive(self): return self._state_val("recording_active", False)
    @Property(str, notify=recordingUpdated)
    def recordingIcon(self): return self._state_val("recording_icon_url", "")
    @Property(list, notify=recordingUpdated)
    def recordingItems(self): return self._state_val("recording_items", [])
    @Property(list, notify=recordingUpdated)
    def recordingMenuList(self): return self._state_val("recording_menu_items", [])

    @Property(bool, notify=imeUpdated)
    def isImeActive(self): return self._state_val("ime_active", False)
    @Property(str, notify=imeUpdated)
    def imeLabel(self): return self._state_val("ime_label", "英")
    @Property(str, notify=imeUpdated)
    def imeName(self): return self._state_val("ime_name", "")
    @Property(str, notify=imeUpdated)
    def imeIcon(self): return self._state_val("ime_icon_url", "")
    @Property(list, notify=imeMenuUpdated)
    def imeMenuList(self): return self._state_val("ime_menu_items", [])

    @Property(bool, notify=gridActiveChanged)
    def isGridActive(self): return self._state_val("is_desktop_grid_active", False)
    @Property(int, notify=volumeChanged)
    def currentVolume(self): return self._state_val("volume", 50)
    @Property(int, notify=brightnessChanged)
    def currentBrightness(self): return self._state_val("brightness", 100)
    @Property(bool, notify=capsLockChanged)
    def isCapsLock(self): return self._state_val("is_caps_lock", False)
    @Property(bool, notify=numLockChanged)
    def isNumLock(self): return self._state_val("is_num_lock", False)
    @Property(int, notify=batteryUpdated)
    def systemBattery(self): return self._state_val("battery_pct", 100)
    @Property(bool, notify=batteryUpdated)
    def isSystemCharging(self): return self._state_val("battery_charging", False)
    
    # 🚀 CPU 属性
    @Property(int, notify=cpuUpdated)
    def cpuPercent(self): return self._state_val("cpu_percent", 0)

    # 计时器相关
    @Property(str, notify=timerUpdated)
    def timerType(self): return self._state_val("timer_type", "countdown")
    @Property(bool, notify=timerUpdated)
    def timerIsRunning(self): return self._state_val("timer_is_running", False)
    @Property(bool, notify=timerUpdated)
    def timerIsPaused(self): return self._state_val("timer_is_paused", False)
    @Property(bool, notify=timerUpdated)
    def timerIsCompleted(self): return self._state_val("timer_is_completed", False)
    @Property(bool, notify=timerUpdated)
    def timerIsOvertime(self): return self._state_val("timer_is_overtime", False)
    @Property(int, notify=timerUpdated)
    def timerOvertimeSec(self): return self._state_val("timer_overtime_sec", 0)
    @Property(int, notify=timerUpdated)
    def timerRemainingSec(self): return self._state_val("timer_remaining_sec", 1500)
    @Property(int, notify=timerUpdated)
    def timerTotalSec(self): return self._state_val("timer_total_sec", 1500)
    @Property(int, notify=timerUpdated)
    def timerElapsedSec(self): return self._state_val("timer_elapsed_sec", 0)
    @Property(str, notify=timerUpdated)
    def timerMode(self): return self._state_val("timer_mode", "focus")
    @Property(list, notify=timerUpdated)
    def timerLaps(self): return self._state_val("timer_laps", [])

    @Property(bool, notify=timerUpdated)
    def cdActive(self): return bool(self._state_val("cd_is_running") or self._state_val("cd_is_paused") or self._state_val("cd_is_overtime"))
    @Property(bool, notify=timerUpdated)
    def cdIsRunning(self): return self._state_val("cd_is_running", False)
    @Property(bool, notify=timerUpdated)
    def cdIsPaused(self): return self._state_val("cd_is_paused", False)
    @Property(bool, notify=timerUpdated)
    def cdIsOvertime(self): return self._state_val("cd_is_overtime", False)
    @Property(int, notify=timerUpdated)
    def cdRemainingSec(self): return self._state_val("cd_remaining_sec", 1500)
    @Property(int, notify=timerUpdated)
    def cdOvertimeSec(self): return self._state_val("cd_overtime_sec", 0)
    @Property(str, notify=timerUpdated)
    def cdMode(self): return self._state_val("cd_mode", "focus")

    @Property(bool, notify=timerUpdated)
    def swActive(self): return bool(self._state_val("sw_is_running") or self._state_val("sw_is_paused"))
    @Property(bool, notify=timerUpdated)
    def swIsRunning(self): return self._state_val("sw_is_running", False)
    @Property(bool, notify=timerUpdated)
    def swIsPaused(self): return self._state_val("sw_is_paused", False)
    @Property(int, notify=timerUpdated)
    def swElapsedSec(self): return self._state_val("sw_elapsed_sec", 0)

    @Property("QVariantMap", notify=overlayChanged)
    def activeOverlay(self): return self._backend.state.get_overlay_dict() if self._backend else {}
    @Property(bool, notify=voiceInputStateChanged)
    def voiceInputActive(self): return self._state_val("voice_input_active", False)
    @Property(str, notify=voiceInputStateChanged)
    def voiceInputText(self): return self._state_val("voice_input_text", "")
    @Property(float, notify=voiceInputLevelChanged)
    def voiceInputLevel(self): return self._state_val("voice_input_level", 0.1)

    @Property(QObject, constant=True)
    def notificationModel(self): return self._notif_model
    @Property(int, notify=unreadCountChanged)
    def unreadCount(self): return self._notif_model.unreadCount
    @Property(str, notify=unreadCountChanged)
    def latestNotificationAvatar(self): return self._notif_model.latestAvatar

    # --- Actions ---
    @Slot()
    def switchWorkspacePrev(self):
        if self._backend and hasattr(self._backend, "workspace") and self._backend.workspace:
            self.run_async(self._backend.workspace.switch_workspace("prev"))
    @Slot()
    def switchWorkspaceNext(self):
        if self._backend and hasattr(self._backend, "workspace") and self._backend.workspace:
            self.run_async(self._backend.workspace.switch_workspace("next"))
    @Slot(int)
    @Slot(str)
    def switchWorkspace(self, target):
        if self._backend and hasattr(self._backend, "workspace") and self._backend.workspace:
            self.run_async(self._backend.workspace.switch_workspace(target))
    @Slot()
    def toggleDesktopGrid(self):
        if self._backend and hasattr(self._backend, "workspace") and self._backend.workspace:
            self.run_async(self._backend.workspace.toggle_desktop_grid())

    @Slot()
    def toggleRecording(self): self._call_backend("recording", "focus_window")
    @Slot()
    def refreshRecordingMenu(self): self._call_backend("recording", "fetch_menu_async")
    @Slot(int)
    def activateRecordingMenuItem(self, item_id: int): self._call_backend("recording", "activate_menu_item", item_id)
        
    @Slot()
    def toggleIme(self): self._call_backend("ime", "toggle")
    @Slot(str)
    def switchImeTo(self, name: str): self._call_backend("ime", "switch_to_im", name)
    @Slot()
    def openImeConfig(self): self._call_backend("ime", "open_config")
    @Slot()
    def refreshImeMenu(self): self._call_backend("ime", "fetch_menu_async")
    @Slot(int, str)
    def activateImeMenuItem(self, item_id: int, unique_name: str = ""): self._call_backend("ime", "activate_menu_item", item_id, unique_name)

    @Slot(int, int)
    def adjustHardware(self, mode: int, delta: int):
        target = "audio" if mode == 0 else "brightness"
        self._call_backend(target, "set_delta", delta)
    @Slot(int, int)
    def setHardware(self, mode: int, val: int):
        target = "audio" if mode == 0 else "brightness"
        action = "set_volume" if mode == 0 else "set_brightness"
        self._call_backend(target, action, val)
    @Slot(int)
    def toggleHardwareMute(self, mode: int):
        action = "toggle_mute" if mode == 0 else "toggle_mic_mute"
        self._call_backend("audio", action)

    @Slot(str)
    def sendMediaCmd(self, action: str):
        mapping = {"MEDIA_PLAY_PAUSE": "PlayPause", "MEDIA_NEXT": "Next", "MEDIA_PREV": "Previous"}
        self._call_backend("mpris", "control", mapping.get(action, action))
    @Slot(str, str)
    def focusMediaWindow(self, title="", artist=""): self._call_backend("mpris", "raise_player")

    @Slot()
    def answerTeamsCall(self): self._call_backend("notifications", "answer_call")
    @Slot()
    def rejectTeamsCall(self): self._call_backend("notifications", "reject_call")
    @Slot()
    def focusTeamsWindow(self): self._call_backend("notifications", "focus_teams")

    @Slot(str)
    def switchTimerType(self, t): self._call_backend("timer", "switch_type", t)
    @Slot()
    def toggleTimerPause(self): self._call_backend("timer", "toggle_pause")
    @Slot(int, str)
    def startTimerPreset(self, sec: int, m: str): self._call_backend("timer", "start_preset", sec, m)
    @Slot(int)
    def adjustTimerTime(self, delta: int): self._call_backend("timer", "adjust_time", delta)
    @Slot()
    def recordTimerLap(self): self._call_backend("timer", "record_lap")
    @Slot()
    def resetTimer(self): self._call_backend("timer", "reset")
    @Slot(str)
    def resetSpecificTimer(self, track: str): self._call_backend("timer", "reset_specific", track)

    @Slot()
    def toggleVoiceInput(self): self._call_backend("voice", "toggle_recording")
    @Slot()
    def stopVoiceInput(self): self._call_backend("voice", "stop_recording")
    @Slot()
    def dismissOverlay(self):
        if self._backend:
            self._backend.state.clear_overlay()
            self.overlayChanged.emit()

    @Slot(bool)
    def setUiActive(self, active: bool):
        if self._backend:
            self._backend.set_ui_active(active)

    @Slot()
    def forceRaise(self): self.view.raise_()
    @Slot()
    def openFullCorridorForMotion(self): self.wm.clear_mask()
    @Slot(int, int, int, int)
    def applySettledMask(self, x, y, w, h): self.wm.set_precise_bounding_mask(x, y, w, h)
    @Slot()
    def setPassthrough(self): self.wm.set_passthrough()
    @Slot()
    def openSystemMonitor(self): self.wm.open_system_monitor()

    @Slot()
    def requestWindowFocus(self):
        if hasattr(self.wm.platform, "acquire_interaction_focus"):
            self.wm.platform.acquire_interaction_focus(self.view)
        else:
            self.view.requestActivate()

    @Slot(bool)
    def setRequireFocus(self, required: bool):
        flags = self.view.flags()
        if required:
            flags &= ~Qt.WindowType.WindowDoesNotAcceptFocus
            self.view.setFlags(flags)
            self.view.show()
            self.requestWindowFocus()
        else:
            flags |= Qt.WindowType.WindowDoesNotAcceptFocus
            self.view.setFlags(flags)
            self.view.show()
            self.restorePreviousFocus()

    @Slot()
    def restorePreviousFocus(self):
        if hasattr(self.wm.platform, "restore_previous_focus"):
            self.wm.platform.restore_previous_focus(self.view)

    @Slot(str, bool, result=dict)
    def getWorldTime(self, tz, is_24h=True): return get_world_time(tz, is_24h)
    @Slot(str, result=str)
    def getTzOffsetStr(self, tz): return get_tz_offset_str(tz)

    @Slot(result="QVariantMap")
    def getSystemHealth(self):
        import shutil
        return {
            "platform": self.wm.platform.platform_name,
            "kwinWorking": bool(self.wm.platform.platform_name.startswith("KDE")),
            "audioWorking": bool(self._backend and hasattr(self._backend, "audio") and self._backend.audio and self._backend.audio._running),
            "brightnessWorking": bool(self._backend and hasattr(self._backend, "brightness") and self._backend.brightness and self._backend.brightness.bus is not None),
            "cavaInstalled": bool(shutil.which("cava")),
            "wlPasteInstalled": bool(shutil.which("wl-paste")),
        }