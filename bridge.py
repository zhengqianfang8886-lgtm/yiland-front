# ==========================================
# 📄 File: bridge.py
# 🌟 阶段式单次视窗拓展机制（杜绝抽搐与卡顿）
# ==========================================
import gc
import time
import atexit
import asyncio
from concurrent.futures import ThreadPoolExecutor

from PySide6.QtCore import QObject, Signal, Slot, Property, Qt
from logger import app_logger
from models import NotificationListModel, BluetoothListModel
from services import (
    WindowManagerService,
    get_world_time,
    get_tz_offset_str,
    get_local_ip,
)
from PySide6.QtGui import QGuiApplication


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
        self._notif_model.unreadCountChanged.connect(self._on_model_unread_changed)

        self._cached_volume = 50
        self._cached_brightness = 100

        self.wm = WindowManagerService(self.view, self._pool, self.config, self)
        self.wm.clipboardTriggered.connect(self.clipboardTriggered)

        self._sig_inproc_event.connect(self._handle_inproc_event, Qt.ConnectionType.QueuedConnection)
        atexit.register(self.cleanup)

    def _on_model_unread_changed(self, count):
        self.unreadCountChanged.emit(count)

    def set_backend(self, backend, loop):
        self._backend = backend
        self._async_loop = loop

    def run_async(self, coro):
        if self._async_loop and self._async_loop.is_running():
            asyncio.run_coroutine_threadsafe(coro, self._async_loop)

    @Slot(str, str)
    def traceLog(self, tag: str, msg: str):
        ts = time.strftime("%H:%M:%S") + f".{int(time.time()*1000)%1000:03d}"
        print(f"\033[96m[{ts}] [{tag}]\033[0m {msg}", flush=True)

    def cleanup(self):
        if hasattr(self, "_notif_model"):
            self._notif_model.clearAll()
        self._pool.shutdown(wait=False, cancel_futures=True)

    # =========================================================================
    # 🚀【极速模式】：单次定界，动画期间绝不 resize 窗口，彻底释放 GPU 120Hz 算力
    # =========================================================================
    @Slot(str)
    def notifyWindowState(self, state_name: str):
        """仅在状态跳变时单次调用（0 毫秒完成），动画全程 GPU 自主计算渲染"""
        screen = QGuiApplication.primaryScreen()
        if not screen: return
        base = screen.geometry() if (not self.config or self.config.anchorMode == "screen") else screen.availableGeometry()
        off_x = self.config.offsetX if self.config else 0
        top_m = self.config.capsuleTopMargin if self.config else 8

        if state_name == "EXPANDED":
            w, h = 440, 270
            final_y = base.y() + top_m
        elif state_name == "TUCKED":
            w, h = 260, 6
            final_y = base.y()  # 顶格
        else:  # NORMAL / PEEKING
            w, h = 440, 52
            final_y = base.y() + top_m

        final_x = base.x() + (base.width() - w) // 2 + off_x
        self.view.setGeometry(final_x, final_y, w, h)

    # 兼容过渡保留
    @Slot("QVariantList")
    def updateCompositeMask(self, rects): pass
    @Slot()
    def setPassthrough(self): pass
    @Slot()
    def clearMask(self): pass
    @Slot()
    def forceClearWindow(self): pass

    # 属性
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
    def isCapsLock(self): return False

    @Property(bool, notify=numLockChanged)
    def isNumLock(self): return False

    @Property(int, constant=True)
    def systemBattery(self): return 100

    @Property(bool, constant=True)
    def isSystemCharging(self): return False

    @Property(bool, constant=True)
    def isBluetoothPowered(self): return True

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
        if action == "MEDIA_PLAY_PAUSE":
            self.run_async(self._backend.mpris.control("PlayPause"))
        elif action == "MEDIA_NEXT":
            self.run_async(self._backend.mpris.control("Next"))
        elif action == "MEDIA_PREV":
            self.run_async(self._backend.mpris.control("Previous"))

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

    @Slot(result=str)
    def getLatestNotificationAvatar(self): return self._notif_model.latestAvatar

    @Slot()
    def forceRaise(self):
        # 仅提升视觉层级，绝不激活视窗焦点
        self.view.raise_()

    @Slot()
    def requestWindowFocus(self):
        # 绝不执行 requestActivate()，保持无焦点状态
        self.view.raise_()

    @Slot()
    def onIslandCollapsed(self):
        gc.collect(generation=1)
        if hasattr(self.view, "engine") and hasattr(self.view.engine(), "trimComponentCache"):
            self.view.engine().trimComponentCache()

    @Slot(str, bool, result=dict)
    def getWorldTime(self, tz_name, is_24h=True): return get_world_time(tz_name, is_24h)

    @Slot(str, result=str)
    def getTzOffsetStr(self, tz_name): return get_tz_offset_str(tz_name)

    def post_inproc_event(self, event_type: str, state_obj):
        try:
            self._sig_inproc_event.emit(event_type, state_obj)
        except RuntimeError:
            pass

    @Slot()
    def openFullCorridorForMotion(self):
        """
        动画开始瞬间调用：临时把遮罩扩大到全视窗，
        确保 GPU 无论如何展开形变，动画绝不会被截断，且在此期间 0 次 setMask！
        """
        self.wm.clear_mask()

    @Slot(int, int, int, int)
    def applySettledMask(self, x: int, y: int, w: int, h: int):
        """
        动画彻底停止瞬间单次调用：在灵动岛四周建立精准输入屏障，
        透明区域立刻放行鼠标点击，穿透到下层所有软件！
        """
        self.wm.set_precise_bounding_mask(x, y, w, h)

    @Slot()
    def setPassthrough(self):
        self.wm.set_passthrough()


    @Slot(str, object)
    def _handle_inproc_event(self, event_type: str, s):
        if event_type in ("MEDIA_UPDATE", "FULL_SYNC"):
            art = s.art_url
            if art and art.startswith("/") and not art.startswith("file://"):
                art = "file://" + art
            self.mediaUpdated.emit(s.title, s.artist, s.playback_status, art, s.position, s.duration)
        elif event_type in ("MEDIA_PROGRESS", "MEDIA_TICK"):
            prog = (s.position / s.duration) if s.duration > 0 else 0.0
            self.progressUpdated.emit(s.position, s.duration, prog)

        if event_type in ("WORKSPACE_CHANGED", "FULL_SYNC"):
            self.workspaceTriggered.emit(s.workspace_index, s.workspace_total, s.workspace_name)
            self.workspaceListUpdated.emit(s.workspaces)

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