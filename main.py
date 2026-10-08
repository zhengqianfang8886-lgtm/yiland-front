# ==========================================
# 📄 File: main.py
# ==========================================
import sys
import os
import signal
import gc
import ctypes

from logger import app_logger
from config import ConfigManager
from bridge import IslandBridge
from ws_client import WebSocketDaemonClient
from theme import theme
from PySide6 import QtSql
from PySide6.QtCore import QUrl, QTimer, Qt
from PySide6.QtGui import QPixmapCache, QGuiApplication
from PySide6.QtQuick import QQuickView

import shutil
import subprocess

def ensure_compiled_shaders():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    frag_src = os.path.join(base_dir, "liquid_glass.frag")
    qsb_dst = os.path.join(base_dir, "liquid_glass.frag.qsb")

    # 如果源码存在且 qsb 文件不存在或源码更新
    if os.path.exists(frag_src):
        should_compile = not os.path.exists(qsb_dst) or (os.path.getmtime(frag_src) > os.path.getmtime(qsb_dst))
        if should_compile:
            qsb_tool = shutil.which("pyside6-qsb") or shutil.which("qsb")
            if qsb_tool:
                try:
                    app_logger.info(f"🎨 正在利用 GPU 编译器构建流体玻璃着色器: {qsb_dst}")
                    subprocess.run(
                        [qsb_tool, "--glsl", "100 es,120,150", "--hlsl", "50", "--msl", "12", "-o", qsb_dst, frag_src],
                        check=True, stdout=subprocess.DEVNULL
                    )
                except Exception as e:
                    app_logger.warning(f"编译着色器失败: {e}")


def trim_memory():
    gc.collect()
    try:
        libc = ctypes.CDLL("libc.so.6")
        if hasattr(libc, "malloc_trim"):
            libc.malloc_trim(0)
    except Exception:
        pass


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    app_logger.info("Alcove Island 渲染架构启动中...")

    app = QGuiApplication(sys.argv)
    config = ConfigManager()
    # ✅ 绑定 config 到全局 theme，启动字体和主题全局联动
    theme.set_config(config)

    QPixmapCache.setCacheLimit(16 * 1024)

    sigint_timer = QTimer()
    sigint_timer.start(1000)
    sigint_timer.timeout.connect(lambda: None)

    view = QQuickView()
    view.setColor("transparent")
    view.setFlags(
        Qt.WindowType.FramelessWindowHint | 
        Qt.WindowType.WindowStaysOnTopHint | 
        Qt.WindowType.Tool |
        Qt.WindowType.BypassWindowManagerHint
    )

    bridge = IslandBridge(view, config)
    app.aboutToQuit.connect(bridge.cleanup)

    window_width, window_height = 860, 270

    def update_view_position():
        screen = app.primaryScreen()
        base_rect = screen.geometry() if config.anchorMode == "screen" else screen.availableGeometry()
        view.setGeometry(
            base_rect.x() + (base_rect.width() - window_width) // 2 + config.offsetX,
            base_rect.y() + config.topMargin,
            window_width,
            window_height,
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
    app_logger.info(f"正在加载灵动岛 QML 主视图: {qml_path}")

    view.setSource(QUrl.fromLocalFile(qml_path))

    if view.status() == QQuickView.Status.Error:
        app_logger.critical("❌ QML 主视图编译失败清单：")
        for err in view.errors():
            print(f"\033[31;1m[QML 错误] {err.toString()}\033[0m")
        sys.exit(1)

    view.show()
    trim_memory()

    ws_client = WebSocketDaemonClient(bridge)
    ws_client.start()

    app_logger.info("✨ 核心渲染系统与线程安全消息总线已就绪，进入主事件循环")
    sys.exit(app.exec())


if __name__ == "__main__":
    main()