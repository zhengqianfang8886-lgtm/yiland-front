# ==========================================
# 📄 File: backend/modules/habits.py
# 🌟 原生 SQLite 习惯日程存储引擎 (WAL 并发模式 · 纯异步线程池隔离版)
# ==========================================
import os
import sqlite3
import time
import asyncio
from typing import List, Dict, Any
from concurrent.futures import ThreadPoolExecutor

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState

DB_DIR = os.path.expanduser("~/.local/share/alcove_island")
DB_PATH = os.path.join(DB_DIR, "habits.db")


class HabitModule(BaseModule):
    """采用专属后台 Worker 与 WAL 事务隔离，杜绝主渲染线程死锁与卡顿"""

    def __init__(self, backend, state: IslandState):
        super().__init__(backend, state)
        self._pool = ThreadPoolExecutor(max_workers=1, thread_name_prefix="HabitDbWorker")

    async def start(self) -> None:
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(self._pool, self._init_db)
        app_logger.info("✅ 原生 SQLite 习惯日程存储引擎已挂载 (WAL 模式激活)")

    async def stop(self) -> None:
        self._pool.shutdown(wait=False, cancel_futures=True)

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(DB_PATH, timeout=5.0)
        conn.execute("PRAGMA journal_mode = WAL;")
        conn.execute("PRAGMA synchronous = NORMAL;")
        return conn

    def _init_db(self):
        os.makedirs(DB_DIR, exist_ok=True)
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS habits (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    icon TEXT DEFAULT '📌',
                    created_at INTEGER
                )
            """)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS habit_logs (
                    habit_id TEXT,
                    date_str TEXT,
                    PRIMARY KEY(habit_id, date_str)
                )
            """)
            conn.commit()

    # -------------------------------------------------------------------------
    # 异步业务接口 (供 Bridge 调度)
    # -------------------------------------------------------------------------
    async def fetch_habits_async(self) -> List[Dict[str, Any]]:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(self._pool, self._sync_get_habits)

    async def add_habit_async(self, name: str, icon: str = "📌") -> List[Dict[str, Any]]:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(self._pool, self._sync_add_habit, name, icon)

    async def delete_habit_async(self, habit_id: str) -> List[Dict[str, Any]]:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(self._pool, self._sync_delete_habit, habit_id)

    async def fetch_month_records_async(self, habit_id: str, year: int, month: int) -> Dict[str, bool]:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(self._pool, self._sync_get_month_records, habit_id, year, month)

    async def toggle_record_async(self, habit_id: str, date_str: str) -> bool:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(self._pool, self._sync_toggle_record, habit_id, date_str)

    # -------------------------------------------------------------------------
    # 线程池同步工作函数
    # -------------------------------------------------------------------------
    def _sync_get_habits(self) -> List[Dict[str, Any]]:
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT id, name, icon FROM habits ORDER BY created_at ASC")
                return [{"id": row[0], "name": row[1], "icon": row[2] or "📌"} for row in cursor.fetchall()]
        except Exception as e:
            app_logger.error(f"[HabitModule] 读取习惯列表异常: {e}")
            return []

    def _sync_add_habit(self, name: str, icon: str = "📌") -> List[Dict[str, Any]]:
        habit_id = f"h_{int(time.time() * 1000)}"
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "INSERT INTO habits (id, name, icon, created_at) VALUES (?, ?, ?, ?)",
                    (habit_id, name.strip(), icon, int(time.time()))
                )
                conn.commit()
        except Exception as e:
            app_logger.error(f"[HabitModule] 新增习惯异常: {e}")
        return self._sync_get_habits()

    def _sync_delete_habit(self, habit_id: str) -> List[Dict[str, Any]]:
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("DELETE FROM habits WHERE id = ?", (habit_id,))
                cursor.execute("DELETE FROM habit_logs WHERE habit_id = ?", (habit_id,))
                conn.commit()
        except Exception as e:
            app_logger.error(f"[HabitModule] 删除习惯异常: {e}")
        return self._sync_get_habits()

    def _sync_get_month_records(self, habit_id: str, year: int, month: int) -> Dict[str, bool]:
        if not habit_id:
            return {}
        prefix = f"{year}-{month + 1:02d}-%"
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "SELECT date_str FROM habit_logs WHERE habit_id = ? AND date_str LIKE ?",
                    (habit_id, prefix)
                )
                return {row[0]: True for row in cursor.fetchall()}
        except Exception as e:
            app_logger.error(f"[HabitModule] 读取打卡记录异常: {e}")
            return {}

    def _sync_toggle_record(self, habit_id: str, date_str: str) -> bool:
        if not habit_id or not date_str:
            return False
        try:
            with self._get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "SELECT date_str FROM habit_logs WHERE habit_id = ? AND date_str = ?",
                    (habit_id, date_str)
                )
                exists = cursor.fetchone() is not None
                if exists:
                    cursor.execute(
                        "DELETE FROM habit_logs WHERE habit_id = ? AND date_str = ?",
                        (habit_id, date_str)
                    )
                else:
                    cursor.execute(
                        "INSERT INTO habit_logs (habit_id, date_str) VALUES (?, ?)",
                        (habit_id, date_str)
                    )
                conn.commit()
                return not exists
        except Exception as e:
            app_logger.error(f"[HabitModule] 切换打卡记录异常: {e}")
            return False