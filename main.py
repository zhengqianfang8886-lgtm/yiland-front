# ==========================================
# 📄 File: main.py
# 🌟 生产级桌面启动中枢 (集成物理级拔除防 W 图标版)
# ==========================================
import sys
import os
import signal
import gc
import ctypes
import threading
import asyncio

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

os.environ["QT_QPA_PLATFORM"] = "wayland"
# os.environ["QT_WAYLAND_SHELL_INTEGRATION"] = "layer-shell"
os.environ.setdefault("QSG_RENDER_LOOP", "threaded")

from backend.logger import app_logger
from backend.config import ConfigManager
from backend.bridge import IslandBridge
from backend.core.backend import DirectIslandBackend
from backend.theme import theme
from backend.platform import detect_platform

from PySide6.QtCore import QUrl, QTimer, Qt, QSize
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
    platform = detect_platform()
    app_logger.info(f"Alcove Island 启动中... 当前平台驱动: [{platform.platform_name}]")

    surface_format = QSurfaceFormat()
    surface_format.setAlphaBufferSize(8)
    surface_format.setRenderableType(QSurfaceFormat.RenderableType.OpenGL)
    surface_format.setSwapBehavior(QSurfaceFormat.SwapBehavior.DoubleBuffer)
    surface_format.setSwapInterval(1)
    QSurfaceFormat.setDefaultFormat(surface_format)

    app = QGuiApplication(sys.argv)
    app.setApplicationName("alcove-island")
    app.setDesktopFileName("alcove-island")
    
    # 🚀【核心防护】：阻止窗口 hide() 时触发程序自杀退出
    app.setQuitOnLastWindowClosed(False)

    config = ConfigManager()
    theme.set_config(config)

    QPixmapCache.setCacheLimit(32 * 1024)

    sigint_timer = QTimer()
    sigint_timer.start(1000)
    sigint_timer.timeout.connect(lambda: None)

    VIEW_W, VIEW_H = 680, 480

    view = QQuickView()
    view.setTitle("Alcove Island")
    view.setColor("transparent")
    view.setFlags(platform.get_window_flags())

    view.setMinimumSize(QSize(VIEW_W, VIEW_H))
    view.setMaximumSize(QSize(VIEW_W, VIEW_H))
    view.resize(QSize(VIEW_W, VIEW_H))

    engine = view.engine()
    engine.addImportPath(os.path.join(BASE_DIR, "ui"))
    engine.addImportPath(os.path.join(BASE_DIR, "ui", "windows"))
    engine.addImportPath(os.path.join(BASE_DIR, "ui", "shell"))
    engine.addImportPath(os.path.join(BASE_DIR, "ui", "views"))
    engine.addImportPath(os.path.join(BASE_DIR, "ui", "components"))

    bridge = IslandBridge(view, config)
    app.aboutToQuit.connect(bridge.cleanup)

    backend, backend_loop = start_backend_event_loop(bridge)

    def update_view_position():
        screen = app.primaryScreen()
        if not screen: return
        base_rect = screen.geometry() if config.anchorMode == "screen" else screen.availableGeometry()
        target_x = base_rect.x() + (base_rect.width() - VIEW_W) // 2 + config.offsetX
        target_y = base_rect.y() + config.topMargin
        platform.apply_window_position(view, screen, target_x, target_y, VIEW_W, VIEW_H)

    # 🚀【究极拔除术】：监听到网格开启时，物理销毁 Wayland Surface，彻底消灭 W 图标
    def handle_grid_state(is_active):
        if is_active:
            view.hide()
        else:
            view.show()
            update_view_position()

    bridge.gridActiveChanged.connect(handle_grid_state)

    update_view_position()
    config.topMarginChanged.connect(lambda _: update_view_position())
    config.offsetXChanged.connect(lambda _: update_view_position())
    config.anchorModeChanged.connect(lambda _: update_view_position())

    context = view.rootContext()
    context.setContextProperty("Theme", theme)
    context.setContextProperty("Bridge", bridge)
    context.setContextProperty("Config", config)
    context.setContextProperty("WorldCities", config.worldCities)

    qml_path = os.path.join(BASE_DIR, "ui", "windows", "Island.qml")
    app_logger.info(f"正在装载灵动岛主视图: {qml_path}")

    view.setSource(QUrl.fromLocalFile(qml_path))

    if view.status() == QQuickView.Status.Error:
        app_logger.critical("❌ QML 编译失败清单：")
        for err in view.errors():
            print(f"\033[31;1m[QML 错误] {err.toString()}\033[0m")
        sys.exit(1)

    view.show()
    update_view_position()

    QTimer.singleShot(150, update_view_position)
    QTimer.singleShot(600, update_view_position)

    trim_memory()

    app_logger.info(f"✨ 零焦点系统级悬浮岛就绪 [{platform.platform_name}]，进入 GUI 主事件循环")
    sys.exit(app.exec())


if __name__ == "__main__":
    main()