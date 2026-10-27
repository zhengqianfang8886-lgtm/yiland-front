# ==========================================
# 📄 File: backend/window.py
# 🌟 窗口物理掩码穿透与外设服务 (修复终端系统监视器查找 Bug 版)
# ==========================================
import shutil
import subprocess
from PySide6.QtCore import QObject
from backend.platform import detect_platform


class WindowManagerService(QObject):
    def __init__(self, view, executor, config=None, parent=None):
        super().__init__(parent)
        self.view = view
        self._pool = executor
        self.config = config
        self.platform = detect_platform()
        self._last_applied_sig = ""

    def set_precise_bounding_mask(self, x: int, y: int, w: int, h: int):
        sig = f"{x},{y},{w},{h}"
        if sig == self._last_applied_sig:
            return
        self._last_applied_sig = sig
        self.platform.apply_input_mask(self.view, x, y, w, h)
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
            # 1. 优先尝试启动独立的 GUI 任务管理器
            for gui_cmd in [
                "mission-center", "resources", "plasma-systemmonitor",
                "gnome-system-monitor", "mate-system-monitor", "xfce4-taskmanager"
            ]:
                if shutil.which(gui_cmd):
                    try:
                        subprocess.Popen([gui_cmd])
                        return
                    except Exception:
                        pass

            # 2. 次级降级方案：探测本地已安装的虚拟终端与 btop/htop (修复了原代码中的变量覆盖 Bug)
            installed_term = None
            for term in ["kitty", "alacritty", "foot", "wezterm", "konsole", "gnome-terminal", "xterm"]:
                if shutil.which(term):
                    installed_term = term
                    break

            if installed_term:
                for cli_mon in ["btop", "htop", "top"]:
                    if shutil.which(cli_mon):
                        try:
                            # 适配 gnome-terminal 的参数格式
                            args = [installed_term, "--", cli_mon] if installed_term == "gnome-terminal" else [installed_term, "-e", cli_mon]
                            subprocess.Popen(args)
                            return
                        except Exception:
                            pass

        self._pool.submit(_open)