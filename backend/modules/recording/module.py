# ==========================================
# 📄 File: backend/modules/recording/module.py
# 🌟 原生录制与 OBS 驱动中枢 (多轨仲裁·原子状态下发版)
# ==========================================
import asyncio
from typing import Optional, List, Dict, Any
from dbus_next.aio import MessageBus
from dbus_next import Message

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
        self._last_arbitration_sig: str = ""

    async def start(self) -> None:
        self._running = True
        self._loop = asyncio.get_running_loop()
        self.audio_monitor.start()

        if self.bus:
            await self._setup_listeners()
            await self.sni_client.discover()

        await self._sync_state_internal("Init")
        app_logger.info("✅ 原生录制与 OBS 驱动就绪 (已装载三位一体自愈判定体系)")

    async def stop(self) -> None:
        self._running = False
        self.audio_monitor.stop()
        if self._debounce_task and not self._debounce_task.done():
            self._debounce_task.cancel()

    def _on_audio_streams_callback(self, streams: List[Dict[str, Any]]):
        self._active_streams = streams
        self._schedule_debounced("AudioStreamsChanged")

    def _schedule_debounced(self, trigger_source: str = "Unknown"):
        if not self._running or not self._loop or not self._loop.is_running():
            return
        self._loop.call_soon_threadsafe(self._do_schedule, trigger_source)

    def _do_schedule(self, trigger_source: str):
        if self._debounce_task and not self._debounce_task.done():
            self._debounce_task.cancel()
        self._debounce_task = self._loop.create_task(self._debounced_sync(trigger_source))

    async def _debounced_sync(self, trigger_source: str):
        try:
            await asyncio.sleep(0.015)
            await self._sync_state_internal(trigger_source)
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
            if msg.member in ("StatusNotifierItemRegistered", "StatusNotifierItemUnregistered"):
                async def _on_reg_change():
                    if msg.member == "StatusNotifierItemUnregistered" and msg.body:
                        unreg_str = str(msg.body[0])
                        if (self.sni_client.sni_dest and self.sni_client.sni_dest in unreg_str) or \
                           (self.sni_client.sni_unique_owner and self.sni_client.sni_unique_owner in unreg_str):
                            self.sni_client.reset(f"收到 StatusNotifierItemUnregistered 信号 ({unreg_str})")

                    await self.sni_client.discover()
                    self._schedule_debounced("DBus_SNI_Watcher_Change")

                self._loop.create_task(_on_reg_change())

            elif msg.member in ("NewIcon", "NewStatus"):
                self._schedule_debounced("DBus_SNI_Icon_Or_Status")

            elif msg.member == "NameOwnerChanged" and msg.body:
                name = str(msg.body[0])
                old_owner = str(msg.body[1])
                new_owner = str(msg.body[2])

                is_bound_dest = (self.sni_client.sni_dest and name == self.sni_client.sni_dest)
                is_bound_owner = (self.sni_client.sni_unique_owner and name == self.sni_client.sni_unique_owner)
                is_named_obs = any(k in name.lower() for k in ("obs", "obsproject"))

                if is_bound_dest or is_bound_owner or is_named_obs:
                    if not new_owner:
                        self.sni_client.reset(f"收到 NameOwnerChanged: {name} 失去持有人 (退出/崩溃)")
                    self._schedule_debounced("DBus_NameOwnerChanged")

        self.bus.add_message_handler(on_dbus_signal)

    async def _sync_state_internal(self, trigger_source: str = "Debounced"):
        # 1. 物理主动核验 SNI 存活状态
        await self.sni_client.verify_liveness()

        # 2. 梳理音频流
        seen = set()
        parsed_items = []
        for out in self._active_streams:
            key = f"{out.get('is_obs')}_{out.get('type')}"
            if key in seen:
                continue
            seen.add(key)
            parsed_items.append(out)

        obs_in_streams = any(it.get("is_obs", False) for it in parsed_items)
        obs_is_present = obs_in_streams or self.sni_client.is_registered

        # 3. 如果只是后台静默托盘（没有采集音频），追加占位项
        if self.sni_client.is_registered and not obs_in_streams:
            parsed_items.append({
                "id": 9999,
                "title": "系统后台驻留",
                "subtitle": "OBS Studio",
                "type": "tray",
                "icon": "✇",
                "is_obs": True
            })

        is_active = len(parsed_items) > 0
        obs_icon_url = ""

        # 🚀【原子状态同步】：只要 OBS 确认在线立即下发图标路径，若不在线立即置空，杜绝残留
        if obs_is_present:
            provider = getattr(self.backend, "tray_image_provider", None)
            pixmaps = await self.sni_client.fetch_pixmaps()
            if provider and pixmaps:
                if provider.update_from_sni_pixmaps("obs", pixmaps) or not self.state.recording_icon_url:
                    self._icon_rev += 1
            obs_icon_url = f"image://tray/obs?r={self._icon_rev}"
        else:
            obs_icon_url = ""

        sig = f"active:{is_active}|stream_obs:{obs_in_streams}|sni_reg:{self.sni_client.is_registered}|items:{len(parsed_items)}"
        if sig != self._last_arbitration_sig:
            self._last_arbitration_sig = sig
            app_logger.info(
                f"📊 [REC-STATE-ARBITRATION] 触发源: [{trigger_source}] -> "
                f"最终呈现: {'[活跃]' if is_active else '[消失]'} | "
                f"音频流判活: {obs_in_streams} (流总数: {len(self._active_streams)}) | "
                f"SNI托盘判活: {self.sni_client.is_registered} (Dest: {self.sni_client.sni_dest}, PID: {self.sni_client.sni_pid})"
            )

        # 4. 原子落盘广播
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
        self._schedule_debounced("MenuAction")