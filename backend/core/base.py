# ==========================================
# 📄 File: backend/core/base.py
# 🌟 模块统一生命周期契约基类
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

    @abstractmethod
    async def start(self) -> None:
        """异步生命周期启动（建立连接、挂载监听）"""
        pass

    @abstractmethod
    async def stop(self) -> None:
        """异步生命周期注销（取消定时器、解除钩子、断开连接）"""
        pass

    def notify(self, event_name: str) -> None:
        """标准事件投递中枢通道"""
        self.backend.broadcast(event_name)