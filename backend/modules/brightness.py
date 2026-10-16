# ==========================================
# 📄 File: backend/modules/brightness.py
# 🌟 原生 D-Bus 亮度驱动（零子进程）
# ==========================================
from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class BrightnessModule(BaseModule):
    """纯 D-Bus 屏幕亮度交互模块，彻底摒弃 brightnessctl 命令行调用"""

    def __init__(self, backend, state: IslandState, bus: MessageBus):
        super().__init__(backend, state)
        self.bus = bus
        self._max_brightness = 100
        self.service = "org.kde.Solid.PowerManagement"
        self.path = "/org/kde/Solid/PowerManagement/Actions/BrightnessControl"
        self.iface = "org.kde.Solid.PowerManagement.Actions.BrightnessControl"

    async def start(self) -> None:
        if not self.bus:
            return
        try:
            # 1. 尝试获取最大亮度
            max_r = await self.bus.call(
                Message(destination=self.service, path=self.path, interface=self.iface, member="brightnessMax")
            )
            if max_r.message_type != MessageType.ERROR and max_r.body:
                self._max_brightness = max_r.body[0]

            # 2. 读取初始亮度
            cur_r = await self.bus.call(
                Message(destination=self.service, path=self.path, interface=self.iface, member="brightness")
            )
            if cur_r.message_type != MessageType.ERROR and cur_r.body:
                self.state.brightness = int(round((cur_r.body[0] / float(self._max_brightness)) * 100))

            # 3. 订阅硬件变更信号
            rule = f"type='signal',interface='{self.iface}',member='brightnessChanged'"
            def on_changed(msg: Message):
                if msg.interface == self.iface and msg.member == "brightnessChanged":
                    val = msg.body[0]
                    self.state.brightness = int(round((val / float(self._max_brightness)) * 100))
                    self.notify("BRIGHTNESS_UPDATE")

            await self.bus.call(
                Message(
                    destination="org.freedesktop.DBus",
                    path="/org/freedesktop/DBus",
                    interface="org.freedesktop.DBus",
                    member="AddMatch",
                    signature="s",
                    body=[rule]
                )
            )
            self.bus.add_message_handler(on_changed)
            app_logger.info(f"原生 KDE Solid 亮度服务接入成功 | 当前亮度: {self.state.brightness}%")
        except Exception as e:
            app_logger.warning(f"亮度 D-Bus 接口挂载失败: {e}")

    async def stop(self) -> None:
        pass

    async def set_delta(self, delta_percent: int) -> None:
        new_val = max(5, min(100, self.state.brightness + delta_percent))
        await self.set_brightness(new_val)

    async def set_brightness(self, target_percent: int) -> None:
        target = max(5, min(100, int(target_percent)))
        self.state.brightness = target
        self.notify("BRIGHTNESS_UPDATE")

        if self.bus:
            raw_val = int((target / 100.0) * self._max_brightness)
            try:
                await self.bus.call(
                    Message(
                        destination=self.service,
                        path=self.path,
                        interface=self.iface,
                        member="setBrightness",
                        signature="i",
                        body=[raw_val]
                    )
                )
            except Exception:
                pass