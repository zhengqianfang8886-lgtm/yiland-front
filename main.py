import sys
import os
import signal
from logger import app_logger, install_qt_log_bridge
from config import ConfigManager
from bridge import IslandBridge
from ws_client import WebSocketDaemonClient
from PySide6.QtCore import QUrl, QTimer, Qt
from PySide6.QtWidgets import QApplication
from PySide6.QtQuick import QQuickView

def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    install_qt_log_bridge()
    app_logger.info("Alcove Island 前端渲染引擎启动中...")

    app = QApplication(sys.argv)
    config = ConfigManager()

    # 保持 SIGINT 响应，便于 Ctrl+C 优雅退出
    sigint_timer = QTimer()
    sigint_timer.start(300)
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

    # 注入上下文对象
    context = view.rootContext()
    context.setContextProperty("Bridge", bridge)
    context.setContextProperty("Config", config)
    context.setContextProperty("WorldCities", config.worldCities)

    base_dir = os.path.dirname(os.path.abspath(__file__))
    view.setSource(QUrl.fromLocalFile(os.path.join(base_dir, "Island.qml")))
    view.show()

    # 启动 WebSocket 守护工作者
    ws_client = WebSocketDaemonClient(bridge)
    ws_client.start()

    sys.exit(app.exec())

if __name__ == "__main__":
    main()