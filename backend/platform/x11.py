# ==========================================
# 📄 File: backend/platform/x11.py
# 🌟 原生 X11 显示服务适配器 (无损保留原系统级行为)
# ==========================================
import shutil
import subprocess
from typing import Callable, Optional

from PySide6.QtCore import Qt, QRect
from PySide6.QtGui import QRegion, QGuiApplication, QScreen
from PySide6.QtQuick import QQuickView

from backend.platform.base import PlatformAdapter
from backend.logger import app_logger


class X11Adapter(PlatformAdapter):
    @property
    def platform_name(self) -> str:
        return "X11"

    def get_window_flags(self) -> Qt.WindowType:
        return (
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.Tool |
            Qt.WindowType.WindowDoesNotAcceptFocus |
            Qt.WindowType.BypassWindowManagerHint
        )

    def apply_window_position(
        self, view: QQuickView, screen: Optional[QScreen], 
        target_x: int, target_y: int, width: int, height: int
    ) -> None:
        view.setGeometry(target_x, target_y, width, height)

    def apply_input_mask(self, view: QQuickView, x: int, y: int, w: int, h: int) -> None:
        if w <= 0 or h <= 0:
            self.set_passthrough(view)
            return
        view.setMask(QRegion(QRect(x, y, w, h)))

    def clear_input_mask(self, view: QQuickView) -> None:
        view.setMask(QRegion(0, 0, view.width(), view.height()))

    def set_passthrough(self, view: QQuickView) -> None:
        view.setMask(QRegion(0, 0, 1, 1))

    def start_clipboard_monitor(self, on_changed_callback: Callable[[str, bool, set], None]) -> None:
        clipboard = QGuiApplication.clipboard()
        self._callback = on_changed_callback

        def _handler():
            mime = clipboard.mimeData()
            if not mime:
                return
            formats = set(mime.formats())
            has_image = mime.hasImage()
            text = clipboard.text() if mime.hasText() else ""
            self._callback(text, has_image, formats)

        self._handler = _handler
        clipboard.dataChanged.connect(self._handler)

    def stop_clipboard_monitor(self) -> None:
        try:
            clipboard = QGuiApplication.clipboard()
            if hasattr(self, "_handler"):
                clipboard.dataChanged.disconnect(self._handler)
        except Exception:
            pass

    def focus_application_window(self, class_pattern: str, title_pattern: str) -> bool:
        if shutil.which("wmctrl"):
            try:
                cmd = f'wmctrl -a "{title_pattern}" 2>/dev/null || wmctrl -x -a "{class_pattern}" 2>/dev/null'
                res = subprocess.run(cmd, shell=True, timeout=1.0)
                return res.returncode == 0
            except Exception as e:
                app_logger.debug(f"[X11] 聚焦窗口异常: {e}")
        return False

    def simulate_shortcut(self, key_combination: str) -> bool:
        if shutil.which("xdotool"):
            try:
                subprocess.Popen(["xdotool", "key", "--clearmodifiers", key_combination])
                return True
            except Exception:
                pass
        return False