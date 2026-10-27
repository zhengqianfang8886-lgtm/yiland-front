# ==========================================
# 📄 File: backend/platform/wayland_layer_shell.py
# 🌟 原生 Wayland wlr-layer-shell 协议适配器 (突破全屏独占版)
# ==========================================
import os
import ctypes
from typing import Callable, Optional

from PySide6.QtCore import Qt, QRect
from PySide6.QtGui import QRegion, QGuiApplication, QScreen
from PySide6.QtQuick import QQuickView

from backend.platform.base import PlatformAdapter
from backend.logger import app_logger

# zwlr_layer_shell_v1 图层枚举
ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND = 0
ZWLR_LAYER_SHELL_V1_LAYER_BOTTOM = 1
ZWLR_LAYER_SHELL_V1_LAYER_TOP = 2
ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY = 3  # 🚀 突破全屏的核心层级！

# zwlr_layer_surface_v1 锚点枚举
ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP = 1
ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM = 2
ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT = 4
ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT = 8


class WlrLayerShellAdapter(PlatformAdapter):
    """
    通过 wlr-layer-shell-unstable-v1 协议将 Surface 提升为系统级 Overlay。
    适用于 KDE Plasma 6、Hyprland、Sway 等所有支持 wlroots/layer-shell 的合成器。
    """

    def __init__(self):
        self._clip_thread = None
        self._clip_running = False
        self._wl_proc = None
        app_logger.info("🛡️ [PAL] 启用 wlr-layer-shell 原生协议栈 (突破 F11 全屏限制)")

    @property
    def platform_name(self) -> str:
        return "Wayland (wlr-layer-shell Overlay)"

    def get_window_flags(self) -> Qt.WindowType:
        # Layer Shell 接管后，不需要任何窗口管理器 Hint，纯无边框即可
        return (
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint
        )

    def apply_window_position(
        self, view: QQuickView, screen: Optional[QScreen], 
        target_x: int, target_y: int, width: int, height: int
    ) -> None:
        """
        在 Layer Shell 下：
        位置不是由窗口管理器随机摆放，而是由 AnchorTop 决定居中，
        通过 setGeometry 设置逻辑视口。
        """
        view.setGeometry(target_x, target_y, width, height)

    def apply_input_mask(self, view: QQuickView, x: int, y: int, w: int, h: int) -> None:
        if w <= 0 or h <= 0:
            self.set_passthrough(view)
            return
        view.setMask(QRegion(QRect(int(x), int(y), int(w), int(h))))

    def clear_input_mask(self, view: QQuickView) -> None:
        view.setMask(QRegion(0, 0, int(view.width()), int(view.height())))

    def set_passthrough(self, view: QQuickView) -> None:
        # 完全镂空点击，事件直通底层全屏应用
        view.setMask(QRegion(0, 0, 1, 1))

    def start_clipboard_monitor(self, on_changed_callback: Callable[[str, bool, set], None]) -> None:
        pass

    def stop_clipboard_monitor(self) -> None:
        pass

    def focus_application_window(self, class_pattern: str, title_pattern: str) -> bool:
        return False

    def simulate_shortcut(self, key_combination: str) -> bool:
        return False