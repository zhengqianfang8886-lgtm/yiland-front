import os
import time
import socket
import shutil
import hashlib
import urllib.parse
import threading
import subprocess
from concurrent.futures import ThreadPoolExecutor
from PySide6.QtCore import QObject, Signal, Slot, QRect, QTimer, QDateTime, QTimeZone, QByteArray
from PySide6.QtGui import QRegion
from logger import app_logger

AVATAR_CACHE_DIR = os.path.expanduser("~/.local/state/alcove_island/avatar_cache")

def process_notification_avatar(raw_avatar_url: str) -> str:
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
        ext = os.path.splitext(clean_path)[1] or ".png"
        cached_filename = f"avatar_{file_hash}{ext}"
        cached_path = os.path.join(AVATAR_CACHE_DIR, cached_filename)
        if not os.path.exists(cached_path):
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
            try: return f"{float(val):.1f}M"
            except ValueError: return f"{val}M"
        elif "K" in unit:
            try:
                f = float(val)
                return f"{int(f)}K" if f >= 10 else f"{f:.1f}K"
            except ValueError: return f"{val}K"
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

    bluetoothUpdated = Signal("QVariantList")
    bluetoothStateChanged = Signal(bool)
    notificationHistoryUpdated = Signal("QVariantList")
    unreadCountChanged = Signal(int)

    _sig_update_media = Signal(str, str, str, str, float, float)
    _sig_update_progress = Signal(float, float, float)
    _sig_force_raise = Signal()

    def __init__(self, view):
        super().__init__()
        self.view = view
        self._curr_pos = 0.0
        self._curr_dur = 0.0
        self._curr_status = "Paused"

        self._bt_lock = threading.Lock()
        self._notif_lock = threading.Lock()

        # 核心改进：引入统一的受控后台工作线程池，杜绝无节制裸线程
        self._pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="IslandWorker")

        self._cached_bluetooth_devices = []
        self._bluetooth_powered = True
        self._known_devices_state = {}
        self._first_poll = True

        self._notification_history = []
        self._unread_count = 0
        self._latest_notif_avatar = ""
        self._cached_ip = get_local_ip()

        self._ipc_sender = None  # 由 ws_client 注入

        self._local_media_timer = QTimer(self)
        self._local_media_timer.setInterval(1000)
        self._local_media_timer.timeout.connect(self._on_local_media_tick)

        self._sig_update_media.connect(self._do_update_media_state)
        self._sig_update_progress.connect(self._do_update_progress_state)
        self._sig_force_raise.connect(self.forceRaise)

    def set_ipc_sender(self, sender_func):
        self._ipc_sender = sender_func

    def _on_local_media_tick(self):
        if self._curr_status == "Playing" and self._curr_dur > 0:
            if self._curr_pos < self._curr_dur:
                self._curr_pos += 1.0
                prog = min(1.0, max(0.0, self._curr_pos / self._curr_dur))
                self.progressUpdated.emit(self._curr_pos, self._curr_dur, prog)

    def update_media_state(self, title, artist, status, art, pos, dur):
        self._sig_update_media.emit(title, artist, status, art, pos, dur)

    def update_progress_state(self, pos, dur, prog):
        self._sig_update_progress.emit(pos, dur, prog)

    def safe_force_raise(self):
        self._sig_force_raise.emit()

    def add_notification(self, icon, title, content, avatar=""):
        if not title and not content:
            return
        now_str = time.strftime("%H:%M")
        safe_avatar = process_notification_avatar(avatar) if avatar else ""
        item_id = int(time.time() * 1000)
        item = {
            "id": item_id, "icon": icon or "💬", "title": title or "新通知",
            "content": content or "", "avatar": safe_avatar, "time": now_str, "read": False
        }
        with self._notif_lock:
            if self._notification_history:
                top = self._notification_history[0]
                if top.get("title") == title and top.get("content") == content:
                    if (item_id - top.get("id", 0)) < 3000:
                        return
            self._notification_history.insert(0, item)
            if len(self._notification_history) > 15:
                self._notification_history.pop()
            self._unread_count += 1
            if safe_avatar:
                self._latest_notif_avatar = safe_avatar
            history_copy = [dict(n) for n in self._notification_history]
            current_unread = self._unread_count
        self.unreadCountChanged.emit(current_unread)
        self.notificationHistoryUpdated.emit(history_copy)

    @Slot(result=list)
    def getNotificationHistory(self):
        with self._notif_lock:
            return [dict(n) for n in self._notification_history]

    @Slot(result=int)
    def getUnreadNotificationCount(self):
        with self._notif_lock:
            return self._unread_count

    @Slot(result=str)
    def getLatestNotificationAvatar(self):
        with self._notif_lock:
            return self._latest_notif_avatar

    @Slot()
    def markAllNotificationsRead(self):
        with self._notif_lock:
            self._unread_count = 0
            for n in self._notification_history:
                n["read"] = True
            history_copy = [dict(n) for n in self._notification_history]
        self.unreadCountChanged.emit(0)
        self.notificationHistoryUpdated.emit(history_copy)

    @Slot()
    def clearNotificationHistory(self):
        with self._notif_lock:
            self._notification_history.clear()
            self._unread_count = 0
            self._latest_notif_avatar = ""
        self.unreadCountChanged.emit(0)
        self.notificationHistoryUpdated.emit([])

    @Slot(str, str, str, str, float, float)
    def _do_update_media_state(self, title, artist, status, art, pos, dur):
        self._curr_status = status
        self._curr_dur = dur
        self._curr_pos = pos
        if status == "Playing":
            if not self._local_media_timer.isActive():
                self._local_media_timer.start()
        else:
            self._local_media_timer.stop()
        self.mediaUpdated.emit(title, artist, status, art, pos, dur)

    @Slot(float, float, float)
    def _do_update_progress_state(self, pos, dur, prog):
        if self._curr_status == "Playing" and self._curr_dur > 0:
            if pos >= self._curr_dur and (self._curr_dur - self._curr_pos > 5):
                return
        if dur > 0:
            self._curr_dur = dur
        if pos > 0:
            self._curr_pos = pos
        self.progressUpdated.emit(self._curr_pos, self._curr_dur, prog)

    @Slot()
    def forceRaise(self):
        self.view.raise_()

    @Slot()
    def requestWindowFocus(self):
        self.view.requestActivate()
        self.view.raise_()

    @Slot(int, int, int, int)
    def updateMask(self, x, y, width, height):
        if width > 0 and height > 0:
            safe_x = max(0, int(x))
            safe_y = max(0, int(y))
            safe_w = min(self.view.width() - safe_x, int(width))
            safe_h = min(self.view.height() - safe_y, int(height))
            if safe_w > 0 and safe_h > 0:
                self.view.setMask(QRegion(QRect(safe_x, safe_y, safe_w, safe_h)))

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

    @Slot()
    def answerTeamsCall(self):
        self.sendIpcCmd("TEAMS_ANSWER")

    @Slot()
    def rejectTeamsCall(self):
        self.sendIpcCmd("TEAMS_REJECT")

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

    @Slot(result=list)
    def getBluetoothDevices(self):
        with self._bt_lock:
            return [dict(d) for d in self._cached_bluetooth_devices]

    @Slot(result=bool)
    def isBluetoothPowered(self):
        with self._bt_lock:
            return self._bluetooth_powered

    @Slot(str)
    def connectBluetooth(self, mac):
        def _con():
            if shutil.which("bluetoothctl"):
                subprocess.run(["bluetoothctl", "connect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self._pool.submit(_con)

    @Slot(str)
    def disconnectBluetooth(self, mac):
        def _dis():
            if shutil.which("bluetoothctl"):
                subprocess.run(["bluetoothctl", "disconnect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self._pool.submit(_dis)

    @Slot()
    def openBluetoothSettings(self):
        def _open():
            candidates = ["blueman-manager", "gnome-control-center", "plasma-open-settings", "kcmshell6", "blueberry", "overskride"]
            for cmd in candidates:
                if shutil.which(cmd):
                    if cmd == "gnome-control-center":
                        subprocess.Popen([cmd, "bluetooth"])
                    elif cmd in ("plasma-open-settings", "kcmshell6"):
                        subprocess.Popen([cmd, "kcm_bluetooth"])
                    else:
                        subprocess.Popen([cmd])
                    return
        self._pool.submit(_open)

    # 🚀 安全重构：彻底消除 shell=True 命令注入漏洞
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
                if shutil.which("wmctrl"):
                    if subprocess.run(["wmctrl", "-a", kw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                        return
                if shutil.which("xdotool"):
                    if subprocess.run(["xdotool", "search", "--onlyvisible", "--name", kw, "windowactivate"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                        return
                if shutil.which("hyprctl"):
                    if subprocess.run(["hyprctl", "dispatch", "focuswindow", f"title:(.*{kw}.*)"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                        return
                if shutil.which("swaymsg"):
                    if subprocess.run(["swaymsg", f'[title="(?i).*{kw}.*"] focus'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                        return
        self._pool.submit(_focus)