import sys
import os
import signal
import gc
import ctypes

os.environ["QSG_DISTANCEFIELD_ANTIALIASING"] = "subpixel"

from logger import app_logger
from config import ConfigManager
from bridge import IslandBridge
from ws_client import WebSocketDaemonClient
from theme import theme
from PySide6.QtCore import QUrl, QTimer, Qt
from PySide6.QtGui import QPixmapCache, QGuiApplication
from PySide6.QtQuick import QQuickView

def trim_memory():
    gc.collect()
    try:
        ctypes.CDLL("libc.so.6").malloc_trim(0)
    except Exception:
        pass

def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    # 🚀 彻底删除 install_qt_log_bridge()！杜绝 PySide6 GIL 回调死锁
    app_logger.info("Alcove Island 前端渲染引擎启动中...")

    app = QGuiApplication(sys.argv)
    config = ConfigManager()

    QPixmapCache.setCacheLimit(16 * 1024)

    sigint_timer = QTimer()
    sigint_timer.start(1000)
    sigint_timer.timeout.connect(lambda: None)

    view = QQuickView()
    view.setColor("transparent")
    view.setFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)

    bridge = IslandBridge(view)
    window_width, window_height = 720, 270

    def update_view_position():
        screen = app.primaryScreen()
        base_rect = screen.geometry() if config.anchorMode == "screen" else screen.availableGeometry()
        view.setGeometry(
            base_rect.x() + (base_rect.width() - window_width) // 2 + config.offsetX,
            base_rect.y() + config.topMargin,
            window_width,
            window_height
        )

    update_view_position()
    config.topMarginChanged.connect(lambda _: update_view_position())
    config.offsetXChanged.connect(lambda _: update_view_position())
    config.anchorModeChanged.connect(lambda _: update_view_position())

    context = view.rootContext()
    context.setContextProperty("Theme", theme)
    context.setContextProperty("Bridge", bridge)
    context.setContextProperty("Config", config)
    context.setContextProperty("WorldCities", config.worldCities)

    base_dir = os.path.dirname(os.path.abspath(__file__))
    qml_path = os.path.join(base_dir, "Island.qml")
    app_logger.info(f"正在加载根组件: {qml_path}")

    # 🚀 加载 QML
    view.setSource(QUrl.fromLocalFile(qml_path))

    if view.status() == QQuickView.Status.Error:
        app_logger.critical("❌ QML 加载失败，详细清单：")
        for err in view.errors():
            print(f"\033[31;1m[QML 错误] {err.toString()}\033[0m")
        sys.exit(1)

    view.show()
    trim_memory()

    ws_client = WebSocketDaemonClient(bridge)
    ws_client.start()

    app_logger.info("✨ 界面与后台总线就绪，进入主事件循环")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()