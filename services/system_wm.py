# ==========================================
# 📄 File: services/system_wm.py
# 🌟 窗口安全掩码 (Masking) 与桌面管理器交互
# ==========================================
import shutil
import hashlib
import subprocess
from PySide6.QtCore import QObject, Signal, QRect
from PySide6.QtGui import QRegion, QGuiApplication
from services.utils import CONCEAL_MIME_TYPES


class WindowManagerService(QObject):
    clipboardTriggered = Signal(str, str, str, int)

    def __init__(self, view, executor, config=None, parent=None):
        super().__init__(parent)
        self.view = view
        self._pool = executor
        self.config = config
        self._last_applied_sig = ""
        self._last_clip_hash = ""
        self._setup_clipboard_listener()

    def set_precise_bounding_mask(self, x: int, y: int, w: int, h: int):
        """精准建立单矩形安全交互窗口，其余透明区域放行鼠标穿透"""
        sig = f"{x},{y},{w},{h}"
        if sig == self._last_applied_sig:
            return
        self._last_applied_sig = sig

        if w <= 0 or h <= 0:
            self.set_passthrough()
            return

        mask_region = QRegion(QRect(x, y, w, h))
        self.view.setMask(mask_region)

    def set_passthrough(self):
        """完全穿透（吸顶隐藏）"""
        if self._last_applied_sig == "PASS":
            return
        self._last_applied_sig = "PASS"
        self.view.setMask(QRegion(0, 0, 1, 1))

    def clear_mask(self):
        """动画期间全开交互"""
        if self._last_applied_sig == "FULL":
            return
        self._last_applied_sig = "FULL"
        self.view.setMask(QRegion(0, 0, self.view.width(), self.view.height()))

    def _setup_clipboard_listener(self):
        clipboard = QGuiApplication.clipboard()
        clipboard.dataChanged.connect(self._on_clipboard_changed)

    def _on_clipboard_changed(self):
        if self.config and not getattr(self.config, "clipboardMonitorEnabled", True):
            return
        clipboard = QGuiApplication.clipboard()
        mime = clipboard.mimeData()
        if not mime:
            return
        formats = set(mime.formats())

        if formats.intersection(CONCEAL_MIME_TYPES):
            self.clipboardTriggered.emit("🔐", "密码凭据", "已安全复制保密数据 · [已脱敏]", 1400)
            return

        if mime.hasImage():
            self.clipboardTriggered.emit("🖼️", "截图/图像", "已复制到剪贴板", 1300)
            return

        if mime.hasText():
            raw_text = clipboard.text()
            if not raw_text or len(raw_text) > 100000:
                return
            content_hash = hashlib.sha256(raw_text.encode("utf-8")).hexdigest()[:16]
            if content_hash == self._last_clip_hash:
                return
            self._last_clip_hash = content_hash
            clean_text = raw_text.strip()
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