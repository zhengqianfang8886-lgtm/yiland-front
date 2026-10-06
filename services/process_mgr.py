# ==========================================
# 📄 File: services/process_mgr.py (生产级健壮架构版)
# ==========================================
import os
import json
import time
import signal
import shlex
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor
from PySide6.QtCore import QObject, QTimer, Signal
from logger import app_logger

TASKS_CONFIG_DIR = os.path.expanduser("~/.config/alcove_island")
TASKS_CONFIG_FILE = os.path.join(TASKS_CONFIG_DIR, "tasks.json")
TASKS_ICONS_DIR = os.path.join(TASKS_CONFIG_DIR, "icons")


class ProcessManagerService(QObject):
    taskListChanged = Signal()
    taskStatusChanged = Signal(str, str, int, str)  # task_id, status, pid, error_msg

    def __init__(self, parent=None):
        super().__init__(parent)
        self._tasks = []
        self._proc_map = {}  # {task_id: (proc, log_file, log_path)}
        self._thread_pool = ThreadPoolExecutor(max_workers=2, thread_name_prefix="ProcTerminator")

        os.makedirs(TASKS_ICONS_DIR, exist_ok=True)
        self._load_tasks()

        self._poll_timer = QTimer(self)
        self._poll_timer.setInterval(1000)
        self._poll_timer.timeout.connect(self._check_processes)
        self._poll_timer.start()

    def get_tasks(self) -> list:
        return self._tasks

    # =========================================================================
    # 🚀 核心架构：智能可执行文件与环境解析引擎
    # =========================================================================
    def _resolve_executable_and_env(self, cmd_str: str, cwd: str):
        """
        自动统一处理：环境变量展开、~展开、相对CWD寻址、当前目录直寻、可执行权限检查与补全
        """
        # 1. 补齐与融合完整用户运行环境变量（确保 Wayland/X11/桌面环境、自定义库能够被子进程识别）
        env = os.environ.copy()
        extra_paths = [
            cwd,
            os.path.expanduser("~/.local/bin"),
            os.path.expanduser("~/bin"),
            "/usr/local/bin"
        ]
        curr_path = env.get("PATH", "")
        env["PATH"] = ":".join(extra_paths) + ":" + curr_path

        # 2. 宏展开命令参数（例如 $HOME, ${VAR}, ~）
        cmd_expanded = os.path.expandvars(os.path.expanduser(cmd_str.strip()))
        has_shell_metachars = any(c in cmd_expanded for c in ["&", "|", ";", ">", "<", "$", "`", "\n"])

        if has_shell_metachars:
            # 复合命令交由系统 Shell 解析
            return ["/bin/sh", "-c", cmd_expanded], env, True

        args = shlex.split(cmd_expanded)
        if not args:
            raise ValueError("命令不能为空")

        raw_exe = args[0]
        resolved_exe = None

        # 情况 A: 显式指定路径（如 ./mac-engine-pro, ../bin/app, /opt/app）
        if "/" in raw_exe:
            target_path = os.path.abspath(raw_exe) if os.path.isabs(raw_exe) else os.path.abspath(os.path.join(cwd, raw_exe))
            if os.path.isfile(target_path):
                resolved_exe = target_path
        # 情况 B: 仅输入程序名（如 mac-engine-pro），优先匹配工作目录 CWD 下是否存在同名文件
        else:
            local_target = os.path.join(cwd, raw_exe)
            if os.path.isfile(local_target):
                resolved_exe = local_target
            else:
                #  fallback 查 PATH
                resolved_exe = shutil.which(raw_exe, path=env["PATH"])

        if not resolved_exe or not os.path.isfile(resolved_exe):
            raise FileNotFoundError(f"未找到可执行文件: '{raw_exe}' (已检查工作目录: '{cwd}')")

        # 3. 自动探测与修复执行权限
        if not os.access(resolved_exe, os.X_OK):
            try:
                os.chmod(resolved_exe, os.stat(resolved_exe).st_mode | 0o111)
                app_logger.info(f"🔧 自动为可执行文件追加执行权限 (+x): {resolved_exe}")
            except Exception as e:
                raise PermissionError(f"文件无执行权限且自动修复失败: {resolved_exe} ({e})")

        args[0] = resolved_exe
        return args, env, False

    def _get_last_error_log(self, log_path: str) -> str:
        """从日志中提取关键的报错信息，用于上报 UI"""
        if not log_path or not os.path.exists(log_path):
            return ""
        try:
            with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
                lines = [l.strip() for l in f.readlines() if l.strip()]
                if lines:
                    return lines[-1][:80]
        except Exception:
            pass
        return ""

    def start_task(self, task_id: str):
        task = next((t for t in self._tasks if t["id"] == task_id), None)
        if not task:
            return

        if task_id in self._proc_map and self._proc_map[task_id][0].poll() is None:
            return

        raw_cwd = task.get("cwd", "~")
        cwd = os.path.abspath(os.path.expanduser(raw_cwd))
        if not os.path.isdir(cwd):
            err = f"工作目录不存在: {cwd}"
            task["status"] = "error"
            self.taskStatusChanged.emit(task_id, "error", 0, err)
            app_logger.error(f"[ProcessManager] {err}")
            return

        cmd_str = task.get("cmd", "").strip()
        if not cmd_str:
            err = "任务启动命令为空"
            task["status"] = "error"
            self.taskStatusChanged.emit(task_id, "error", 0, err)
            return

        log_path = f"/tmp/alcove_task_{task_id}.log"
        log_file = None
        try:
            exec_args, exec_env, is_shell = self._resolve_executable_and_env(cmd_str, cwd)
            log_file = open(log_path, "w", encoding="utf-8")

            # 启动独立会话组（方便后续完全回收子进程及其子派生进程）
            proc = subprocess.Popen(
                exec_args,
                cwd=cwd,
                env=exec_env,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                start_new_session=True
            )

            # 🚀 架构增强：微等待 80ms 检测是否由于缺失动态库/参数错误而瞬间猝死
            time.sleep(0.08)
            ret = proc.poll()
            if ret is not None:
                log_file.flush()
                log_file.close()
                err_detail = self._get_last_error_log(log_path) or f"进程非正常退出 (状态码 {ret})"
                task["status"] = "error"
                task["pid"] = 0
                self.taskStatusChanged.emit(task_id, "error", 0, err_detail)
                app_logger.error(f"[ProcessManager] 启动即闪退: {err_detail}")
                return

            self._proc_map[task_id] = (proc, log_file, log_path)
            task["status"] = "running"
            task["pid"] = proc.pid
            self.taskStatusChanged.emit(task_id, "running", proc.pid, "")
            app_logger.info(f"✨ 成功拉起服务 [{task.get('name')}] (PID: {proc.pid})")

        except Exception as e:
            app_logger.error(f"启动失败: {e}")
            if log_file and not log_file.closed:
                log_file.close()
            task["status"] = "error"
            task["pid"] = 0
            self.taskStatusChanged.emit(task_id, "error", 0, str(e))

    def stop_task(self, task_id: str):
        task = next((t for t in self._tasks if t["id"] == task_id), None)
        entry = self._proc_map.pop(task_id, None)

        if entry:
            proc, log_file, _ = entry
            if log_file and not log_file.closed:
                try: log_file.close()
                except Exception: pass

            def _terminate_worker():
                if proc.poll() is None:
                    try:
                        pgid = os.getpgid(proc.pid)
                        os.killpg(pgid, signal.SIGTERM)
                    except Exception:
                        try: proc.terminate()
                        except Exception: pass

                    # 等待优雅退出，超时强制 SIGKILL，彻底回收避免僵尸进程
                    try:
                        proc.wait(timeout=1.2)
                    except subprocess.TimeoutExpired:
                        try:
                            pgid = os.getpgid(proc.pid)
                            os.killpg(pgid, signal.SIGKILL)
                        except Exception:
                            try: proc.kill()
                            except Exception: pass
                        try: proc.wait(timeout=0.5)
                        except Exception: pass

            self._thread_pool.submit(_terminate_worker)

        if task:
            task["status"] = "stopped"
            task["pid"] = 0
            self.taskStatusChanged.emit(task_id, "stopped", 0, "")

    def _check_processes(self):
        for t in self._tasks:
            tid = t["id"]
            entry = self._proc_map.get(tid)
            if entry is not None:
                proc, log_file, log_path = entry
                ret = proc.poll()
                if ret is not None:
                    if log_file and not log_file.closed:
                        try: log_file.close()
                        except Exception: pass
                    self._proc_map.pop(tid, None)
                    err_msg = self._get_last_error_log(log_path) if ret != 0 else ""
                    t["status"] = "error" if ret != 0 else "stopped"
                    t["pid"] = 0
                    self.taskStatusChanged.emit(tid, t["status"], 0, err_msg)

    def _load_tasks(self):
        os.makedirs(TASKS_CONFIG_DIR, exist_ok=True)
        if not os.path.exists(TASKS_CONFIG_FILE):
            self._tasks = []
            return

        try:
            with open(TASKS_CONFIG_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                for item in loaded:
                    item["status"] = "stopped"
                    item["pid"] = 0
                    item.setdefault("icon", "")
                self._tasks = loaded
        except Exception as e:
            app_logger.error(f"读取任务配置失败: {e}")
            self._tasks = []

    def _save_tasks(self):
        try:
            os.makedirs(TASKS_CONFIG_DIR, exist_ok=True)
            to_save = [
                {
                    "id": t["id"],
                    "name": t.get("name", "未命名"),
                    "cwd": t.get("cwd", os.path.expanduser("~")),
                    "cmd": t.get("cmd", ""),
                    "icon": t.get("icon", "")
                }
                for t in self._tasks
            ]
            with open(TASKS_CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(to_save, f, indent=2, ensure_ascii=False)
        except Exception as e:
            app_logger.error(f"保存任务配置失败: {e}")

    def import_task_icon(self, raw_path: str, task_id: str) -> str:
        if not raw_path: return ""
        clean_path = raw_path[7:] if raw_path.startswith("file://") else raw_path
        clean_path = os.path.abspath(os.path.expanduser(clean_path))
        if not os.path.exists(clean_path): return ""
        if os.path.dirname(clean_path) == TASKS_ICONS_DIR: return clean_path
        try:
            ext = os.path.splitext(clean_path)[1].lower() or ".png"
            target_path = os.path.join(TASKS_ICONS_DIR, f"task_{task_id}_{int(time.time())}{ext}")
            shutil.copy2(clean_path, target_path)
            return target_path
        except Exception as e:
            app_logger.error(f"持久化图标失败: {e}")
            return clean_path

    def start_all(self):
        for t in self._tasks: self.start_task(t["id"])

    def stop_all(self):
        for tid in list(self._proc_map.keys()): self.stop_task(tid)

    def add_task(self, name: str, cwd: str, cmd: str, icon: str = ""):
        new_id = f"task_{int(time.time() * 1000)}"
        saved_icon = self.import_task_icon(icon, new_id) if icon else ""
        self._tasks.append({
            "id": new_id,
            "name": name.strip() or "新建任务",
            "cwd": os.path.abspath(os.path.expanduser(cwd.strip() or "~")),
            "cmd": cmd.strip(),
            "icon": saved_icon,
            "status": "stopped",
            "pid": 0
        })
        self._save_tasks()
        self.taskListChanged.emit()

    def update_task(self, task_id: str, name: str, cwd: str, cmd: str, icon: str = ""):
        task = next((t for t in self._tasks if t["id"] == task_id), None)
        if not task: return
        task["name"] = name.strip()
        task["cwd"] = os.path.abspath(os.path.expanduser(cwd.strip() or "~"))
        task["cmd"] = cmd.strip()
        task["icon"] = self.import_task_icon(icon, task_id) if icon else ""
        self._save_tasks()
        self.taskListChanged.emit()

    def delete_task(self, task_id: str):
        self.stop_task(task_id)
        self._tasks = [t for t in self._tasks if t["id"] != task_id]
        self._save_tasks()
        self.taskListChanged.emit()

    def cleanup(self):
        self.stop_all()
        self._thread_pool.shutdown(wait=False, cancel_futures=True)