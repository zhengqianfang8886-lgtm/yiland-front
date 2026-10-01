import sys
import os
import json
import signal
import socket
import time
import asyncio
import threading
import subprocess
import shutil
import re
import hashlib
import urllib.parse
from logger import app_logger, install_qt_log_bridge
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl, QRect, QTimer, Qt, QDateTime, QTimeZone, QByteArray
from PySide6.QtGui import QRegion, QFontDatabase
from PySide6.QtWidgets import QApplication
from PySide6.QtQuick import QQuickView

CONFIG_FILE = os.path.expanduser("~/.config/alcove_island_config.json")
AVATAR_CACHE_DIR = os.path.expanduser("~/.local/state/alcove_island/avatar_cache")

DEFAULT_SAVED_CLOCKS = [
    { "name": "伦敦", "en": "London", "country": "英国", "iso": "GB", "tz": "Europe/London" },
    { "name": "纽约", "en": "New York", "country": "美国", "iso": "US", "tz": "America/New_York" },
    { "name": "旧金山", "en": "San Francisco", "country": "美国", "iso": "US", "tz": "America/Los_Angeles" },
    { "name": "东京", "en": "Tokyo", "country": "日本", "iso": "JP", "tz": "Asia/Tokyo" }
]

def process_notification_avatar(raw_avatar_url: str) -> str:
    if not raw_avatar_url: return ""
    try:
        parsed = urllib.parse.urlparse(raw_avatar_url)
        clean_path = parsed.path if parsed.scheme in ("file", "") else raw_avatar_url
        if parsed.scheme == "file" and not clean_path.startswith("/"): clean_path = "/" + clean_path
        if parsed.scheme in ("http", "https"): return raw_avatar_url
        if not os.path.exists(clean_path): return ""
        os.makedirs(AVATAR_CACHE_DIR, exist_ok=True)
        mtime = os.path.getmtime(clean_path)
        file_hash = hashlib.md5(f"{clean_path}_{mtime}".encode("utf-8")).hexdigest()[:12]
        ext = os.path.splitext(clean_path)[1] or ".png"
        cached_filename = f"avatar_{file_hash}{ext}"
        cached_path = os.path.join(AVATAR_CACHE_DIR, cached_filename)
        if not os.path.exists(cached_path): shutil.copy2(clean_path, cached_path)
        return f"file://{cached_path}"
    except Exception as e:
        app_logger.warning(f"处理头像缓存失败: {e}")
        return ""

def to_compact_speed(speed_str: str) -> str:
    if not speed_str: return "0K"
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
        elif "B" in unit: return "0K"
    return "0K"

def get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception: return "127.0.0.1"

