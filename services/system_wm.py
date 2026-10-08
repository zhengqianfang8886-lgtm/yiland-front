# ==========================================
# 📄 File: services/system_wm.py
# 🌟 修复圆角退化挖空漏洞 · 稳定复合遮罩与防误穿透
# ==========================================
import os
import shutil
import hashlib
import subprocess
from PySide6.QtCore import QObject, QRect, Signal
from PySide6.QtGui import QRegion, QPainterPath, QGuiApplication
from logger import app_logger
from services.utils import CONCEAL_MIME_TYPES


class WindowManagerService(QObject):
    clipboardTriggered = Signal(str, str, str, int)

    def __init__(self, view, executor, config=None, parent=None):
        super().__init__(parent)
        self.view = view
        self._pool = executor
        self.config = config
        self._last_applied_mask = QRegion()
        self._last_applied_rects_sig = ""
        self._last_clip_hash = ""
        self._setup_clipboard_listener()

    # 🚀【核心重构】：具备几何拓扑自愈保护的 1-bit 窗口遮罩合成器
    def update_composite_mask(self, rects):
        if not rects:
            self.set_passthrough()
            return

        vw = self.view.width()
        vh = self.view.height()

        sig_parts = []
        valid_items = []

        for r in rects:
            rx = max(0, int(r.get("x", 0)))
            ry = max(0, int(r.get("y", 0)))
            rw = min(vw - rx, int(r.get("w", 0)))
            rh = min(vh - ry, int(r.get("h", 0)))
            rr = max(0, int(r.get("r", 0)))

            if rw <= 2 or rh <= 2:
                continue

            # 🚀【关键数学约束】：圆角半径绝对不得超过短边的一半！彻底阻止自交退化导致的挖空消失！
            max_r = max(0, int(min(rw, rh) / 2) - 1)
            safe_r = min(rr, max_r)

            sig_parts.append(f"{rx},{ry},{rw},{rh},{safe_r}")
            valid_items.append((rx, ry, rw, rh, safe_r))

        new_sig = "|".join(sig_parts)
        if new_sig == self._last_applied_rects_sig:
            return
        self._last_applied_rects_sig = new_sig

        composite = QRegion()
        for rx, ry, rw, rh, safe_r in valid_items:
            if safe_r <= 2:
                composite = composite.united(QRegion(rx, ry, rw, rh))
            else:
                path = QPainterPath()
                path.addRoundedRect(float(rx), float(ry), float(rw), float(rh), float(safe_r), float(safe_r))
                poly = path.toFillPolygon().toPolygon()
                if not poly.isEmpty():
                    composite = composite.united(QRegion(poly))
                else:
                    # 兜底：若多边形异常，退化为实体矩形，绝不允许小岛消失
                    composite = composite.united(QRegion(rx, ry, rw, rh))

        if not composite.isEmpty():
            if composite != self._last_applied_mask:
                self._last_applied_mask = composite
                self.view.setMask(composite)
                self.view.requestUpdate()
        else:
            self.set_passthrough()

    def set_passthrough(self):
        passthrough_region = QRegion(-10, -10, 1, 1)
        self._last_applied_rects_sig = "PASSTHROUGH"
        if self._last_applied_mask != passthrough_region:
            self._last_applied_mask = passthrough_region
            self.view.setMask(passthrough_region)
            self.view.requestUpdate()

    def clear_mask(self):
        self._last_applied_rects_sig = "CLEAR"
        self._last_applied_mask = QRegion()
        self.view.setMask(QRegion())
        self.view.requestUpdate()

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