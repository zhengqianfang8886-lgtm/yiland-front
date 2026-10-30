# ==========================================
# 📄 File: backend/modules/ime/module.py
# 🌟 原生 Fcitx5 功能驱动中枢 (基于通用 SNI 基类架构版)
# ==========================================
import asyncio
from typing import Optional, List, Dict, Any

from dbus_next.aio import MessageBus
from dbus_next import Message

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState
from backend.core.sni_base import BaseSniClient
from backend.modules.ime.controller import FcitxController


class ImeModule(BaseModule):
    """基于 BaseSniClient 的 Fcitx5 专职驱动，保留全部中英特化"""

    def __init__(self, backend, state: IslandState, bus: Optional[MessageBus] = None):
        super().__init__(backend, state)
        self.bus = bus
        self._running = False
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._debounce_task: Optional[asyncio.Task] = None

        # 核心：使用通用 SNI 客户端替代原有的散装逻辑
        self.sni_client = BaseSniClient(self.bus, ["fcitx"], fallback_dest="org.fcitx.Fcitx5")
        self.controller = FcitxController(self.bus)
        self._current_im_name = "keyboard-us"
        self._icon_rev = 0

    async def start(self) -> None:
        self._running = True
        self._loop = asyncio.get_running_loop()

        await self.sni_client.discover()
        if self.bus:
            await self._setup_listeners()

        await self.sync_state()
        await self.fetch_menu_async()
        app_logger.info("✅ Fcitx5 输入法驱动已就绪 (已接入通用 SNI 架构)")

    async def stop(self) -> None:
        self._running = False
        if self._debounce_task and not self._debounce_task.done():
            self._debounce_task.cancel()

    def trigger_sync(self) -> None:
        if not self._running or not self._loop or not self._loop.is_running():
            return
        self._loop.call_soon_threadsafe(self._schedule_debounced)

    def _schedule_debounced(self) -> None:
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
                            interface="org.freedesktop.DBus", member="AddMatch", signature="s", body=[rule])
                )
            except Exception:
                pass

        def on_dbus_signal(msg: Message):
            if msg.member in ("NewIcon", "NewTitle", "CurrentInputMethodChanged", "LayoutUpdated"):
                self.trigger_sync()

        self.bus.add_message_handler(on_dbus_signal)

    async def sync_state(self) -> None:
        if not self.bus:
            return

        im_state, cur_im = await self.controller.get_state_and_im()
        self._current_im_name = cur_im

        icon_data_url = self.state.ime_icon_url
        pixmaps = await self.sni_client.fetch_pixmaps()

        # 统一委托通用 UniversalTrayImageProvider
        provider = getattr(self.backend, "tray_image_provider", None)
        if provider and pixmaps:
            if provider.update_from_sni_pixmaps("ime", pixmaps) or not icon_data_url:
                self._icon_rev += 1
                icon_data_url = f"image://tray/ime?r={self._icon_rev}"
        elif not pixmaps:
            icon_data_url = ""

        is_active = (im_state == 2)
        label_fallback = "朗" if is_active else "A"

        self.state.batch_update(
            ime_active=is_active,
            ime_name=cur_im,
            ime_label=label_fallback,
            ime_icon_url=icon_data_url
        )
        self.notify("IME_UPDATE")

    async def fetch_menu_async(self) -> List[Dict[str, Any]]:
        cur_lower = self._current_im_name.lower()

        def _tag_ime_item(item: dict, props: dict) -> dict:
            lbl = item["label"].lower()
            unique = ""
            if "rime" in lbl or "中州韵" in item["label"]: unique = "rime"
            elif "pinyin" in lbl or "拼音" in item["label"]: unique = "pinyin"
            elif "wubi" in lbl or "五笔" in item["label"]: unique = "wubi"
            elif "keyboard" in lbl or "英语" in item["label"] or "键盘" in item["label"]: unique = "keyboard-us"
            item["uniqueName"] = unique

            if self.state.ime_active:
                if unique and unique in cur_lower:
                    item["isActive"] = True
            else:
                if unique == "keyboard-us":
                    item["isActive"] = True
            return item

        items = await self.sni_client.fetch_menu_tree(post_process_fn=_tag_ime_item)
        if items:
            self.state.ime_menu_items = items
            self.notify("IME_UPDATE")
        return items

    async def activate_menu_item(self, item_id: int, unique_name: str = "") -> None:
        if "配置" in unique_name or item_id == -3 or unique_name == "config":
            self.controller.open_config()
            self.trigger_sync()
            return

        if unique_name:
            await self.controller.switch_im_native(unique_name)

        if item_id >= 0:
            await self.sni_client.activate_menu_item(item_id)

        self.trigger_sync()

    async def toggle(self) -> None:
        await self.controller.toggle()
        self.trigger_sync()

    async def switch_to_im(self, im_name: str) -> None:
        await self.controller.switch_im_native(im_name)
        self.trigger_sync()

    async def open_config(self) -> None:
        self.controller.open_config()