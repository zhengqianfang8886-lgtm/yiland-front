# ==========================================
# 📄 File: main.py
# 🌟 绝对零焦点 (Non-Focusable) 纯 GPU 架构
# ==========================================
import sys
import os
import signal
import gc
import ctypes
import threading
import asyncio

from logger import app_logger
from config import ConfigManager
from bridge import IslandBridge
from core.backend import DirectIslandBackend
from theme import theme

from PySide6.QtCore import QUrl, QTimer, Qt
from PySide6.QtGui import QPixmapCache, QGuiApplication, QSurfaceFormat
from PySide6.QtQuick import QQuickView


def trim_memory():
    gc.collect()
    try:
        libc = ctypes.CDLL("libc.so.6")
        if hasattr(libc, "malloc_trim"):
            libc.malloc_trim(0)
    except Exception:
        pass


def start_backend_event_loop(bridge: IslandBridge):
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    backend = DirectIslandBackend(bridge)
    bridge.set_backend(backend, loop)

    def _thread_target():
        app_logger.info("⚡ 进程内后台 D-Bus 异步引擎启动中...")
        loop.run_until_complete(backend.initialize())
        loop.run_forever()

    t = threading.Thread(target=_thread_target, daemon=True, name="AsyncDbusEngine")
    t.start()
    return backend, loop


def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    app_logger.info("Alcove Island (Strict Non-Focus Mode) 启动中...")

    # 硬件 32 位 ARGB 透明通道
    surface_format = QSurfaceFormat()
    surface_format.setAlphaBufferSize(8)
    surface_format.setRenderableType(QSurfaceFormat.RenderableType.OpenGL)
    surface_format.setSwapBehavior(QSurfaceFormat.SwapBehavior.DoubleBuffer)
    QSurfaceFormat.setDefaultFormat(surface_format)

    app = QGuiApplication(sys.argv)
    config = ConfigManager()
    theme.set_config(config)

    QPixmapCache.setCacheLimit(32 * 1024)

    sigint_timer = QTimer()
    sigint_timer.start(1000)
    sigint_timer.timeout.connect(lambda: None)

    view = QQuickView()
    view.setColor("transparent")

    # =========================================================================
    # 🚀【绝对零焦点标志位】：
    # 1. WindowDoesNotAcceptFocus: 严禁视窗接受键盘聚焦，永远不抢下层活动窗口光标
    # 2. WindowStaysOnTopHint: 置顶展示
    # 3. FramelessWindowHint: 无边框
    # 4. Tool: 避免在任务栏生成图标
    # =========================================================================
    view.setFlags(
        Qt.WindowType.FramelessWindowHint | 
        Qt.WindowType.WindowStaysOnTopHint | 
        Qt.WindowType.Tool |
        Qt.WindowType.WindowDoesNotAcceptFocus
    )

    bridge = IslandBridge(view, config)
    app.aboutToQuit.connect(bridge.cleanup)

    backend, backend_loop = start_backend_event_loop(bridge)

    FIXED_W, FIXED_H = 460, 280

    def update_view_position():
        screen = app.primaryScreen()
        if not screen: return
        base_rect = screen.geometry() if config.anchorMode == "screen" else screen.availableGeometry()
        view.setGeometry(
            base_rect.x() + (base_rect.width() - FIXED_W) // 2 + config.offsetX,
            base_rect.y() + config.topMargin,
            FIXED_W,
            FIXED_H,
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
    app_logger.info(f"正在装载灵动岛主视图: {qml_path}")

    view.setSource(QUrl.fromLocalFile(qml_path))

    if view.status() == QQuickView.Status.Error:
        app_logger.critical("❌ QML 编译失败清单：")
        for err in view.errors():
            print(f"\033[31;1m[QML 错误] {err.toString()}\033[0m")
        sys.exit(1)

    view.show()
    trim_memory()

    app_logger.info("✨ 零焦点系统级悬浮岛就绪，进入 GUI 主事件循环")
    sys.exit(app.exec())


if __name__ == "__main__":
    main()