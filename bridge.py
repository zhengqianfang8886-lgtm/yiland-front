import os
import gc
import json
import time
import socket
import shutil
import hashlib
import urllib.parse
import subprocess
from concurrent.futures import ThreadPoolExecutor

from PySide6.QtCore import (
    QObject, Signal, Slot, Property, QRect, QTimer,
    QDateTime, QTimeZone, QByteArray, Qt
)
from PySide6.QtGui import QRegion
from logger import app_logger
from models import NotificationListModel, BluetoothListModel

AVATAR_CACHE_DIR = os.path.expanduser("~/.local/state/alcove_island/avatar_cache")


def process_notification_avatar(raw_avatar_url: str) -> str:
    """提取头像并使用 Pillow 强制裁剪为抗锯齿透明正圆 PNG，彻底解决直角残留"""
    if not raw_avatar_url:
        return ""
    try:
        parsed = urllib.parse.urlparse(raw_avatar_url)
        clean_path = parsed.path if parsed.scheme in ("file", "") else raw_avatar_url
        if parsed.scheme == "file" and not clean_path.startswith("/"):
            clean_path = "/" + clean_path
        if parsed.scheme in ("http", "https"):
            return raw_avatar_url
        if not os.path.exists(clean_path):
            return ""
        os.makedirs(AVATAR_CACHE_DIR, exist_ok=True)
        mtime = os.path.getmtime(clean_path)
        file_hash = hashlib.md5(f"{clean_path}_{mtime}".encode("utf-8")).hexdigest()[:12]
        cached_filename = f"avatar_circle_{file_hash}.png"
        cached_path = os.path.join(AVATAR_CACHE_DIR, cached_filename)
        
        if not os.path.exists(cached_path):
            try:
                from PIL import Image, ImageDraw
                im = Image.open(clean_path).convert("RGBA")
                size = min(im.size)
                left = (im.width - size) // 2
                top = (im.height - size) // 2
                im = im.crop((left, top, left + size, top + size))
                
                # 制作带抗锯齿的正圆 Alpha 蒙版
                mask = Image.new("L", (size, size), 0)
                draw = ImageDraw.Draw(mask)
                draw.ellipse((0, 0, size, size), fill=255)
                im.putalpha(mask)
                im.save(cached_path, "PNG")
            except Exception as pe:
                app_logger.warning(f"PIL 圆形裁剪降级: {pe}")
                shutil.copy2(clean_path, cached_path)
                
        return f"file://{cached_path}"
    except Exception as e:
        app_logger.warning(f"处理头像缓存异常: {e}")
        return ""


def to_compact_speed(speed_str: str) -> str:
    if not speed_str:
        return "0K"
    parts = speed_str.strip().split()
    if len(parts) >= 2:
        val, unit = parts[0], parts[1].upper()
        if "M" in unit:
            try:
                return f"{float(val):.1f}M"
            except ValueError:
                return f"{val}M"
        elif "K" in unit:
            try:
                f = float(val)
                return f"{int(f)}K" if f >= 10 else f"{f:.1f}K"
            except ValueError:
                return f"{val}K"
        elif "B" in unit:
            return "0K"
    return "0K"


def get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


