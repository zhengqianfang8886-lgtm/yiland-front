# ==========================================
# 📄 File: backend/modules/workspace.py
# 🌟 原生虚拟桌面监听与切换 (极速 30ms 物理拔除时序版)
# ==========================================
import os
import json
import asyncio
from typing import Dict, Any, Optional

from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType, Variant

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class WorkspaceModule(BaseModule):
    def __init__(self, backend, state: IslandState, bus: MessageBus):
        super().__init__(backend, state)
        self.bus = bus
        self.engine = "none"
        self._desktop_map: Dict[str, Dict[str, Any]] = {}

    def _unwrap_variant(self, variant: Any) -> Any:
        if hasattr(variant, 'value'): return self._unwrap_variant(variant.value)
        if isinstance(variant, list): return [self._unwrap_variant(item) for item in variant]
        if isinstance(variant, dict): return {k: self._unwrap_variant(v) for k, v in variant.items()}
        return variant

    async def start(self) -> None:
        if await self._try_init_kwin():
            self.engine = "kwin"
            app_logger.info(f"虚拟桌面后端: KDE KWin (当前: [{self.state.workspace_index}] {self.state.workspace_name}, 总数: {self.state.workspace_total})")
            return

        if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
            self.engine = "hyprland"
            app_logger.info("虚拟桌面后端: Hyprland IPC Socket")
            await self._sync_hyprland_workspaces()
            asyncio.create_task(self._listen_hyprland())
            return

        if os.environ.get("DISPLAY") and not os.environ.get("WAYLAND_DISPLAY"):
            self.engine = "x11"
            app_logger.info("虚拟桌面后端: X11 EWMH")
            asyncio.create_task(self._listen_x11())
            return

        app_logger.warning("未检测到兼容的虚拟桌面合成器。")

    async def stop(self) -> None:
        pass

    async def _try_init_kwin(self) -> bool:
        if not self.bus:
            return False
        try:
            reply = await self.bus.call(
                Message(
                    destination="org.kde.KWin",
                    path="/VirtualDesktopManager",
                    interface="org.freedesktop.DBus.Properties",
                    member="Get",
                    signature="ss",
                    body=["org.kde.KWin.VirtualDesktopManager", "current"]
                )
            )
            if reply.message_type == MessageType.ERROR:
                return False

            await self._sync_kwin_desktops()
            await self._setup_kwin_listeners()
            return True
        except Exception:
            return False

    async def _sync_kwin_desktops(self):
        try:
            reply = await self.bus.call(
                Message(
                    destination="org.kde.KWin",
                    path="/VirtualDesktopManager",
                    interface="org.freedesktop.DBus.Properties",
                    member="Get",
                    signature="ss",
                    body=["org.kde.KWin.VirtualDesktopManager", "desktops"]
                )
            )
            raw_desktops = self._unwrap_variant(reply.body[0])

            cur_reply = await self.bus.call(
                Message(
                    destination="org.kde.KWin",
                    path="/VirtualDesktopManager",
                    interface="org.freedesktop.DBus.Properties",
                    member="Get",
                    signature="ss",
                    body=["org.kde.KWin.VirtualDesktopManager", "current"]
                )
            )
            cur_id = str(self._unwrap_variant(cur_reply.body[0]))

            self.state.workspace_total = len(raw_desktops)
            workspaces_list = []
            self._desktop_map.clear()

            for idx, entry in enumerate(raw_desktops, start=1):
                d_id = ""
                name = f"Desktop {idx}"
                pos = idx

                if isinstance(entry, (list, tuple)):
                    pos = int(entry[0]) if len(entry) > 0 else idx
                    d_id = str(entry[1]) if len(entry) > 1 else str(entry[0])
                    if len(entry) > 2 and str(entry[2]).strip():
                        name = str(entry[2])
                elif isinstance(entry, dict):
                    d_id = str(entry.get("id", ""))
                    name = str(entry.get("name", name))
                    pos = int(entry.get("position", idx))
                else:
                    d_id = str(entry)

                if name == f"Desktop {idx}":
                    try:
                        name_reply = await self.bus.call(
                            Message(
                                destination="org.kde.KWin",
                                path=f"/VirtualDesktopManager/Desktops/{d_id}",
                                interface="org.freedesktop.DBus.Properties",
                                member="Get",
                                signature="ss",
                                body=["org.kde.KWin.VirtualDesktop", "name"]
                            )
                        )
                        if name_reply.message_type != MessageType.ERROR:
                            name = str(self._unwrap_variant(name_reply.body[0]))
                    except Exception:
                        pass

                info = {"id": d_id, "name": name, "index": pos}
                self._desktop_map[d_id] = info
                workspaces_list.append({
                    "id": d_id,
                    "index": pos,
                    "name": name,
                    "active": (d_id == cur_id)
                })

            self.state.workspaces = sorted(workspaces_list, key=lambda x: x["index"])
            cur_info = self._desktop_map.get(cur_id)
            if cur_info:
                self.state.workspace_index = cur_info["index"]
                self.state.workspace_name = cur_info["name"]

        except Exception as e:
            app_logger.error(f"同步 KWin 虚拟桌面异常: {e}")

    async def _setup_kwin_listeners(self):
        rules = [
            "type='signal',interface='org.kde.KWin.VirtualDesktopManager',member='currentChanged',path='/VirtualDesktopManager'",
            "type='signal',interface='org.kde.KWin.VirtualDesktopManager',member='desktopCreated',path='/VirtualDesktopManager'",
            "type='signal',interface='org.kde.KWin.VirtualDesktopManager',member='desktopRemoved',path='/VirtualDesktopManager'",
            "type='signal',interface='org.kde.KWin.VirtualDesktopManager',member='countChanged',path='/VirtualDesktopManager'",
            "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/VirtualDesktopManager'",
            "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/Effects'"
        ]

        def on_dbus_signal(msg: Message):
            if msg.path == "/Effects" and msg.member == "PropertiesChanged":
                async def check_effect_status():
                    is_active = await self._check_if_grid_active()
                    if self.state.is_desktop_grid_active != is_active:
                        self.state.is_desktop_grid_active = is_active
                        self.notify("GRID_STATE_CHANGED")
                asyncio.create_task(check_effect_status())
                return

            if msg.member in ("desktopCreated", "desktopRemoved", "countChanged") or (
                msg.member == "PropertiesChanged" and ("desktops" in str(msg.body) or "count" in str(msg.body))
            ):
                async def handle_topology_change():
                    await asyncio.sleep(0.05)
                    await self._sync_kwin_desktops()
                    self.notify("WORKSPACE_CHANGED")
                asyncio.create_task(handle_topology_change())
                return

            if msg.member == "currentChanged":
                raw_arg = self._unwrap_variant(msg.body[0])
                new_id = str(raw_arg)

                async def handle_current_change():
                    if new_id not in self._desktop_map:
                        await self._sync_kwin_desktops()

                    cur_info = self._desktop_map.get(new_id)
                    if cur_info:
                        self.state.workspace_index = cur_info["index"]
                        self.state.workspace_name = cur_info["name"]
                        for w in self.state.workspaces:
                            w["active"] = (w["id"] == new_id)
                        self.notify("WORKSPACE_CHANGED")

                    if self.state.is_desktop_grid_active:
                        self.state.is_desktop_grid_active = False
                        self.notify("GRID_STATE_CHANGED")

                asyncio.create_task(handle_current_change())

        for rule in rules:
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
        self.bus.add_message_handler(on_dbus_signal)

    def _resolve_target_id(self, target: Any) -> Optional[str]:
        if target is None:
            return None
        target_str = str(target).strip()

        if target_str in self._desktop_map:
            return target_str

        if target in (0, "0"):
            sorted_desktops = sorted(self.state.workspaces, key=lambda x: x.get("index", 0))
            if sorted_desktops:
                return sorted_desktops[0].get("id")

        for d_id, info in self._desktop_map.items():
            if str(info.get("name", "")).lower() == target_str.lower():
                return d_id

        if target_str.isdigit():
            idx = int(target_str)
            for d_id, info in self._desktop_map.items():
                if info.get("index") == idx:
                    return d_id

        return None

    async def switch_workspace(self, target: Any) -> bool:
        if self.engine == "kwin":
            sorted_desktops = sorted(self.state.workspaces, key=lambda x: x.get("index", 0))
            sorted_ids = [d.get("id") for d in sorted_desktops if d.get("id")]

            if target in ("next", "prev"):
                if not sorted_ids:
                    return False
                
                cur_id = None
                for d in sorted_desktops:
                    if d.get("active"):
                        cur_id = d.get("id")
                        break
                
                cur_idx = sorted_ids.index(cur_id) if cur_id in sorted_ids else 0
                count = len(sorted_ids)
                next_idx = (cur_idx + 1) % count if target == "next" else (cur_idx - 1 + count) % count
                target_id = sorted_ids[next_idx]
            else:
                target_id = self._resolve_target_id(target)

            if not target_id:
                return False

            try:
                reply = await self.bus.call(
                    Message(
                        destination="org.kde.KWin",
                        path="/VirtualDesktopManager",
                        interface="org.freedesktop.DBus.Properties",
                        member="Set",
                        signature="ssv",
                        body=["org.kde.KWin.VirtualDesktopManager", "current", Variant("s", target_id)]
                    )
                )
                if reply.message_type != MessageType.ERROR:
                    return True
            except Exception:
                pass

            try:
                reply = await self.bus.call(
                    Message(
                        destination="org.kde.KWin",
                        path="/VirtualDesktopManager",
                        interface="org.kde.KWin.VirtualDesktopManager",
                        member="setCurrent",
                        signature="s",
                        body=[target_id]
                    )
                )
                return (reply.message_type != MessageType.ERROR)
            except Exception:
                pass
            return False

        elif self.engine == "hyprland":
            cmd = ["hyprctl", "dispatch", "workspace", "e+1" if target == "next" else ("e-1" if target == "prev" else str(target))]
            proc = await asyncio.create_subprocess_exec(*cmd)
            await proc.communicate()
            await self._sync_hyprland_workspaces()
            return proc.returncode == 0

        return False

    async def _check_if_grid_active(self) -> bool:
        if not self.bus:
            return False
        try:
            reply = await self.bus.call(
                Message(
                    destination="org.kde.KWin",
                    path="/Effects",
                    interface="org.freedesktop.DBus.Properties",
                    member="Get",
                    signature="ss",
                    body=["org.kde.kwin.Effects", "activeEffects"]
                )
            )
            if reply.message_type != MessageType.ERROR and reply.body:
                active_list = self._unwrap_variant(reply.body[0])
                if isinstance(active_list, (list, tuple)):
                    return any(name in active_list for name in ("desktopgrid", "overview", "presentwindows"))
        except Exception:
            pass
        return False

    async def _grid_watchdog_loop(self):
        while self.state.is_desktop_grid_active:
            await asyncio.sleep(0.3)
            is_active = await self._check_if_grid_active()
            if not is_active:
                self.state.is_desktop_grid_active = False
                self.notify("GRID_STATE_CHANGED")
                break

    async def toggle_desktop_grid(self) -> bool:
        """🚀 时序隐形触发核心：极速 30ms 物理拔除后呼出平铺网格"""
        if not self.bus:
            return False

        if not self.state.is_desktop_grid_active:
            self.state.is_desktop_grid_active = True
            self.notify("GRID_STATE_CHANGED")
            # 🌟 缩短至 30ms 极速缓冲，提升触发手感
            await asyncio.sleep(0.03)

        success = False
        try:
            reply = await self.bus.call(
                Message(
                    destination="org.kde.kglobalaccel",
                    path="/component/kwin",
                    interface="org.kde.kglobalaccel.Component",
                    member="invokeShortcut",
                    signature="s",
                    body=["ShowDesktopGrid"]
                )
            )
            success = (reply.message_type != MessageType.ERROR)
        except Exception:
            pass

        if not success:
            try:
                reply = await self.bus.call(
                    Message(
                        destination="org.kde.kglobalaccel",
                        path="/component/kwin",
                        interface="org.kde.kglobalaccel.Component",
                        member="invokeShortcut",
                        signature="s",
                        body=["Grid View"]
                    )
                )
                success = (reply.message_type != MessageType.ERROR)
            except Exception:
                pass

        if self.state.is_desktop_grid_active:
            asyncio.create_task(self._grid_watchdog_loop())

        return success

    async def _sync_hyprland_workspaces(self):
        try:
            proc = await asyncio.create_subprocess_exec("hyprctl", "workspaces", "-j", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
            out, _ = await proc.communicate()
            ws_data = json.loads(out.decode())

            proc_active = await asyncio.create_subprocess_exec("hyprctl", "activeworkspace", "-j", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
            out_active, _ = await proc_active.communicate()
            active_data = json.loads(out_active.decode())
            active_id = active_data.get("id", 1)

            ws_list = []
            for w in ws_data:
                wid = w.get("id")
                ws_list.append({
                    "id": str(wid),
                    "index": wid,
                    "name": w.get("name", str(wid)),
                    "active": (wid == active_id)
                })

            self.state.workspaces = sorted(ws_list, key=lambda x: x["index"])
            self.state.workspace_total = len(ws_list)
            self.state.workspace_index = active_id
            self.state.workspace_name = active_data.get("name", str(active_id))
            self.notify("WORKSPACE_CHANGED")
        except Exception:
            pass

    async def _listen_hyprland(self):
        his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        sock_path = f"/tmp/hypr/{his}/.socket2.sock"
        if not os.path.exists(sock_path):
            sock_path = f"{os.environ.get('XDG_RUNTIME_DIR')}/hypr/{his}/.socket2.sock"

        while True:
            try:
                reader, _ = await asyncio.open_unix_connection(sock_path)
                while line := await reader.readline():
                    decoded = line.decode().strip()
                    if decoded.startswith("workspace>>") or decoded.startswith("createworkspace>>") or decoded.startswith("destroyworkspace>>"):
                        await self._sync_hyprland_workspaces()
            except Exception:
                await asyncio.sleep(3)

    async def _listen_x11(self):
        while True:
            try:
                proc = await asyncio.create_subprocess_exec(
                    "xprop", "-root", "-spy", "_NET_CURRENT_DESKTOP",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.DEVNULL
                )
                while line := await proc.stdout.readline():
                    text = line.decode().strip()
                    if "_NET_CURRENT_DESKTOP" in text:
                        idx = int(text.split("=")[-1].strip()) + 1
                        self.state.workspace_index = idx
                        self.state.workspace_name = f"Desktop {idx}"
                        self.notify("WORKSPACE_CHANGED")
            except Exception:
                await asyncio.sleep(3)