# ==========================================
# 📄 File: backend/modules/ime/menu.py
# 🌟 DBusMenu 协议通信与全深度树形菜单解析器
# ==========================================
import time
from typing import Optional, List, Dict, Any

from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType, Variant

from backend.logger import app_logger


def unwrap_dbus_value(v: Any) -> Any:
    return v.value if hasattr(v, 'value') else v


class FcitxMenuClient:
    """专职与 Fcitx5 SNI / DBusMenu 规范通信"""

    def __init__(self, bus: Optional[MessageBus]):
        self.bus = bus
        self.sni_dest: Optional[str] = None
        self.sni_path: str = "/StatusNotifierItem"
        self.menu_path: str = "/MenuBar"
        self._is_probing = False

    async def discover_sni_address(self) -> bool:
        if not self.bus or self._is_probing:
            return False

        self._is_probing = True
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

                    try:
                        id_rep = await self.bus.call(
                            Message(destination=dest, path=obj_path,
                                    interface="org.freedesktop.DBus.Properties",
                                    member="Get", signature="ss",
                                    body=["org.kde.StatusNotifierItem", "Id"])
                        )
                        raw_id = id_rep.body[0] if (id_rep.message_type != MessageType.ERROR and id_rep.body) else ""
                        raw_id = unwrap_dbus_value(raw_id)

                        if "fcitx" in str(raw_id).lower() or "fcitx" in dest.lower():
                            self.sni_dest = dest
                            self.sni_path = obj_path

                            menu_rep = await self.bus.call(
                                Message(destination=dest, path=obj_path,
                                        interface="org.freedesktop.DBus.Properties",
                                        member="Get", signature="ss",
                                        body=["org.kde.StatusNotifierItem", "Menu"])
                            )
                            if menu_rep.body:
                                self.menu_path = str(unwrap_dbus_value(menu_rep.body[0]))
                            return True
                    except Exception:
                        pass
        except Exception:
            pass
        finally:
            self._is_probing = False

        if not self.sni_dest:
            self.sni_dest = "org.fcitx.Fcitx5"
            self.sni_path = "/StatusNotifierItem"
            self.menu_path = "/MenuBar"
        return False

    @staticmethod
    def guess_im_uniquename(label: str) -> str:
        lbl = label.lower()
        if "中州韵" in label or "rime" in lbl:
            return "rime"
        if "拼音" in label or "pinyin" in lbl:
            return "pinyin"
        if "英语" in label or "english" in lbl or "键盘" in label or "american" in lbl or "us" in lbl:
            return "keyboard-us"
        if "五笔" in label or "wubi" in lbl:
            return "wubi"
        return ""

    async def fetch_menu_tree(self, current_im: str, is_active: bool) -> List[Dict[str, Any]]:
        """从 DBusMenu 抓取全深度树形菜单"""
        if not self.bus:
            return []

        dest = self.sni_dest or "org.fcitx.Fcitx5"
        path = self.menu_path or "/MenuBar"

        try:
            try:
                await self.bus.call(
                    Message(destination=dest, path=path, interface="com.canonical.dbusmenu",
                            member="AboutToShow", signature="i", body=[0])
                )
            except Exception:
                pass

            # 🚀 核心关键点：递归深度传 -1，命令 Fcitx5 一次性把二级、三级子菜单全部取回！
            reply = await self.bus.call(
                Message(
                    destination=dest, path=path, interface="com.canonical.dbusmenu",
                    member="GetLayout", signature="iias",
                    body=[0, -1, ["label", "enabled", "visible", "type", "toggle-type", "toggle-state", "children-display"]]
                )
            )

            if reply.body and len(reply.body) >= 2:
                root_node = unwrap_dbus_value(reply.body[1])
                children = root_node[2] if len(root_node) >= 3 else []
                menu_items: List[Dict[str, Any]] = []

                cur_im_lower = current_im.lower()

                for child in children:
                    c = unwrap_dbus_value(child)
                    c_id = int(c[0])
                    props = {k: unwrap_dbus_value(v) for k, v in c[1].items()}
                    raw_subchildren = c[2] if len(c) >= 3 else []

                    label = str(props.get("label", "")).replace("_", "").strip()
                    item_type = str(props.get("type", "standard"))
                    is_sep = (item_type == "separator" or not label)
                    if not props.get("visible", True):
                        continue

                    guessed_unique = self.guess_im_uniquename(label)

                    is_item_active = False
                    if is_active:
                        if guessed_unique and cur_im_lower and (guessed_unique in cur_im_lower or cur_im_lower in guessed_unique):
                            is_item_active = True
                        elif props.get("toggle-state", 0) == 1:
                            is_item_active = True
                    else:
                        if guessed_unique == "keyboard-us" or "英语" in label or "键盘" in label:
                            is_item_active = True

                    has_sub = (props.get("children-display", "") == "submenu") or len(raw_subchildren) > 0
                    sub_items: List[Dict[str, Any]] = []

                    # 递归解析二级子菜单项
                    if raw_subchildren:
                        for sub in raw_subchildren:
                            s = unwrap_dbus_value(sub)
                            s_props = {k: unwrap_dbus_value(v) for k, v in s[1].items()}
                            s_label = str(s_props.get("label", "")).replace("_", "").strip()
                            if not s_props.get("visible", True):
                                continue

                            sub_items.append({
                                "id": int(s[0]),
                                "label": s_label,
                                "isSeparator": (str(s_props.get("type", "")) == "separator" or not s_label),
                                "isActive": (s_props.get("toggle-state", 0) == 1),
                                "enabled": bool(s_props.get("enabled", True)),
                                "hasSubmenu": False,
                                "children": []
                            })

                    if sub_items:
                        app_logger.info(f"[IME Menu] 解析出二级子菜单: 项='{label}', 子项数量={len(sub_items)}")

                    menu_items.append({
                        "id": c_id,
                        "uniqueName": guessed_unique,
                        "label": label,
                        "isSeparator": is_sep,
                        "isActive": is_item_active,
                        "hasSubmenu": has_sub,
                        "enabled": bool(props.get("enabled", True)),
                        "children": sub_items
                    })

                # 智能插入分组隔离分隔线：让“输入法主项”、“Rime 特性开关”、“系统配置”分界分明
                formatted_items: List[Dict[str, Any]] = []
                for i, it in enumerate(menu_items):
                    formatted_items.append(it)
                    # 在输入法主列表和特性开关之间插入分隔线
                    if i < len(menu_items) - 1:
                        next_it = menu_items[i + 1]
                        if it.get("uniqueName") and not next_it.get("uniqueName") and not it.get("isSeparator") and not next_it.get("isSeparator") and "配置" not in next_it.get("label", ""):
                            formatted_items.append({"id": -99, "uniqueName": "", "label": "", "isSeparator": True, "isActive": False, "hasSubmenu": False, "enabled": False, "children": []})

                return formatted_items
        except Exception as e:
            app_logger.debug(f"[IME Menu] 解析 DBusMenu 异常: {e}")

        return []

    async def send_menu_event(self, item_id: int) -> bool:
        """向 DBusMenu 下发点击事件"""
        if not self.bus or item_id < 0:
            return False

        dest = self.sni_dest or "org.fcitx.Fcitx5"
        path = self.menu_path or "/MenuBar"
        try:
            ts = int(time.time()) & 0xFFFFFFFF
            reply = await self.bus.call(
                Message(
                    destination=dest, path=path,
                    interface="com.canonical.dbusmenu",
                    member="Event", signature="isvu",
                    body=[item_id, "clicked", Variant("i", 0), ts]
                )
            )
            return reply.message_type != MessageType.ERROR
        except Exception:
            return False