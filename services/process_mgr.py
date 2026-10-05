# ==========================================
# 📄 File: services/process_mgr.py (支持真实图片持久化)
# ==========================================
import os
import json
import time
import signal
import shlex
import shutil
import subprocess
from PySide6.QtCore import QObject, QTimer, Signal
from logger import app_logger

TASKS_CONFIG_DIR = os.path.expanduser("~/.config/alcove_island")
TASKS_CONFIG_FILE = os.path.join(TASKS_CONFIG_DIR, "tasks.json")
TASKS_ICONS_DIR = os.path.join(TASKS_CONFIG_DIR, "icons")


class ProcessManagerService(QObject):
    taskListChanged = Signal()
    taskStatusChanged = Signal(str, str, int)  # task_id, status, pid

    def __init__(self, parent=None):
        super().__init__(parent)
        self._tasks = []
        self._proc_map = {}

        os.makedirs(TASKS_ICONS_DIR, exist_ok=True)
        self._load_tasks()

        self._poll_timer = QTimer(self)
        self._poll_timer.setInterval(1000)
        self._poll_timer.timeout.connect(self._check_processes)
        self._poll_timer.start()

    def get_tasks(self) -> list:
        return self._tasks

    # 🚀 将用户选取的图片克隆到软件私有 icons 目录，持久化保全
    def import_task_icon(self, raw_path: str, task_id: str) -> str:
        if not raw_path:
            return ""
        clean_path = raw_path[7:] if raw_path.startswith("file://") else raw_path
        clean_path = os.path.abspath(os.path.expanduser(clean_path))
        if not os.path.exists(clean_path):
            return ""
        
        # 若已在私有目录中则直接返回
        if os.path.dirname(clean_path) == TASKS_ICONS_DIR:
            return clean_path

        try:
            ext = os.path.splitext(clean_path)[1].lower() or ".png"
            target_filename = f"task_{task_id}_{int(time.time())}{ext}"
            target_path = os.path.join(TASKS_ICONS_DIR, target_filename)
            shutil.copy2(clean_path, target_path)
            app_logger.info(f"✨ 成功导入并持久化服务图标: {target_path}")
            return target_path
        except Exception as e:
            app_logger.error(f"持久化服务图标失败: {e}")
            return clean_path

    def _load_tasks(self):
        os.makedirs(TASKS_CONFIG_DIR, exist_ok=True)
        if not os.path.exists(TASKS_CONFIG_FILE):
            self._tasks = [
                {
                    "id": "task_1",
                    "name": "Alcove WebSocket Daemon",
                    "cwd": os.path.expanduser("~"),
                    "cmd": "echo 'Service Ready' && sleep 3600",
                    "icon": "",
                    "status": "stopped",
                    "pid": 0
                }
            ]
            self._save_tasks()
            return

        try:
            with open(TASKS_CONFIG_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                for item in loaded:
                    item["status"] = "stopped"
                    item["pid"] = 0
                    if "icon" not in item:
                        item["icon"] = ""
                self._tasks = loaded
        except Exception as e:
            app_logger.error(f"读取任务配置失败: {e}")
            self._tasks = []

    def _save_tasks(self):
        try:
            os.makedirs(TASKS_CONFIG_DIR, exist_ok=True)
            to_save = []
            for t in self._tasks:
                to_save.append({
                    "id": t["id"],
                    "name": t.get("name", "未命名"),
                    "cwd": t.get("cwd", os.path.expanduser("~")),
                    "cmd": t.get("cmd", ""),
                    "icon": t.get("icon", "")
                })
            with open(TASKS_CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(to_save, f, indent=2, ensure_ascii=False)
        except Exception as e:
            app_logger.error(f"保存任务配置失败: {e}")

    def _check_processes(self):
        for t in self._tasks:
            tid = t["id"]
            entry = self._proc_map.get(tid)
            if entry is not None:
                proc, log_file = entry
                ret = proc.poll()
                if ret is not None:
                    if log_file and not log_file.closed:
                        try: log_file.close()
                        except Exception: pass
                    self._proc_map.pop(tid, None)
                    t["status"] = "error" if ret != 0 else "stopped"
                    t["pid"] = 0
                    self.taskStatusChanged.emit(tid, t["status"], 0)

    def start_task(self, task_id: str):
        task = next((t for t in self._tasks if t["id"] == task_id), None)
        if not task: return
        if task_id in self._proc_map and self._proc_map[task_id][0].poll() is None:
            return

        raw_cwd = task.get("cwd", "~")
        cwd = os.path.abspath(os.path.expanduser(raw_cwd))
        if not os.path.isdir(cwd):
            task["status"] = "error"
            self.taskStatusChanged.emit(task_id, "error", 0)
            return

        cmd_str = task.get("cmd", "").strip()
        if not cmd_str:
            task["status"] = "error"
            self.taskStatusChanged.emit(task_id, "error", 0)
            return

        log_path = f"/tmp/alcove_task_{task_id}.log"
        log_file = None
        try:
            log_file = open(log_path, "w", encoding="utf-8")
            has_shell_metachars = any(c in cmd_str for c in ["&", "|", ";", ">", "<", "$", "`", "\n"])
            if not has_shell_metachars:
                args = shlex.split(cmd_str)
                executable = shutil.which(args[0])
                if not executable: raise FileNotFoundError(f"未找到命令: {args[0]}")
                proc = subprocess.Popen(args, cwd=cwd, stdout=log_file, stderr=subprocess.STDOUT, start_new_session=True)
            else:
                proc = subprocess.Popen(["/bin/sh", "-c", cmd_str], cwd=cwd, stdout=log_file, stderr=subprocess.STDOUT, start_new_session=True)

            self._proc_map[task_id] = (proc, log_file)
            task["status"] = "running"
            task["pid"] = proc.pid
            self.taskStatusChanged.emit(task_id, "running", proc.pid)
        except Exception as e:
            app_logger.error(f"启动失败: {e}")
            if log_file and not log_file.closed: log_file.close()
            task["status"] = "error"
            task["pid"] = 0
            self.taskStatusChanged.emit(task_id, "error", 0)

    def stop_task(self, task_id: str):
        task = next((t for t in self._tasks if t["id"] == task_id), None)
        entry = self._proc_map.get(task_id)
        if entry:
            proc, log_file = entry
            if proc.poll() is None:
                try:
                    pgid = os.getpgid(proc.pid)
                    os.killpg(pgid, signal.SIGTERM)
                except Exception:
                    try: proc.terminate()
                    except Exception: pass
            if log_file and not log_file.closed:
                try: log_file.close()
                except Exception: pass

        self._proc_map.pop(task_id, None)
        if task:
            task["status"] = "stopped"
            task["pid"] = 0
            self.taskStatusChanged.emit(task_id, "stopped", 0)

    def start_all(self):
        for t in self._tasks: self.start_task(t["id"])

    def stop_all(self):
        for t in list(self._proc_map.keys()): self.stop_task(t)

    def add_task(self, name: str, cwd: str, cmd: str, icon: str = ""):
        new_id = f"task_{int(time.time() * 1000)}"
        saved_icon = self.import_task_icon(icon, new_id) if icon else ""
        new_item = {
            "id": new_id,
            "name": name.strip() or "新建任务",
            "cwd": os.path.abspath(os.path.expanduser(cwd.strip() or "~")),
            "cmd": cmd.strip(),
            "icon": saved_icon,
            "status": "stopped",
            "pid": 0
        }
        self._tasks.append(new_item)
        self._save_tasks()
        self.taskListChanged.emit()

    def update_task(self, task_id: str, name: str, cwd: str, cmd: str, icon: str = ""):
        task = next((t for t in self._tasks if t["id"] == task_id), None)
        if not task: return
        task["name"] = name.strip()
        task["cwd"] = os.path.abspath(os.path.expanduser(cwd.strip() or "~"))
        task["cmd"] = cmd.strip()
        if icon:
            task["icon"] = self.import_task_icon(icon, task_id)
        else:
            task["icon"] = ""
        self._save_tasks()
        self.taskListChanged.emit()

    def delete_task(self, task_id: str):
        self.stop_task(task_id)
        self._tasks = [t for t in self._tasks if t["id"] != task_id]
        self._save_tasks()
        self.taskListChanged.emit()

    def cleanup(self):
        self.stop_all()