# ==========================================
# 📄 File: core/backend.py
# 🌟 极简单进程挂载中枢（仅保留核心 5 模块：桌面/MPRIS/亮度/音频/Teams）
# ==========================================
import sys
import asyncio
from typing import Optional
try:
    from loguru import logger
except ImportError:
    from logger import app_logger as logger

from dbus_next.aio import MessageBus
from dbus_next.constants import BusType

from core.state import IslandState
from modules.mpris import MprisModule
from modules.brightness import BrightnessModule
from modules.audio import AudioModule
from modules.notifications import NotificationModule
from modules.workspace import WorkspaceModule


class DirectIslandBackend:
    """运行在后台 Asyncio 线程的直通中枢，直接与 Qt Bridge 内存直连"""

    def __init__(self, bridge):
        self.bridge = bridge
        self.state = IslandState()
        self.log = logger.bind(module="INPROC_BACKEND")

        self.session_bus: Optional[MessageBus] = None
        self.workspace: Optional[WorkspaceModule] = None
        self.mpris: Optional[MprisModule] = None
        self.brightness: Optional[BrightnessModule] = None
        self.audio: Optional[AudioModule] = None
        self.notifications: Optional[NotificationModule] = None

    def broadcast(self, event_type: str = "UPDATE"):
        """内存直通调度：直接通过 Bridge 信号将状态推向 Qt 主线程"""
        if self.bridge:
            self.bridge.post_inproc_event(event_type, self.state)

    async def initialize(self):
        self.log.info("正在建立 D-Bus 进程内异步连接...")
        try:
            self.session_bus = await MessageBus(bus_type=BusType.SESSION).connect()
            self.log.success("Session Bus 连接成功。")
        except Exception as e:
            self.log.critical(f"Session Bus 连接失败: {e}")
            return

        # 1. 虚拟桌面模块 (KWin / Hyprland / X11)
        self.workspace = WorkspaceModule(self.session_bus, self.state, self)
        await self.workspace.init()

        # 2. 原生 MPRIS 媒体模块 (播放/切歌/进度/置顶)
        self.mpris = MprisModule(self.session_bus, self.state, self)
        await self.mpris.init()

        # 3. 屏幕亮度模块 (KDE Solid / brightnessctl)
        self.brightness = BrightnessModule(self.session_bus, self.state, self)
        await self.brightness.init()

        # 4. 音频模块 (WirePlumber / wpctl 原生)
        self.audio = AudioModule(self.state, self)
        await self.audio.init()

        # 5. Teams 通知与通话嗅探模块
        self.notifications = NotificationModule(self.state, self)
        await self.notifications.init()

        # 首次状态全量同步
        self.broadcast("FULL_SYNC")
        self.log.success("✨ 进程内核心 5 模块已就绪，内存直通管道已建立！")

    async def shutdown(self):
        self.log.info("正在释放后台资源...")
        if self.audio:
            await self.audio.close()
        if self.notifications:
            await self.notifications.close()
        if self.mpris:
            await self.mpris.close()