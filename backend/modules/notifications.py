# ==========================================
# 📄 File: backend/modules/notifications.py
# 🌟 Teams 专属过滤 · 零磁盘落盘 · PAL 兼容适配版
# ==========================================
import os
import asyncio
from typing import Optional

from dbus_next.aio import MessageBus
from dbus_next.constants import BusType
from dbus_next import Message

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState
from backend.platform import detect_platform


def is_debug_mode() -> bool:
    return os.getenv("DEBUG") in ("1", "true", "True") or os.getenv("ISLAND_DEBUG") in ("1", "true", "True")


class TeamsFilterConfig:
    TEAMS_DOMAINS = ["teams.live.com", "teams.microsoft.com", "teams.cloud.microsoft", "teams.office.com"]
    TEAMS_APPS = ["teams", "teams-for-linux", "microsoft-teams", "ms-teams"]
    CALL_KEYWORDS = ["正在呼叫", "来电", "邀请您加入通话", "邀请你加入通话", "视频通话", "语音通话", "calling", "incoming call"]
    CALL_END_KEYWORDS = ["未接来电", "已取消呼叫", "通话已结束", "通话结束", "missed call", "call ended"]


class NotificationModule(BaseModule):
    """利用 D-Bus BecomeMonitor 原生嗅探 Teams 消息与来电（不抢占系统通知服务）"""

    def __init__(self, backend, state: IslandState):
        super().__init__(backend, state)
        self.platform = detect_platform()
        self.monitor_bus: Optional[MessageBus] = None
        self.action_bus: Optional[MessageBus] = None
        self.current_call_id: Optional[int] = None
        self.is_calling: bool = False
        self._call_timeout_task: Optional[asyncio.Task] = None

    def _unwrap_variant(self, variant):
        if hasattr(variant, 'value'): return self._unwrap_variant(variant.value)
        if isinstance(variant, list): return [self._unwrap_variant(item) for item in variant]
        if isinstance(variant, dict): return {k: self._unwrap_variant(v) for k, v in variant.items()}
        return variant

    async def start(self) -> None:
        try:
            self.action_bus = await MessageBus(bus_type=BusType.SESSION).connect()
        except Exception:
            pass
        asyncio.create_task(self._monitor_lifecycle_loop())
        app_logger.info("Teams 通知与来电监听模块已就绪")

    async def stop(self) -> None:
        if self._call_timeout_task and not self._call_timeout_task.done():
            self._call_timeout_task.cancel()
        if self.monitor_bus:
            try:
                self.monitor_bus.disconnect()
            except Exception:
                pass

    async def _monitor_lifecycle_loop(self):
        while True:
            try:
                self.monitor_bus = await MessageBus(bus_type=BusType.SESSION).connect()
                rule_notify = "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
                rule_closed = "type='signal',interface='org.freedesktop.Notifications',member='NotificationClosed'"

                await self.monitor_bus.call(
                    Message(
                        destination="org.freedesktop.DBus",
                        path="/org/freedesktop/DBus",
                        interface="org.freedesktop.DBus.Monitoring",
                        member="BecomeMonitor",
                        signature="asu",
                        body=[[rule_notify, rule_closed], 0]
                    )
                )

                self.monitor_bus.send = lambda *args, **kwargs: None
                self.monitor_bus.add_message_handler(self._on_dbus_message)
                if is_debug_mode():
                    app_logger.info("✅ Teams 专属嗅探器已挂载 (BecomeMonitor 成功)")

                await self.monitor_bus.wait_for_disconnect()
            except Exception as e:
                if is_debug_mode():
                    app_logger.error(f"通知监听断开: {e}，将在 3 秒后重试...")
                await asyncio.sleep(3)

    def _on_dbus_message(self, msg: Message) -> bool:
        if msg.member == "Notify":
            asyncio.create_task(self._handle_notify_async(msg))
        elif msg.member == "NotificationClosed" and self.is_calling:
            self._stop_call("系统挂断信号")
        return True

    async def _handle_notify_async(self, msg: Message):
        try:
            app_name = str(msg.body[0] if len(msg.body) > 0 else "").lower()
            replaces_id = int(msg.body[1] if len(msg.body) > 1 else 0)
            raw_summary = str(msg.body[3] if len(msg.body) > 3 else "").strip()
            raw_body = str(msg.body[4] if len(msg.body) > 4 else "").strip()
            raw_hints = msg.body[6] if len(msg.body) > 6 else {}
            hints = self._unwrap_variant(raw_hints)

            # 1. 严格白名单过滤：只拦截 Teams 消息
            origin_name = str(hints.get("x-kde-origin-name", "")).lower()
            desktop_entry = str(hints.get("desktop-entry", "")).lower()

            is_teams_web = any(domain in origin_name for domain in TeamsFilterConfig.TEAMS_DOMAINS)
            is_teams_app = any(app in app_name or app in desktop_entry for app in TeamsFilterConfig.TEAMS_APPS)

            if not (is_teams_web or is_teams_app):
                return

            if not raw_summary and not raw_body:
                return

            # 2. 提取联系人头像路径
            avatar_path = ""
            for key in ["image-path", "image_path", "image-uri"]:
                p = hints.get(key)
                if p and os.path.exists(str(p)):
                    avatar_path = f"file://{os.path.abspath(str(p))}"
                    break

            if not avatar_path:
                app_icon = str(msg.body[2] if len(msg.body) > 2 else "")
                if app_icon.startswith("file://") and os.path.exists(app_icon[7:]):
                    avatar_path = app_icon

            self.state.last_notify_title = raw_summary
            self.state.last_notify_content = raw_body
            self.state.last_notify_avatar = avatar_path

            combined = f"{raw_summary} {raw_body}".lower()

            # 3. 来电挂断/通话结束
            if any(kw in combined for kw in TeamsFilterConfig.CALL_END_KEYWORDS):
                self._stop_call(raw_body)
                return

            # 4. 来电响铃模式
            if any(kw in combined for kw in TeamsFilterConfig.CALL_KEYWORDS):
                self.is_calling = True
                self.current_call_id = replaces_id if replaces_id != 0 else msg.serial
                self.state.last_notify_icon = "📞"
                self.notify("TEAMS_CALL_INCOMING")

                if self._call_timeout_task and not self._call_timeout_task.done():
                    self._call_timeout_task.cancel()
                self._call_timeout_task = asyncio.create_task(self._auto_call_watchdog(45))
                return

            # 5. 普通文字消息
            self.state.last_notify_icon = "💬"
            self.notify("TEAMS_NOTIFICATION")

        except Exception as e:
            if is_debug_mode():
                app_logger.error(f"处理 Teams 消息异常: {e}")

    def _stop_call(self, reason: str):
        if not self.is_calling: return
        self.is_calling = False
        self.current_call_id = None
        if self._call_timeout_task and not self._call_timeout_task.done():
            self._call_timeout_task.cancel()
        self.notify("TEAMS_CALL_ENDED")

    async def _auto_call_watchdog(self, timeout_sec: int):
        await asyncio.sleep(timeout_sec)
        if self.is_calling:
            self._stop_call("超时无应答挂断")

    async def focus_teams(self) -> bool:
        """通过 PAL 平台适配层聚焦 Teams 窗口"""
        return self.platform.focus_application_window(class_pattern="teams", title_pattern="Microsoft Teams")

    async def answer_call(self) -> bool:
        """快捷安全接听"""
        if not self.is_calling: return False
        await self.focus_teams()
        await asyncio.sleep(0.15)
        # 通过 PAL 触发组合键
        return self.platform.simulate_shortcut("ctrl+shift+s")

    async def reject_call(self) -> bool:
        """快捷安全拒接"""
        if not self.is_calling: return False
        await self.focus_teams()
        await asyncio.sleep(0.15)
        res = self.platform.simulate_shortcut("ctrl+shift+d")
        self._stop_call("主动拒接")
        return res