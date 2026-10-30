# ==========================================
# 📄 File: main.py
# 🌟 生产级桌面启动中枢 (集成统一 UniversalTrayImageProvider 零拷贝版)
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
from backend.core.tray_provider import UniversalTrayImageProvider
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


def start_backend_event_loop(bridge: IslandBridge, tray_image_provider: UniversalTrayImageProvider = None):
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    
    # 向后兼容 DirectIslandBackend 的老参数签名，同时注入统合的 tray_image_provider
    backend = DirectIslandBackend(
        bridge, 
        image_provider=tray_image_provider, 
        image_provider_rec=tray_image_provider
    )
    backend.tray_image_provider = tray_image_provider
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
    app.setQuitOnLastWindowClosed(False)

    config = ConfigManager()
    theme.set_config(config)

    QPixmapCache.setCacheLimit(32 * 1024)

    sigint_timer = QTimer()
    sigint_timer.start(1000)
    sigint_timer.timeout.connect(lambda: None)

    # main.py 中将 VIEW_W, VIEW_H 调整为更从容的尺寸：
    VIEW_W, VIEW_H = 780, 520

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
    engine.addImportPath(os.path.join(BASE_DIR, "ui", "components", "tray"))

    # 🚀 挂载统合的 UniversalTrayImageProvider：
    # 1. 注册现代通用通道 image://tray/
    # 2. 100% 兼容存量通道 image://ime/ 与 image://recording/
    tray_image_provider = UniversalTrayImageProvider()
    engine.addImageProvider("tray", tray_image_provider)
    engine.addImageProvider("ime", tray_image_provider)
    engine.addImageProvider("recording", tray_image_provider)

    bridge = IslandBridge(view, config)
    app.aboutToQuit.connect(bridge.cleanup)

    backend, backend_loop = start_backend_event_loop(bridge, tray_image_provider=tray_image_provider)

    def update_view_position():
        screen = app.primaryScreen()
        if not screen:
            return
        base_rect = screen.geometry() if config.anchorMode == "screen" else screen.availableGeometry()
        target_x = base_rect.x() + (base_rect.width() - VIEW_W) // 2 + config.offsetX
        target_y = base_rect.y() + config.topMargin
        platform.apply_window_position(view, screen, target_x, target_y, VIEW_W, VIEW_H)

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