class ConfigManager(QObject):
    timeFormatChanged = Signal(str)
    showSecondsChanged = Signal(bool)
    showDateChanged = Signal(bool)
    topMarginChanged = Signal(int)
    offsetXChanged = Signal(int)
    anchorModeChanged = Signal(str)
    fontFamilyChanged = Signal(str)
    multiIslandExpandDirectionChanged = Signal(str)
    splitGapChanged = Signal(int)

    showNetSpeedChanged = Signal(bool)
    showMediaTabChanged = Signal(bool)
    showCalendarTabChanged = Signal(bool)
    showWorkspaceTabChanged = Signal(bool)
    showNetworkTabChanged = Signal(bool)
    showClockTabChanged = Signal(bool)
    showBluetoothTabChanged = Signal(bool)
    savedClocksChanged = Signal(list)

    def __init__(self):
        super().__init__()
        self._timeFormat = "12h"
        self._showSeconds = False
        self._showDate = False
        self._topMargin = 0
        self._offsetX = 0
        self._anchorMode = "screen"
        self._fontFamily = "系统默认 (Default)"
        self._multiIslandExpandDirection = "right"
        self._splitGap = 8

        self._showNetSpeed = True
        self._showMediaTab = True
        self._showCalendarTab = True
        self._showWorkspaceTab = True
        self._showNetworkTab = True
        self._showClockTab = True
        self._showBluetoothTab = True
        self._savedClocks = list(DEFAULT_SAVED_CLOCKS)

        self._system_fonts = self._load_system_fonts()
        self._world_cities = self._load_world_cities()
        self.load()

    def _load_world_cities(self):
        try:
            base_dir = os.path.dirname(os.path.abspath(__file__))
            json_path = os.path.join(base_dir, "world_cities.json")
            if os.path.exists(json_path):
                with open(json_path, "r", encoding="utf-8") as f: return json.load(f)
        except Exception: pass
        return []

    def _load_system_fonts(self):
        try:
            families = sorted(list(set(QFontDatabase.families())))
            return ["系统默认 (Default)"] + families
        except Exception: return ["系统默认 (Default)"]

    def _migrate_clock_items(self, clock_list):
        if not clock_list or not isinstance(clock_list, list): return list(DEFAULT_SAVED_CLOCKS)
        city_lookup = {c.get("name"): c for c in self._world_cities} if self._world_cities else {}
        migrated = []
        for item in clock_list:
            if not isinstance(item, dict): continue
            if not item.get("tz") and item.get("name") in city_lookup: item = dict(city_lookup[item["name"]])
            migrated.append(item)
        return migrated if migrated else list(DEFAULT_SAVED_CLOCKS)

    def load(self):
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    self._timeFormat = data.get("timeFormat", "12h")
                    self._showSeconds = data.get("showSeconds", False)
                    self._showDate = data.get("showDate", False)
                    self._topMargin = data.get("topMargin", 0)
                    self._offsetX = data.get("offsetX", 0)
                    self._anchorMode = data.get("anchorMode", "screen")
                    self._fontFamily = data.get("fontFamily", "系统默认 (Default)")
                    self._multiIslandExpandDirection = data.get("multiIslandExpandDirection", "right")
                    self._splitGap = data.get("splitGap", 8)
                    self._showNetSpeed = data.get("showNetSpeed", True)
                    self._showMediaTab = data.get("showMediaTab", True)
                    self._showCalendarTab = data.get("showCalendarTab", True)
                    self._showWorkspaceTab = data.get("showWorkspaceTab", True)
                    self._showNetworkTab = data.get("showNetworkTab", True)
                    self._showClockTab = data.get("showClockTab", True)
                    self._showBluetoothTab = data.get("showBluetoothTab", True)
                    self._savedClocks = self._migrate_clock_items(data.get("savedClocks", DEFAULT_SAVED_CLOCKS))
            except Exception: pass

    def save(self):
        try:
            os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump({
                    "timeFormat": self._timeFormat, "showSeconds": self._showSeconds, "showDate": self._showDate,
                    "topMargin": self._topMargin, "offsetX": self._offsetX, "anchorMode": self._anchorMode,
                    "fontFamily": self._fontFamily, "multiIslandExpandDirection": self._multiIslandExpandDirection,
                    "splitGap": self._splitGap, "showNetSpeed": self._showNetSpeed, "showMediaTab": self._showMediaTab,
                    "showCalendarTab": self._showCalendarTab, "showWorkspaceTab": self._showWorkspaceTab,
                    "showNetworkTab": self._showNetworkTab, "showClockTab": self._showClockTab,
                    "showBluetoothTab": self._showBluetoothTab, "savedClocks": self._savedClocks
                }, f, indent=2, ensure_ascii=False)
        except Exception: pass

    @Property(str, notify=timeFormatChanged)
    def timeFormat(self): return self._timeFormat
    @timeFormat.setter
    def timeFormat(self, val):
        if self._timeFormat != val: self._timeFormat = val; self.save(); self.timeFormatChanged.emit(val)

    @Property(bool, notify=showSecondsChanged)
    def showSeconds(self): return self._showSeconds
    @showSeconds.setter
    def showSeconds(self, val):
        if self._showSeconds != val: self._showSeconds = val; self.save(); self.showSecondsChanged.emit(val)

    @Property(bool, notify=showDateChanged)
    def showDate(self): return self._showDate
    @showDate.setter
    def showDate(self, val):
        if self._showDate != val: self._showDate = val; self.save(); self.showDateChanged.emit(val)

    @Property(bool, notify=showNetSpeedChanged)
    def showNetSpeed(self): return self._showNetSpeed
    @showNetSpeed.setter
    def showNetSpeed(self, val):
        if self._showNetSpeed != val: self._showNetSpeed = val; self.save(); self.showNetSpeedChanged.emit(val)

    @Property(bool, notify=showMediaTabChanged)
    def showMediaTab(self): return self._showMediaTab
    @showMediaTab.setter
    def showMediaTab(self, val):
        if self._showMediaTab != val: self._showMediaTab = val; self.save(); self.showMediaTabChanged.emit(val)

    @Property(bool, notify=showCalendarTabChanged)
    def showCalendarTab(self): return self._showCalendarTab
    @showCalendarTab.setter
    def showCalendarTab(self, val):
        if self._showCalendarTab != val: self._showCalendarTab = val; self.save(); self.showCalendarTabChanged.emit(val)

    @Property(bool, notify=showWorkspaceTabChanged)
    def showWorkspaceTab(self): return self._showWorkspaceTab
    @showWorkspaceTab.setter
    def showWorkspaceTab(self, val):
        if self._showWorkspaceTab != val: self._showWorkspaceTab = val; self.save(); self.showWorkspaceTabChanged.emit(val)

    @Property(bool, notify=showNetworkTabChanged)
    def showNetworkTab(self): return self._showNetworkTab
    @showNetworkTab.setter
    def showNetworkTab(self, val):
        if self._showNetworkTab != val: self._showNetworkTab = val; self.save(); self.showNetworkTabChanged.emit(val)

    @Property(bool, notify=showClockTabChanged)
    def showClockTab(self): return self._showClockTab
    @showClockTab.setter
    def showClockTab(self, val):
        if self._showClockTab != val: self._showClockTab = val; self.save(); self.showClockTabChanged.emit(val)

    @Property(bool, notify=showBluetoothTabChanged)
    def showBluetoothTab(self): return self._showBluetoothTab
    @showBluetoothTab.setter
    def showBluetoothTab(self, val):
        if self._showBluetoothTab != val: self._showBluetoothTab = val; self.save(); self.showBluetoothTabChanged.emit(val)

    @Property(int, notify=splitGapChanged)
    def splitGap(self): return self._splitGap
    @splitGap.setter
    def splitGap(self, val):
        val = max(2, min(24, int(val)))
        if self._splitGap != val: self._splitGap = val; self.save(); self.splitGapChanged.emit(val)

    @Property(int, notify=topMarginChanged)
    def topMargin(self): return self._topMargin
    @topMargin.setter
    def topMargin(self, val):
        val = int(val)
        if self._topMargin != val: self._topMargin = val; self.save(); self.topMarginChanged.emit(val)

    @Property(int, notify=offsetXChanged)
    def offsetX(self): return self._offsetX
    @offsetX.setter
    def offsetX(self, val):
        val = int(val)
        if self._offsetX != val: self._offsetX = val; self.save(); self.offsetXChanged.emit(val)

    @Property(str, notify=anchorModeChanged)
    def anchorMode(self): return self._anchorMode
    @anchorMode.setter
    def anchorMode(self, val):
        if self._anchorMode != val: self._anchorMode = val; self.save(); self.anchorModeChanged.emit(val)

    @Property(str, notify=multiIslandExpandDirectionChanged)
    def multiIslandExpandDirection(self): return self._multiIslandExpandDirection
    @multiIslandExpandDirection.setter
    def multiIslandExpandDirection(self, val):
        if self._multiIslandExpandDirection != val:
            self._multiIslandExpandDirection = val
            self.save()
            self.multiIslandExpandDirectionChanged.emit(val)

    @Property(list, notify=savedClocksChanged)
    def savedClocks(self): return self._savedClocks
    @savedClocks.setter
    def savedClocks(self, val):
        if self._savedClocks != val:
            self._savedClocks = list(val)
            self.save()
            self.savedClocksChanged.emit(self._savedClocks)

    @Property(list, constant=True)
    def systemFonts(self): return self._system_fonts
    @Property(list, constant=True)
    def worldCities(self): return self._world_cities
    @Property(str, notify=fontFamilyChanged)
    def fontFamily(self): return self._fontFamily
    @fontFamily.setter
    def fontFamily(self, val):
        if self._fontFamily != val: self._fontFamily = val; self.save(); self.fontFamilyChanged.emit(val)

