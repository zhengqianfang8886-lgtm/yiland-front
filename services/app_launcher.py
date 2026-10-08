# ==========================================
# 📄 File: services/app_launcher.py
# 🌟 全链路日志追踪 · 健壮进程派生与应用库扫描
# ==========================================
import os
import json
import time
import shutil
import shlex
import subprocess
from PySide6.QtCore import QObject, Signal
from PySide6.QtGui import QIcon
from logger import app_logger

APPS_CONFIG_DIR = os.path.expanduser("~/.config/alcove_island")
APPS_CONFIG_FILE = os.path.join(APPS_CONFIG_DIR, "apps.json")
APP_ICONS_CACHE_DIR = os.path.expanduser("~/.local/state/alcove_island/app_icons")


class AppLauncherService(QObject):
    appsChanged = Signal()

    def __init__(self, executor, parent=None):
        super().__init__(parent)
        self._pool = executor
        self._apps = []

        os.makedirs(APPS_CONFIG_DIR, exist_ok=True)
        os.makedirs(APP_ICONS_CACHE_DIR, exist_ok=True)
        self._load_apps()

    def get_apps(self) -> list:
        return self._apps

    def _resolve_icon_to_file(self, icon_name_or_path: str) -> str:
        if not icon_name_or_path:
            return ""

        clean = icon_name_or_path.strip()
        if clean.startswith("file://"):
            clean = clean[7:]

        if os.path.isabs(clean) and os.path.exists(clean):
            return f"file://{clean}"

        cached_path = os.path.join(APP_ICONS_CACHE_DIR, f"{clean}.png")
        if os.path.exists(cached_path):
            return f"file://{cached_path}"

        try:
            qicon = QIcon.fromTheme(clean)
            if not qicon.isNull():
                pix = qicon.pixmap(96, 96)
                if not pix.isNull():
                    pix.save(cached_path, "PNG")
                    return f"file://{cached_path}"
        except Exception:
            pass

        search_dirs = [
            "/usr/share/pixmaps",
            "/usr/share/icons/hicolor/48x48/apps",
            "/usr/share/icons/hicolor/scalable/apps",
            os.path.expanduser("~/.local/share/icons")
        ]
        for sdir in search_dirs:
            for ext in [".png", ".svg", ".xpm"]:
                candidate = os.path.join(sdir, f"{clean}{ext}")
                if os.path.exists(candidate):
                    return f"file://{candidate}"

        return ""

    def _load_apps(self):
        if os.path.exists(APPS_CONFIG_FILE):
            try:
                with open(APPS_CONFIG_FILE, "r", encoding="utf-8") as f:
                    self._apps = json.load(f)
                    for item in self._apps:
                        item["icon"] = self._resolve_icon_to_file(item.get("raw_icon", item.get("icon", "")))
                if self._apps:
                    app_logger.info(f"📂 [AppLauncher] 成功加载 {len(self._apps)} 个应用配置")
                    return
            except Exception as e:
                app_logger.warning(f"⚠️ [AppLauncher] 读取应用配置失败: {e}")

        # 默认自动检测本地已安装应用
        self._apps = []
        candidates = [
            ("终端", "utilities-terminal", "kitty", "kitty"),
            ("终端", "terminal", "alacritty", "alacritty"),
            ("终端", "terminal", "gnome-terminal", "gnome-terminal"),
            ("文件", "system-file-manager", "nautilus", "nautilus"),
            ("文件", "folder", "dolphin", "dolphin"),
            ("浏览器", "google-chrome", "google-chrome", "google-chrome-stable"),
            ("浏览器", "firefox", "firefox", "firefox"),
            ("代码", "visual-studio-code", "code", "code"),
            ("系统设置", "preferences-system", "gnome-control-center", "gnome-control-center")
        ]

        seen_names = set()
        for name, icon, exe, cmd in candidates:
            if shutil.which(exe) and name not in seen_names:
                seen_names.add(name)
                icon_file = self._resolve_icon_to_file(icon)
                self._apps.append({
                    "id": f"app_{int(time.time() * 1000)}_{len(self._apps)}",
                    "name": name,
                    "exec": cmd,
                    "raw_icon": icon,
                    "icon": icon_file
                })
                if len(self._apps) >= 6:
                    break

        self._save_apps()

    def _save_apps(self):
        try:
            os.makedirs(APPS_CONFIG_DIR, exist_ok=True)
            with open(APPS_CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(self._apps, f, indent=2, ensure_ascii=False)
            app_logger.info(f"💾 [AppLauncher] 应用清单已持久化写入: {APPS_CONFIG_FILE}")
        except Exception as e:
            app_logger.error(f"❌ [AppLauncher] 保存应用列表失败: {e}")

    # =========================================================================
    # 🚀【核心启动引擎与全链路日志】
    # =========================================================================
    def launch_app(self, app_id: str):
        app_logger.info(f"👉 [AppLauncher] 收到启动请求 -> target app_id: {app_id}")
        app_item = next((a for a in self._apps if a["id"] == app_id), None)
        if not app_item:
            app_logger.error(f"❌ [AppLauncher] 启动失败：未找到对应的应用记录 (ID: {app_id})")
            return

        name = app_item.get("name", "未命名应用")
        cmd_str = app_item.get("exec", "").strip()
        app_logger.info(f"📋 [AppLauncher] 命中目标应用: [{name}], 原始启动命令: '{cmd_str}'")

        if not cmd_str:
            app_logger.error(f"❌ [AppLauncher] 应用 [{name}] 没有配置启动命令，无法拉起！")
            return

        def _exec():
            try:
                # 1. 优先针对 .desktop 文件通过 gio 或 gtk-launch 启动
                if cmd_str.endswith(".desktop"):
                    if shutil.which("gio"):
                        app_logger.info(f"🚀 [AppLauncher] 通过系统 gio launch 拉起: {cmd_str}")
                        subprocess.Popen(["gio", "launch", cmd_str], start_new_session=True)
                        return
                    if shutil.which("gtk-launch"):
                        desktop_id = os.path.basename(cmd_str).replace(".desktop", "")
                        app_logger.info(f"🚀 [AppLauncher] 通过系统 gtk-launch 拉起: {desktop_id}")
                        subprocess.Popen(["gtk-launch", desktop_id], start_new_session=True)
                        return

                # 2. 宏展开命令参数（剥离 %U, %u, %F, %f 等桌面快捷字段）
                cmd_expanded = os.path.expandvars(os.path.expanduser(cmd_str))
                raw_args = shlex.split(cmd_expanded)
                clean_args = [a for a in raw_args if not (a.startswith("%") and len(a) == 2)]

                if not clean_args:
                    app_logger.error(f"❌ [AppLauncher] 解析后参数为空！")
                    return

                # 3. 检查可执行程序在系统 PATH 中是否存在
                exe = clean_args[0]
                if not os.path.isabs(exe) and not shutil.which(exe):
                    app_logger.error(f"❌ [AppLauncher] 可执行文件 '{exe}' 在系统 PATH 中未找到，请检查安装！")
                    return

                app_logger.info(f"🚀 [AppLauncher] 正在派生独立进程: {clean_args}")
                proc = subprocess.Popen(
                    clean_args,
                    start_new_session=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                app_logger.info(f"✨ [AppLauncher] 成功唤起应用 [{name}]！进程 PID: {proc.pid}")
            except Exception as err:
                app_logger.error(f"💥 [AppLauncher] 拉起进程发生异常: {err}")

        self._pool.submit(_exec)

    def delete_app(self, app_id: str):
        app_logger.info(f"🗑️ [AppLauncher] 删除应用 ID: {app_id}")
        self._apps = [a for a in self._apps if a["id"] != app_id]
        self._save_apps()
        self.appsChanged.emit()

    def add_app(self, name: str, exec_cmd: str, raw_icon: str):
        new_id = f"app_{int(time.time() * 1000)}"
        resolved_icon = self._resolve_icon_to_file(raw_icon)
        new_item = {
            "id": new_id,
            "name": name.strip() or "未命名应用",
            "exec": exec_cmd.strip(),
            "raw_icon": raw_icon,
            "icon": resolved_icon
        }
        app_logger.info(f"➕ [AppLauncher] 录入新应用: {new_item}")
        self._apps.append(new_item)
        self._save_apps()
        self.appsChanged.emit()

    def scan_system_desktop_apps(self) -> list:
        """扫描系统 /usr/share/applications/ 下的可用桌面应用供选择"""
        results = []
        seen = set()
        dirs = ["/usr/share/applications", os.path.expanduser("~/.local/share/applications")]
        for adir in dirs:
            if not os.path.exists(adir):
                continue
            for f in sorted(os.listdir(adir)):
                if f.endswith(".desktop"):
                    fpath = os.path.join(adir, f)
                    try:
                        name, exec_cmd, icon, nodisplay = "", "", "", False
                        with open(fpath, "r", encoding="utf-8", errors="ignore") as fp:
                            for line in fp:
                                line = line.strip()
                                if line == "NoDisplay=true":
                                    nodisplay = True
                                    break
                                if line.startswith("Name=") and not name:
                                    name = line.split("=", 1)[1]
                                elif line.startswith("Exec=") and not exec_cmd:
                                    raw_e = line.split("=", 1)[1]
                                    exec_cmd = " ".join([p for p in raw_e.split() if not p.startswith("%")])
                                elif line.startswith("Icon=") and not icon:
                                    icon = line.split("=", 1)[1]
                        if not nodisplay and name and exec_cmd and name not in seen:
                            seen.add(name)
                            results.append({
                                "name": name,
                                "exec": exec_cmd,
                                "raw_icon": icon,
                                "icon": self._resolve_icon_to_file(icon)
                            })
                    except Exception:
                        pass
        return results[:80]