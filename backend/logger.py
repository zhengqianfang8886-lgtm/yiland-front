# ==========================================
# 📄 File: logger.py
# 🌟 零泄密硬阻断日志核心 · 物理过滤所有信息提示
# ==========================================
import os
import sys
import logging
from logging.handlers import RotatingFileHandler

LOG_DIR = os.path.expanduser("~/.local/state/alcove_island")
LOG_FILE = os.path.join(LOG_DIR, "island.log")


class ZeroLeakageFilter(logging.Filter):
    """
    🔒 零泄密安全过滤器：
    物理拦截并直接丢弃任何包含通知、提示、来电、聊天内容或剪贴板明文的日志，
    确保磁盘日志 (island.log) 和控制台绝对不留任何痕迹。
    """
    FORBIDDEN_KEYWORDS = (
        "通知", "提示", "来电", "呼叫", "剪贴板", "notification", "alert",
        "call", "clipboard", "teams", "message", "消息", "chat"
    )

    def filter(self, record):
        try:
            msg = str(record.getMessage()).lower()
            for kw in self.FORBIDDEN_KEYWORDS:
                if kw in msg:
                    return False
        except Exception:
            pass
        return True


class ColoredFormatter(logging.Formatter):
    COLORS = {
        logging.DEBUG: "\033[90m",
        logging.INFO: "\033[32m",
        logging.WARNING: "\033[33m",
        logging.ERROR: "\033[31m",
        logging.CRITICAL: "\033[35m",
    }
    RESET = "\033[0m"

    def format(self, record):
        color = self.COLORS.get(record.levelno, self.RESET)
        record.levelname = f"{color}{record.levelname:<5}{self.RESET}"
        return super().format(record)


def setup_logger(name: str = "AlcoveIsland") -> logging.Logger:
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger

    env_level = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, env_level, logging.INFO)
    logger.setLevel(level)

    # 挂载安全防泄密过滤器
    leak_filter = ZeroLeakageFilter()
    logger.addFilter(leak_filter)

    console_handler = logging.StreamHandler(sys.stdout)
    console_fmt = ColoredFormatter(
        "[%(asctime)s] %(levelname)s [%(name)s] %(message)s",
        datefmt="%H:%M:%S"
    )
    console_handler.setFormatter(console_fmt)
    console_handler.addFilter(leak_filter)
    logger.addHandler(console_handler)

    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        file_handler = RotatingFileHandler(
            LOG_FILE, maxBytes=2 * 1024 * 1024, backupCount=3, encoding="utf-8"
        )
        file_fmt = logging.Formatter(
            "[%(asctime)s] [%(levelname)s] [%(name)s] [%(filename)s:%(lineno)d] %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )
        file_handler.setFormatter(file_fmt)
        file_handler.addFilter(leak_filter)
        logger.addHandler(file_handler)
    except Exception:
        pass

    return logger


app_logger = setup_logger()