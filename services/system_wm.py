# ==========================================
# 📄 File: services/system_wm.py
# 🌟 静态着陆单次穿透引擎 (零动画争抢版)
# ==========================================
import os
import shutil
import hashlib
import subprocess
from PySide6.QtCore import QObject, Signal, QRect
from PySide6.QtGui import QRegion, QGuiApplication
from logger import app_logger
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

    # 🚀【核心机制】：仅在动画完全静止后由 QML 单次调用，设置纯矩形精准穿透
    def set_precise_bounding_mask(self, x: int, y: int, w: int, h: int):
        sig = f"{x},{y},{w},{h}"
        if sig == self._last_applied_sig:
            return
        self._last_applied_sig = sig

        if w <= 0 or h <= 0:
            self.set_passthrough()
            return

        # 使用硬件消耗最小的单矩形 Region，绝不破坏 OpenGL Framebuffer
        mask_region = QRegion(QRect(x, y, w, h))
        self.view.setMask(mask_region)

    def set_passthrough(self):
        """完全穿透（用于吸顶隐藏）"""
        if self._last_applied_sig == "PASS":
            return
        self._last_applied_sig = "PASS"
        self.view.setMask(QRegion(0, 0, 1, 1))

    def clear_mask(self):
        """恢复全窗口可交互"""
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
            detail_str = f"已复制 {count} 字符 · \"{preview}\""
            self.clipboardTriggered.emit("📋", "剪贴板", detail_str, 1300)

    def focus_teams_window(self):
        def _focus():
            candidates = ["teams-for-linux", "Microsoft Teams", "crx_cifhbcnohmdccbgoicgdjpfamggdegmo"]
            for kw in candidates:
                try:
                    if shutil.which("wmctrl") and subprocess.run(["wmctrl", "-x", "-a", kw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0).returncode == 0:
                        return
                    if shutil.which("hyprctl") and subprocess.run(["hyprctl", "dispatch", "focuswindow", f"class:(.*{kw}.*)"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0).returncode == 0:
                        return
                    if shutil.which("swaymsg") and subprocess.run(["swaymsg", f'[class="(?i).*{kw}.*"] focus'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0).returncode == 0:
                        return
                    if shutil.which("xdotool") and subprocess.run(["xdotool", "search", "--onlyvisible", "--class", kw, "windowactivate"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0).returncode == 0:
                        return
                except subprocess.TimeoutExpired:
                    continue
        self._pool.submit(_focus)

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

    def connect_bluetooth(self, mac: str):
        def _con():
            if shutil.which("bluetoothctl"):
                try:
                    subprocess.run(["bluetoothctl", "connect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3.0)
                except Exception:
                    pass
        self._pool.submit(_con)

    def disconnect_bluetooth(self, mac: str):
        def _dis():
            if shutil.which("bluetoothctl"):
                try:
                    subprocess.run(["bluetoothctl", "disconnect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3.0)
                except Exception:
                    pass
        self._pool.submit(_dis)