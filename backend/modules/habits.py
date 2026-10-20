# ==========================================
# 📄 File: backend/modules/habits.py
# 🌟 原生 SQLite 打卡存储模块 (彻底消灭前端主线程同步死锁与 _v2 灾难)
# ==========================================
import os
import sqlite3
import time
from typing import List, Dict, Any
from concurrent.futures import ThreadPoolExecutor

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState

DB_DIR = os.path.expanduser("~/.local/share/alcove_island")
DB_PATH = os.path.join(DB_DIR, "habits.db")


class HabitModule(BaseModule):
    """采用单一专属线程保障 SQLite 事务并发安全，杜绝 QML 线程卡顿"""

    def __init__(self, backend, state: IslandState):
        super().__init__(backend, state)
        self._pool = ThreadPoolExecutor(max_workers=1, thread_name_prefix="HabitDbWorker")

    async def start(self) -> None:
        await asyncio_run_in_pool(self._pool, self._init_db)
        app_logger.info("✅ 原生 SQLite 习惯日程存储引擎已挂载")

    async def stop(self) -> None:
        self._pool.shutdown(wait=False)

    def _init_db(self):
        os.makedirs(DB_DIR, exist_ok=True)
        with sqlite3.connect(DB_PATH) as conn:
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

    def get_habits(self) -> List[Dict[str, Any]]:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT id, name, icon FROM habits ORDER BY created_at ASC")
            return [{"id": row[0], "name": row[1], "icon": row[2] or "📌"} for row in cursor.fetchall()]

    def add_habit(self, name: str, icon: str = "📌") -> List[Dict[str, Any]]:
        habit_id = f"h_{int(time.time() * 1000)}"
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute(
                "INSERT INTO habits (id, name, icon, created_at) VALUES (?, ?, ?, ?)",
                (habit_id, name.strip(), icon, int(time.time()))
            )
            conn.commit()
        return self.get_habits()

    def delete_habit(self, habit_id: str) -> List[Dict[str, Any]]:
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute("DELETE FROM habits WHERE id = ?", (habit_id,))
            cursor.execute("DELETE FROM habit_logs WHERE habit_id = ?", (habit_id,))
            conn.commit()
        return self.get_habits()

    def get_month_records(self, habit_id: str, year: int, month: int) -> Dict[str, bool]:
        if not habit_id:
            return {}
        prefix = f"{year}-{month + 1:02d}-%"
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT date_str FROM habit_logs WHERE habit_id = ? AND date_str LIKE ?", (habit_id, prefix))
            return {row[0]: True for row in cursor.fetchall()}

    def toggle_record(self, habit_id: str, date_str: str) -> bool:
        if not habit_id or not date_str:
            return False
        with sqlite3.connect(DB_PATH) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT date_str FROM habit_logs WHERE habit_id = ? AND date_str = ?", (habit_id, date_str))
            exists = cursor.fetchone() is not None
            if exists:
                cursor.execute("DELETE FROM habit_logs WHERE habit_id = ? AND date_str = ?", (habit_id, date_str))
            else:
                cursor.execute("INSERT INTO habit_logs (habit_id, date_str) VALUES (?, ?)", (habit_id, date_str))
            conn.commit()
            return not exists


async def asyncio_run_in_pool(executor, func, *args):
    import asyncio
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(executor, func, *args)