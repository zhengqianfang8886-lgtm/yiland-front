# ==========================================
# 📄 File: backend/core/sni_base.py
# 🌟 通用 FreeDesktop SNI 与 Canonical DBusMenu 协议网关 (双名追踪·死活强校验版)
# ==========================================
import os
import time
from typing import Optional, List, Dict, Any, Callable

from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType, Variant
from backend.logger import app_logger


def unwrap_dbus_value(v: Any) -> Any:
    return v.value if hasattr(v, "value") else v


class BaseSniClient:
    def __init__(self, bus: Optional[MessageBus], service_keywords: List[str], fallback_dest: str = ""):
        self.bus = bus
        self.keywords = [k.lower() for k in service_keywords]
        
        # 🚀【架构关键 4】：同时跟踪通用服务名 (Well-Known)、唯一连接名 (Unique Owner) 和物理 PID
        self.sni_dest: Optional[str] = fallback_dest or None
        self.sni_unique_owner: Optional[str] = None
        self.sni_pid: Optional[int] = None

        self.sni_path: str = "/StatusNotifierItem"
        self.menu_path: str = "/MenuBar"
        self.is_registered: bool = False
        self._is_probing: bool = False

    def reset(self, reason: str = "Unspecified"):
        """彻底清理状态并打印排查日志"""
        if self.is_registered or self.sni_dest:
            app_logger.info(f"🔌 [SNI::RESET] 触发物理注销 (原因: {reason}) | 原目标: {self.sni_dest} (Owner: {self.sni_unique_owner}, PID: {self.sni_pid})")
        self.sni_dest = None
        self.sni_unique_owner = None
        self.sni_pid = None
        self.is_registered = False

    async def verify_liveness(self) -> bool:
        """🚀【架构关键 5】：主动向 D-Bus 和内核发起存活性双重鉴权"""
        if not self.is_registered or not self.sni_dest or not self.bus:
            return False

        # 1. 物理 PID 校验
        if self.sni_pid is not None:
            try:
                os.kill(self.sni_pid, 0)
            except OSError:
                self.reset(f"PID {self.sni_pid} 在系统进程表中已彻底消亡")
                return False

        # 2. D-Bus 总线归属权校验
        try:
            r = await self.bus.call(
                Message(
                    destination="org.freedesktop.DBus",
                    path="/org/freedesktop/DBus",
                    interface="org.freedesktop.DBus",
                    member="NameHasOwner",
                    signature="s",
                    body=[self.sni_unique_owner or self.sni_dest]
                )
            )
            if r.message_type != MessageType.ERROR and r.body:
                if not bool(r.body[0]):
                    self.reset("D-Bus 报告目标服务已失去连接持有人 (NameHasOwner == False)")
                    return False
        except Exception as e:
            self.reset(f"D-Bus 存活鉴权调用异常: {e}")
            return False

        return True

    async def discover(self) -> bool:
        if not self.bus or self._is_probing:
            return self.is_registered

        self._is_probing = True
        found_dest = None
        found_path = None

        try:
            reply = await self.bus.call(
                Message(
                    destination="org.kde.StatusNotifierWatcher",
                    path="/StatusNotifierWatcher",
                    interface="org.freedesktop.DBus.Properties",
                    member="Get",
                    signature="ss",
                    body=["org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems"]
                )
            )

            if reply.message_type != MessageType.ERROR and reply.body:
                items = unwrap_dbus_value(reply.body[0])
                for item_str in items:
                    parts = str(item_str).split("/", 1)
                    dest = parts[0]
                    obj_path = "/" + parts[1] if len(parts) > 1 else "/StatusNotifierItem"

                    # 匹配服务名称
                    dest_lower = dest.lower()
                    if any(k in dest_lower for k in self.keywords):
                        found_dest = dest
                        found_path = obj_path
                        break

                    # 深度匹配 Id 属性
                    try:
                        id_rep = await self.bus.call(
                            Message(destination=dest, path=obj_path,
                                    interface="org.freedesktop.DBus.Properties",
                                    member="Get", signature="ss",
                                    body=["org.kde.StatusNotifierItem", "Id"])
                        )
                        if id_rep.body:
                            raw_id = str(unwrap_dbus_value(id_rep.body[0])).lower()
                            if any(k in raw_id for k in self.keywords):
                                found_dest = dest
                                found_path = obj_path
                                break
                    except Exception:
                        pass
        except Exception as e:
            app_logger.debug(f"[BaseSniClient::discover] 探测异常: {e}")
        finally:
            self._is_probing = False

        if found_dest:
            await self._bind_sni(found_dest, found_path)
            return True
        else:
            if self.is_registered:
                self.reset("在 RegisteredStatusNotifierItems 扫描中未发现目标，判定已离线")
            return False

    async def _bind_sni(self, dest: str, obj_path: str):
        self.sni_dest = dest
        self.sni_path = obj_path
        self.is_registered = True

        # 解析它的 Unique Owner 和 Unix PID
        try:
            owner_reply = await self.bus.call(
                Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                        interface="org.freedesktop.DBus", member="GetNameOwner",
                        signature="s", body=[dest])
            )
            if owner_reply.body:
                self.sni_unique_owner = str(owner_reply.body[0])

            pid_reply = await self.bus.call(
                Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                        interface="org.freedesktop.DBus", member="GetConnectionUnixProcessID",
                        signature="s", body=[self.sni_unique_owner or dest])
            )
            if pid_reply.body:
                self.sni_pid = int(pid_reply.body[0])
        except Exception:
            pass

        app_logger.info(f"🔗 [SNI::BIND] 成功挂载目标 -> Dest: {dest} (Owner: {self.sni_unique_owner}, PID: {self.sni_pid})")

        # 解析菜单对象路径
        try:
            menu_rep = await self.bus.call(
                Message(destination=dest, path=obj_path,
                        interface="org.freedesktop.DBus.Properties",
                        member="Get", signature="ss",
                        body=["org.kde.StatusNotifierItem", "Menu"])
            )
            if menu_rep.body:
                self.menu_path = str(unwrap_dbus_value(menu_rep.body[0]))
        except Exception:
            self.menu_path = "/MenuBar"

    async def fetch_pixmaps(self) -> List[Any]:
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
                return unwrap_dbus_value(r.body[0]) or []
        except Exception:
            pass
        return []

    async def fetch_menu_tree(self, post_process_fn: Optional[Callable] = None) -> List[Dict[str, Any]]:
        if not self.bus or not self.sni_dest:
            return []

        try:
            try:
                await self.bus.call(
                    Message(destination=self.sni_dest, path=self.menu_path,
                            interface="com.canonical.dbusmenu", member="AboutToShow",
                            signature="i", body=[0])
                )
            except Exception:
                pass

            reply = await self.bus.call(
                Message(
                    destination=self.sni_dest, path=self.menu_path,
                    interface="com.canonical.dbusmenu", member="GetLayout",
                    signature="iias",
                    body=[0, -1, ["label", "enabled", "visible", "type", "toggle-type", "toggle-state", "children-display"]]
                )
            )

            if reply.body and len(reply.body) >= 2:
                root_node = unwrap_dbus_value(reply.body[1])
                children = root_node[2] if len(root_node) >= 3 else []

                def _parse_nodes(nodes) -> List[Dict[str, Any]]:
                    result = []
                    for child in nodes:
                        c = unwrap_dbus_value(child)
                        c_id = int(c[0])
                        props = {k: unwrap_dbus_value(v) for k, v in c[1].items()}
                        raw_sub = c[2] if len(c) >= 3 else []

                        if not props.get("visible", True):
                            continue

                        label = str(props.get("label", "")).replace("_", "").strip()
                        item_type = str(props.get("type", "standard"))
                        is_sep = (item_type == "separator" or not label)
                        has_sub = (props.get("children-display", "") == "submenu") or len(raw_sub) > 0

                        item = {
                            "id": c_id,
                            "label": label,
                            "isSeparator": is_sep,
                            "isActive": (props.get("toggle-state", 0) == 1),
                            "enabled": bool(props.get("enabled", True)),
                            "hasSubmenu": has_sub,
                            "children": _parse_nodes(raw_sub) if raw_sub else []
                        }

                        if post_process_fn:
                            item = post_process_fn(item, props)

                        result.append(item)
                    return result

                return _parse_nodes(children)

        except Exception as e:
            app_logger.debug(f"[BaseSniClient] 解析菜单异常 ({self.sni_dest}): {e}")

        return []

    async def activate_menu_item(self, item_id: int) -> bool:
        if not self.bus or not self.sni_dest or item_id < 0:
            return False
        try:
            ts = int(time.time()) & 0xFFFFFFFF
            reply = await self.bus.call(
                Message(
                    destination=self.sni_dest, path=self.menu_path,
                    interface="com.canonical.dbusmenu",
                    member="Event", signature="isvu",
                    body=[item_id, "clicked", Variant("i", 0), ts]
                )
            )
            return reply.message_type != MessageType.ERROR
        except Exception:
            return False