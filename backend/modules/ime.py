# ==========================================
# 📄 File: backend/modules/ime.py
# 🌟 原生 Fcitx5 通道 (D-Bus 原生 Toggle 与 DBusMenu 规范事件回传版)
# ==========================================
import os
import sys
import time
import shutil
import hashlib
import asyncio
import subprocess
from typing import Optional, List, Dict, Any, Tuple

from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType, Variant

from PySide6.QtGui import QImage
from PySide6.QtCore import QBuffer, QIODevice

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class ImeModule(BaseModule):
    def __init__(self, backend, state: IslandState, bus: Optional[MessageBus] = None):
        super().__init__(backend, state)
        self.bus = bus
        self._running = False
        self._loop: Optional[asyncio.AbstractEventLoop] = None

        self._fcitx_sni_dest: Optional[str] = None
        self._fcitx_sni_path: str = "/StatusNotifierItem"
        self._fcitx_menu_path: str = "/MenuBar"

        self._last_pixmap_hash = ""
        self._is_probing = False
        self._debounce_task: Optional[asyncio.Task] = None

    def set_active(self, active: bool) -> None:
        super().set_active(active)
        if active and self._running:
            self.trigger_sync()

    async def start(self) -> None:
        self._running = True
        self._loop = asyncio.get_running_loop()

        await self._discover_fcitx_sni_address()

        if self.bus:
            await self._setup_listeners()

        await self.sync_state()
        await self.fetch_menu_async()
        app_logger.info("✅ Fcitx5 原生 D-Bus 事件总线与菜单模块就绪")

    async def stop(self) -> None:
        self._running = False
        if self._debounce_task and not self._debounce_task.done():
            self._debounce_task.cancel()

    def trigger_sync(self):
        if not self._running or not self._loop or not self._loop.is_running():
            return
        self._loop.call_soon_threadsafe(self._schedule_debounced)

    def _schedule_debounced(self):
        if not self._running:
            return
        if self._debounce_task and not self._debounce_task.done():
            self._debounce_task.cancel()
        self._debounce_task = self._loop.create_task(self._debounced_sync())

    async def _debounced_sync(self):
        try:
            await asyncio.sleep(0.035)
            await self.sync_state()
            await self.fetch_menu_async()
        except asyncio.CancelledError:
            pass
        except Exception as e:
            app_logger.debug(f"[IME] 状态同步异常: {e}")

    async def _discover_fcitx_sni_address(self) -> bool:
        if not self.bus or self._is_probing:
            return False

        self._is_probing = True
        try:
            watcher_msg = Message(
                destination="org.kde.StatusNotifierWatcher",
                path="/StatusNotifierWatcher",
                interface="org.freedesktop.DBus.Properties",
                member="Get",
                signature="ss",
                body=["org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems"]
            )
            reply = await self.bus.call(watcher_msg)

            if reply.message_type != MessageType.ERROR and reply.body:
                registered_items = reply.body[0]
                if hasattr(registered_items, 'value'):
                    registered_items = registered_items.value

                for item_str in registered_items:
                    dest, obj_path = self._split_sni_item(str(item_str))
                    try:
                        id_reply = await self.bus.call(
                            Message(
                                destination=dest,
                                path=obj_path,
                                interface="org.freedesktop.DBus.Properties",
                                member="Get",
                                signature="ss",
                                body=["org.kde.StatusNotifierItem", "Id"]
                            )
                        )
                        raw_id = id_reply.body[0] if (id_reply.message_type != MessageType.ERROR and id_reply.body) else ""
                        if hasattr(raw_id, 'value'): raw_id = raw_id.value

                        if "fcitx" in str(raw_id).lower() or "fcitx" in dest.lower():
                            self._fcitx_sni_dest = dest
                            self._fcitx_sni_path = obj_path

                            menu_reply = await self.bus.call(
                                Message(
                                    destination=dest,
                                    path=obj_path,
                                    interface="org.freedesktop.DBus.Properties",
                                    member="Get",
                                    signature="ss",
                                    body=["org.kde.StatusNotifierItem", "Menu"]
                                )
                            )
                            if menu_reply.body:
                                raw_menu = menu_reply.body[0]
                                self._fcitx_menu_path = str(raw_menu.value if hasattr(raw_menu, 'value') else raw_menu)
                            return True
                    except Exception:
                        pass
        except Exception:
            pass
        finally:
            self._is_probing = False

        if not self._fcitx_sni_dest:
            self._fcitx_sni_dest = "org.fcitx.Fcitx5"
            self._fcitx_sni_path = "/StatusNotifierItem"
            self._fcitx_menu_path = "/MenuBar"
        return False

    def _split_sni_item(self, item_str: str) -> Tuple[str, str]:
        if "/" in item_str:
            parts = item_str.split("/", 1)
            return parts[0], "/" + parts[1]
        return item_str, "/StatusNotifierItem"

    async def _setup_listeners(self):
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
                    Message(
                        destination="org.freedesktop.DBus",
                        path="/org/freedesktop/DBus",
                        interface="org.freedesktop.DBus",
                        member="AddMatch",
                        signature="s",
                        body=[rule]
                    )
                )
            except Exception:
                pass

        def on_dbus_signal(msg: Message):
            if msg.member in ("NewIcon", "NewTitle", "CurrentInputMethodChanged", "LayoutUpdated"):
                self.trigger_sync()

        self.bus.add_message_handler(on_dbus_signal)

    async def fetch_menu_async(self) -> List[Dict[str, Any]]:
        if not self.bus:
            return []

        def _unwrap(v):
            return v.value if hasattr(v, 'value') else v

        menu_items: List[Dict[str, Any]] = []
        dest = self._fcitx_sni_dest or "org.fcitx.Fcitx5"
        path = self._fcitx_menu_path or "/MenuBar"

        try:
            try:
                await self.bus.call(
                    Message(destination=dest, path=path, interface="com.canonical.dbusmenu",
                            member="AboutToShow", signature="i", body=[0])
                )
            except Exception:
                pass

            reply = await self.bus.call(
                Message(
                    destination=dest,
                    path=path,
                    interface="com.canonical.dbusmenu",
                    member="GetLayout",
                    signature="iias",
                    body=[0, 2, ["label", "enabled", "visible", "type", "toggle-type", "toggle-state", "children-display"]]
                )
            )

            if reply.body and len(reply.body) >= 2:
                root_node = _unwrap(reply.body[1])
                children = root_node[2] if len(root_node) >= 3 else []

                for child in children:
                    c = _unwrap(child)
                    c_id = int(c[0])
                    raw_props = c[1]
                    raw_subchildren = c[2] if len(c) >= 3 else []
                    props = {k: _unwrap(v) for k, v in raw_props.items()}

                    label = str(props.get("label", "")).replace("_", "").strip()
                    item_type = str(props.get("type", "standard"))
                    is_sep = (item_type == "separator" or not label)
                    visible = bool(props.get("visible", True))
                    if not visible:
                        continue

                    is_active = (props.get("toggle-state", 0) == 1)
                    has_sub = (props.get("children-display", "") == "submenu")
                    enabled = bool(props.get("enabled", True))

                    sub_items: List[Dict[str, Any]] = []
                    if raw_subchildren:
                        for sub in raw_subchildren:
                            s = _unwrap(sub)
                            s_id = int(s[0])
                            s_props = {k: _unwrap(v) for k, v in s[1].items()}
                            s_label = str(s_props.get("label", "")).replace("_", "").strip()
                            s_type = str(s_props.get("type", "standard"))
                            s_is_sep = (s_type == "separator" or not s_label)
                            if not s_props.get("visible", True):
                                continue

                            sub_items.append({
                                "id": s_id,
                                "label": s_label,
                                "isSeparator": s_is_sep,
                                "isActive": (s_props.get("toggle-state", 0) == 1),
                                "enabled": bool(s_props.get("enabled", True)),
                                "hasSubmenu": False,
                                "children": []
                            })

                    if (has_sub or props.get("children-display") == "submenu") and not sub_items:
                        has_sub = True
                        try:
                            await self.bus.call(
                                Message(destination=dest, path=path, interface="com.canonical.dbusmenu",
                                        member="AboutToShow", signature="i", body=[c_id])
                            )
                            sub_rep = await self.bus.call(
                                Message(
                                    destination=dest, path=path, interface="com.canonical.dbusmenu",
                                    member="GetLayout", signature="iias",
                                    body=[c_id, 1, ["label", "enabled", "visible", "type", "toggle-type", "toggle-state"]]
                                )
                            )
                            if sub_rep.body and len(sub_rep.body) >= 2:
                                s_root = _unwrap(sub_rep.body[1])
                                s_kids = s_root[2] if len(s_root) >= 3 else []
                                for sk in s_kids:
                                    s_item = _unwrap(sk)
                                    sk_props = {k: _unwrap(v) for k, v in s_item[1].items()}
                                    sk_label = str(sk_props.get("label", "")).replace("_", "").strip()
                                    if not sk_props.get("visible", True): continue
                                    sub_items.append({
                                        "id": int(s_item[0]),
                                        "label": sk_label,
                                        "isSeparator": (str(sk_props.get("type", "")) == "separator" or not sk_label),
                                        "isActive": (sk_props.get("toggle-state", 0) == 1),
                                        "enabled": bool(sk_props.get("enabled", True)),
                                        "hasSubmenu": False,
                                        "children": []
                                    })
                        except Exception:
                            pass

                    menu_items.append({
                        "id": c_id,
                        "uniqueName": "",
                        "label": label,
                        "isSeparator": is_sep,
                        "isActive": is_active,
                        "hasSubmenu": has_sub or len(sub_items) > 0,
                        "enabled": enabled,
                        "children": sub_items
                    })

                if menu_items:
                    self.state.ime_menu_items = menu_items
                    self.notify("IME_UPDATE")
                    return menu_items
        except Exception as e:
            app_logger.debug(f"[IME] DBusMenu 解析失败: {e}")

        return []

    # =========================================================================
    # 🚀【核心修复点 1】：严格规范 DBusMenu Event 参数 (Variant('i', 0))
    # =========================================================================
    async def activate_menu_item(self, item_id: int, unique_name: str = ""):
        if item_id >= 0 and self._fcitx_sni_dest and self._fcitx_menu_path:
            try:
                # 规范说明：DBusMenu 点击事件要求 data 必须为 int32 (0 代表鼠标左键点击)
                await self.bus.call(
                    Message(
                        destination=self._fcitx_sni_dest,
                        path=self._fcitx_menu_path,
                        interface="com.canonical.dbusmenu",
                        member="Event",
                        signature="isvu",
                        body=[item_id, "clicked", Variant("i", 0), int(time.time())]
                    )
                )
                self.trigger_sync()
                return
            except Exception as e:
                app_logger.debug(f"[IME] DBusMenu 点击回传失败: {e}")

        # 兜底：如果是直接传唯一的输入法名
        if unique_name and unique_name != "config":
            await self.switch_to_im(unique_name)
        elif item_id == -3 or unique_name == "config":
            await self.open_config()

        self.trigger_sync()

    # =========================================================================
    # 🚀【核心修复点 2】：左键点击胶囊切换，原生 D-Bus Controller1.Toggle()
    # =========================================================================
    async def toggle(self):
        """左键点击胶囊：直接通过 D-Bus 接口原生切换中英，彻底告别失焦命令行"""
        success = False
        try:
            r = await self.bus.call(
                Message(
                    destination="org.fcitx.Fcitx5",
                    path="/controller",
                    interface="org.fcitx.Fcitx.Controller1",
                    member="Toggle"
                )
            )
            success = (r.message_type != MessageType.ERROR)
        except Exception:
            pass

        if not success:
            try:
                proc = await asyncio.create_subprocess_exec("fcitx5-remote", "-t")
                await proc.communicate()
            except Exception:
                pass

        self.trigger_sync()

    async def switch_to_im(self, im_name: str):
        """直接通过 Controller1 原生 SetCurrentIM(s) 切换指定输入法"""
        try:
            await self.bus.call(
                Message(
                    destination="org.fcitx.Fcitx5",
                    path="/controller",
                    interface="org.fcitx.Fcitx.Controller1",
                    member="SetCurrentIM",
                    signature="s",
                    body=[im_name]
                )
            )
        except Exception:
            try:
                proc = await asyncio.create_subprocess_exec("fcitx5-remote", "-s", im_name)
                await proc.communicate()
            except Exception:
                pass

        self.trigger_sync()

    async def sync_state(self):
        if not self.bus:
            return

        im_state = 1
        cur_im = "keyboard-us"
        try:
            r_st = await self.bus.call(
                Message(destination="org.fcitx.Fcitx5", path="/controller",
                        interface="org.fcitx.Fcitx.Controller1", member="State")
            )
            if r_st.body: im_state = r_st.body[0]

            r_im = await self.bus.call(
                Message(destination="org.fcitx.Fcitx5", path="/controller",
                        interface="org.fcitx.Fcitx.Controller1", member="CurrentInputMethod")
            )
            if r_im.body: cur_im = str(r_im.body[0])
        except Exception:
            pass

        raw_props: Dict[str, Any] = {}
        target_dest = self._fcitx_sni_dest or "org.fcitx.Fcitx5"
        target_path = self._fcitx_sni_path or "/StatusNotifierItem"

        try:
            reply = await self.bus.call(
                Message(
                    destination=target_dest,
                    path=target_path,
                    interface="org.freedesktop.DBus.Properties",
                    member="GetAll",
                    signature="s",
                    body=["org.kde.StatusNotifierItem"]
                )
            )
            if reply.body:
                raw_props = {k: (v.value if hasattr(v, 'value') else v) for k, v in reply.body[0].items()}
        except Exception:
            await self._discover_fcitx_sni_address()

        pixmaps = raw_props.get("IconPixmap", [])
        icon_data_url = self.state.ime_icon_url

        if isinstance(pixmaps, list) and len(pixmaps) > 0:
            try:
                best_pix = max(pixmaps, key=lambda p: p[0] if isinstance(p, (list, tuple)) else 0)
                decoded_w = int(best_pix[0])
                decoded_h = int(best_pix[1])
                raw_bytes = bytes(best_pix[2])

                current_hash = hashlib.md5(raw_bytes).hexdigest()
                if current_hash != self._last_pixmap_hash:
                    self._last_pixmap_hash = current_hash
                    buf = bytearray(len(raw_bytes))
                    buf[0::4] = raw_bytes[1::4]
                    buf[1::4] = raw_bytes[2::4]
                    buf[2::4] = raw_bytes[3::4]
                    buf[3::4] = raw_bytes[0::4]

                    qimg = QImage(bytes(buf), decoded_w, decoded_h, decoded_w * 4, QImage.Format.Format_RGBA8888)
                    qbuf = QBuffer()
                    qbuf.open(QIODevice.OpenModeFlag.WriteOnly)
                    qimg.save(qbuf, "PNG")
                    b64 = qbuf.data().toBase64().data().decode("ascii")
                    icon_data_url = f"data:image/png;base64,{b64}"
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

    async def open_config(self):
        for bin_name in ["fcitx5-config-qt", "fcitx5-configtool", "kcmshell6"]:
            if shutil.which(bin_name):
                try:
                    if bin_name == "kcmshell6":
                        subprocess.Popen([bin_name, "kcm_fcitx5"])
                    else:
                        subprocess.Popen([bin_name])
                    return
                except Exception:
                    pass