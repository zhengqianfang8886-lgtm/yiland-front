# ==========================================
# 📄 File: bridge.py
# 🌟 统一事件中枢与 Qt 桥接层
# ==========================================
import gc
import time
import atexit
import asyncio
from concurrent.futures import ThreadPoolExecutor

from PySide6.QtCore import QObject, Signal, Slot, Property, Qt
from models import NotificationListModel, BluetoothListModel
from services import WindowManagerService, get_world_time, get_tz_offset_str


class IslandBridge(QObject):
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

    # 性能与硬件信号
    memoryUpdated = Signal(int, str, str)
    netSpeedUpdated = Signal(str, str, str, str)
    batteryUpdated = Signal(int, bool)

    _sig_inproc_event = Signal(str, object)

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

        # 缓存属性（单一来源：后端推流）
        self._cached_volume = 50
        self._cached_brightness = 100
        self._cached_caps_lock = False
        self._cached_num_lock = False
        self._cached_battery = 100
        self._cached_charging = False

        self.wm = WindowManagerService(self.view, self._pool, self.config, self)
        self.wm.clipboardTriggered.connect(self.clipboardTriggered)

        self._sig_inproc_event.connect(self._handle_inproc_event, Qt.ConnectionType.QueuedConnection)
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

    # --- 属性绑定 ---
    @Property(QObject, constant=True)
    def notificationModel(self): return self._notif_model

    @Property(int, notify=unreadCountChanged)
    def unreadCount(self): return self._notif_model.unreadCount

    @Property(str, notify=unreadCountChanged)
    def latestNotificationAvatar(self): return self._notif_model.latestAvatar

    @Property(QObject, constant=True)
    def bluetoothModel(self): return self._bt_model

    @Property(int, notify=volumeChanged)
    def currentVolume(self): return self._cached_volume

    @Property(int, notify=brightnessChanged)
    def currentBrightness(self): return self._cached_brightness

    @Property(bool, notify=capsLockChanged)
    def isCapsLock(self): return self._cached_caps_lock

    @Property(bool, notify=numLockChanged)
    def isNumLock(self): return self._cached_num_lock

    @Property(int, notify=batteryUpdated)
    def systemBattery(self): return self._cached_battery

    @Property(bool, notify=batteryUpdated)
    def isSystemCharging(self): return self._cached_charging

    @Property(bool, constant=True)
    def isBluetoothPowered(self): return True

    # --- 硬件与系统控制槽函数 ---
    @Slot(int, int)
    def adjustHardware(self, mode: int, delta: int):
        if not self._backend: return
        if mode == 0 and self._backend.audio:
            self.run_async(self._backend.audio.set_delta(delta))
        elif mode == 1 and self._backend.brightness:
            self.run_async(self._backend.brightness.set_delta(delta))

    @Slot(int)
    def toggleHardwareMute(self, mode: int):
        if not self._backend: return
        if mode == 0 and self._backend.audio:
            self.run_async(self._backend.audio.toggle_mute())
        elif mode == 2 and self._backend.audio:
            self.run_async(self._backend.audio.toggle_mic_mute())

    @Slot(int)
    def adjustVolume(self, delta_pct: int):
        if self._backend and self._backend.audio:
            self.run_async(self._backend.audio.set_delta(delta_pct))

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
    def openBluetoothSettings(self): self.wm.open_bluetooth_settings()

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

    def post_inproc_event(self, event_type: str, state_obj):
        try:
            self._sig_inproc_event.emit(event_type, state_obj)
        except RuntimeError:
            pass

    @Slot(str, object)
    def _handle_inproc_event(self, event_type: str, s):
        # 1. 媒体事件
        if event_type in ("MEDIA_UPDATE", "FULL_SYNC"):
            art = s.art_url
            if art and art.startswith("/") and not art.startswith("file://"):
                art = "file://" + art
            self.mediaUpdated.emit(s.title, s.artist, s.playback_status, art, s.position, s.duration)
        elif event_type in ("MEDIA_PROGRESS", "MEDIA_TICK"):
            prog = (s.position / s.duration) if s.duration > 0 else 0.0
            self.progressUpdated.emit(s.position, s.duration, prog)

        # 2. 工作区事件
        if event_type in ("WORKSPACE_CHANGED", "FULL_SYNC"):
            self.workspaceTriggered.emit(s.workspace_index, s.workspace_total, s.workspace_name)
            self.workspaceListUpdated.emit(s.workspaces)

        # 3. 硬件音量与亮度
        if event_type in ("VOLUME_UPDATE", "FULL_SYNC"):
            self._cached_volume = s.volume
            self.volumeChanged.emit(s.volume)
            self.hardwareMuteStateChanged.emit(s.is_muted, s.is_mic_muted)
            if event_type == "VOLUME_UPDATE":
                icon = "🔇" if s.is_muted else ("🔈" if s.volume == 0 else "🔊")
                self.osdTriggered.emit(icon, "Volume", s.volume)

        if event_type in ("BRIGHTNESS_UPDATE", "FULL_SYNC"):
            self._cached_brightness = s.brightness
            self.brightnessChanged.emit(s.brightness)
            if event_type == "BRIGHTNESS_UPDATE":
                self.osdTriggered.emit("☀️", "Display", s.brightness)

        # 4. 键盘锁
        if event_type in ("KEYBOARD_LOCK_UPDATE", "FULL_SYNC"):
            if self._cached_caps_lock != s.is_caps_lock:
                self._cached_caps_lock = s.is_caps_lock
                self.capsLockChanged.emit(s.is_caps_lock)
            if self._cached_num_lock != s.is_num_lock:
                self._cached_num_lock = s.is_num_lock
                self.numLockChanged.emit(s.is_num_lock)

        # 5. 性能与网速
        if event_type in ("MEMORY_UPDATE", "FULL_SYNC"):
            self.memoryUpdated.emit(s.memory_percent, s.memory_used_gb, s.memory_total_gb)

        if event_type in ("NET_SPEED_UPDATE", "FULL_SYNC"):
            self.netSpeedUpdated.emit(s.net_down_speed, s.net_up_speed, s.net_down_compact, s.net_up_compact)

        if event_type in ("BATTERY_UPDATE", "FULL_SYNC"):
            self._cached_battery = s.battery_pct
            self._cached_charging = s.battery_charging
            self.batteryUpdated.emit(s.battery_pct, s.battery_charging)

        # 6. 通话与通知
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
            self.alertTriggered.emit(s.last_notify_icon or "💬", t_title, t_sub, 3500, avatar)