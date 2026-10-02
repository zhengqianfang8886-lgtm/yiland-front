import sys
import os
import signal
import gc
import ctypes

# 🚀 1. 彻底删除 QSG_RENDER_LOOP="basic"！让 Qt 恢复默认 threaded 线程垂直同步休眠！
# （仅保留字形抗锯齿优化）
os.environ["QSG_DISTANCEFIELD_ANTIALIASING"] = "subpixel"

from logger import app_logger, install_qt_log_bridge
from config import ConfigManager
from bridge import IslandBridge
from ws_client import WebSocketDaemonClient
from theme import theme
from PySide6.QtCore import QUrl, QTimer, Qt
from PySide6.QtGui import QPixmapCache, QGuiApplication
from PySide6.QtQuick import QQuickView

def trim_memory():
    """强制让 Linux 内核回收未使用的 glibc 堆内存"""
    gc.collect()
    try:
        ctypes.CDLL("libc.so.6").malloc_trim(0)
    except Exception:
        pass

def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    install_qt_log_bridge()
    app_logger.info("Alcove Island 前端渲染引擎启动中...")

    # 纯轻量级 GUI 底座（抛弃 QtWidgets 40MB 包袱）
    app = QGuiApplication(sys.argv)
    config = ConfigManager()

    # 显存位图缓存锁死为 16MB
    QPixmapCache.setCacheLimit(16 * 1024)

    # 降低心跳定时器频率到 1000ms（原 300ms 纯属浪费 CPU）
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
    view.setSource(QUrl.fromLocalFile(os.path.join(base_dir, "Island.qml")))
    view.show()

    # 🚀 启动后立即执行内核级内存剪裁
    trim_memory()

    ws_client = WebSocketDaemonClient(bridge)
    ws_client.start()

    sys.exit(app.exec())

if __name__ == "__main__":
    main()