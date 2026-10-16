# ==========================================
# 📄 File: core/backend.py
# 🌟 单一异步事实源控制中枢
# ==========================================
import asyncio
from typing import Optional
try:
    from loguru import logger
except ImportError:
    from logger import app_logger as logger

from dbus_next.aio import MessageBus
from dbus_next.constants import BusType

from core.state import IslandState
from modules.workspace import WorkspaceModule
from modules.mpris import MprisModule
from modules.brightness import BrightnessModule
from modules.audio import AudioModule
from modules.notifications import NotificationModule
from modules.system import SystemModule


class DirectIslandBackend:
    """后台 Asyncio 单事实源驱动核心"""

    def __init__(self, bridge):
        self.bridge = bridge
        self.state = IslandState()
        self.log = logger.bind(module="BACKEND_CORE")

        self.session_bus: Optional[MessageBus] = None
        self.workspace: Optional[WorkspaceModule] = None
        self.mpris: Optional[MprisModule] = None
        self.brightness: Optional[BrightnessModule] = None
        self.audio: Optional[AudioModule] = None
        self.notifications: Optional[NotificationModule] = None
        self.system: Optional[SystemModule] = None

    def broadcast(self, event_type: str = "UPDATE"):
        """内存管道：投递事件至 Qt 主线程"""
        if self.bridge:
            self.bridge.post_inproc_event(event_type, self.state)

    async def initialize(self):
        self.log.info("正在启动底层 D-Bus 与系统监听引擎...")
        try:
            self.session_bus = await MessageBus(bus_type=BusType.SESSION).connect()
            self.log.success("Session Bus 建立成功。")
        except Exception as e:
            self.log.critical(f"Session Bus 连接失败: {e}")
            return

        # 1. 虚拟桌面 (KWin / Hyprland / X11)
        self.workspace = WorkspaceModule(self.session_bus, self.state, self)
        await self.workspace.init()

        # 2. 媒体中心 (MPRIS + 频谱跳动 + 调色盘)
        self.mpris = MprisModule(self.session_bus, self.state, self)
        await self.mpris.init()

        # 3. 屏幕亮度
        self.brightness = BrightnessModule(self.session_bus, self.state, self)
        await self.brightness.init()

        # 4. 音频/麦克风
        self.audio = AudioModule(self.state, self)
        await self.audio.init()

        # 5. Teams 通话与通知
        self.notifications = NotificationModule(self.state, self)
        await self.notifications.init()

        # 6. 系统硬件、电池、网速、键盘锁
        self.system = SystemModule(self.state, self)
        await self.system.init()

        self.broadcast("FULL_SYNC")
        self.log.success("✨ 全量 6 大系统模块归一化完成，无冗余运行！")

    async def shutdown(self):
        self.log.info("正在关闭后端服务...")
        for mod in [self.system, self.audio, self.notifications, self.mpris]:
            if mod:
                try:
                    await mod.close()
                except Exception:
                    pass