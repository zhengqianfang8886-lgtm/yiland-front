# ==========================================
# 📄 File: backend/bridge.py
# 🌟 Qt / QML 统一交互中枢 (已彻底剔除 OSD 弹窗信号)
# ==========================================
import atexit
import asyncio
from concurrent.futures import ThreadPoolExecutor

from PySide6.QtCore import QObject, Signal, Slot, Property, Qt, QEvent
from backend.models import NotificationListModel
from backend.window import WindowManagerService
from backend.bridge_events import BridgeEventDispatcher
from backend.utils import get_world_time, get_tz_offset_str


class WindowEventFilter(QObject):
    def __init__(self, bridge):
        super().__init__()
        self.bridge = bridge

    def eventFilter(self, watched, event):
        if event.type() == QEvent.Type.WindowDeactivate:
            self.bridge.windowDeactivated.emit()
        return super().eventFilter(watched, event)


class IslandBridge(QObject):
    """QML 与 Python 后端统一总线门面 (单一事实源定义)"""

    # =========================================================================
    # 1. Qt 核心信号列表
    # =========================================================================
    # 媒体与声学
    mediaUpdated = Signal(str, str, str, str, float, float)
    progressUpdated = Signal(float, float, float)
    audioSpectrumUpdated = Signal(float, float, float, float)
    dominantColorUpdated = Signal(str)

    # 硬件与按键状态 (已移除 osdTriggered 信号)
    hardwareMuteStateChanged = Signal(bool, bool)
    volumeChanged = Signal(int)
    brightnessChanged = Signal(int)
    capsLockChanged = Signal(bool)
    numLockChanged = Signal(bool)

    # 工作区与系统悬浮
    workspaceTriggered = Signal(int, int, str)
    workspaceListUpdated = Signal("QVariantList")
    alertTriggered = Signal(str, str, str, int, str)
    callIncomingTriggered = Signal(str, str, str)
    callEndedTriggered = Signal()
    unreadCountChanged = Signal(int)
    gridActiveChanged = Signal(bool)

    # 硬件负载、网速与计时
    memoryUpdated = Signal(int, str, str)
    netSpeedUpdated = Signal(str, str, str, str, str, str)
    batteryUpdated = Signal(int, bool)
    timerUpdated = Signal()
    overlayChanged = Signal()

    # 端侧离线语音
    voiceInputLevelChanged = Signal(float)
    voiceInputStateChanged = Signal(bool, str)

    # 系统输入法
    imeUpdated = Signal(bool, str, str, str)
    imeMenuUpdated = Signal("QVariantList")
    windowDeactivated = Signal()

    # 内部跨线程派发专用信号
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
        self._notif_model.unreadCountChanged.connect(self.unreadCountChanged.emit)

        self.wm = WindowManagerService(self.view, self._pool, self.config, self)
        self._dispatcher = BridgeEventDispatcher(self)

        self._sig_inproc_event.connect(self._handle_inproc_event, Qt.ConnectionType.QueuedConnection)
        self._sig_spectrum_event.connect(self.audioSpectrumUpdated.emit, Qt.ConnectionType.QueuedConnection)

        self._event_filter = WindowEventFilter(self)
        self.view.installEventFilter(self._event_filter)

        self.windowDeactivated.connect(self._on_window_deactivated)
        atexit.register(self.cleanup)

    def _on_window_deactivated(self):
        if self._backend and self._backend.ime:
            self._backend.ime.trigger_sync()

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
        self._dispatcher.dispatch(event_type, s)

    # --- 输入法属性 ---
    @Property(bool, notify=imeUpdated)
    def isImeActive(self): return self._backend.state.ime_active if self._backend else False

    @Property(str, notify=imeUpdated)
    def imeLabel(self): return self._backend.state.ime_label if self._backend else "英"

    @Property(str, notify=imeUpdated)
    def imeName(self): return self._backend.state.ime_name if self._backend else ""

    @Property(str, notify=imeUpdated)
    def imeIcon(self): return self._backend.state.ime_icon_url if self._backend else ""

    @Property(list, notify=imeMenuUpdated)
    def imeMenuList(self):
        return getattr(self._backend.state, "ime_menu_items", []) if self._backend else []

    @Slot()
    def refreshImeMenu(self):
        if self._backend and self._backend.ime:
            self.run_async(self._backend.ime.fetch_menu_async())

    @Slot(int, str)
    def activateImeMenuItem(self, item_id: int, unique_name: str = ""):
        print(f"\033[33;1m[Bridge] 收到前端 activateImeMenuItem(id={item_id}, unique_name='{unique_name}')\033[0m")
        if self._backend and self._backend.ime:
            self.run_async(self._backend.ime.activate_menu_item(item_id, unique_name))

    # --- 硬件与系统监视属性 ---
    @Property(bool, notify=gridActiveChanged)
    def isGridActive(self): return self._backend.state.is_desktop_grid_active if self._backend else False

    @Property(int, notify=volumeChanged)
    def currentVolume(self): return self._backend.state.volume if self._backend else 50

    @Property(int, notify=brightnessChanged)
    def currentBrightness(self): return self._backend.state.brightness if self._backend else 100

    @Property(bool, notify=capsLockChanged)
    def isCapsLock(self): return self._backend.state.is_caps_lock if self._backend else False

    @Property(bool, notify=numLockChanged)
    def isNumLock(self): return self._backend.state.is_num_lock if self._backend else False

    @Property(int, notify=batteryUpdated)
    def systemBattery(self): return self._backend.state.battery_pct if self._backend else 100

    @Property(bool, notify=batteryUpdated)
    def isSystemCharging(self): return self._backend.state.battery_charging if self._backend else False

    # =========================================================================
    # 定时器双轨独立属性 (支持前端同时展示)
    # =========================================================================
    # --- 兼容视图属性 ---
    @Property(str, notify=timerUpdated)
    def timerType(self): return self._backend.state.timer_type if self._backend else "countdown"

    @Property(bool, notify=timerUpdated)
    def timerIsRunning(self): return self._backend.state.timer_is_running if self._backend else False

    @Property(bool, notify=timerUpdated)
    def timerIsPaused(self): return self._backend.state.timer_is_paused if self._backend else False

    @Property(bool, notify=timerUpdated)
    def timerIsCompleted(self): return self._backend.state.timer_is_completed if self._backend else False

    @Property(bool, notify=timerUpdated)
    def timerIsOvertime(self): return getattr(self._backend.state, "timer_is_overtime", False) if self._backend else False

    @Property(int, notify=timerUpdated)
    def timerOvertimeSec(self): return getattr(self._backend.state, "timer_overtime_sec", 0) if self._backend else 0

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

    # --- 🚀 独立【倒计时轨】专有属性 ---
    @Property(bool, notify=timerUpdated)
    def cdActive(self):
        s = self._backend.state if self._backend else None
        return bool(s and (s.cd_is_running or s.cd_is_paused or s.cd_is_overtime))

    @Property(bool, notify=timerUpdated)
    def cdIsRunning(self): return self._backend.state.cd_is_running if self._backend else False

    @Property(bool, notify=timerUpdated)
    def cdIsPaused(self): return self._backend.state.cd_is_paused if self._backend else False

    @Property(bool, notify=timerUpdated)
    def cdIsOvertime(self): return self._backend.state.cd_is_overtime if self._backend else False

    @Property(int, notify=timerUpdated)
    def cdRemainingSec(self): return self._backend.state.cd_remaining_sec if self._backend else 1500

    @Property(int, notify=timerUpdated)
    def cdOvertimeSec(self): return self._backend.state.cd_overtime_sec if self._backend else 0

    @Property(str, notify=timerUpdated)
    def cdMode(self): return self._backend.state.cd_mode if self._backend else "focus"

    # --- 🚀 独立【正向秒表轨】专有属性 ---
    @Property(bool, notify=timerUpdated)
    def swActive(self):
        s = self._backend.state if self._backend else None
        return bool(s and (s.sw_is_running or s.sw_is_paused))

    @Property(bool, notify=timerUpdated)
    def swIsRunning(self): return self._backend.state.sw_is_running if self._backend else False

    @Property(bool, notify=timerUpdated)
    def swIsPaused(self): return self._backend.state.sw_is_paused if self._backend else False

    @Property(int, notify=timerUpdated)
    def swElapsedSec(self): return self._backend.state.sw_elapsed_sec if self._backend else 0

    # --- 槽函数 ---
    @Slot(str)
    def resetSpecificTimer(self, track_type: str):
        """精准重置某一轨 (countdown 或 stopwatch)"""
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.reset_specific(track_type))

    # --- 打断与语音属性 ---
    @Property("QVariantMap", notify=overlayChanged)
    def activeOverlay(self): return self._backend.state.get_overlay_dict() if self._backend else {}

    @Property(bool, notify=voiceInputStateChanged)
    def voiceInputActive(self): return self._backend.state.voice_input_active if self._backend else False

    @Property(str, notify=voiceInputStateChanged)
    def voiceInputText(self): return self._backend.state.voice_input_text if self._backend else ""

    @Property(float, notify=voiceInputLevelChanged)
    def voiceInputLevel(self): return self._backend.state.voice_input_level if self._backend else 0.1

    # --- 列表模型 ---
    @Property(QObject, constant=True)
    def notificationModel(self): return self._notif_model

    @Property(int, notify=unreadCountChanged)
    def unreadCount(self): return self._notif_model.unreadCount

    @Property(str, notify=unreadCountChanged)
    def latestNotificationAvatar(self): return self._notif_model.latestAvatar

    # =========================================================================
    # 3. 业务槽函数
    # =========================================================================
    @Slot()
    def toggleIme(self):
        print("\033[33;1m[Bridge] 收到前端 toggleIme() 槽函数调用\033[0m")
        if self._backend and self._backend.ime:
            self.run_async(self._backend.ime.toggle())

    @Slot(str)
    def switchImeTo(self, im_name: str):
        print(f"\033[33;1m[Bridge] 收到前端 switchImeTo('{im_name}')\033[0m")
        if self._backend and self._backend.ime:
            self.run_async(self._backend.ime.switch_to_im(im_name))

    @Slot()
    def openImeConfig(self):
        if self._backend and self._backend.ime: self.run_async(self._backend.ime.open_config())

    @Slot(int, int)
    def adjustHardware(self, mode: int, delta: int):
        if not self._backend: return
        if mode == 0 and self._backend.audio: self.run_async(self._backend.audio.set_delta(delta))
        elif mode == 1 and self._backend.brightness: self.run_async(self._backend.brightness.set_delta(delta))

    @Slot(int, int)
    def setHardware(self, mode: int, target_val: int):
        if not self._backend: return
        if mode == 0 and self._backend.audio: self.run_async(self._backend.audio.set_volume(target_val))
        elif mode == 1 and self._backend.brightness: self.run_async(self._backend.brightness.set_brightness(target_val))

    @Slot(int)
    def toggleHardwareMute(self, mode: int):
        if not self._backend or not self._backend.audio: return
        if mode == 0: self.run_async(self._backend.audio.toggle_mute())
        elif mode == 2: self.run_async(self._backend.audio.toggle_mic_mute())

    @Slot(int)
    @Slot(str)
    def switchWorkspace(self, target):
        if self._backend and self._backend.workspace: self.run_async(self._backend.workspace.switch_workspace(target))

    @Slot()
    def switchWorkspacePrev(self):
        if self._backend and self._backend.workspace: self.run_async(self._backend.workspace.switch_workspace("prev"))

    @Slot()
    def switchWorkspaceNext(self):
        if self._backend and self._backend.workspace: self.run_async(self._backend.workspace.switch_workspace("next"))

    @Slot()
    def toggleDesktopGrid(self):
        if self._backend and self._backend.workspace: self.run_async(self._backend.workspace.toggle_desktop_grid())

    @Slot(str)
    def sendMediaCmd(self, action: str):
        if not self._backend or not self._backend.mpris: return
        action_map = {"MEDIA_PLAY_PAUSE": "PlayPause", "MEDIA_NEXT": "Next", "MEDIA_PREV": "Previous"}
        cmd = action_map.get(action, action)
        self.run_async(self._backend.mpris.control(cmd))

    @Slot(str, str)
    def focusMediaWindow(self, title="", artist=""):
        if self._backend and self._backend.mpris: self.run_async(self._backend.mpris.raise_player())

    @Slot(str)
    def switchTimerType(self, t_type: str):
        if self._backend and self._backend.timer: self.run_async(self._backend.timer.switch_type(t_type))

    @Slot()
    def toggleTimerPause(self):
        if self._backend and self._backend.timer: self.run_async(self._backend.timer.toggle_pause())

    @Slot(int, str)
    def startTimerPreset(self, sec: int, mode: str):
        if self._backend and self._backend.timer: self.run_async(self._backend.timer.start_preset(sec, mode))

    @Slot(int)
    def adjustTimerTime(self, delta_sec: int):
        if self._backend and self._backend.timer: self.run_async(self._backend.timer.adjust_time(delta_sec))

    @Slot()
    def recordTimerLap(self):
        if self._backend and self._backend.timer: self.run_async(self._backend.timer.record_lap())

    @Slot()
    def resetTimer(self):
        if self._backend and self._backend.timer: self.run_async(self._backend.timer.reset())

    @Slot()
    def toggleVoiceInput(self):
        if self._backend and self._backend.voice: self.run_async(self._backend.voice.toggle_recording())

    @Slot()
    def stopVoiceInput(self):
        if self._backend and self._backend.voice: self.run_async(self._backend.voice.stop_recording())

    @Slot()
    def dismissOverlay(self):
        if self._backend:
            self._backend.state.clear_overlay()
            self.overlayChanged.emit()

    @Slot(bool)
    def setUiActive(self, active: bool):
        if self._backend: self._backend.set_ui_active(active)

    @Slot(str, bool, result=dict)
    def getWorldTime(self, tz_name, is_24h=True): return get_world_time(tz_name, is_24h)

    @Slot(str, result=str)
    def getTzOffsetStr(self, tz_name): return get_tz_offset_str(tz_name)

    @Slot(result="QVariantMap")
    def getSystemHealth(self):
        import shutil
        return {
            "platform": self.wm.platform.platform_name,
            "kwinWorking": bool(self.wm.platform.platform_name.startswith("KDE")),
            "audioWorking": bool(self._backend and self._backend.audio and self._backend.audio._running),
            "brightnessWorking": bool(self._backend and self._backend.brightness and self._backend.brightness.bus is not None),
            "cavaInstalled": bool(shutil.which("cava")),
            "wlPasteInstalled": bool(shutil.which("wl-paste")),
        }

    @Slot()
    def openSystemMonitor(self): self.wm.open_system_monitor()

    @Slot()
    def forceRaise(self): self.view.raise_()

    @Slot()
    def openFullCorridorForMotion(self): self.wm.clear_mask()

    @Slot(int, int, int, int)
    def applySettledMask(self, x: int, y: int, w: int, h: int): self.wm.set_precise_bounding_mask(x, y, w, h)

    @Slot()
    def setPassthrough(self): self.wm.set_passthrough()

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