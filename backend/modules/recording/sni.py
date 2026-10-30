# ==========================================
# 📄 File: backend/modules/recording/sni.py
# 🌟 OBS SNI 托盘与 DBusMenu 专职客户端 (按需懒加载版)
# ==========================================
import time
from typing import Optional, List, Dict, Any
from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType, Variant
from backend.logger import app_logger


def unwrap_dbus(v: Any) -> Any:
    return v.value if hasattr(v, 'value') else v


class ObsSniClient:
    """专职维护 OBS 的 StatusNotifierItem 与 DBusMenu，与音频流采集物理隔离"""

    def __init__(self, bus: Optional[MessageBus]):
        self.bus = bus
        self.sni_dest: Optional[str] = None
        self.sni_path: str = "/StatusNotifierItem"
        self.menu_path: str = "/MenuBar"
        self.is_registered: bool = False
        self._is_probing: bool = False

    async def discover(self) -> bool:
        """精准探测 OBS 的 SNI 实例地址"""
        if not self.bus or self._is_probing:
            return self.is_registered

        self._is_probing = True
        try:
            reply = await self.bus.call(
                Message(
                    destination="org.kde.StatusNotifierWatcher",
                    path="/StatusNotifierWatcher",
                    interface="org.freedesktop.DBus.Properties",
                    member="Get", signature="ss",
                    body=["org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems"]
                )
            )
            if reply.message_type != MessageType.ERROR and reply.body:
                items = unwrap_dbus(reply.body[0])
                for it in items:
                    parts = str(it).split("/", 1)
                    dest = parts[0]
                    obj_path = "/" + parts[1] if len(parts) > 1 else "/StatusNotifierItem"

                    # 快速特征初筛
                    if "obs" in dest.lower() or "obsproject" in dest.lower():
                        self.sni_dest = dest
                        self.sni_path = obj_path
                        self.is_registered = True
                        await self._resolve_menu_path()
                        return True

                    # 深度验证 Id 属性
                    try:
                        id_rep = await self.bus.call(
                            Message(destination=dest, path=obj_path,
                                    interface="org.freedesktop.DBus.Properties",
                                    member="Get", signature="ss",
                                    body=["org.kde.StatusNotifierItem", "Id"])
                        )
                        if id_rep.body:
                            raw_id = str(unwrap_dbus(id_rep.body[0])).lower()
                            if "obs" in raw_id or "com.obsproject" in raw_id:
                                self.sni_dest = dest
                                self.sni_path = obj_path
                                self.is_registered = True
                                await self._resolve_menu_path()
                                return True
                    except Exception:
                        pass
        except Exception:
            pass
        finally:
            self._is_probing = False

        self.is_registered = False
        return False

    async def _resolve_menu_path(self):
        try:
            menu_rep = await self.bus.call(
                Message(destination=self.sni_dest, path=self.sni_path,
                        interface="org.freedesktop.DBus.Properties",
                        member="Get", signature="ss",
                        body=["org.kde.StatusNotifierItem", "Menu"])
            )
            if menu_rep.body:
                self.menu_path = str(unwrap_dbus(menu_rep.body[0]))
        except Exception:
            self.menu_path = "/MenuBar"

    async def fetch_pixmaps(self) -> List[Any]:
        """抓取托盘位图原始数据"""
        if not self.bus or not self.sni_dest:
            return []
        try:
            r = await self.bus.call(
                Message(destination=self.sni_dest, path=self.sni_path,
                        interface="org.freedesktop.DBus.Properties",
                        member="Get", signature="ss",
                        body=["org.kde.StatusNotifierItem", "IconPixmap"])
            )
            if r.message_type != MessageType.ERROR and r.body:
                return unwrap_dbus(r.body[0]) or []
        except Exception:
            pass
        return []

    async def fetch_menu_tree(self) -> List[Dict[str, Any]]:
        """按需抓取全深度多级树形菜单 (仅在用户右键点击时触发)"""
        if not self.bus or not self.sni_dest:
            return []

        try:
            try:
                await self.bus.call(
                    Message(destination=self.sni_dest, path=self.menu_path,
                            interface="com.canonical.dbusmenu",
                            member="AboutToShow", signature="i", body=[0])
                )
            except Exception:
                pass

            reply = await self.bus.call(
                Message(destination=self.sni_dest, path=self.menu_path,
                        interface="com.canonical.dbusmenu",
                        member="GetLayout", signature="iias",
                        body=[0, -1, ["label", "enabled", "visible", "type", "toggle-state", "children-display"]])
            )

            if reply.body and len(reply.body) >= 2:
                root = unwrap_dbus(reply.body[1])
                children = root[2] if len(root) >= 3 else []

                def parse_nodes(nodes) -> List[Dict[str, Any]]:
                    res = []
                    for ch in nodes:
                        c = unwrap_dbus(ch)
                        c_id = int(c[0])
                        p = {k: unwrap_dbus(v) for k, v in c[1].items()}
                        raw_sub = c[2] if len(c) >= 3 else []
                        label = str(p.get("label", "")).replace("_", "").strip()
                        item_type = str(p.get("type", "standard"))
                        is_sep = (item_type == "separator" or not label)
                        if not p.get("visible", True):
                            continue
                        has_sub = (p.get("children-display", "") == "submenu") or len(raw_sub) > 0
                        res.append({
                            "id": c_id,
                            "label": label,
                            "isSeparator": is_sep,
                            "isActive": (p.get("toggle-state", 0) == 1),
                            "enabled": bool(p.get("enabled", True)),
                            "hasSubmenu": has_sub,
                            "children": parse_nodes(raw_sub) if raw_sub else []
                        })
                    return res

                return parse_nodes(children)
        except Exception as e:
            app_logger.debug(f"[ObsSniClient] 拉取 DBusMenu 异常: {e}")
        return []

    async def activate_menu_item(self, item_id: int) -> bool:
        if not self.bus or not self.sni_dest or item_id < 0:
            return False
        try:
            ts = int(time.time()) & 0xFFFFFFFF
            reply = await self.bus.call(
                Message(destination=self.sni_dest, path=self.menu_path,
                        interface="com.canonical.dbusmenu",
                        member="Event", signature="isvu",
                        body=[item_id, "clicked", Variant("i", 0), ts])
            )
            return reply.message_type != MessageType.ERROR
        except Exception:
            return False