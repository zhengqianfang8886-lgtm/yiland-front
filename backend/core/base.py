# ==========================================
# 📄 File: backend/core/base.py
# 🌟 模块统一生命周期契约基类 (扩展统一打断契约)
# ==========================================
from abc import ABC, abstractmethod
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from backend.core.backend import DirectIslandBackend
    from backend.core.state import IslandState


class BaseModule(ABC):
    """Alcove Island 系统硬件与 D-Bus 功能驱动抽象基类"""

    def __init__(self, backend: "DirectIslandBackend", state: "IslandState"):
        self.backend = backend
        self.state = state
        self._is_active = True

    @abstractmethod
    async def start(self) -> None:
        """异步生命周期启动（建立连接、挂载监听）"""
        pass

    @abstractmethod
    async def stop(self) -> None:
        """异步生命周期注销（取消定时器、解除钩子、断开连接）"""
        pass

    def set_active(self, active: bool) -> None:
        """休眠断路器：用于控制模块在灵动岛深潜/隐藏时进入低功耗待机"""
        self._is_active = active

    def notify(self, event_name: str) -> None:
        """标准事件投递中枢通道"""
        self.backend.broadcast(event_name)

    def trigger_overlay(self, key: str, title: str, subtitle: str = "",
                        icon: str = "🔔", duration_ms: int = 3500, avatar: str = "",
                        val: int = 0, priority: int = 40) -> None:
        """
        🚀【架构契约】：任何业务驱动想要弹出打断，直接调用此契约方法。
        天然线程安全、原子写入状态、自动走系统总线跨线程派发。
        """
        self.state.set_overlay(key, title, subtitle, icon, duration_ms, avatar, val, priority)
        self.notify("OVERLAY_CHANGED")