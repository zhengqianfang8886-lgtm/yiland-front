# ==========================================
# 📄 File: backend/platform/__init__.py
# ==========================================
import os
from backend.platform.base import PlatformAdapter
from backend.platform.x11 import X11Adapter
from backend.platform.kde_wayland import KdePlasmaWaylandAdapter
from backend.logger import app_logger

_current_platform: PlatformAdapter = None


def detect_platform() -> PlatformAdapter:
    global _current_platform
    if _current_platform is not None:
        return _current_platform

    session_type = os.environ.get("XDG_SESSION_TYPE", "").lower()
    if session_type == "wayland":
        app_logger.info("🛡️ [PAL] 自动识别运行环境: KDE Plasma Wayland (启用 KWin 原生事件提权驱动)")
        _current_platform = KdePlasmaWaylandAdapter()
    else:
        app_logger.info("🛡️ [PAL] 自动识别运行环境: X11 传统会话")
        _current_platform = X11Adapter()

    return _current_platform