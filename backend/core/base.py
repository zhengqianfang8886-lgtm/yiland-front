# ==========================================
# 📄 File: backend/core/base.py
# 🌟 统一模块抽象基类 (集成动态状态发布与自适应动作反射)
# ==========================================
import inspect
from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, Dict, Any

if TYPE_CHECKING:
    from backend.core.backend import DirectIslandBackend
    from backend.core.state import IslandState


class BaseModule(ABC):
    """Alcove Island 系统功能驱动抽象基类"""

    def __init__(self, backend: "DirectIslandBackend", state: "IslandState"):
        self.backend = backend
        self.state = state
        self._is_active = True
        # 模块标识符，默认取类名小写去掉 Module (例如 RecordingModule -> recording)
        self.name = self.__class__.__name__.lower().replace("module", "")

    @abstractmethod
    async def start(self) -> None:
        """异步生命周期启动"""
        pass

    @abstractmethod
    async def stop(self) -> None:
        """异步生命周期注销"""
        pass

    def set_active(self, active: bool) -> None:
        self._is_active = active

    def notify(self, event_name: str) -> None:
        """标准底层通知通道"""
        self.backend.broadcast(event_name)

    # 🚀【新增核心契约】：一行代码发布自身模块状态并全网广播
    def publish(self, **kwargs) -> None:
        """
        动态发布状态到单一事实源，并自动触发前端同步：
        例如: self.publish(active=True, app="OBS Studio")
        """
        self.state.update_module_state(self.name, **kwargs)
        self.backend.broadcast_module_update(self.name, kwargs)

    # 🚀【新增核心契约】：动作反射调度器 (供 Bridge.invoke 动态反射调用)
    async def execute_action(self, action_name: str, *args, **kwargs) -> Any:
        method = getattr(self, action_name, None)
        if not method or not callable(method):
            raise AttributeError(f"模块 [{self.name}] 未实现动作方法: {action_name}")

        if inspect.iscoroutinefunction(method):
            return await method(*args, **kwargs)
        else:
            return method(*args, **kwargs)