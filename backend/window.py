# ==========================================
# 📄 File: backend/window.py
# 🌟 窗口物理掩码穿透服务 (已彻底移除剪贴板监听)
# ==========================================
import shutil
import subprocess
from PySide6.QtCore import QObject, Signal
from backend.platform import detect_platform


class WindowManagerService(QObject):
    clipboardTriggered = Signal(str, str, str, int)

    def __init__(self, view, executor, config=None, parent=None):
        super().__init__(parent)
        self.view = view
        self._pool = executor
        self.config = config
        self.platform = detect_platform()
        self._last_applied_sig = ""

        # 🚀 彻底禁用平台级剪贴板监听，不再启动线程与轮询

    def set_precise_bounding_mask(self, x: int, y: int, w: int, h: int):
        sig = f"{x},{y},{w},{h}"
        if sig == self._last_applied_sig:
            return
        self._last_applied_sig = sig
        self.platform.apply_input_mask(self.view, x, y, w, h)
        # 🚀【核心加固】：强制刷新渲染管线，让 Wayland 合成器立即收到新的穿透区域
        if hasattr(self.view, "requestUpdate"):
            self.view.requestUpdate()

    def set_passthrough(self):
        if self._last_applied_sig == "PASS":
            return
        self._last_applied_sig = "PASS"
        self.platform.set_passthrough(self.view)
        if hasattr(self.view, "requestUpdate"):
            self.view.requestUpdate()

    def clear_mask(self):
        if self._last_applied_sig == "FULL":
            return
        self._last_applied_sig = "FULL"
        self.platform.clear_input_mask(self.view)
        if hasattr(self.view, "requestUpdate"):
            self.view.requestUpdate()

    def open_system_monitor(self):
        def _open():
            for cmd in ["mission-center", "resources", "gnome-system-monitor", "plasma-systemmonitor", "mate-system-monitor", "xfce4-taskmanager"]:
                if shutil.which(cmd):
                    try:
                        subprocess.Popen([cmd])
                        return
                    except Exception:
                        pass
            for term in ["kitty", "alacritty", "foot", "wezterm", "gnome-terminal", "konsole"]:
                if shutil.which(cmd):
                    for mon in ["btop", "htop", "top"]:
                        if shutil.which(mon):
                            try:
                                subprocess.Popen([term, "-e", mon])
                                return
                            except Exception:
                                pass
        self._pool.submit(_open)

    def open_bluetooth_settings(self):
        def _open():
            for cmd in ["blueman-manager", "gnome-control-center", "plasma-open-settings", "kcmshell6", "blueberry", "overskride"]:
                if shutil.which(cmd):
                    try:
                        if cmd == "gnome-control-center":
                            subprocess.Popen([cmd, "bluetooth"])
                        elif cmd in ("plasma-open-settings", "kcmshell6"):
                            subprocess.Popen([cmd, "kcm_bluetooth"])
                        else:
                            subprocess.Popen([cmd])
                        return
                    except Exception:
                        pass
        self._pool.submit(_open)