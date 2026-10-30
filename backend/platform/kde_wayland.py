# ==========================================
# 📄 File: backend/platform/kde_wayland.py
# 🌟 KDE 5 & 6 Plasma Wayland 专属驱动 (集成 KWin 原生激活与聚焦版)
# ==========================================
import os
import time
import shutil
import subprocess
import threading
from typing import Callable, Optional

from PySide6.QtCore import Qt, QRect
from PySide6.QtGui import QRegion, QGuiApplication, QScreen
from PySide6.QtQuick import QQuickView

from backend.platform.base import PlatformAdapter
from backend.logger import app_logger


class KdePlasmaWaylandAdapter(PlatformAdapter):
    def __init__(self):
        self._clip_thread: Optional[threading.Thread] = None
        self._clip_running = False
        self._wl_proc: Optional[subprocess.Popen] = None
        self._seq = 0
        self._lock = threading.Lock()

        threading.Thread(target=self._clean_and_apply_kwin_rules, daemon=True).start()

    @property
    def platform_name(self) -> str:
        return "KDE Plasma Wayland (Zero-Focus Overlay Dock)"

    def get_window_flags(self) -> Qt.WindowType:
        return (
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.WindowDoesNotAcceptFocus |
            Qt.WindowType.SplashScreen
        )

    def _find_qdbus(self) -> Optional[str]:
        for candidate in ["qdbus6", "qdbus-qt6", "qdbus", "qdbus-qt5"]:
            if shutil.which(candidate):
                return candidate
        return None

    def _clean_and_apply_kwin_rules(self):
        kw_bin = shutil.which("kwriteconfig6") or shutil.which("kwriteconfig5")
        qdbus_bin = self._find_qdbus()
        if not kw_bin:
            return

        rule_id = "alcove_island_hud_shield"
        rules = [
            ("Description", "Alcove Island HUD Shield"),
            ("wmclass", "alcove-island"),
            ("wmclassmatch", "1"),
            ("types", "2"),
            ("typesrule", "2"),
            ("layer", "overlay"),
            ("layerrule", "2"),
            ("above", "true"),
            ("aboverule", "2"),
            ("fullscreen", "false"),
            ("fullscreenrule", "2"),
            ("quicktile", "0"),
            ("quicktilerule", "2"),
            ("desktop", "0"),
            ("desktoprule", "2"),
            ("skiptaskbar", "true"),
            ("skiptaskbarrule", "2"),
            ("skipswitcher", "true"),
            ("skipswitcherrule", "2"),
            ("skippager", "true"),
            ("skippagerrule", "2"),
            ("skipoverview", "true"),
            ("skipoverviewrule", "2"),
            ("noborder", "true"),
            ("noborderrule", "2"),
            ("acceptfocus", "false"),
            ("acceptfocusrule", "2"),
            ("fsplevel", "0"),
            ("fsplevelrule", "2"),
        ]

        try:
            for k, v in rules:
                subprocess.run([kw_bin, "--file", "kwinrulesrc", "--group", rule_id, "--key", k, v],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.3)
            subprocess.run([kw_bin, "--file", "kwinrulesrc", "--group", "General", "--key", "rules", rule_id],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.3)
            if qdbus_bin:
                subprocess.run([qdbus_bin, "org.kde.KWin", "/KWin", "org.kde.KWin.reconfigure"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.3)
            app_logger.info("✅ KWin 磁盘规则已刷新 (KDE 5 零焦点防扰规则生效)")
        except Exception as e:
            app_logger.debug(f"[KDE Wayland] 清洗 KWin 规则异常: {e}")

    def _execute_kwin_script(self, script_body: str, script_name_prefix: str = "alcove_kwin"):
        with self._lock:
            self._seq += 1
            seq = self._seq

        unique_name = f"{script_name_prefix}_{os.getpid()}_{seq}"
        runtime_dir = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
        tmp_script = os.path.join(runtime_dir, f"{unique_name}.js")
        qdbus_bin = self._find_qdbus()

        try:
            with open(tmp_script, "w", encoding="utf-8") as f:
                f.write(script_body)

            script_id = None
            if qdbus_bin:
                load_cmd = [qdbus_bin, "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.loadScript", tmp_script, unique_name]
                p_load = subprocess.run(load_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=1.0)
                if p_load.returncode == 0:
                    tokens = p_load.stdout.strip().split()
                    if tokens and (tokens[-1].isdigit() or tokens[-1].lstrip("-").isdigit()):
                        script_id = tokens[-1]
            else:
                load_cmd = ["dbus-send", "--session", "--dest=org.kde.KWin", "--type=method_call", "--print-reply=literal",
                            "/Scripting", "org.kde.kwin.Scripting.loadScript", f"string:{tmp_script}", f"string:{unique_name}"]
                p_load = subprocess.run(load_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=1.0)
                if p_load.returncode == 0:
                    tokens = p_load.stdout.strip().split()
                    if tokens and (tokens[-1].isdigit() or tokens[-1].lstrip("-").isdigit()):
                        script_id = tokens[-1]

            if not script_id or script_id == "-1":
                return

            candidates = [
                (f"/Scripting/Script{script_id}", "org.kde.kwin.Script.run"),
                ("/Scripting", "org.kde.kwin.Scripting.start"),
                (f"/{script_id}", "org.kde.kwin.Script.run")
            ]

            for obj_path, method_sig in candidates:
                if qdbus_bin:
                    run_cmd = [qdbus_bin, "org.kde.KWin", obj_path, method_sig]
                else:
                    run_cmd = ["dbus-send", "--session", "--dest=org.kde.KWin", "--type=method_call", obj_path, method_sig]

                p_run = subprocess.run(run_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=0.8)
                if p_run.returncode == 0:
                    break

            def _cleanup_script():
                time.sleep(2.0)
                if qdbus_bin:
                    subprocess.run(
                        [qdbus_bin, "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting.unloadScript", unique_name],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.5
                    )
                else:
                    subprocess.run(
                        ["dbus-send", "--session", "--dest=org.kde.KWin", "--type=method_call",
                         "/Scripting", "org.kde.kwin.Scripting.unloadScript", f"string:{unique_name}"],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.5
                    )

            threading.Thread(target=_cleanup_script, daemon=True).start()

        except Exception as e:
            app_logger.debug(f"[KDE Wayland] 调度 KWin 窗口脚本异常: {e}")
        finally:
            if os.path.exists(tmp_script):
                try:
                    os.remove(tmp_script)
                except OSError:
                    pass

    def apply_window_position(
        self, view: QQuickView, screen: Optional[QScreen], 
        target_x: int, target_y: int, width: int, height: int
    ) -> None:
        view.setGeometry(target_x, target_y, width, height)
        my_pid = os.getpid()

        template = """
        (function() {
            var targetPid = __TARGET_PID__;
            var targetX = __TARGET_X__;
            var targetY = __TARGET_Y__;
            var targetW = __TARGET_W__;
            var targetH = __TARGET_H__;

            function configureClient(c) {
                if (!c) return false;
                var isTarget = false;
                if (c.pid && c.pid === targetPid) {
                    isTarget = true;
                } else {
                    var cls = (c.resourceClass || c.desktopFileName || "").toString().toLowerCase();
                    if (cls === "alcove-island" || cls === "alcove_island") {
                        isTarget = true;
                    }
                }

                if (isTarget) {
                    try { if (typeof c.dock !== "undefined") c.dock = true; } catch(e) {}
                    c.onAllDesktops = true;
                    c.keepAbove = true;
                    c.skipTaskbar = true;
                    c.skipPager = true;
                    c.skipSwitcher = true;
                    if (typeof c.skipOverview !== "undefined") c.skipOverview = true;

                    try {
                        if (typeof c.frameGeometry !== "undefined") {
                            c.frameGeometry = { x: targetX, y: targetY, width: targetW, height: targetH };
                        } else if (typeof c.geometry !== "undefined") {
                            c.geometry = { x: targetX, y: targetY, width: targetW, height: targetH };
                        }
                    } catch(e) {}
                    return true;
                }
                return false;
            }

            var list = (typeof workspace.windowList === "function") ? workspace.windowList() : 
                       ((typeof workspace.clientList === "function") ? workspace.clientList() : []);
            for (var i = 0; i < list.length; i++) {
                configureClient(list[i]);
            }
        })();
        """
        kwin_js = (template
                   .replace("__TARGET_PID__", str(my_pid))
                   .replace("__TARGET_X__", str(target_x))
                   .replace("__TARGET_Y__", str(target_y))
                   .replace("__TARGET_W__", str(width))
                   .replace("__TARGET_H__", str(height)))

        threading.Thread(target=self._execute_kwin_script, args=(kwin_js, "alcove_pos"), daemon=True).start()

    def acquire_interaction_focus(self, view: QQuickView):
        pass

    def restore_previous_focus(self, view: QQuickView):
        pass

    def apply_input_mask(self, view: QQuickView, x: int, y: int, w: int, h: int) -> None:
        if w <= 0 or h <= 0:
            self.set_passthrough(view)
            return
        view.setMask(QRegion(QRect(int(x), int(y), int(w), int(h))))

    def clear_input_mask(self, view: QQuickView) -> None:
        view.setMask(QRegion(0, 0, int(view.width()), int(view.height())))

    def set_passthrough(self, view: QQuickView) -> None:
        view.setMask(QRegion())

    def start_clipboard_monitor(self, on_changed_callback: Callable[[str, bool, set], None]) -> None:
        pass

    def stop_clipboard_monitor(self) -> None:
        pass

    # 🚀【核心补全】：通过原生 KWin 脚本精准唤醒并聚焦指定外部应用窗口
    def focus_application_window(self, class_pattern: str, title_pattern: str) -> bool:
        cls_p = (class_pattern or "").lower()
        title_p = (title_pattern or "").lower()

        focus_js = f"""
        (function() {{
            var clsTarget = "{cls_p}";
            var titleTarget = "{title_p}";

            var list = (typeof workspace.windowList === "function") ? workspace.windowList() : 
                       ((typeof workspace.clientList === "function") ? workspace.clientList() : []);

            for (var i = 0; i < list.length; i++) {{
                var c = list[i];
                if (!c) continue;
                var cls = (c.resourceClass || c.desktopFileName || "").toString().toLowerCase();
                var cap = (c.caption || "").toString().toLowerCase();

                var matched = false;
                if (clsTarget && cls.indexOf(clsTarget) !== -1) matched = true;
                if (!matched && titleTarget && cap.indexOf(titleTarget) !== -1) matched = true;

                if (matched) {{
                    c.minimized = false;
                    if (typeof workspace.activeWindow !== "undefined") {{
                        workspace.activeWindow = c;
                    }} else if (typeof workspace.activeClient !== "undefined") {{
                        workspace.activeClient = c;
                    }}
                    return true;
                }}
            }}
            return false;
        }})();
        """
        threading.Thread(target=self._execute_kwin_script, args=(focus_js, "alcove_focus"), daemon=True).start()
        return True

    def simulate_shortcut(self, key_combination: str) -> bool:
        return False