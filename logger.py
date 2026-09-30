import os
import sys
import logging
from logging.handlers import RotatingFileHandler
from PySide6.QtCore import qInstallMessageHandler, QtMsgType

# 日志输出目录（规范的 Linux / macOS 用户状态目录）
LOG_DIR = os.path.expanduser("~/.local/state/alcove_island")
LOG_FILE = os.path.join(LOG_DIR, "island.log")

class ColoredFormatter(logging.Formatter):
    """带 ANSI 颜色的终端格式化器"""
    COLORS = {
        logging.DEBUG: "\033[90m",    # 灰
        logging.INFO: "\033[32m",     # 绿
        logging.WARNING: "\033[33m",  # 黄
        logging.ERROR: "\033[31m",    # 红
        logging.CRITICAL: "\033[35m", # 紫
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

    # 支持通过环境变量设置级别，例如: LOG_LEVEL=DEBUG python main.py
    env_level = os.getenv("LOG_LEVEL", "INFO").upper()
    level = getattr(logging, env_level, logging.INFO)
    logger.setLevel(level)

    # 1. 终端处理器 (彩色，高可读)
    console_handler = logging.StreamHandler(sys.stdout)
    console_fmt = ColoredFormatter(
        "[%(asctime)s] %(levelname)s [%(name)s] %(message)s",
        datefmt="%H:%M:%S"
    )
    console_handler.setFormatter(console_fmt)
    logger.addHandler(console_handler)

    # 2. 滚动文件处理器 (纯文本，单文件 2MB，保留 3 份)
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
        logger.addHandler(file_handler)
    except Exception as e:
        logger.warning(f"无法初始化持久化日志文件: {e}")

    return logger

app_logger = setup_logger()

def install_qt_log_bridge():
    """将 QML / Qt 底层的所有 warning 与 error 路由接入 Python 日志"""
    qml_logger = logging.getLogger("QML")

    def qt_message_handler(mode, context, message):
        file = context.file or "Unknown"
        line = context.line
        text = f"{message} ({file}:{line})"

        if mode == QtMsgType.QtDebugMsg:
            qml_logger.debug(text)
        elif mode == QtMsgType.QtInfoMsg:
            qml_logger.info(text)
        elif mode == QtMsgType.QtWarningMsg:
            qml_logger.warning(text)
        elif mode == QtMsgType.QtCriticalMsg:
            qml_logger.error(text)
        elif mode == QtMsgType.QtFatalMsg:
            qml_logger.critical(text)

    qInstallMessageHandler(qt_message_handler)
