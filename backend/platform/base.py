# ==========================================
# 📄 File: backend/platform/base.py
# 🌟 跨显示服务与桌面环境平台抽象层契约 (PAL)
# ==========================================
from abc import ABC, abstractmethod
from typing import Callable, Optional
from PySide6.QtCore import Qt
from PySide6.QtGui import QScreen, QRegion
from PySide6.QtQuick import QQuickView


class PlatformAdapter(ABC):
    """桌面平台底层服务适配器基类"""

    @property
    @abstractmethod
    def platform_name(self) -> str:
        """返回适配器名称"""
        pass

    @abstractmethod
    def get_window_flags(self) -> Qt.WindowType:
        """获取适用于该平台合成器的窗口 Flags"""
        pass

    @abstractmethod
    def apply_window_position(
        self, view: QQuickView, screen: Optional[QScreen], 
        target_x: int, target_y: int, width: int, height: int
    ) -> None:
        """在屏幕上精确定位窗口并设置层级"""
        pass

    @abstractmethod
    def apply_input_mask(self, view: QQuickView, x: int, y: int, w: int, h: int) -> None:
        """应用鼠标点击穿透掩码"""
        pass

    @abstractmethod
    def clear_input_mask(self, view: QQuickView) -> None:
        """重置全域交互"""
        pass

    @abstractmethod
    def set_passthrough(self, view: QQuickView) -> None:
        """完全放行鼠标点击穿透"""
        pass

    @abstractmethod
    def start_clipboard_monitor(self, on_changed_callback: Callable[[str, bool, set], None]) -> None:
        """启动适合该环境的剪贴板监听"""
        pass

    @abstractmethod
    def stop_clipboard_monitor(self) -> None:
        """停止剪贴板监听"""
        pass

    @abstractmethod
    def focus_application_window(self, class_pattern: str, title_pattern: str) -> bool:
        """唤醒并聚焦指定外部应用窗口"""
        pass

    @abstractmethod
    def simulate_shortcut(self, key_combination: str) -> bool:
        """模拟触发全局按键组合"""
        pass