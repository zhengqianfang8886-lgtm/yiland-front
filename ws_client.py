import json
import asyncio
import threading
from bridge import IslandBridge, to_compact_speed
from logger import app_logger

def _sanitize_media_time(val):
    if val is None:
        return 0.0
    try:
        f = float(val)
        if f <= 0: return 0.0
        if f > 10000000: return f / 1000000.0
        if f > 100000: return f / 1000.0
        return f
    except Exception:
        return 0.0

class WebSocketDaemonClient:
    """专职异步 WebSocket 监听守护服务，负责将系统状态实时解构并路由至 IslandBridge"""

    def __init__(self, bridge: IslandBridge, uri="ws://127.0.0.1:8765"):
        self.bridge = bridge
        self.uri = uri
        self.loop = None
        self.cmd_queue = None
        self.bridge.set_ipc_sender(self.send_command)

    def send_command(self, action: str, **kwargs):
        if self.cmd_queue and self.loop and self.loop.is_running():
            payload = json.dumps({"action": action, **kwargs})
            asyncio.run_coroutine_threadsafe(self.cmd_queue.put(payload), self.loop)

    def start(self):
        worker = threading.Thread(target=self._run_loop, daemon=True, name="WsDaemonThread")
        worker.start()

    def _run_loop(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        self.cmd_queue = asyncio.Queue()
        self.loop.run_until_complete(self._connect_and_listen())

    async def _connect_and_listen(self):
        import websockets
        while True:
            try:
                async with websockets.connect(self.uri) as ws:
                    app_logger.info(f"[WS] 成功直连灵动岛后端 D-Bus 守护服务: {self.uri}")

                    async def sender():
                        while True:
                            msg = await self.cmd_queue.get()
                            await ws.send(msg)
                            self.cmd_queue.task_done()

                    async def receiver():
                        async for message in ws:
                            self._dispatch_message(message)

                    await asyncio.gather(sender(), receiver())
            except Exception:
                await asyncio.sleep(2)

    def _dispatch_message(self, message: str):
        try:
            msg = json.loads(message)
            m_type = msg.get("type", "")
            data = msg.get("data", {})

            # 1. 媒体播放与进度
            if m_type in ("MEDIA_PROGRESS", "MEDIA_TICK") and "media" in data:
                m = data["media"]
                pos = _sanitize_media_time(m.get("position"))
                dur = _sanitize_media_time(m.get("duration"))
                raw_prog = m.get("progress")
                prog = float(raw_prog) if raw_prog is not None else (pos / dur if dur > 0 else 0.0)
                self.bridge.update_progress_state(pos, dur, min(1.0, max(0.0, prog)))

            elif m_type in ("MEDIA_UPDATE", "FULL_SYNC") and "media" in data:
                m = data["media"]
                art = m.get("art_url", "")
                if art and art.startswith("/") and not art.startswith("file://"):
                    art = "file://" + art
                pos = _sanitize_media_time(m.get("position", 0.0))
                dur = _sanitize_media_time(m.get("duration", 0.0))
                self.bridge.update_media_state(
                    m.get("title", "等待播放..."),
                    m.get("artist", "未知歌手"),
                    m.get("status", "Paused"),
                    art, pos, dur
                )

            # 2. 虚拟工作区
            if m_type in ("WORKSPACE_CHANGED", "FULL_SYNC") and "workspace" in data:
                ws_info = data["workspace"]
                self.bridge.workspaceTriggered.emit(
                    int(ws_info.get("current_index", 1)),
                    int(ws_info.get("total", 4)),
                    str(ws_info.get("current_name", ""))
                )
                if "list" in ws_info:
                    self.bridge.workspaceListUpdated.emit(ws_info.get("list", []))

            # 3. 音量/亮度 OSD
            if m_type == "VOLUME_UPDATE" and "system" in data:
                sys_info = data["system"]
                self.bridge.osdTriggered.emit("🔇" if sys_info.get("muted", False) else "🔊", "Volume", int(sys_info.get("volume", 50)))
            elif m_type == "BRIGHTNESS_UPDATE" and "system" in data:
                self.bridge.osdTriggered.emit("☀️", "Display", int(data["system"].get("brightness", 50)))

            # 4. 蓝牙状态与连接更新
            if "bluetooth" in data:
                b_info = data["bluetooth"]
                devices = b_info.get("connected_devices", [])
                powered = b_info.get("powered", True)
                alerts_to_emit = []
                with self.bridge._bt_lock:
                    self.bridge._bluetooth_powered = powered
                    self.bridge._cached_bluetooth_devices = devices
                    if not self.bridge._first_poll and m_type in ("BLUETOOTH_CONNECT", "BLUETOOTH_DISCONNECT", "BLUETOOTH_BATTERY"):
                        for dev in devices:
                            mac = dev.get("mac")
                            conn = dev.get("connected", False)
                            bat = dev.get("battery")
                            name = dev.get("name", "蓝牙设备")
                            prev_conn, _ = self.bridge._known_devices_state.get(mac, (None, None))
                            if prev_conn is not None and prev_conn != conn:
                                emoji = "🎧" if any(w in name.lower() for w in ["buds", "pods", "wh-", "head", "audio"]) else "蓝牙"
                                alerts_to_emit.append((emoji, name, f"已连接 · 🔋 电量 {bat}%" if (conn and bat is not None) else ("已连接" if conn else "已断开连接"), 2500, ""))
                            self.bridge._known_devices_state[mac] = (conn, bat)
                    else:
                        for dev in devices:
                            self.bridge._known_devices_state[dev.get("mac")] = (dev.get("connected", False), dev.get("battery"))
                    self.bridge._first_poll = False
                    devices_copy = [dict(d) for d in devices]

                self.bridge.bluetoothStateChanged.emit(powered)
                self.bridge.bluetoothUpdated.emit(devices_copy)
                for alert in alerts_to_emit:
                    self.bridge.alertTriggered.emit(*alert)

            # 5. 网络带宽与 VPN 状态
            if "network" in data:
                net_info = data["network"]
                rx_str = net_info.get("rx_speed", "0 B/s")
                tx_str = net_info.get("tx_speed", "0 B/s")
                self.bridge.netSpeedUpdated.emit(rx_str, tx_str, to_compact_speed(rx_str), to_compact_speed(tx_str), self.bridge._cached_ip)
                if m_type == "VPN_CONNECTED":
                    self.bridge.alertTriggered.emit("🛡️", "VPN 安全网络已接入", net_info.get("vpn_name", "VPN Active"), 2000, "")
                elif m_type == "VPN_DISCONNECTED":
                    self.bridge.alertTriggered.emit("⚠️", "VPN 网络已断开", "恢复公网直连模式", 2000, "")

            # 6. 系统及 Teams 呼叫通知（增强调试日志与空通知拦截）
            if m_type in ("TEAMS_NOTIFICATION", "BROWSER_NOTIFICATION", "TEAMS_CALL_INCOMING"):
                if "notification" in data:
                    noti = data["notification"]
                    t_title = noti.get("title", "").strip()
                    t_sub = noti.get("content", "").strip()
                    safe_avatar = noti.get("avatar", "")
                    
                    # 只有标题或正文有效且非空串时才计入未读
                    if len(t_title) > 0 or len(t_sub) > 0:
                        app_logger.info(f"[Notif] 收到通知推送: 标题='{t_title}' | 内容='{t_sub}'")
                        self.bridge.add_notification(noti.get("icon", "💬"), t_title, t_sub, safe_avatar)
                        if m_type == "TEAMS_CALL_INCOMING":
                            self.bridge.alertTriggered.emit(noti.get("icon", "📞"), t_title, t_sub or "正在呼叫...", 0, safe_avatar)
                            self.bridge.safe_force_raise()
                        else:
                            self.bridge.alertTriggered.emit(noti.get("icon", "🔔"), t_title, t_sub, 4500, safe_avatar)

            elif m_type == "TEAMS_CALL_ENDED":
                if "notification" in data:
                    noti = data["notification"]
                    self.bridge.alertTriggered.emit("📞", noti.get("title", "") or "Teams 通话", noti.get("content", "") or "呼叫已完成", 1500, "")
                self.bridge.callEndedTriggered.emit()

            self.bridge.syncDataUpdated.emit(data)
        except Exception as err:
            app_logger.error(f"[WS] 消息解析异常: {err}")