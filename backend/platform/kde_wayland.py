# ==========================================
# 📄 File: backend/platform/kde_wayland.py
# 🌟 KDE Plasma 5/6 Wayland 原生适配驱动 (修复无竞争+双版本执行器版)
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

    @property
    def platform_name(self) -> str:
        return "KDE Plasma Wayland"

    def get_window_flags(self) -> Qt.WindowType:
        return (
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.Tool |
            Qt.WindowType.BypassWindowManagerHint
        )

    def _find_qdbus(self) -> Optional[str]:
        # 🚀 优先寻找 Qt 6 的 qdbus 工具以精确适配 Plasma 6
        for candidate in ["qdbus6", "qdbus-qt6", "qdbus", "qdbus-qt5"]:
            if shutil.which(candidate):
                return candidate
        return None

    def _execute_kwin_script(self, script_body: str, script_name_prefix: str = "alcove_kwin"):
        """符合 KDE KWin 5/6 规范的 D-Bus Scripting 执行通道 (带线程隔离与多版本自适应)"""
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

            # 1. 装载临时脚本
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
                app_logger.debug(f"[KDE Wayland] 加载 KWin 脚本未返回有效 ID: {script_id}")
                return

            # 2. 依次尝试 Plasma 6/5 的触发方法
            executed = False
            candidates = [
                # 方案 A: Plasma 6 的标准脚本对象路径
                (f"/Scripting/Script{script_id}", "org.kde.kwin.Script.run"),
                # 方案 B: 部分发行版 Plasma 6 的全局激活入口
                ("/Scripting", "org.kde.kwin.Scripting.start"),
                # 方案 C: Plasma 5 的根对象路径
                (f"/{script_id}", "org.kde.kwin.Script.run")
            ]

            for obj_path, method_sig in candidates:
                if qdbus_bin:
                    run_cmd = [qdbus_bin, "org.kde.KWin", obj_path, method_sig]
                else:
                    run_cmd = ["dbus-send", "--session", "--dest=org.kde.KWin", "--type=method_call",
                               obj_path, method_sig]

                p_run = subprocess.run(run_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=0.8)
                if p_run.returncode == 0:
                    executed = True
                    break

            if not executed:
                app_logger.debug("[KDE Wayland] KWin 脚本启动通知已派发 (无须阻塞)")

            # 3. 延时注销一次性脚本，保持 KWin 脚本运行时树干净
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

        # 🚀 兼顾 Plasma 5 (clientList) 与 Plasma 6 (windowList/windowAdded) 的自适应脚本
        kwin_js = f"""
        (function() {{
            var targetPid = {my_pid};
            var targetX = {target_x};
            var targetY = {target_y};
            var targetW = {width};
            var targetH = {height};

            function configureClient(c) {{
                if (!c) return false;
                var isTarget = false;
                if (c.pid && c.pid === targetPid) {{
                    isTarget = true;
                }} else {{
                    var cls = (c.resourceClass || c.desktopFileName || "").toString().toLowerCase();
                    var cap = (c.caption || "").toString();
                    if (cls.indexOf("alcove-island") !== -1 || cap.indexOf("Alcove Island") !== -1) {{
                        isTarget = true;
                    }}
                }}

                if (isTarget) {{
                    c.onAllDesktops = true;
                    c.keepAbove = true;
                    c.skipTaskbar = true;
                    c.skipPager = true;
                    c.skipSwitcher = true;

                    try {{
                        if (typeof c.frameGeometry !== "undefined") {{
                            c.frameGeometry = {{ x: targetX, y: targetY, width: targetW, height: targetH }};
                        }}
                    }} catch(e) {{}}
                    try {{
                        if (typeof c.geometry !== "undefined") {{
                            c.geometry = {{ x: targetX, y: targetY, width: targetW, height: targetH }};
                        }}
                    }} catch(e) {{}}
                    return true;
                }}
                return false;
            }}

            var list = (typeof workspace.windowList === "function") ? workspace.windowList() : 
                       ((typeof workspace.clientList === "function") ? workspace.clientList() : []);
            for (var i = 0; i < list.length; i++) {{
                configureClient(list[i]);
            }}
            if (typeof workspace.windowAdded !== "undefined") {{
                workspace.windowAdded.connect(configureClient);
            }}
            if (typeof workspace.clientAdded !== "undefined") {{
                workspace.clientAdded.connect(configureClient);
            }}
        }})();
        """
        threading.Thread(target=self._execute_kwin_script, args=(kwin_js, "alcove_position"), daemon=True).start()

    def apply_input_mask(self, view: QQuickView, x: int, y: int, w: int, h: int) -> None:
        if w <= 0 or h <= 0:
            self.set_passthrough(view)
            return

        # 逻辑像素传参，由 Qt 框架在 Wayland 驱动层自动处理屏幕 DPI 缩放
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
        kwin_js = f"""
        (function() {{
            var list = (typeof workspace.windowList === "function") ? workspace.windowList() : 
                       ((typeof workspace.clientList === "function") ? workspace.clientList() : []);
            for (var i = 0; i < list.length; i++) {{
                var w = list[i];
                var cls = (w.resourceClass || w.desktopFileName || "").toString().toLowerCase();
                var cap = (w.caption || "").toString().toLowerCase();
                if (cls.indexOf("{c_pat}") !== -1 || cap.indexOf("{t_pat}") !== -1) {{
                    if (typeof workspace.activeWindow !== "undefined") {{
                        workspace.activeWindow = w;
                    }}
                    if (typeof workspace.activeClient !== "undefined") {{
                        workspace.activeClient = w;
                    }}
                    break;
                }}
            }}
        }})();
        """
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