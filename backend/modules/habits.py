# ==========================================
# 📄 File: backend/modules/habits.py
# 🌟 原生 SQLite 习惯日程引擎 (WAL 事务隔离 + 后端日历排期矩阵生成器)
# ==========================================
import os
import sqlite3
import time
import asyncio
import calendar
from datetime import datetime, date
from typing import List, Dict, Any
from concurrent.futures import ThreadPoolExecutor

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState

DB_DIR = os.path.expanduser("~/.local/share/alcove_island")
DB_PATH = os.path.join(DB_DIR, "habits.db")


class HabitModule(BaseModule):
    """采用专属后台 Worker 与 WAL 事务隔离，全面卸载前端日历排期负担"""

    def __init__(self, backend, state: IslandState):
        super().__init__(backend, state)
        self._pool = ThreadPoolExecutor(max_workers=1, thread_name_prefix="HabitDbWorker")

    async def start(self) -> None:
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(self._pool, self._init_db)
        app_logger.info("✅ 原生 SQLite 习惯日程与日历矩阵引擎已就绪")

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
    # 异步对外业务接口
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

    # 🚀【核心加固】：将日历 35/42 网格的全部数学运算移入后端线程池
    async def generate_calendar_grid_async(self, year: int, month: int, habit_id: str) -> List[Dict[str, Any]]:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(self._pool, self._sync_generate_calendar_grid, year, month, habit_id)

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
        # month 参数约定为 0-11
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
                    cursor.execute("DELETE FROM habit_logs WHERE habit_id = ? AND date_str = ?", (habit_id, date_str))
                else:
                    cursor.execute("INSERT INTO habit_logs (habit_id, date_str) VALUES (?, ?)", (habit_id, date_str))
                conn.commit()
                return not exists
        except Exception as e:
            app_logger.error(f"[HabitModule] 切换打卡记录异常: {e}")
            return False

    def _sync_generate_calendar_grid(self, year: int, month: int, habit_id: str) -> List[Dict[str, Any]]:
        """
        🚀 纯后端高能生成 35 或 42 格标准化排期，前台 QML 仅接收纯模型
        """
        month_records = self._sync_get_month_records(habit_id, year, month)
        today = date.today()

        py_month = month + 1
        cal = calendar.Calendar(firstweekday=0) # 周一为每周起始
        grid = []

        raw_dates = list(cal.itermonthdates(year, py_month))
        # 补齐到 35 或 42 个格子
        target_len = 42 if len(raw_dates) > 35 else 35
        while len(raw_dates) < target_len:
            last = raw_dates[-1]
            raw_dates.append(last.fromordinal(last.toordinal() + 1))

        for d in raw_dates:
            d_str = d.strftime("%Y-%m-%d")
            is_cur_month = (d.year == year and d.month == py_month)
            is_today = (d == today)
            is_checked = month_records.get(d_str, False)

            grid.append({
                "year": d.year,
                "month": d.month - 1, # 转回 0-based
                "day": d.day,
                "dateStr": d_str,
                "isCurrentMonth": is_cur_month,
                "isToday": is_today,
                "isChecked": is_checked
            })

        return grid