cmd_queue = None
loop_holder = None

def _sanitize_media_time(val):
    if val is None: return 0.0
    try:
        f = float(val)
        if f <= 0: return 0.0
        if f > 10000000: return f / 1000000.0
        if f > 100000: return f / 1000.0
        return f
    except Exception: return 0.0

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

        self._cached_bluetooth_devices = []
        self._bluetooth_powered = True
        self._known_devices_state = {}
        self._first_poll = True

        self._notification_history = []
        self._unread_count = 0
        self._latest_notif_avatar = ""
        self._cached_ip = get_local_ip()

        self._local_media_timer = QTimer(self)
        self._local_media_timer.setInterval(1000)
        self._local_media_timer.timeout.connect(self._on_local_media_tick)

        self._sig_update_media.connect(self._do_update_media_state)
        self._sig_update_progress.connect(self._do_update_progress_state)
        self._sig_force_raise.connect(self.forceRaise)

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
        if not title and not content: return
        now_str = time.strftime("%H:%M")
        safe_avatar = process_notification_avatar(avatar) if avatar else ""
        item_id = int(time.time() * 1000)
        item = {"id": item_id, "icon": icon or "💬", "title": title or "新通知", "content": content or "", "avatar": safe_avatar, "time": now_str, "read": False}
        with self._notif_lock:
            if self._notification_history:
                top = self._notification_history[0]
                if top.get("title") == title and top.get("content") == content:
                    if (item_id - top.get("id", 0)) < 3000: return
            self._notification_history.insert(0, item)
            if len(self._notification_history) > 15: self._notification_history.pop()
            self._unread_count += 1
            if safe_avatar: self._latest_notif_avatar = safe_avatar
            history_copy = [dict(n) for n in self._notification_history]
            current_unread = self._unread_count
        self.unreadCountChanged.emit(current_unread)
        self.notificationHistoryUpdated.emit(history_copy)

    @Slot(result=list)
    def getNotificationHistory(self):
        with self._notif_lock: return [dict(n) for n in self._notification_history]

    @Slot(result=int)
    def getUnreadNotificationCount(self):
        with self._notif_lock: return self._unread_count

    @Slot(result=str)
    def getLatestNotificationAvatar(self):
        with self._notif_lock: return self._latest_notif_avatar

    @Slot()
    def markAllNotificationsRead(self):
        with self._notif_lock:
            self._unread_count = 0
            for n in self._notification_history: n["read"] = True
            history_copy = [dict(n) for n in self._notification_history]
        self.unreadCountChanged.emit(0)
        self.notificationHistoryUpdated.emit(history_copy)

    @Slot()
    def clearNotificationHistory(self):
        with self._notif_lock:
            self._notification_history = []
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
            if not self._local_media_timer.isActive(): self._local_media_timer.start()
        else: self._local_media_timer.stop()
        self.mediaUpdated.emit(title, artist, status, art, pos, dur)

    @Slot(float, float, float)
    def _do_update_progress_state(self, pos, dur, prog):
        if self._curr_status == "Playing" and self._curr_dur > 0:
            if pos >= self._curr_dur and (self._curr_dur - self._curr_pos > 5): return
        if dur > 0: self._curr_dur = dur
        if pos > 0: self._curr_pos = pos
        self.progressUpdated.emit(self._curr_pos, self._curr_dur, prog)

    @Slot()
    def forceRaise(self): self.view.raise_()
    @Slot()
    def requestWindowFocus(self): self.view.requestActivate(); self.view.raise_()

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
        global cmd_queue, loop_holder
        if cmd_queue and loop_holder:
            payload = json.dumps({"action": action, **kwargs})
            asyncio.run_coroutine_threadsafe(cmd_queue.put(payload), loop_holder)

    @Slot(str)
    def sendMediaCmd(self, action: str): self.sendIpcCmd(action)

    # ================= 虚拟桌面切换核心槽函数（全域循环） =================
    @Slot(int)
    @Slot(str)
    def switchWorkspace(self, target):
        self.sendIpcCmd("WORKSPACE_SWITCH", target=target)

    # 🚀 环形循环切上一个桌面
    @Slot()
    def switchWorkspacePrev(self):
        self.sendIpcCmd("WORKSPACE_PREV")

    # 🚀 环形循环切下一个桌面
    @Slot()
    def switchWorkspaceNext(self):
        self.sendIpcCmd("WORKSPACE_NEXT")

    @Slot()
    def answerTeamsCall(self): self.sendIpcCmd("TEAMS_ANSWER")
    @Slot()
    def rejectTeamsCall(self): self.sendIpcCmd("TEAMS_REJECT")
    @Slot()
    def focusTeamsWindow(self): self.sendIpcCmd("TEAMS_FOCUS")

    @Slot(str, bool, result=dict)
    def getWorldTime(self, tz_name, is_24h=True):
        try:
            tz = QTimeZone(QByteArray(tz_name.encode("utf-8"))) if tz_name else QTimeZone.systemTimeZone()
            if not tz.isValid(): tz = QTimeZone.systemTimeZone()
            now_utc = QDateTime.currentDateTimeUtc()
            target_dt = now_utc.toTimeZone(tz)
            local_dt = QDateTime.currentDateTime()
            local_tz = QTimeZone.systemTimeZone()
            h = target_dt.time().hour(); m = target_dt.time().minute()
            time_str = f"{h:02d}:{m:02d}" if is_24h else f"{h%12 or 12:02d}:{m:02d}{' PM' if h>=12 else ' AM'}"
            diff_hours = round((tz.offsetFromUtc(now_utc) - local_tz.offsetFromUtc(now_utc)) / 3600.0, 1)
            day_diff = local_dt.date().daysTo(target_dt.date())
            day_str = "今天" if day_diff == 0 else ("明天" if day_diff > 0 else "昨天")
            diff_str = "与本地同时" if diff_hours == 0 else (f"快 {diff_hours:g}h · {day_str}" if diff_hours > 0 else f"慢 {abs(diff_hours):g}h · {day_str}")
            return {"time": time_str, "diff": diff_str, "isDay": 6 <= h < 18, "isWorking": 9 <= h < 18}
        except Exception: return {"time": "--:--", "diff": "", "isDay": True, "isWorking": False}

    @Slot(str, result=str)
    def getTzOffsetStr(self, tz_name):
        try:
            tz = QTimeZone(QByteArray(tz_name.encode("utf-8"))) if tz_name else None
            if not tz or not tz.isValid(): return "UTC"
            off_sec = tz.offsetFromUtc(QDateTime.currentDateTimeUtc())
            off_h = off_sec // 3600; off_m = abs((off_sec % 3600) // 60)
            sign = "+" if off_sec >= 0 else ""
            return f"UTC{sign}{off_h}" if off_m == 0 else f"UTC{sign}{off_h}:{off_m:02d}"
        except Exception: return "UTC"

    @Slot(result=list)
    def getBluetoothDevices(self):
        with self._bt_lock: return [dict(d) for d in self._cached_bluetooth_devices]

    @Slot(result=bool)
    def isBluetoothPowered(self):
        with self._bt_lock: return self._bluetooth_powered

    @Slot(str)
    def connectBluetooth(self, mac):
        def _con():
            if shutil.which("bluetoothctl"): subprocess.run(["bluetoothctl", "connect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        threading.Thread(target=_con, daemon=True).start()

    @Slot(str)
    def disconnectBluetooth(self, mac):
        def _dis():
            if shutil.which("bluetoothctl"): subprocess.run(["bluetoothctl", "disconnect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        threading.Thread(target=_dis, daemon=True).start()

    @Slot()
    def openBluetoothSettings(self):
        def _open():
            for cmd in ["blueman-manager", "gnome-control-center bluetooth", "plasma-open-settings kcm_bluetooth", "kcmshell6 kcm_bluetooth", "blueberry", "overskride"]:
                if shutil.which(cmd.split()[0]): subprocess.Popen(cmd, shell=True); return
        threading.Thread(target=_open, daemon=True).start()

    @Slot(str, str)
    def focusMediaWindow(self, title="", artist=""):
        def _focus():
            search_terms = []
            if title and title != "等待播放...":
                clean_title = title.split(" - ")[0].split("—")[0].strip()
                if len(clean_title) >= 2: search_terms.append(clean_title)
            if artist and artist != "未知歌手": search_terms.append(artist.strip())
            players = ["Spotify", "netease-cloud-music", "yesplaymusic", "qqmusic", "QQMusic", "music", "VLC", "Chrome", "Chromium", "Firefox"]
            candidates = search_terms + players
            if shutil.which("wmctrl"):
                for kw in candidates:
                    if kw and subprocess.run(["wmctrl", "-a", kw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0: return
            if shutil.which("xdotool"):
                for kw in candidates[:4]:
                    if kw and subprocess.run(f"xdotool search --onlyvisible --name '{kw}' windowactivate", shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0: return
            if shutil.which("hyprctl"):
                for kw in candidates[:4]:
                    if kw and subprocess.run(["hyprctl", "dispatch", "focuswindow", f"title:(.*{kw}.*)"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0: return
            if shutil.which("swaymsg"):
                for kw in candidates[:4]:
                    if kw and subprocess.run(["swaymsg", f'[title="(?i).*{kw}.*"] focus'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0: return
        threading.Thread(target=_focus, daemon=True).start()

def ws_worker(bridge: IslandBridge):
    global cmd_queue, loop_holder
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop_holder = loop
    cmd_queue = asyncio.Queue()

    async def run():
        import websockets
        uri = "ws://127.0.0.1:8765"
        while True:
            try:
                async with websockets.connect(uri) as ws:
                    app_logger.info(f"[WS] 成功直连灵动岛后端 D-Bus 守护服务: {uri}")
                    async def sender():
                        while True:
                            msg = await cmd_queue.get()
                            await ws.send(msg)
                            cmd_queue.task_done()

                    async def receiver():
                        async for message in ws:
                            try:
                                msg = json.loads(message)
                                m_type = msg.get("type", "")
                                data = msg.get("data", {})

                                if m_type in ("MEDIA_PROGRESS", "MEDIA_TICK") and "media" in data:
                                    m = data["media"]
                                    pos = _sanitize_media_time(m.get("position"))
                                    dur = _sanitize_media_time(m.get("duration"))
                                    raw_prog = m.get("progress")
                                    prog = float(raw_prog) if raw_prog is not None else (pos / dur if dur > 0 else 0.0)
                                    bridge.update_progress_state(pos, dur, min(1.0, max(0.0, prog)))

                                elif m_type in ("MEDIA_UPDATE", "FULL_SYNC") and "media" in data:
                                    m = data["media"]
                                    art = m.get("art_url", "")
                                    if art and art.startswith("/") and not art.startswith("file://"): art = "file://" + art
                                    pos = _sanitize_media_time(m.get("position", 0.0))
                                    dur = _sanitize_media_time(m.get("duration", 0.0))
                                    bridge.update_media_state(m.get("title", "等待播放..."), m.get("artist", "未知歌手"), m.get("status", "Paused"), art, pos, dur)

                                if m_type in ("WORKSPACE_CHANGED", "FULL_SYNC") and "workspace" in data:
                                    ws_info = data["workspace"]
                                    bridge.workspaceTriggered.emit(int(ws_info.get("current_index", 1)), int(ws_info.get("total", 4)), str(ws_info.get("current_name", "")))
                                    if "list" in ws_info:
                                        bridge.workspaceListUpdated.emit(ws_info.get("list", []))

                                if m_type == "VOLUME_UPDATE" and "system" in data:
                                    sys_info = data["system"]
                                    bridge.osdTriggered.emit("🔇" if sys_info.get("muted", False) else "🔊", "Volume", int(sys_info.get("volume", 50)))
                                elif m_type == "BRIGHTNESS_UPDATE" and "system" in data:
                                    bridge.osdTriggered.emit("☀️", "Display", int(data["system"].get("brightness", 50)))

                                if "bluetooth" in data:
                                    b_info = data["bluetooth"]
                                    devices = b_info.get("connected_devices", [])
                                    powered = b_info.get("powered", True)
                                    alerts_to_emit = []
                                    with bridge._bt_lock:
                                        bridge._bluetooth_powered = powered
                                        bridge._cached_bluetooth_devices = devices
                                        if not bridge._first_poll and m_type in ("BLUETOOTH_CONNECT", "BLUETOOTH_DISCONNECT", "BLUETOOTH_BATTERY"):
                                            for dev in devices:
                                                mac = dev.get("mac"); conn = dev.get("connected", False); bat = dev.get("battery"); name = dev.get("name", "蓝牙设备")
                                                prev_conn, _ = bridge._known_devices_state.get(mac, (None, None))
                                                if prev_conn is not None and prev_conn != conn:
                                                    emoji = "🎧" if any(w in name.lower() for w in ["buds", "pods", "wh-", "head", "audio"]) else "蓝牙"
                                                    alerts_to_emit.append((emoji, name, f"已连接 · 🔋 电量 {bat}%" if (conn and bat is not None) else ("已连接" if conn else "已断开连接"), 2500, ""))
                                                bridge._known_devices_state[mac] = (conn, bat)
                                        else:
                                            for dev in devices: bridge._known_devices_state[dev.get("mac")] = (dev.get("connected", False), dev.get("battery"))
                                        bridge._first_poll = False
                                        devices_copy = [dict(d) for d in devices]
                                    bridge.bluetoothStateChanged.emit(powered)
                                    bridge.bluetoothUpdated.emit(devices_copy)
                                    for alert in alerts_to_emit: bridge.alertTriggered.emit(*alert)

                                if "network" in data:
                                    net_info = data["network"]
                                    rx_str = net_info.get("rx_speed", "0 B/s"); tx_str = net_info.get("tx_speed", "0 B/s")
                                    bridge.netSpeedUpdated.emit(rx_str, tx_str, to_compact_speed(rx_str), to_compact_speed(tx_str), bridge._cached_ip)
                                    if m_type == "VPN_CONNECTED": bridge.alertTriggered.emit("🛡️", "VPN 安全网络已接入", net_info.get("vpn_name", "VPN Active"), 2000, "")
                                    elif m_type == "VPN_DISCONNECTED": bridge.alertTriggered.emit("⚠️", "VPN 网络已断开", "恢复公网直连模式", 2000, "")

                                if m_type in ("TEAMS_NOTIFICATION", "BROWSER_NOTIFICATION", "TEAMS_CALL_INCOMING"):
                                    if "notification" in data:
                                        noti = data["notification"]
                                        t_title = noti.get("title", "").strip(); t_sub = noti.get("content", "").strip()
                                        safe_avatar = process_notification_avatar(noti.get("avatar", ""))
                                        if t_title or t_sub:
                                            bridge.add_notification(noti.get("icon", "💬"), t_title, t_sub, safe_avatar)
                                            if m_type == "TEAMS_CALL_INCOMING":
                                                bridge.alertTriggered.emit(noti.get("icon", "📞"), t_title, t_sub or "正在呼叫...", 0, safe_avatar)
                                                bridge.safe_force_raise()
                                            else:
                                                bridge.alertTriggered.emit(noti.get("icon", "🔔"), t_title, t_sub, 4500, safe_avatar)

                                elif m_type == "TEAMS_CALL_ENDED":
                                    if "notification" in data:
                                        noti = data["notification"]
                                        bridge.alertTriggered.emit("📞", noti.get("title", "") or "Teams 通话", noti.get("content", "") or "呼叫已完成", 1500, "")
                                    bridge.callEndedTriggered.emit()

                                bridge.syncDataUpdated.emit(data)
                            except Exception as err:
                                app_logger.error(f"[WS] 消息解析异常: {err}")

                    await asyncio.gather(sender(), receiver())
            except Exception:
                await asyncio.sleep(2)
    loop.run_until_complete(run())

def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    install_qt_log_bridge()
    app_logger.info("Alcove Island 前端渲染引擎启动中...")
    app = QApplication(sys.argv)
    config = ConfigManager()

    sigint_timer = QTimer(); sigint_timer.start(300); sigint_timer.timeout.connect(lambda: None)
    view = QQuickView()
    view.setColor("transparent")
    view.setFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
    bridge = IslandBridge(view)
    window_width, window_height = 720, 270

    def update_view_position():
        screen = app.primaryScreen()
        base_rect = screen.geometry() if config.anchorMode == "screen" else screen.availableGeometry()
        view.setGeometry(base_rect.x() + (base_rect.width() - window_width) // 2 + config.offsetX, base_rect.y() + config.topMargin, window_width, window_height)

    update_view_position()
    config.topMarginChanged.connect(lambda _: update_view_position())
    config.offsetXChanged.connect(lambda _: update_view_position())
    config.anchorModeChanged.connect(lambda _: update_view_position())

    view.rootContext().setContextProperty("Bridge", bridge)
    view.rootContext().setContextProperty("Config", config)
    view.rootContext().setContextProperty("WorldCities", config.worldCities)

    base_dir = os.path.dirname(os.path.abspath(__file__))
    view.setSource(QUrl.fromLocalFile(os.path.join(base_dir, "Island.qml")))
    view.show()

    threading.Thread(target=ws_worker, args=(bridge,), daemon=True).start()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()