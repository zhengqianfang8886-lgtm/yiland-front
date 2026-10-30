# ==========================================
# 📄 File: backend/modules/recording/module.py
# 🌟 原生录制与 OBS 驱动中枢 (精准生命周期即时销毁版)
# ==========================================
import asyncio
from typing import Optional, List, Dict, Any
from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState
from backend.core.sni_base import BaseSniClient
from backend.modules.recording.monitor import AudioCaptureMonitor


class RecordingModule(BaseModule):
    def __init__(self, backend, state: IslandState, bus: Optional[MessageBus] = None):
        super().__init__(backend, state)
        self.bus = bus
        self._running = False
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._debounce_task: Optional[asyncio.Task] = None

        self.sni_client = BaseSniClient(self.bus, ["obs", "obsproject"])
        self.audio_monitor = AudioCaptureMonitor(self._on_audio_streams_callback)

        self._active_streams: List[Dict[str, Any]] = []
        self._icon_rev: int = 0

    async def start(self) -> None:
        self._running = True
        self._loop = asyncio.get_running_loop()
        self.audio_monitor.start()

        if self.bus:
            await self._setup_listeners()
            await self.sni_client.discover()

        await self._sync_state_internal()
        app_logger.info("✅ 原生录制与 OBS 托盘驱动已就绪 (支持退出即时消融)")

    async def stop(self) -> None:
        self._running = False
        self.audio_monitor.stop()
        if self._debounce_task and not self._debounce_task.done():
            self._debounce_task.cancel()

    def _on_audio_streams_callback(self, streams: List[Dict[str, Any]]):
        self._active_streams = streams
        self._schedule_debounced()

    def _schedule_debounced(self):
        if not self._running or not self._loop or not self._loop.is_running():
            return
        self._loop.call_soon_threadsafe(self._do_schedule)

    def _do_schedule(self):
        if self._debounce_task and not self._debounce_task.done():
            self._debounce_task.cancel()
        self._debounce_task = self._loop.create_task(self._debounced_sync())

    async def _debounced_sync(self):
        try:
            await asyncio.sleep(0.015)
            await self._sync_state_internal()
        except asyncio.CancelledError:
            pass

    async def _setup_listeners(self):
        rules = [
            "type='signal',interface='org.kde.StatusNotifierWatcher',member='StatusNotifierItemRegistered'",
            "type='signal',interface='org.kde.StatusNotifierWatcher',member='StatusNotifierItemUnregistered'",
            "type='signal',interface='org.kde.StatusNotifierItem',member='NewIcon'",
            "type='signal',interface='org.kde.StatusNotifierItem',member='NewStatus'",
            "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'"
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
            # 1. SNI 项注册或注销
            if msg.member in ("StatusNotifierItemRegistered", "StatusNotifierItemUnregistered"):
                async def _on_reg_change():
                    # 如果注销的正好是我们的对象
                    if msg.member == "StatusNotifierItemUnregistered" and msg.body:
                        unreg_str = str(msg.body[0])
                        if self.sni_client.sni_dest and self.sni_client.sni_dest in unreg_str:
                            self.sni_client.reset()

                    await self.sni_client.discover()
                    self._schedule_debounced()

                self._loop.create_task(_on_reg_change())

            # 2. 图标变更
            elif msg.member in ("NewIcon", "NewStatus"):
                self._schedule_debounced()

            # 3. 🚀【核心修复 2】：精确追踪 OBS 匿名代号进程退出
            elif msg.member == "NameOwnerChanged" and msg.body:
                name = str(msg.body[0])
                new_owner = str(msg.body[2])

                is_bound_target = bool(self.sni_client.sni_dest and name == self.sni_client.sni_dest)
                is_named_obs = any(k in name.lower() for k in ("obs", "obsproject"))

                if is_bound_target or is_named_obs:
                    if not new_owner:
                        # 进程彻底消亡，瞬间物理断开
                        self.sni_client.reset()
                    self._schedule_debounced()

        self.bus.add_message_handler(on_dbus_signal)

    async def _sync_state_internal(self):
        # 🚀【核心修复 3】：主动发起探针，彻底确认目标 D-Bus 服务是否真的活着
        if self.sni_client.sni_dest and self.bus:
            try:
                r = await self.bus.call(
                    Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                            interface="org.freedesktop.DBus", member="NameHasOwner",
                            signature="s", body=[self.sni_client.sni_dest])
                )
                if r.message_type != MessageType.ERROR and r.body:
                    if not bool(r.body[0]):
                        self.sni_client.reset()
            except Exception:
                self.sni_client.reset()

        # 整理音频采音流
        seen = set()
        parsed_items = []
        for out in self._active_streams:
            key = f"{out['is_obs']}_{out['type']}"
            if key in seen:
                continue
            seen.add(key)
            parsed_items.append(out)

        obs_in_streams = any(it.get("is_obs", False) for it in parsed_items)
        obs_is_present = obs_in_streams or self.sni_client.is_registered

        if self.sni_client.is_registered and not obs_in_streams:
            parsed_items.append({
                "id": 9999, "title": "系统后台驻留", "subtitle": "OBS Studio",
                "type": "tray", "icon": "✇", "is_obs": True
            })

        is_active = len(parsed_items) > 0
        obs_icon_url = ""

        if obs_is_present:
            provider = getattr(self.backend, "tray_image_provider", None)
            pixmaps = await self.sni_client.fetch_pixmaps()
            if provider and pixmaps:
                if provider.update_from_sni_pixmaps("obs", pixmaps) or not self.state.recording_icon_url:
                    self._icon_rev += 1
            obs_icon_url = f"image://tray/obs?r={self._icon_rev}"

        # 🚀【核心修复 4】：OBS 退出后，原子状态全部归零
        self.state.batch_update(
            recording_active=is_active,
            recording_items=parsed_items,
            recording_icon_url=obs_icon_url
        )
        self.notify("RECORDING_UPDATE")

    async def fetch_menu_async(self) -> List[Dict[str, Any]]:
        menu = await self.sni_client.fetch_menu_tree()
        if not menu:
            menu = [{"id": 101, "label": "唤醒 OBS Studio 窗口", "isSeparator": False, "isActive": False, "enabled": True}]
        self.state.recording_menu_items = menu
        self.notify("RECORDING_UPDATE")
        return menu

    async def focus_window(self):
        if hasattr(self.backend.bridge, "wm") and hasattr(self.backend.bridge.wm, "platform"):
            success = self.backend.bridge.wm.platform.focus_application_window("com.obsproject.Studio", "OBS")
            if not success:
                self.backend.bridge.wm.platform.focus_application_window("obs", "OBS")

    async def activate_menu_item(self, item_id: int):
        if item_id == 101:
            await self.focus_window()
            return
        await self.sni_client.activate_menu_item(item_id)
        self._schedule_debounced()