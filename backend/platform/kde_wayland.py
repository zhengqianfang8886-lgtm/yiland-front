# ==========================================
# 📄 File: backend/platform/kde_wayland.py
# 🌟 KDE Plasma Wayland 原生适配驱动 (磁盘规则大清洗 · 焦点通道彻底打通版)
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
        return "KDE Plasma Wayland"

    def get_window_flags(self) -> Qt.WindowType:
        # 允许窗口接收键盘输入与激活
        return (
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.Tool
        )

    def _clean_and_apply_kwin_rules(self):
        """🚀【物理大清洗】：彻底清除磁盘 kwinrulesrc 里的历史拒焦残留配置"""
        kw_bin = shutil.which("kwriteconfig6") or shutil.which("kwriteconfig5")
        qdbus_bin = self._find_qdbus()
        if not kw_bin:
            return

        rule_id = "alcove_island_hud_shield"
        rules = [
            ("Description", "Alcove Island Dynamic Focus HUD"),
            ("wmclass", "alcove-island"),
            ("wmclassmatch", "1"),
            ("layer", "overlay"),
            ("layerrule", "2"),
            ("fullscreen", "false"),
            ("fullscreenrule", "2"),
            ("quicktile", "0"),
            ("quicktilerule", "2"),
            ("ignoreglobalshortcuts", "true"),
            ("ignoreglobalshortcutsrule", "2"),
            ("above", "true"),
            ("aboverule", "2"),
            ("skiptaskbar", "true"),
            ("skiptaskbarrule", "2"),
            ("skipswitcher", "true"),
            ("skipswitcherrule", "2"),
            ("noborder", "true"),
            ("noborderrule", "2"),
            # 🚀【核心覆盖】：彻底废除 acceptfocus=false，允许接收焦点
            ("acceptfocus", "true"),
            ("acceptfocusrule", "0"),  # 0 = 不强制限制
            ("fsplevel", "0"),
            ("fsplevelrule", "0"),
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
            app_logger.info("✅ KWin 磁盘规则已清洗：键盘输入通道已解除封锁")
        except Exception as e:
            app_logger.debug(f"[KDE Wayland] 清洗 KWin 规则异常: {e}")

    def _find_qdbus(self) -> Optional[str]:
        for candidate in ["qdbus6", "qdbus-qt6", "qdbus", "qdbus-qt5"]:
            if shutil.which(candidate):
                return candidate
        return None

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
                time.sleep(1.5)
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
                    var cap = (c.caption || "").toString();
                    if (cls.indexOf("alcove-island") !== -1 || cap.indexOf("Alcove Island") !== -1) {
                        isTarget = true;
                    }
                }

                if (isTarget) {
                    c.onAllDesktops = true;
                    c.keepAbove = true;
                    c.skipTaskbar = true;
                    c.skipPager = true;
                    c.skipSwitcher = true;

                    function lockDown() {
                        try {
                            if (typeof c.fullScreen !== "undefined") c.fullScreen = false;
                            if (typeof c.quickTileMode !== "undefined" && c.quickTileMode !== 0) {
                                c.quickTileMode = 0;
                            }
                        } catch(e) {}
                        try {
                            if (typeof c.frameGeometry !== "undefined") {
                                c.frameGeometry = { x: targetX, y: targetY, width: targetW, height: targetH };
                            }
                        } catch(e) {}
                        try {
                            if (typeof c.geometry !== "undefined") {
                                c.geometry = { x: targetX, y: targetY, width: targetW, height: targetH };
                            }
                        } catch(e) {}
                    }

                    lockDown();

                    if (typeof c.quickTileModeChanged !== "undefined") {
                        c.quickTileModeChanged.connect(lockDown);
                    }
                    if (typeof c.frameGeometryChanged !== "undefined") {
                        c.frameGeometryChanged.connect(function() {
                            if (c.x !== targetX || c.y !== targetY) {
                                lockDown();
                            }
                        });
                    }
                    return true;
                }
                return false;
            }

            var list = (typeof workspace.windowList === "function") ? workspace.windowList() : 
                       ((typeof workspace.clientList === "function") ? workspace.clientList() : []);
            for (var i = 0; i < list.length; i++) {
                configureClient(list[i]);
            }
            if (typeof workspace.windowAdded !== "undefined") {
                workspace.windowAdded.connect(configureClient);
            }
            if (typeof workspace.clientAdded !== "undefined") {
                workspace.clientAdded.connect(configureClient);
            }
        })();
        """
        kwin_js = (template
                   .replace("__TARGET_PID__", str(my_pid))
                   .replace("__TARGET_X__", str(target_x))
                   .replace("__TARGET_Y__", str(target_y))
                   .replace("__TARGET_W__", str(width))
                   .replace("__TARGET_H__", str(height)))

        threading.Thread(target=self._execute_kwin_script, args=(kwin_js, "alcove_position"), daemon=True).start()

    def acquire_interaction_focus(self, view: QQuickView):
        my_pid = os.getpid()
        template = """
        (function() {
            var targetPid = __TARGET_PID__;
            var list = (typeof workspace.windowList === "function") ? workspace.windowList() : 
                       ((typeof workspace.clientList === "function") ? workspace.clientList() : []);
            for (var i = 0; i < list.length; i++) {
                var w = list[i];
                if (w && w.pid === targetPid) {
                    if (typeof workspace.activeWindow !== "undefined") workspace.activeWindow = w;
                    else if (typeof workspace.activeClient !== "undefined") workspace.activeClient = w;
                    break;
                }
            }
        })();
        """
        activate_js = template.replace("__TARGET_PID__", str(my_pid))
        threading.Thread(target=self._execute_kwin_script, args=(activate_js, "alcove_acquire_focus"), daemon=True).start()
        view.requestActivate()

    def restore_previous_focus(self, view: QQuickView):
        my_pid = os.getpid()
        template = """
        (function() {
            var targetPid = __TARGET_PID__;
            var curDesk = (typeof workspace.currentVirtualDesktop !== "undefined") ? workspace.currentVirtualDesktop : 
                          ((typeof workspace.currentDesktop !== "undefined") ? workspace.currentDesktop : null);

            var list = (typeof workspace.stackingOrder === "function") ? workspace.stackingOrder() :
                       ((typeof workspace.windowList === "function") ? workspace.windowList() : []);

            for (var j = list.length - 1; j >= 0; j--) {
                var w = list[j];
                if (!w || (w.pid && w.pid === targetPid) || w.minimized || w.skipTaskbar) continue;

                var onCurrent = false;
                if (w.onAllDesktops) {
                    onCurrent = true;
                } else if (typeof w.isOnDesktop === "function" && curDesk !== null) {
                    onCurrent = w.isOnDesktop(curDesk);
                } else if (typeof w.desktops !== "undefined" && curDesk !== null && Array.isArray(w.desktops)) {
                    onCurrent = (w.desktops.indexOf(curDesk) !== -1);
                } else if (typeof w.desktop !== "undefined" && curDesk !== null) {
                    onCurrent = (w.desktop === curDesk);
                }

                if (onCurrent) {
                    if (typeof workspace.activeWindow !== "undefined") {
                        workspace.activeWindow = w;
                    } else if (typeof workspace.activeClient !== "undefined") {
                        workspace.activeClient = w;
                    }
                    break;
                }
            }
        })();
        """
        restore_js = template.replace("__TARGET_PID__", str(my_pid))
        threading.Thread(target=self._execute_kwin_script, args=(restore_js, "alcove_restore_focus"), daemon=True).start()

    def apply_input_mask(self, view: QQuickView, x: int, y: int, w: int, h: int) -> None:
        if w <= 0 or h <= 0:
            self.set_passthrough(view)
            return
        view.setMask(QRegion(QRect(int(x), int(y), int(w), int(h))))

    def clear_input_mask(self, view: QQuickView) -> None:
        view.setMask(QRegion(0, 0, int(view.width()), int(view.height())))

    def set_passthrough(self, view: QQuickView) -> None:
        view.setMask(QRegion(0, 0, 1, 1))

    def start_clipboard_monitor(self, on_changed_callback: Callable[[str, bool, set], None]) -> None:
        self._clip_running = True
        has_wl_paste = bool(shutil.which("wl-paste"))

        if has_wl_paste:
            def _wl_worker():
                while self._clip_running:
                    try:
                        self._wl_proc = subprocess.Popen(
                            ["wl-paste", "--watch", "echo", "changed"],
                            stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL,
                            text=True
                        )
                        for line in self._wl_proc.stdout:
                            if not self._clip_running:
                                break
                            try:
                                text_res = subprocess.run(["wl-paste", "-n"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=0.5)
                                text = text_res.stdout
                                type_res = subprocess.run(["wl-paste", "--list-types"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=0.5)
                                types = set(type_res.stdout.splitlines())
                                has_image = any("image" in t for t in types)
                                on_changed_callback(text, has_image, types)
                            except Exception:
                                pass
                    except Exception as e:
                        app_logger.debug(f"[KDE Wayland] wl-paste worker: {e}")
                    if self._clip_running:
                        time.sleep(2)

            self._clip_thread = threading.Thread(target=_wl_worker, daemon=True, name="WlPasteClipboardWatcher")
            self._clip_thread.start()
            app_logger.info("✅ 已挂载 Wayland 零焦点独立剪贴板看门狗 (wl-paste)")
        else:
            clipboard = QGuiApplication.clipboard()
            def _fallback():
                mime = clipboard.mimeData()
                if not mime: return
                on_changed_callback(clipboard.text() if mime.hasText() else "", mime.hasImage(), set(mime.formats()))
            self._fallback_handler = _fallback
            clipboard.dataChanged.connect(self._fallback_handler)

    def stop_clipboard_monitor(self) -> None:
        self._clip_running = False
        if self._wl_proc:
            try:
                self._wl_proc.terminate()
            except Exception:
                pass

    def focus_application_window(self, class_pattern: str, title_pattern: str) -> bool:
        c_pat = class_pattern.lower()
        t_pat = title_pattern.lower()
        template = """
        (function() {
            var list = (typeof workspace.windowList === "function") ? workspace.windowList() : 
                       ((typeof workspace.clientList === "function") ? workspace.clientList() : []);
            for (var i = 0; i < list.length; i++) {
                var w = list[i];
                var cls = (w.resourceClass || w.desktopFileName || "").toString().toLowerCase();
                var cap = (w.caption || "").toString().toLowerCase();
                if (cls.indexOf("__CLASS_PAT__") !== -1 || cap.indexOf("__TITLE_PAT__") !== -1) {
                    if (typeof workspace.activeWindow !== "undefined") {
                        workspace.activeWindow = w;
                    }
                    if (typeof workspace.activeClient !== "undefined") {
                        workspace.activeClient = w;
                    }
                    break;
                }
            }
        })();
        """
        kwin_js = template.replace("__CLASS_PAT__", c_pat).replace("__TITLE_PAT__", t_pat)
        self._execute_kwin_script(kwin_js, "alcove_focus")
        return True

    def simulate_shortcut(self, key_combination: str) -> bool:
        if shutil.which("ydotool"):
            key_map = {"ctrl": "29", "shift": "42", "alt": "56", "s": "31", "d": "32"}
            parts = [p.strip().lower() for p in key_combination.split("+")]
            codes = [key_map[p] for p in parts if p in key_map]
            if codes:
                press = " ".join([f"{c}:1" for c in codes])
                release = " ".join([f"{c}:0" for c in reversed(codes)])
                try:
                    subprocess.run(f"ydotool key {press} {release}", shell=True, timeout=1.0)
                    return True
                except Exception:
                    pass

        if shutil.which("wtype"):
            try:
                subprocess.run(f"wtype -M ctrl -M shift -k {key_combination[-1]}", shell=True, timeout=1.0)
                return True
            except Exception:
                pass
        return False