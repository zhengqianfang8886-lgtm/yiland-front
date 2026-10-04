# ==========================================
# 📄 File: services/process_mgr.py
# ==========================================
import os
import json
import time
import signal
import subprocess
from PySide6.QtCore import QObject, QTimer, Signal
from logger import app_logger

TASKS_CONFIG_DIR = os.path.expanduser("~/.config/alcove_island")
TASKS_CONFIG_FILE = os.path.join(TASKS_CONFIG_DIR, "tasks.json")


class ProcessManagerService(QObject):
    taskListChanged = Signal()
    taskStatusChanged = Signal(str, str, int)  # task_id, status ("running"|"stopped"|"error"), pid

    def __init__(self, parent=None):
        super().__init__(parent)
        self._tasks = []
        self._proc_map = {}  # { task_id: subprocess.Popen }

        self._load_tasks()

        self._poll_timer = QTimer(self)
        self._poll_timer.setInterval(1000)
        self._poll_timer.timeout.connect(self._check_processes)
        self._poll_timer.start()

    def get_tasks(self) -> list:
        return self._tasks

    def _load_tasks(self):
        os.makedirs(TASKS_CONFIG_DIR, exist_ok=True)
        if not os.path.exists(TASKS_CONFIG_FILE):
            self._tasks = [
                {
                    "id": "task_1",
                    "name": "Alcove WebSocket Daemon",
                    "cwd": os.path.expanduser("~"),
                    "cmd": "echo 'Service Ready' && sleep 3600",
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
                    "cmd": t.get("cmd", "")
                })
            with open(TASKS_CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(to_save, f, indent=2, ensure_ascii=False)
        except Exception as e:
            app_logger.error(f"保存任务配置失败: {e}")

    def _check_processes(self):
        for t in self._tasks:
            tid = t["id"]
            proc = self._proc_map.get(tid)
            if proc is not None:
                ret = proc.poll()
                if ret is not None:
                    self._proc_map.pop(tid, None)
                    t["status"] = "error" if ret != 0 else "stopped"
                    t["pid"] = 0
                    self.taskStatusChanged.emit(tid, t["status"], 0)

    def start_task(self, task_id: str):
        task = next((t for t in self._tasks if t["id"] == task_id), None)
        if not task:
            return

        if task_id in self._proc_map and self._proc_map[task_id].poll() is None:
            return

        cwd = os.path.expanduser(task.get("cwd", "~"))
        if not os.path.isdir(cwd):
            task["status"] = "error"
            self.taskStatusChanged.emit(task_id, "error", 0)
            return

        log_path = f"/tmp/alcove_task_{task_id}.log"
        try:
            log_file = open(log_path, "w", encoding="utf-8")
            # ✅ 使用 start_new_session=True 替代有死锁风险的 preexec_fn=os.setsid
            proc = subprocess.Popen(
                task["cmd"],
                cwd=cwd,
                shell=True,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                start_new_session=True
            )
            self._proc_map[task_id] = proc
            task["status"] = "running"
            task["pid"] = proc.pid
            self.taskStatusChanged.emit(task_id, "running", proc.pid)
            app_logger.info(f"启动子进程 [{task['name']}] (PID: {proc.pid}) -> {task['cmd']}")
        except Exception as e:
            app_logger.error(f"执行任务启动失败: {e}")
            task["status"] = "error"
            task["pid"] = 0
            self.taskStatusChanged.emit(task_id, "error", 0)

    def stop_task(self, task_id: str):
        task = next((t for t in self._tasks if t["id"] == task_id), None)
        proc = self._proc_map.get(task_id)

        if proc and proc.poll() is None:
            try:
                pgid = os.getpgid(proc.pid)
                os.killpg(pgid, signal.SIGTERM)
                app_logger.info(f"发送 SIGTERM 到进程组 PGID: {pgid}")
            except ProcessLookupError:
                pass
            except Exception:
                try:
                    proc.terminate()
                except Exception:
                    pass

        self._proc_map.pop(task_id, None)
        if task:
            task["status"] = "stopped"
            task["pid"] = 0
            self.taskStatusChanged.emit(task_id, "stopped", 0)

    def start_all(self):
        for t in self._tasks:
            self.start_task(t["id"])

    def stop_all(self):
        for t in list(self._proc_map.keys()):
            self.stop_task(t)

    def add_task(self, name: str, cwd: str, cmd: str):
        new_id = f"task_{int(time.time() * 1000)}"
        new_item = {
            "id": new_id,
            "name": name.strip() or "新建任务",
            "cwd": os.path.expanduser(cwd.strip() or "~"),
            "cmd": cmd.strip(),
            "status": "stopped",
            "pid": 0
        }
        self._tasks.append(new_item)
        self._save_tasks()
        self.taskListChanged.emit()

    def update_task(self, task_id: str, name: str, cwd: str, cmd: str):
        task = next((t for t in self._tasks if t["id"] == task_id), None)
        if not task:
            return
        task["name"] = name.strip()
        task["cwd"] = os.path.expanduser(cwd.strip())
        task["cmd"] = cmd.strip()
        self._save_tasks()
        self.taskListChanged.emit()

    def delete_task(self, task_id: str):
        self.stop_task(task_id)
        self._tasks = [t for t in self._tasks if t["id"] != task_id]
        self._save_tasks()
        self.taskListChanged.emit()

    def cleanup(self):
        self.stop_all()