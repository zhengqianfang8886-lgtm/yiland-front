# ==========================================
# 📄 File: tests/preview_ui.py
# 🌟 UI 独立沙盒调试启动器
# ==========================================
import sys
import os
import signal
import time

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from PySide6.QtCore import QObject, Signal, Slot, Property, Qt, QUrl, QTimer
from PySide6.QtGui import QGuiApplication, QSurfaceFormat
from PySide6.QtQuick import QQuickView

from backend.config import ConfigManager
from backend.theme import theme
from backend.models import NotificationListModel, BluetoothListModel


class MockBridge(QObject):
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

    def __init__(self, parent=None):
        super().__init__(parent)
        self._notif_model = NotificationListModel(self)
        self._bt_model = BluetoothListModel(self)
        self._curr_ws = 1
        self._is_playing = True
        self._vol = 65

    @Property(QObject, constant=True)
    def notificationModel(self): return self._notif_model

    @Property(int, notify=unreadCountChanged)
    def unreadCount(self): return self._notif_model.unreadCount

    @Property(str, notify=unreadCountChanged)
    def latestNotificationAvatar(self): return self._notif_model.latestAvatar

    @Property(QObject, constant=True)
    def bluetoothModel(self): return self._bt_model

    @Property(int, notify=volumeChanged)
    def currentVolume(self): return self._vol

    @Property(int, notify=brightnessChanged)
    def currentBrightness(self): return 90

    @Property(bool, notify=capsLockChanged)
    def isCapsLock(self): return False

    @Property(bool, notify=numLockChanged)
    def isNumLock(self): return True

    @Property(int, constant=True)
    def systemBattery(self): return 85

    @Property(bool, constant=True)
    def isSystemCharging(self): return True

    @Property(bool, constant=True)
    def isBluetoothPowered(self): return True

    @Slot(str, str)
    def traceLog(self, tag: str, msg: str):
        ts = time.strftime("%H:%M:%S") + f".{int(time.time()*1000)%1000:03d}"
        print(f"\033[96m[{ts}] [{tag}]\033[0m {msg}", flush=True)

    @Slot("QVariantList")
    def updateCompositeMask(self, rects): pass
    @Slot()
    def setPassthrough(self): pass
    @Slot()
    def clearMask(self): pass
    @Slot()
    def forceClearWindow(self): pass
    @Slot()
    def forceRaise(self): pass
    @Slot()
    def requestWindowFocus(self): pass
    @Slot()
    def onIslandCollapsed(self): pass
    @Slot(str, bool, result=dict)
    def getWorldTime(self, tz, is_24h=True):
        return {"time": time.strftime("%H:%M"), "diff": "本地", "isDay": True, "isWorking": True}
    @Slot(str, result=str)
    def getTzOffsetStr(self, tz): return "UTC+8"

    @Slot()
    def mockToggleMusic(self):
        self._is_playing = not self._is_playing
        status = "Playing" if self._is_playing else "Paused"
        self.mediaUpdated.emit(
            "Viva La Vida" if self._is_playing else "已暂停",
            "Coldplay", status, "", 120.0, 240.0
        )
        self.dominantColorUpdated.emit("#22c55e" if self._is_playing else "#64748b")

    @Slot()
    def mockNextWorkspace(self):
        self._curr_ws = (self._curr_ws % 4) + 1
        ws_list = [
            {"id": 1, "index": 1, "name": "Main", "active": self._curr_ws == 1},
            {"id": 2, "index": 2, "name": "Dev", "active": self._curr_ws == 2},
            {"id": 3, "index": 3, "name": "Web", "active": self._curr_ws == 3},
            {"id": 4, "index": 4, "name": "Media", "active": self._curr_ws == 4},
        ]
        self.workspaceTriggered.emit(self._curr_ws, 4, ws_list[self._curr_ws - 1]["name"])
        self.workspaceListUpdated.emit(ws_list)

    @Slot()
    def mockTriggerAlert(self):
        self.alertTriggered.emit("💬", "张三", "下午 3 点准时开技术评审会", 4000, "")

    @Slot()
    def mockTriggerCall(self):
        self.callIncomingTriggered.emit("李四 (Teams)", "邀请你加入视频通话...", "")

    @Slot()
    def mockEndCall(self):
        self.callEndedTriggered.emit()

    @Slot(int)
    def adjustVolume(self, delta: int):
        self._vol = max(0, min(100, self._vol + delta))
        self.volumeChanged.emit(self._vol)
        self.osdTriggered.emit("🔊", "Volume", self._vol)

    @Slot(str)
    def sendMediaCmd(self, cmd: str):
        self.mockToggleMusic()


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    surface_format = QSurfaceFormat()
    surface_format.setAlphaBufferSize(8)
    surface_format.setRenderableType(QSurfaceFormat.RenderableType.OpenGL)
    QSurfaceFormat.setDefaultFormat(surface_format)

    app = QGuiApplication(sys.argv)
    config = ConfigManager()
    theme.set_config(config)

    view = QQuickView()
    view.setTitle("Alcove Island - UI 独立调试沙盒")
    view.resize(1000, 520)

    engine = view.engine()
    engine.addImportPath(os.path.join(BASE_DIR, "ui"))
    engine.addImportPath(os.path.join(BASE_DIR, "ui", "windows"))
    engine.addImportPath(os.path.join(BASE_DIR, "ui", "shell"))
    engine.addImportPath(os.path.join(BASE_DIR, "ui", "views"))
    engine.addImportPath(os.path.join(BASE_DIR, "ui", "components"))

    bridge = MockBridge()

    context = view.rootContext()
    context.setContextProperty("Theme", theme)
    context.setContextProperty("Bridge", bridge)
    context.setContextProperty("Config", config)
    context.setContextProperty("WorldCities", config.worldCities)

    sandbox_path = os.path.join(BASE_DIR, "tests", "PreviewSandbox.qml")
    view.setSource(QUrl.fromLocalFile(sandbox_path))

    anim_timer = QTimer()
    def tick_spectrum():
        import random
        if bridge._is_playing:
            s1 = random.uniform(0.2, 0.9)
            s2 = random.uniform(0.3, 1.0)
            s3 = random.uniform(0.2, 0.8)
            s4 = random.uniform(0.1, 0.6)
            bridge.audioSpectrumUpdated.emit(s1, s2, s3, s4)
    anim_timer.timeout.connect(tick_spectrum)
    anim_timer.start(80)

    QTimer.singleShot(150, lambda: bridge.mockToggleMusic())
    QTimer.singleShot(200, lambda: bridge.mockNextWorkspace())

    view.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
