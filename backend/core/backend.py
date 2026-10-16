# ==========================================
# 📄 File: backend/core/backend.py
# 🌟 单一异步控制调度总线
# ==========================================
import asyncio
from typing import Optional, List

from dbus_next.aio import MessageBus
from dbus_next.constants import BusType

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState

from backend.modules.workspace import WorkspaceModule
from backend.modules.mpris import MprisModule
from backend.modules.brightness import BrightnessModule
from backend.modules.audio import AudioModule
from backend.modules.notifications import NotificationModule
from backend.modules.system import SystemModule


class DirectIslandBackend:
    """系统级异步单一事实源控制核心"""

    def __init__(self, bridge):
        self.bridge = bridge
        self.state = IslandState()
        self.session_bus: Optional[MessageBus] = None
        self.modules: List[BaseModule] = []

        # 靶向直通引用（供 Bridge 槽函数调用硬件）
        self.workspace: Optional[WorkspaceModule] = None
        self.mpris: Optional[MprisModule] = None
        self.brightness: Optional[BrightnessModule] = None
        self.audio: Optional[AudioModule] = None
        self.notifications: Optional[NotificationModule] = None
        self.system: Optional[SystemModule] = None

    def broadcast(self, event_type: str = "UPDATE"):
        """投递系统事件快照至 Qt GUI 线程"""
        if self.bridge:
            self.bridge.post_inproc_event(event_type, self.state)

    def push_spectrum(self, s1: float, s2: float, s3: float, s4: float):
        """流体声谱高频专线（绕过大状态同步）"""
        if self.bridge:
            self.bridge.post_spectrum_event(s1, s2, s3, s4)

    async def initialize(self):
        app_logger.info("⚡ 正在启动底层 D-Bus 与驱动总线...")
        try:
            self.session_bus = await MessageBus(bus_type=BusType.SESSION).connect()
            app_logger.info("✅ D-Bus Session 管道连接成功")
        except Exception as e:
            app_logger.error(f"❌ D-Bus Session 连接失败: {e}")

        # 实例化子模块
        self.workspace = WorkspaceModule(self, self.state, self.session_bus)
        self.mpris = MprisModule(self, self.state, self.session_bus)
        self.brightness = BrightnessModule(self, self.state, self.session_bus)
        self.audio = AudioModule(self, self.state)
        self.notifications = NotificationModule(self, self.state)
        self.system = SystemModule(self, self.state)

        self.modules = [
            self.workspace,
            self.mpris,
            self.brightness,
            self.audio,
            self.notifications,
            self.system,
        ]

        # 规范化批量并行启动
        init_tasks = [mod.start() for mod in self.modules]
        results = await asyncio.gather(*init_tasks, return_exceptions=True)
        for mod, res in zip(self.modules, results):
            if isinstance(res, Exception):
                app_logger.error(f"模块 [{mod.__class__.__name__}] 启动异常: {res}")

        self.broadcast("FULL_SYNC")
        app_logger.info("✨ 所有底层硬件系统驱动全部接入完毕，处于事件驱动模式。")

    async def shutdown(self):
        app_logger.info("🛑 正在停止后端驱动引擎...")
        stop_tasks = [mod.stop() for mod in self.modules]
        await asyncio.gather(*stop_tasks, return_exceptions=True)
        if self.session_bus:
            try:
                self.session_bus.disconnect()
            except Exception:
                pass
        app_logger.info("✅ 后端服务安全卸载完成。")