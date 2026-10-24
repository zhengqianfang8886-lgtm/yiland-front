# ==========================================
# 📄 File: backend/platform/__init__.py
# 🌟 平台自动嗅探与单例工厂
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
    desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").upper()
    is_kde = "KDE" in desktop or os.environ.get("KDE_FULL_SESSION") == "true"

    if session_type == "wayland":
        if is_kde:
            app_logger.info("🛡️ [PAL] 自动识别运行环境: KDE Plasma Wayland (启用 KWin D-Bus 与独立剪贴板看门狗)")
            _current_platform = KdePlasmaWaylandAdapter()
        else:
            # 预留给未来 Hyprland / GNOME / Sway
            app_logger.info(f"🛡️ [PAL] 自动识别运行环境: 通用 Wayland ({desktop})，启用 KDE/Wayland 兼容协议栈")
            _current_platform = KdePlasmaWaylandAdapter()
    else:
        app_logger.info("🛡️ [PAL] 自动识别运行环境: X11 传统会话 (启用原生 XShape 与 QClipboard)")
        _current_platform = X11Adapter()

    return _current_platform