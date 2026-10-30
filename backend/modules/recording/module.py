# ==========================================
# 📄 File: backend/modules/recording/module.py
# 🌟 原生录制与 OBS 驱动中枢 (恢复托盘图标事件动态刷新版)
# ==========================================
import asyncio
from typing import Optional, List, Dict, Any
from dbus_next.aio import MessageBus
from dbus_next import Message

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState
from backend.modules.recording.sni import ObsSniClient
from backend.modules.recording.monitor import AudioCaptureMonitor


class RecordingModule(BaseModule):
    def __init__(self, backend, state: IslandState, bus: Optional[MessageBus] = None):
        super().__init__(backend, state)
        self.bus = bus
        self._running = False
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._debounce_task: Optional[asyncio.Task] = None

        self.sni_client = ObsSniClient(self.bus)
        self.audio_monitor = AudioCaptureMonitor(self._on_audio_streams_callback)

        self._active_streams: List[Dict[str, Any]] = []
        self._icon_rev: int = 0

    async def start(self) -> None:
        self._running = True
        self._loop = asyncio.get_running_loop()
        self.audio_monitor.start()

        if self.bus:
            await self._setup_targeted_listeners()
            await self.sni_client.discover()

        await self._sync_state_internal()
        app_logger.info("✅ 原生录制隐私指示器与 OBS 托盘就绪 (完全支持实时状态刷新)")

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
            # 15ms 黄金防抖窗口，合并瞬间风暴
            await asyncio.sleep(0.015)
            await self._sync_state_internal()
        except asyncio.CancelledError:
            pass
        except Exception as e:
            app_logger.debug(f"[RecordingModule] 同步异常: {e}")

    async def _setup_targeted_listeners(self):
        """🚀 精准绑定 D-Bus 信号，重新接纳 NewIcon 与 NewStatus"""
        rules = [
            "type='signal',interface='org.kde.StatusNotifierWatcher',member='StatusNotifierItemRegistered'",
            "type='signal',interface='org.kde.StatusNotifierWatcher',member='StatusNotifierItemUnregistered'",
            # 恢复托盘事件动态刷新
            "type='signal',interface='org.kde.StatusNotifierItem',member='NewIcon'",
            "type='signal',interface='org.kde.StatusNotifierItem',member='NewStatus'",
            "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'"
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
            # 1. 注册发现
            if msg.member in ("StatusNotifierItemRegistered", "StatusNotifierItemUnregistered"):
                async def _on_reg():
                    await self.sni_client.discover()
                    self._schedule_debounced()
                self._loop.create_task(_on_reg())
            
            # 2. 🚀 事件驱动：实时捕获 OBS 录制开始时的图标切换 (如叠加快捷小红点)
            elif msg.member in ("NewIcon", "NewStatus"):
                # 直接丢进防抖引擎，在 _sync_state_internal 中靠字节比对过滤垃圾信号
                self._schedule_debounced()
                
            # 3. 进程起落
            elif msg.member == "NameOwnerChanged" and msg.body:
                name = str(msg.body[0])
                if "obs" in name.lower() or "obsproject" in name.lower():
                    self._schedule_debounced()

        self.bus.add_message_handler(on_dbus_signal)

    async def _sync_state_internal(self):
        """核心状态裁决：仅在状态真正改变时原子落盘"""
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
                "id": 9999,
                "title": "系统后台驻留",
                "subtitle": "OBS Studio",
                "type": "tray",
                "icon": "✇",
                "is_obs": True
            })

        is_active = len(parsed_items) > 0
        obs_icon_url = ""

        # 🚀 在防抖周期内抓取最新的托盘位图
        if obs_is_present:
            icon_provider = getattr(self.backend, "image_provider_rec", None)
            pixmaps = await self.sni_client.fetch_pixmaps()
            if icon_provider and pixmaps:
                # 只有二进制像素真正发生了改变（例如多了一个红点），才会导致 rev+1，驱动 QML 重绘
                if icon_provider.update_from_sni_pixmaps(pixmaps) or not self.state.recording_icon_url:
                    self._icon_rev += 1
            obs_icon_url = f"image://recording/current?r={self._icon_rev}"

        # 原子更新单一事实源
        self.state.batch_update(
            recording_active=is_active,
            recording_items=parsed_items,
            recording_icon_url=obs_icon_url
        )
        self.notify("RECORDING_UPDATE")

    # =========================================================================
    # 动作响应
    # =========================================================================
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