class IslandBridge(QObject):
    mediaUpdated = Signal(str, str, str, str, float, float)
    progressUpdated = Signal(float, float, float)
    osdTriggered = Signal(str, str, int)
    workspaceTriggered = Signal(int, int, str)
    workspaceListUpdated = Signal("QVariantList")
    alertTriggered = Signal(str, str, str, int, str)
    callEndedTriggered = Signal()
    syncDataUpdated = Signal("QVariantMap")
    netSpeedUpdated = Signal(str, str, str, str, str)

    bluetoothStateChanged = Signal(bool)
    unreadCountChanged = Signal(int)

    _sig_daemon_payload = Signal(str, str)

    def __init__(self, view):
        super().__init__()
        self.view = view

        self._curr_title = ""
        self._curr_artist = ""
        self._curr_pos = 0.0
        self._curr_dur = 0.0
        self._curr_status = "Paused"

        self._notif_model = NotificationListModel(self)
        self._bt_model = BluetoothListModel(self)
        self._notif_model.unreadCountChanged.connect(self.unreadCountChanged)

        self._bluetooth_powered = True
        self._known_devices_state = {}
        self._first_poll = True
        self._cached_ip = get_local_ip()

        self._ipc_sender = None
        self._pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="SubprocessWorker")

        self._local_media_timer = QTimer(self)
        self._local_media_timer.setInterval(1000)
        self._local_media_timer.timeout.connect(self._on_local_media_tick)

        self._sig_daemon_payload.connect(self._handle_daemon_payload, Qt.ConnectionType.QueuedConnection)

    @Property(QObject, constant=True)
    def notificationModel(self):
        return self._notif_model

    @Property(QObject, constant=True)
    def bluetoothModel(self):
        return self._bt_model

    def set_ipc_sender(self, sender_func):
        self._ipc_sender = sender_func

    def post_daemon_message(self, msg_type: str, data_json_str: str):
        self._sig_daemon_payload.emit(msg_type, data_json_str)

    def _on_local_media_tick(self):
        if self._curr_status == "Playing" and self._curr_dur > 0:
            if self._curr_pos < self._curr_dur:
                self._curr_pos += 1.0
                prog = min(1.0, max(0.0, self._curr_pos / self._curr_dur))
                self.progressUpdated.emit(self._curr_pos, self._curr_dur, prog)

    @Slot(str, str)
    def _handle_daemon_payload(self, m_type: str, data_str: str):
        try:
            data = json.loads(data_str) if data_str else {}
        except Exception as e:
            app_logger.error(f"解析报文异常: {e}")
            return

        if m_type in ("MEDIA_PROGRESS", "MEDIA_TICK") and "media" in data:
            m = data["media"]
            self._apply_media_progress(m.get("position"), m.get("duration"), float(m.get("progress", -1.0)))

        elif m_type in ("MEDIA_UPDATE", "FULL_SYNC") and "media" in data:
            m = data["media"]
            art = m.get("art_url", "")
            if art and art.startswith("/") and not art.startswith("file://"):
                art = "file://" + art
            self._apply_media_state(
                m.get("title", "等待播放..."),
                m.get("artist", "未知歌手"),
                m.get("status", "Paused"),
                art,
                m.get("position"),
                m.get("duration"),
            )

        if m_type in ("WORKSPACE_CHANGED", "FULL_SYNC") and "workspace" in data:
            ws_info = data["workspace"]
            self.workspaceTriggered.emit(
                int(ws_info.get("current_index", 1)),
                int(ws_info.get("total", 4)),
                str(ws_info.get("current_name", "")),
            )
            if "list" in ws_info:
                self.workspaceListUpdated.emit(ws_info.get("list", []))

        if m_type == "VOLUME_UPDATE" and "system" in data:
            sys_info = data["system"]
            self.osdTriggered.emit(
                "🔇" if sys_info.get("muted", False) else "🔊",
                "Volume",
                int(sys_info.get("volume", 50)),
            )
        elif m_type == "BRIGHTNESS_UPDATE" and "system" in data:
            self.osdTriggered.emit("☀️", "Display", int(data["system"].get("brightness", 50)))

        if "bluetooth" in data:
            b_info = data["bluetooth"]
            devices = b_info.get("connected_devices", [])
            powered = b_info.get("powered", True)
            self._bluetooth_powered = powered

            alerts_to_emit = []
            if not self._first_poll and m_type in ("BLUETOOTH_CONNECT", "BLUETOOTH_DISCONNECT", "BLUETOOTH_BATTERY"):
                for dev in devices:
                    mac = dev.get("mac")
                    conn = dev.get("connected", False)
                    bat = dev.get("battery")
                    name = dev.get("name", "蓝牙设备")
                    prev_conn, _ = self._known_devices_state.get(mac, (None, None))
                    if prev_conn is not None and prev_conn != conn:
                        emoji = "🎧" if any(w in name.lower() for w in ["buds", "pods", "wh-", "head", "audio"]) else "蓝牙"
                        status_str = f"已连接 · 🔋 电量 {bat}%" if (conn and bat is not None) else ("已连接" if conn else "已断开连接")
                        alerts_to_emit.append((emoji, name, status_str, 2500, ""))
                    self._known_devices_state[mac] = (conn, bat)
            else:
                for dev in devices:
                    self._known_devices_state[dev.get("mac")] = (dev.get("connected", False), dev.get("battery"))
            self._first_poll = False

            self._bt_model.sync_devices(devices)
            self.bluetoothStateChanged.emit(powered)
            for alert in alerts_to_emit:
                self.alertTriggered.emit(*alert)

        if "network" in data:
            net_info = data["network"]
            rx_str = net_info.get("rx_speed", "0 B/s")
            tx_str = net_info.get("tx_speed", "0 B/s")
            self.netSpeedUpdated.emit(rx_str, tx_str, to_compact_speed(rx_str), to_compact_speed(tx_str), self._cached_ip)
            if m_type == "VPN_CONNECTED":
                self.alertTriggered.emit("🛡️", "VPN 安全网络已接入", net_info.get("vpn_name", "VPN Active"), 2000, "")
            elif m_type == "VPN_DISCONNECTED":
                self.alertTriggered.emit("⚠️", "VPN 网络已断开", "恢复公网直连模式", 2000, "")

        if m_type in ("TEAMS_NOTIFICATION", "BROWSER_NOTIFICATION", "TEAMS_CALL_INCOMING"):
            if "notification" in data:
                noti = data["notification"]
                t_title = noti.get("title", "").strip()
                t_sub = noti.get("content", "").strip()
                raw_avatar = noti.get("avatar", "")
                safe_avatar = process_notification_avatar(raw_avatar) if raw_avatar else ""

                if t_title or t_sub:
                    item_id = int(time.time() * 1000)
                    now_str = time.strftime("%H:%M")
                    self._notif_model.add_notification({
                        "id": item_id,
                        "icon": noti.get("icon", "💬"),
                        "title": t_title or "新通知",
                        "content": t_sub or "",
                        "avatar": safe_avatar,
                        "time": now_str,
                        "read": False,
                    })
                    if m_type == "TEAMS_CALL_INCOMING":
                        self.alertTriggered.emit(noti.get("icon", "📞"), t_title, t_sub or "正在呼叫...", 0, safe_avatar)
                        self.view.raise_()
                    else:
                        self.alertTriggered.emit(noti.get("icon", "🔔"), t_title, t_sub, 4500, safe_avatar)

        elif m_type == "TEAMS_CALL_ENDED":
            if "notification" in data:
                noti = data["notification"]
                self.alertTriggered.emit("📞", noti.get("title", "") or "Teams 通话", noti.get("content", "") or "呼叫已完成", 1500, "")
            self.callEndedTriggered.emit()

        self.syncDataUpdated.emit(data)

    def _apply_media_state(self, title, artist, status, art, pos_val, dur_val):
        pos = self._sanitize_time(pos_val)
        dur = self._sanitize_time(dur_val)
        is_track_changed = (title != self._curr_title) or (artist != self._curr_artist)
        self._curr_status = status

        if is_track_changed:
            self._curr_title = title
            self._curr_artist = artist
            self._curr_dur = dur if (dur and dur > 0) else 0.0
            self._curr_pos = pos if (pos and pos >= 0) else 0.0
        else:
            if dur and dur > 0:
                self._curr_dur = dur
            if pos and pos > 0:
                self._curr_pos = pos

        if status == "Playing":
            if not self._local_media_timer.isActive():
                self._local_media_timer.start()
        else:
            if self._local_media_timer.isActive():
                self._local_media_timer.stop()

        self.mediaUpdated.emit(title, artist, status, art, self._curr_pos, self._curr_dur)

    def _apply_media_progress(self, pos_val, dur_val, prog):
        pos = self._sanitize_time(pos_val)
        dur = self._sanitize_time(dur_val)
        if dur and dur > 0:
            self._curr_dur = dur
        if pos and pos >= 0:
            self._curr_pos = pos

        actual_prog = prog
        if actual_prog < 0:
            actual_prog = min(1.0, max(0.0, self._curr_pos / self._curr_dur)) if self._curr_dur > 0 else 0.0

        self.progressUpdated.emit(self._curr_pos, self._curr_dur, actual_prog)

    @staticmethod
    def _sanitize_time(val):
        if val is None:
            return None
        try:
            f = float(val)
            if f < 0:
                return 0.0
            if f >= 100_000:
                return f / 1_000_000.0
            return f
        except Exception:
            return None

    @Slot(int, int, int, int)
    def updateMask(self, x, y, width, height):
        if width > 0 and height > 0:
            vw = self.view.width()
            vh = self.view.height()
            safe_x = max(0, int(x))
            safe_y = max(0, int(y))
            safe_w = min(vw - safe_x, int(width))
            safe_h = min(vh - safe_y, int(height))
            if safe_w > 0 and safe_h > 0:
                self.view.setMask(QRegion(QRect(safe_x, safe_y, safe_w, safe_h)))

    @Slot("QVariantList")
    def updateCompositeMask(self, rects):
        if not rects:
            return
        composite = QRegion()
        vw = self.view.width()
        vh = self.view.height()
        for r in rects:
            rx = max(0, int(r.get("x", 0)))
            ry = max(0, int(r.get("y", 0)))
            rw = min(vw - rx, int(r.get("w", 0)))
            rh = min(vh - ry, int(r.get("h", 0)))
            if rw > 0 and rh > 0:
                composite = composite.united(QRect(rx, ry, rw, rh))
        if not composite.isEmpty():
            self.view.setMask(composite)

    @Slot(result=str)
    def getLatestNotificationAvatar(self):
        return self._notif_model.latestAvatar

    @Slot()
    def forceRaise(self):
        self.view.raise_()

    @Slot()
    def requestWindowFocus(self):
        self.view.requestActivate()
        self.view.raise_()

    @Slot()
    def onIslandCollapsed(self):
        gc.collect(generation=1)
        if hasattr(self.view, "engine") and hasattr(self.view.engine(), "trimComponentCache"):
            self.view.engine().trimComponentCache()

    def sendIpcCmd(self, action: str, **kwargs):
        if self._ipc_sender:
            self._ipc_sender(action, **kwargs)

    @Slot(str)
    def sendMediaCmd(self, action: str):
        self.sendIpcCmd(action)

    @Slot(int)
    @Slot(str)
    def switchWorkspace(self, target):
        self.sendIpcCmd("WORKSPACE_SWITCH", target=target)

    @Slot()
    def switchWorkspacePrev(self):
        self.sendIpcCmd("WORKSPACE_PREV")

    @Slot()
    def switchWorkspaceNext(self):
        self.sendIpcCmd("WORKSPACE_NEXT")

    # 🚀 一键接听 Teams 来电
    @Slot()
    def answerTeamsCall(self):
        self.sendIpcCmd("TEAMS_ANSWER")

    # 🚀 拒接/挂断 Teams 来电
    @Slot()
    def rejectTeamsCall(self):
        self.sendIpcCmd("TEAMS_REJECT")

    # 🚀 激活聚焦 Teams 窗口
    @Slot()
    def focusTeamsWindow(self):
        self.sendIpcCmd("TEAMS_FOCUS")

    @Slot(str, bool, result=dict)
    def getWorldTime(self, tz_name, is_24h=True):
        try:
            tz = QTimeZone(QByteArray(tz_name.encode("utf-8"))) if tz_name else QTimeZone.systemTimeZone()
            if not tz.isValid():
                tz = QTimeZone.systemTimeZone()
            now_utc = QDateTime.currentDateTimeUtc()
            target_dt = now_utc.toTimeZone(tz)
            local_dt = QDateTime.currentDateTime()
            local_tz = QTimeZone.systemTimeZone()
            h = target_dt.time().hour()
            m = target_dt.time().minute()
            time_str = f"{h:02d}:{m:02d}" if is_24h else f"{h%12 or 12:02d}:{m:02d}{' PM' if h>=12 else ' AM'}"
            diff_hours = round((tz.offsetFromUtc(now_utc) - local_tz.offsetFromUtc(now_utc)) / 3600.0, 1)
            day_diff = local_dt.date().daysTo(target_dt.date())
            day_str = "今天" if day_diff == 0 else ("明天" if day_diff > 0 else "昨天")
            diff_str = "与本地同时" if diff_hours == 0 else (f"快 {diff_hours:g}h · {day_str}" if diff_hours > 0 else f"慢 {abs(diff_hours):g}h · {day_str}")
            return {"time": time_str, "diff": diff_str, "isDay": 6 <= h < 18, "isWorking": 9 <= h < 18}
        except Exception:
            return {"time": "--:--", "diff": "", "isDay": True, "isWorking": False}

    @Slot(str, result=str)
    def getTzOffsetStr(self, tz_name):
        try:
            tz = QTimeZone(QByteArray(tz_name.encode("utf-8"))) if tz_name else None
            if not tz or not tz.isValid():
                return "UTC"
            off_sec = tz.offsetFromUtc(QDateTime.currentDateTimeUtc())
            off_h = off_sec // 3600
            off_m = abs((off_sec % 3600) // 60)
            sign = "+" if off_sec >= 0 else ""
            return f"UTC{sign}{off_h}" if off_m == 0 else f"UTC{sign}{off_h}:{off_m:02d}"
        except Exception:
            return "UTC"

    @Slot(result=bool)
    def isBluetoothPowered(self):
        return self._bluetooth_powered

    @Slot(str)
    def connectBluetooth(self, mac):
        def _con():
            if shutil.which("bluetoothctl"):
                try:
                    subprocess.run(["bluetoothctl", "connect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3.0)
                except subprocess.TimeoutExpired:
                    app_logger.warning(f"连接蓝牙设备超时: {mac}")
        self._pool.submit(_con)

    @Slot(str)
    def disconnectBluetooth(self, mac):
        def _dis():
            if shutil.which("bluetoothctl"):
                try:
                    subprocess.run(["bluetoothctl", "disconnect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3.0)
                except subprocess.TimeoutExpired:
                    app_logger.warning(f"断开蓝牙设备超时: {mac}")
        self._pool.submit(_dis)

    @Slot()
    def openBluetoothSettings(self):
        def _open():
            candidates = ["blueman-manager", "gnome-control-center", "plasma-open-settings", "kcmshell6", "blueberry", "overskride"]
            for cmd in candidates:
                if shutil.which(cmd):
                    try:
                        if cmd == "gnome-control-center":
                            subprocess.Popen([cmd, "bluetooth"])
                        elif cmd in ("plasma-open-settings", "kcmshell6"):
                            subprocess.Popen([cmd, "kcm_bluetooth"])
                        else:
                            subprocess.Popen([cmd])
                        return
                    except Exception as e:
                        app_logger.warning(f"调起蓝牙设置程序异常: {e}")
        self._pool.submit(_open)

    @Slot(str, str)
    def focusMediaWindow(self, title="", artist=""):
        def _focus():
            candidates = []
            if title and title != "等待播放...":
                clean_title = title.split(" - ")[0].split("—")[0].strip()
                if len(clean_title) >= 2:
                    candidates.append(clean_title)
            if artist and artist != "未知歌手":
                candidates.append(artist.strip())

            players = ["Spotify", "netease-cloud-music", "yesplaymusic", "qqmusic", "QQMusic", "music", "VLC", "Chrome", "Chromium", "Firefox"]
            candidates.extend(players)

            for kw in candidates:
                if not kw:
                    continue
                try:
                    if shutil.which("wmctrl"):
                        if subprocess.run(["wmctrl", "-a", kw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.5).returncode == 0:
                            return
                    if shutil.which("xdotool"):
                        if subprocess.run(["xdotool", "search", "--onlyvisible", "--name", kw, "windowactivate"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.5).returncode == 0:
                            return
                    if shutil.which("hyprctl"):
                        if subprocess.run(["hyprctl", "dispatch", "focuswindow", f"title:(.*{kw}.*)"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.5).returncode == 0:
                            return
                    if shutil.which("swaymsg"):
                        if subprocess.run(["swaymsg", f'[title="(?i).*{kw}.*"] focus'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.5).returncode == 0:
                            return
                except subprocess.TimeoutExpired:
                    continue
        self._pool.submit(_focus)