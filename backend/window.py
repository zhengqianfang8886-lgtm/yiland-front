# ==========================================
# 📄 File: backend/window.py
# 🌟 窗口物理掩码穿透与安全剪贴板监听器 (PAL 适配重构版)
# ==========================================
import shutil
import hashlib
import subprocess
from PySide6.QtCore import QObject, Signal
from backend.utils import CONCEAL_MIME_TYPES
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
        self._last_clip_hash = ""

        # 启动平台自适应剪贴板监听
        self.platform.start_clipboard_monitor(self._on_platform_clipboard_changed)

    def set_precise_bounding_mask(self, x: int, y: int, w: int, h: int):
        """精准建立交互窗口，其余透明区域放行鼠标穿透"""
        sig = f"{x},{y},{w},{h}"
        if sig == self._last_applied_sig:
            return
        self._last_applied_sig = sig
        self.platform.apply_input_mask(self.view, x, y, w, h)

    def set_passthrough(self):
        """完全穿透"""
        if self._last_applied_sig == "PASS":
            return
        self._last_applied_sig = "PASS"
        self.platform.set_passthrough(self.view)

    def clear_mask(self):
        """全开交互通道"""
        if self._last_applied_sig == "FULL":
            return
        self._last_applied_sig = "FULL"
        self.platform.clear_input_mask(self.view)

    def _on_platform_clipboard_changed(self, text: str, has_image: bool, formats: set):
        if self.config and not getattr(self.config, "clipboardMonitorEnabled", True):
            return

        if formats.intersection(CONCEAL_MIME_TYPES):
            self.clipboardTriggered.emit("🔐", "密码凭据", "已安全复制保密数据 · [已脱敏]", 1400)
            return

        if has_image:
            self.clipboardTriggered.emit("🖼️", "截图/图像", "已复制到剪贴板", 1300)
            return

        if text:
            if len(text) > 100000:
                return
            content_hash = hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]
            if content_hash == self._last_clip_hash:
                return
            self._last_clip_hash = content_hash
            clean_text = text.strip()
            count = len(clean_text)
            if count == 0:
                return
            preview = clean_text.replace("\n", " ").replace("\r", " ").strip()
            if len(preview) > 16:
                preview = preview[:14] + "..."
            self.clipboardTriggered.emit("📋", "剪贴板", f"已复制 {count} 字符 · \"{preview}\"", 1300)

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
                if shutil.which(term):
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