# ==========================================
# 📄 File: backend/core/backend.py
# 🌟 单一异步控制调度总线 (集成线程安全只读快照派发版)
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
from backend.modules.timer import TimerModule
from backend.modules.habits import HabitModule
from backend.modules.voice import VoiceInputModule
from backend.modules.ime import ImeModule


class DirectIslandBackend:
    """系统级异步单一事实源控制核心"""

    def __init__(self, bridge, image_provider=None):
        self.bridge = bridge
        self.image_provider = image_provider
        self.state = IslandState()
        self.session_bus: Optional[MessageBus] = None
        self.modules: List[BaseModule] = []

        # 核心功能模块直通引用
        self.workspace: Optional[WorkspaceModule] = None
        self.mpris: Optional[MprisModule] = None
        self.brightness: Optional[BrightnessModule] = None
        self.audio: Optional[AudioModule] = None
        self.notifications: Optional[NotificationModule] = None
        self.system: Optional[SystemModule] = None
        self.timer: Optional[TimerModule] = None
        self.habits: Optional[HabitModule] = None
        self.voice: Optional[VoiceInputModule] = None
        self.ime: Optional[ImeModule] = None  # 👈 新增

    def broadcast(self, event_type: str = "UPDATE"):
        """🚀 线程安全增强：导出只读快照投递进 Qt 事件总线，杜绝跨线程撕裂与竞态"""
        if self.bridge:
            safe_snapshot = self.state.snapshot()
            self.bridge.post_inproc_event(event_type, safe_snapshot)

    def push_spectrum(self, s1: float, s2: float, s3: float, s4: float):
        if self.bridge:
            self.bridge.post_spectrum_event(s1, s2, s3, s4)

    def set_ui_active(self, active: bool):
        for mod in self.modules:
            try:
                mod.set_active(active)
            except Exception as e:
                app_logger.warning(f"模块 [{mod.__class__.__name__}] 切换休眠失败: {e}")

    async def initialize(self):
        app_logger.info("⚡ 正在启动底层 D-Bus 与驱动总线...")
        try:
            self.session_bus = await MessageBus(bus_type=BusType.SESSION).connect()
            app_logger.info("✅ D-Bus Session 管道连接成功")
        except Exception as e:
            app_logger.error(f"❌ D-Bus Session 连接失败: {e}")

        # 实例化驱动子模块
        self.workspace = WorkspaceModule(self, self.state, self.session_bus)
        self.mpris = MprisModule(self, self.state, self.session_bus)
        self.brightness = BrightnessModule(self, self.state, self.session_bus)
        self.audio = AudioModule(self, self.state)
        self.notifications = NotificationModule(self, self.state)
        self.system = SystemModule(self, self.state)
        self.timer = TimerModule(self, self.state)
        self.habits = HabitModule(self, self.state)
        self.voice = VoiceInputModule(self, self.state)
        self.ime = ImeModule(self, self.state, self.session_bus)  # 👈 新增

        self.modules = [
            self.workspace,
            self.mpris,
            self.brightness,
            self.audio,
            self.notifications,
            self.system,
            self.timer,
            self.habits,
            self.voice,
            self.ime,  # 👈 新增
        ]

        init_tasks = [mod.start() for mod in self.modules]
        results = await asyncio.gather(*init_tasks, return_exceptions=True)
        for mod, res in zip(self.modules, results):
            if isinstance(res, Exception):
                app_logger.error(f"模块 [{mod.__class__.__name__}] 启动异常: {res}")

        self.broadcast("FULL_SYNC")
        app_logger.info("✨ 所有原生硬件驱动、计时引擎与语音识别管道接入完毕。")

    async def shutdown(self):
        app_logger.info("🛑 正在卸载后端服务...")
        stop_tasks = [mod.stop() for mod in self.modules]
        await asyncio.gather(*stop_tasks, return_exceptions=True)
        if self.session_bus:
            try:
                self.session_bus.disconnect()
            except Exception:
                pass