# ==========================================
# 📄 File: backend/bridge.py
# 🌟 Qt / QML 统一交互中枢 (QMetaObject 强类型绑定 · 消除非可绑定警告版)
# ==========================================
import atexit
import asyncio
from concurrent.futures import ThreadPoolExecutor

from PySide6.QtCore import QObject, Signal, Slot, Property, Qt, QEvent
from backend.models import NotificationListModel, BluetoothListModel
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
    """QML 与 Python 后端统一总线门面"""

    # =========================================================================
    # 1. Qt 核心信号列表 (严格作为 Property 的 NOTIFY 依赖项)
    # =========================================================================
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

    workspaceTriggered = Signal(int, int, str)
    workspaceListUpdated = Signal("QVariantList")
    alertTriggered = Signal(str, str, str, int, str)
    callIncomingTriggered = Signal(str, str, str)
    callEndedTriggered = Signal()
    unreadCountChanged = Signal(int)
    gridActiveChanged = Signal(bool)

    memoryUpdated = Signal(int, str, str)
    netSpeedUpdated = Signal(str, str, str, str, str, str)
    batteryUpdated = Signal(int, bool)
    timerUpdated = Signal()
    overlayChanged = Signal()

    voiceInputLevelChanged = Signal(float)
    voiceInputStateChanged = Signal(bool, str)

    habitsLoaded = Signal("QVariantList")
    monthRecordsLoaded = Signal(str, int, int, "QVariantMap")
    habitRecordToggled = Signal(str, str, bool)
    calendarGridLoaded = Signal(int, int, "QVariantList")

    imeUpdated = Signal(bool, str, str, str)  # is_active, label, im_name, icon_url
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
        self._dispatcher = BridgeEventDispatcher(self)

        self._sig_inproc_event.connect(self._handle_inproc_event, Qt.ConnectionType.QueuedConnection)
        self._sig_spectrum_event.connect(self.audioSpectrumUpdated.emit, Qt.ConnectionType.QueuedConnection)

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

    @Property(str, notify=imeUpdated)
    def imeIcon(self):
        return self._backend.state.ime_icon_url if self._backend else ""

    @Slot(str, object)
    def _handle_inproc_event(self, event_type: str, s):
        self._dispatcher.dispatch(event_type, s)

    # =========================================================================
    # 2. QML 绑定属性 (显式绑定真实 Signal 对象，彻底消灭 non-bindable 警告)
    # =========================================================================
    # --- 输入法属性 ---
    @Property(bool, notify=imeUpdated)
    def isImeActive(self):
        return self._backend.state.ime_active if self._backend else False

    @Property(str, notify=imeUpdated)
    def imeLabel(self):
        return self._backend.state.ime_label if self._backend else "英"

    @Property(str, notify=imeUpdated)
    def imeName(self):
        return self._backend.state.ime_name if self._backend else ""

    # --- 硬件与系统监视属性 ---
    @Property(bool, notify=gridActiveChanged)
    def isGridActive(self):
        return self._backend.state.is_desktop_grid_active if self._backend else False

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

    # --- 定时器属性 ---
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

    # --- 打断与语音属性 ---
    @Property("QVariantMap", notify=overlayChanged)
    def activeOverlay(self):
        return self._backend.state.get_overlay_dict() if self._backend else {}

    @Property(bool, notify=voiceInputStateChanged)
    def voiceInputActive(self):
        return self._backend.state.voice_input_active if self._backend else False

    @Property(str, notify=voiceInputStateChanged)
    def voiceInputText(self):
        return self._backend.state.voice_input_text if self._backend else ""

    @Property(float, notify=voiceInputLevelChanged)
    def voiceInputLevel(self):
        return self._backend.state.voice_input_level if self._backend else 0.1

    # --- 列表模型常量 ---
    @Property(QObject, constant=True)
    def notificationModel(self): return self._notif_model

    @Property(int, notify=unreadCountChanged)
    def unreadCount(self): return self._notif_model.unreadCount

    @Property(str, notify=unreadCountChanged)
    def latestNotificationAvatar(self): return self._notif_model.latestAvatar

    @Property(QObject, constant=True)
    def bluetoothModel(self): return self._bt_model

    # =========================================================================
    # 3. 业务槽函数 (QML 触发执行)
    # =========================================================================
    # --- 输入法控制 ---
    @Slot()
    def toggleIme(self):
        if self._backend and self._backend.ime: self.run_async(self._backend.ime.toggle())

    @Slot(str)
    def switchImeTo(self, im_name: str):
        if self._backend and self._backend.ime: self.run_async(self._backend.ime.switch_to_im(im_name))

    @Slot()
    def openImeConfig(self):
        if self._backend and self._backend.ime: self.run_async(self._backend.ime.open_config())

    # --- 硬件调节 ---
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

    # --- 工作区与平铺网格 ---
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

    # --- 媒体控制 ---
    @Slot(str)
    def sendMediaCmd(self, action: str):
        if not self._backend or not self._backend.mpris: return
        action_map = {"MEDIA_PLAY_PAUSE": "PlayPause", "MEDIA_NEXT": "Next", "MEDIA_PREV": "Previous"}
        cmd = action_map.get(action, action)
        self.run_async(self._backend.mpris.control(cmd))

    @Slot(str, str)
    def focusMediaWindow(self, title="", artist=""):
        if self._backend and self._backend.mpris: self.run_async(self._backend.mpris.raise_player())

    # --- 定时器控制 ---
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

    # --- 习惯日程与日历 ---
    @Slot()
    def requestHabits(self):
        if not self._backend or not self._backend.habits: self.habitsLoaded.emit([]); return
        async def _run():
            data = await self._backend.habits.fetch_habits_async()
            self.habitsLoaded.emit(data)
        self.run_async(_run())

    @Slot(str, str)
    def requestAddHabit(self, name: str, icon: str = "📌"):
        if not self._backend or not self._backend.habits: return
        async def _run():
            data = await self._backend.habits.add_habit_async(name, icon)
            self.habitsLoaded.emit(data)
        self.run_async(_run())

    @Slot(str)
    def requestDeleteHabit(self, habit_id: str):
        if not self._backend or not self._backend.habits: return
        async def _run():
            data = await self._backend.habits.delete_habit_async(habit_id)
            self.habitsLoaded.emit(data)
        self.run_async(_run())

    @Slot(str, int, int)
    def requestMonthRecords(self, habit_id: str, year: int, month: int):
        if not self._backend or not self._backend.habits: self.monthRecordsLoaded.emit(habit_id, year, month, {}); return
        async def _run():
            data = await self._backend.habits.fetch_month_records_async(habit_id, year, month)
            self.monthRecordsLoaded.emit(habit_id, year, month, data)
        self.run_async(_run())

    @Slot(str, str)
    def requestToggleRecord(self, habit_id: str, date_str: str):
        if not self._backend or not self._backend.habits: return
        async def _run():
            is_checked = await self._backend.habits.toggle_record_async(habit_id, date_str)
            self.habitRecordToggled.emit(habit_id, date_str, is_checked)
        self.run_async(_run())

    @Slot(int, int, str)
    def requestCalendarGrid(self, year: int, month: int, habit_id: str):
        if not self._backend or not self._backend.habits: self.calendarGridLoaded.emit(year, month, []); return
        async def _run():
            grid = await self._backend.habits.generate_calendar_grid_async(year, month, habit_id)
            self.calendarGridLoaded.emit(year, month, grid)
        self.run_async(_run())

    # --- 语言与打断 ---
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

    # --- 工具函数与系统诊断 ---
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
            "dbConnected": bool(self._backend and self._backend.habits)
        }

    # --- 窗口管理器代理 ---
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
        """🚀 动态焦点护盾控制：仅在需要打字时撕开护盾获取焦点"""
        flags = self.view.flags()
        if required:
            # 移除不接受焦点的限制，并提权
            flags &= ~Qt.WindowType.WindowDoesNotAcceptFocus
            self.view.setFlags(flags)
            self.view.show() # Qt 机制：修改 flag 后必须 show 使其生效
            self.requestWindowFocus()
        else:
            # 恢复绝对防抢夺护盾，并把焦点还给之前的宿主应用
            flags |= Qt.WindowType.WindowDoesNotAcceptFocus
            self.view.setFlags(flags)
            self.view.show()
            self.restorePreviousFocus()

    @Slot()
    def restorePreviousFocus(self):
        if hasattr(self.wm.platform, "restore_previous_focus"):
            self.wm.platform.restore_previous_focus(self.view)