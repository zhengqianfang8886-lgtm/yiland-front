# ==========================================
# 📄 File: backend/modules/ime/module.py
# 🌟 原生 Fcitx5 功能驱动中枢 (高内聚分层门面)
# ==========================================
import asyncio
from typing import Optional, List, Dict, Any

from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState

from backend.modules.ime.pixmap import ImePixmapDecoder
from backend.modules.ime.controller import FcitxController
from backend.modules.ime.menu import FcitxMenuClient, unwrap_dbus_value


class ImeModule(BaseModule):
    """Alcove Island 原生 Fcitx5 输入法模块门面"""

    def __init__(self, backend, state: IslandState, bus: Optional[MessageBus] = None):
        super().__init__(backend, state)
        self.bus = bus
        self._running = False
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._debounce_task: Optional[asyncio.Task] = None

        # 挂载专职子模块
        self.pixmap_decoder = ImePixmapDecoder()
        self.controller = FcitxController(self.bus)
        self.menu_client = FcitxMenuClient(self.bus)
        self._current_im_name = "keyboard-us"

    def set_active(self, active: bool) -> None:
        super().set_active(active)
        if active and self._running:
            self.trigger_sync()

    async def start(self) -> None:
        self._running = True
        self._loop = asyncio.get_running_loop()

        await self.menu_client.discover_sni_address()

        if self.bus:
            await self._setup_listeners()

        await self.sync_state()
        await self.fetch_menu_async()
        app_logger.info("✅ Fcitx5 架构拆分驱动已就绪")

    async def stop(self) -> None:
        self._running = False
        if self._debounce_task and not self._debounce_task.done():
            self._debounce_task.cancel()

    def trigger_sync(self) -> None:
        if not self._running or not self._loop or not self._loop.is_running():
            return
        self._loop.call_soon_threadsafe(self._schedule_debounced)

    def _schedule_debounced(self) -> None:
        if not self._running:
            return
        if self._debounce_task and not self._debounce_task.done():
            self._debounce_task.cancel()
        self._debounce_task = self._loop.create_task(self._debounced_sync())

    async def _debounced_sync(self) -> None:
        try:
            await asyncio.sleep(0.010)
            await self.sync_state()
            await self.fetch_menu_async()
        except asyncio.CancelledError:
            pass
        except Exception as e:
            app_logger.debug(f"[IME Module] 同步异常: {e}")

    async def _setup_listeners(self) -> None:
        rules = [
            "type='signal',interface='org.kde.StatusNotifierItem',member='NewIcon'",
            "type='signal',interface='org.kde.StatusNotifierItem',member='NewTitle'",
            "type='signal',interface='org.fcitx.Fcitx.Controller1',member='CurrentInputMethodChanged'",
            "type='signal',interface='com.canonical.dbusmenu',member='LayoutUpdated'",
            "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='org.fcitx.Fcitx5'"
        ]

        for rule in rules:
            try:
                await self.bus.call(
                    Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                            interface="org.freedesktop.DBus", member="AddMatch",
                            signature="s", body=[rule])
                )
            except Exception:
                pass

        def on_dbus_signal(msg: Message):
            if msg.member in ("NewIcon", "NewTitle", "CurrentInputMethodChanged", "LayoutUpdated"):
                self.trigger_sync()

        self.bus.add_message_handler(on_dbus_signal)

    async def fetch_menu_async(self) -> List[Dict[str, Any]]:
        """从 MenuClient 拉取菜单并通知前端"""
        items = await self.menu_client.fetch_menu_tree(self._current_im_name, self.state.ime_active)
        if items:
            self.state.ime_menu_items = items
            self.notify("IME_UPDATE")
        return items

    async def activate_menu_item(self, item_id: int, unique_name: str = "") -> None:
        """统一处理菜单项点击"""
        if "配置" in unique_name or item_id == -3 or unique_name == "config":
            self.controller.open_config()
            self.trigger_sync()
            return

        target_im = unique_name if unique_name in ("rime", "pinyin", "keyboard-us", "wubi") else self.menu_client.guess_im_uniquename(unique_name)
        if target_im:
            await self.controller.switch_im_native(target_im)

        # 始终下发 DBusMenu Event 确保二级配置（全半角/简繁）生效
        if item_id >= 0:
            await self.menu_client.send_menu_event(item_id)

        self.trigger_sync()

    async def toggle(self) -> None:
        """左键点击胶囊切换中英"""
        await self.controller.toggle()
        self.trigger_sync()

    async def switch_to_im(self, im_name: str) -> None:
        await self.controller.switch_im_native(im_name)
        self.trigger_sync()

    async def open_config(self) -> None:
        self.controller.open_config()

    async def sync_state(self) -> None:
        """同步 Fcitx5 状态与托盘图标"""
        if not self.bus:
            return

        # 1. 抓取状态与当前 IM
        im_state, cur_im = await self.controller.get_state_and_im()
        self._current_im_name = cur_im

        # 2. 抓取 SNI 属性与图标
        dest = self.menu_client.sni_dest or "org.fcitx.Fcitx5"
        path = self.menu_client.sni_path or "/StatusNotifierItem"

        icon_data_url = self.state.ime_icon_url
        try:
            r_props = await self.bus.call(
                Message(destination=dest, path=path,
                        interface="org.freedesktop.DBus.Properties",
                        member="GetAll", signature="s",
                        body=["org.kde.StatusNotifierItem"])
            )
            if r_props.message_type != MessageType.ERROR and r_props.body:
                raw_dict = {k: unwrap_dbus_value(v) for k, v in r_props.body[0].items()}
                pixmaps = raw_dict.get("IconPixmap", [])
                new_icon = self.pixmap_decoder.decode_best_pixmap(pixmaps)
                if new_icon:
                    icon_data_url = new_icon
        except Exception:
            pass

        is_active = (im_state == 2)
        label_fallback = "朗" if is_active else "A"

        self.state.batch_update(
            ime_active=is_active,
            ime_name=cur_im,
            ime_label=label_fallback,
            ime_icon_url=icon_data_url
        )
        self.notify("IME_UPDATE")