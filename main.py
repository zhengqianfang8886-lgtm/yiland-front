import sys
import os
import json
import signal
import asyncio
import threading
from logger import app_logger, install_qt_log_bridge
from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl, QRect, QTimer, Qt
from PySide6.QtGui import QRegion, QFontDatabase
from PySide6.QtWidgets import QApplication
from PySide6.QtQuick import QQuickView

CONFIG_FILE = os.path.expanduser("~/.config/alcove_island_config.json")

class ConfigManager(QObject):
    timeFormatChanged = Signal(str)
    showSecondsChanged = Signal(bool)
    showDateChanged = Signal(bool)
    topMarginChanged = Signal(int)
    offsetXChanged = Signal(int)
    anchorModeChanged = Signal(str)
    fontFamilyChanged = Signal(str)

    def __init__(self):
        super().__init__()
        self._timeFormat = "12h"
        self._showSeconds = False
        self._showDate = False
        self._topMargin = 0
        self._offsetX = 0
        self._anchorMode = "screen"
        self._fontFamily = "系统默认 (Default)"
        self._system_fonts = self._load_system_fonts()
        self.load()

    def _load_system_fonts(self):
        try:
            families = sorted(list(set(QFontDatabase.families())))
            return ["系统默认 (Default)"] + families
        except Exception as e:
            app_logger.warning(f"获取系统字体失败: {e}")
            return ["系统默认 (Default)"]

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
            except Exception as e:
                app_logger.error(f"[Config] 加载配置失败: {e}")

    def save(self):
        try:
            os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump({
                    "timeFormat": self._timeFormat,
                    "showSeconds": self._showSeconds,
                    "showDate": self._showDate,
                    "topMargin": self._topMargin,
                    "offsetX": self._offsetX,
                    "anchorMode": self._anchorMode,
                    "fontFamily": self._fontFamily
                }, f, indent=2)
            app_logger.info(f"[Config] 配置已持久化 -> font={self._fontFamily}")
        except Exception as e:
            app_logger.error(f"[Config] 保存配置失败: {e}")

    @Property(str, notify=timeFormatChanged)
    def timeFormat(self):
        return self._timeFormat

    @timeFormat.setter
    def timeFormat(self, val):
        if self._timeFormat != val:
            self._timeFormat = val
            self.save()
            self.timeFormatChanged.emit(val)

    @Property(bool, notify=showSecondsChanged)
    def showSeconds(self):
        return self._showSeconds

    @showSeconds.setter
    def showSeconds(self, val):
        if self._showSeconds != val:
            self._showSeconds = val
            self.save()
            self.showSecondsChanged.emit(val)

    @Property(bool, notify=showDateChanged)
    def showDate(self):
        return self._showDate

    @showDate.setter
    def showDate(self, val):
        if self._showDate != val:
            self._showDate = val
            self.save()
            self.showDateChanged.emit(val)

    @Property(int, notify=topMarginChanged)
    def topMargin(self):
        return self._topMargin

    @topMargin.setter
    def topMargin(self, val):
        val = int(val)
        if self._topMargin != val:
            self._topMargin = val
            self.save()
            self.topMarginChanged.emit(val)

    @Property(int, notify=offsetXChanged)
    def offsetX(self):
        return self._offsetX

    @offsetX.setter
    def offsetX(self, val):
        val = int(val)
        if self._offsetX != val:
            self._offsetX = val
            self.save()
            self.offsetXChanged.emit(val)

    @Property(str, notify=anchorModeChanged)
    def anchorMode(self):
        return self._anchorMode

    @anchorMode.setter
    def anchorMode(self, val):
        if self._anchorMode != val:
            self._anchorMode = val
            self.save()
            self.anchorModeChanged.emit(val)

    @Property(list, constant=True)
    def systemFonts(self):
        return self._system_fonts

    @Property(str, notify=fontFamilyChanged)
    def fontFamily(self):
        return self._fontFamily

    @fontFamily.setter
    def fontFamily(self, val):
        if self._fontFamily != val:
            self._fontFamily = val
            self.save()
            self.fontFamilyChanged.emit(val)

cmd_queue = None
loop_holder = None

def _sanitize_media_time(val):
    """自适应媒体时间单位清洗器：微秒(us) -> 毫秒(ms) -> 秒(s)"""
    if val is None:
        return 0.0
    try:
        f = float(val)
        if f <= 0:
            return 0.0
        # 大于 1000 万：必为微秒 (MPRIS 原生规范，如 240,000,000us -> 240s)
        if f > 10000000:
            return f / 1000000.0
        # 大于 10 万且小于 1000 万：大概率为毫秒
        if f > 100000:
            return f / 1000.0
        return f
    except (ValueError, TypeError):
        return 0.0

class IslandBridge(QObject):
    mediaUpdated = Signal(str, str, str, str, float, float)
    progressUpdated = Signal(float, float, float)
    osdTriggered = Signal(str, str, int)
    workspaceTriggered = Signal(int, int, str)
    alertTriggered = Signal(str, str, str, int, str)
    callEndedTriggered = Signal()
    syncDataUpdated = Signal("QVariantMap")

    def __init__(self, view):
        super().__init__()
        self.view = view

        # 核心：本地平滑递增心跳机制 (Local Interpolation)
        self._curr_pos = 0.0
        self._curr_dur = 0.0
        self._curr_status = "Paused"

        self._local_media_timer = QTimer(self)
        self._local_media_timer.setInterval(1000)
        self._local_media_timer.timeout.connect(self._on_local_media_tick)

    def _on_local_media_tick(self):
        """当处于播放状态时，即使后台没有上报游标，本地自动每秒前进 1 秒"""
        if self._curr_status == "Playing" and self._curr_dur > 0:
            if self._curr_pos < self._curr_dur:
                self._curr_pos += 1.0
                prog = min(1.0, max(0.0, self._curr_pos / self._curr_dur))
                self.progressUpdated.emit(self._curr_pos, self._curr_dur, prog)

    def update_media_state(self, title, artist, status, art, pos, dur):
        self._curr_status = status
        self._curr_dur = dur
        self._curr_pos = pos

        if status == "Playing":
            if not self._local_media_timer.isActive():
                self._local_media_timer.start()
        else:
            self._local_media_timer.stop()

        self.mediaUpdated.emit(title, artist, status, art, pos, dur)

    def update_progress_state(self, pos, dur, prog):
        # 防溢出防火墙：如果正在播放，而收到 pos >= dur，直接忽略这次假的满格
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
                region = QRegion(QRect(safe_x, safe_y, safe_w, safe_h))
                self.view.setMask(region)

    @Slot(str)
    def sendMediaCmd(self, action):
        global cmd_queue, loop_holder
        if cmd_queue and loop_holder:
            payload = json.dumps({"action": action})
            asyncio.run_coroutine_threadsafe(cmd_queue.put(payload), loop_holder)

    @Slot(str, str)
    def focusMediaWindow(self, title="", artist=""):
        def _focus():
            import subprocess, shutil
            search_terms = []
            if title and title != "等待播放...":
                clean_title = title.split(" - ")[0].split("—")[0].strip()
                if len(clean_title) >= 2:
                    search_terms.append(clean_title)
            if artist and artist != "未知歌手":
                search_terms.append(artist.strip())

            players = ["Spotify", "netease-cloud-music", "yesplaymusic", "qqmusic", "QQMusic", "music", "VLC", "Chrome", "Chromium", "Firefox"]
            candidates = search_terms + players

            if shutil.which("wmctrl"):
                for kw in candidates:
                    if not kw: continue
                    if subprocess.run(["wmctrl", "-a", kw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                        return
            if shutil.which("xdotool"):
                for kw in candidates[:4]:
                    if not kw: continue
                    cmd = f"xdotool search --onlyvisible --name '{kw}' windowactivate"
                    if subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                        return
            if shutil.which("hyprctl"):
                for kw in candidates[:4]:
                    if not kw: continue
                    if subprocess.run(["hyprctl", "dispatch", "focuswindow", f"title:(.*{kw}.*)"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                        return
            if shutil.which("swaymsg"):
                for kw in candidates[:4]:
                    if not kw: continue
                    if subprocess.run(["swaymsg", f'[title="(?i).*{kw}.*"] focus'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                        return

        threading.Thread(target=_focus, daemon=True).start()

    @Slot()
    def focusTeamsWindow(self):
        def _focus():
            import subprocess, shutil
            if shutil.which("wmctrl"):
                for kw in ["Teams", "Microsoft Teams"]:
                    if subprocess.run(["wmctrl", "-a", kw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                        return
            if shutil.which("xdotool"):
                if subprocess.run(["xdotool", "search", "--onlyvisible", "--name", "Teams", "windowactivate"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                    return
            if shutil.which("hyprctl"):
                if subprocess.run(["hyprctl", "dispatch", "focuswindow", "title:(.*Teams.*)"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                    return
            if shutil.which("swaymsg"):
                if subprocess.run(["swaymsg", '[title="(?i).*teams.*"] focus'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                    return

        threading.Thread(target=_focus, daemon=True).start()

def ws_worker(bridge):
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
                    app_logger.info(f"[WS] 连接成功: {uri}")
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

                                # 核心：强制标准输出打印，确保终端 100% 可见
                                # if "media" in data or "MEDIA" in m_type:
                                    # print(f"\033[1;36m[WS-RECV] type={m_type} | media={data.get('media')}\033[0m", flush=True)

                                if m_type == "MEDIA_PROGRESS" and "media" in data:
                                    m = data["media"]
                                    raw_pos = m.get("position")
                                    raw_dur = m.get("duration")

                                    pos = _sanitize_media_time(raw_pos)
                                    dur = _sanitize_media_time(raw_dur)

                                    raw_prog = m.get("progress")
                                    prog = float(raw_prog) if raw_prog is not None else (pos / dur if dur > 0 else 0.0)
                                    prog = min(1.0, max(0.0, prog))

                                    # 如果后端广播了进度百分比（如 0.74），通过百分比精确还原真实的秒数
                                    if dur > 0 and pos >= dur and 0.0 < prog < 0.999:
                                        pos = dur * prog

                                    bridge.update_progress_state(pos, dur, prog)

                                elif m_type in ("MEDIA_UPDATE", "FULL_SYNC") and "media" in data:
                                    m = data["media"]
                                    art = m.get("art_url", "")
                                    if art and art.startswith("/") and not art.startswith("file://"):
                                        art = "file://" + art

                                    pos = _sanitize_media_time(m.get("position", 0.0))
                                    dur = _sanitize_media_time(m.get("duration", 0.0))
                                    status = m.get("status", "Paused")

                                    raw_prog = m.get("progress")
                                    if raw_prog is not None and dur > 0 and pos >= dur:
                                        p_val = float(raw_prog)
                                        if 0.0 < p_val < 0.999:
                                            pos = dur * p_val

                                    bridge.update_media_state(
                                        m.get("title", "等待播放..."),
                                        m.get("artist", "未知歌手"),
                                        status,
                                        art, pos, dur
                                    )

                                if m_type == "WORKSPACE_CHANGED" and "workspace" in data:
                                    ws_info = data["workspace"]
                                    c_idx = int(ws_info.get("current_index", 1))
                                    t_tot = int(ws_info.get("total", 4))
                                    c_name = str(ws_info.get("current_name", ""))
                                    bridge.workspaceTriggered.emit(c_idx, t_tot, c_name)

                                if m_type == "VOLUME_UPDATE" and "system" in data:
                                    sys_info = data["system"]
                                    vol = int(sys_info.get("volume", 50))
                                    icon = "🔇" if sys_info.get("muted", False) else "🔊"
                                    bridge.osdTriggered.emit(icon, "Volume", vol)
                                elif m_type == "BRIGHTNESS_UPDATE" and "system" in data:
                                    bri = int(data["system"].get("brightness", 50))
                                    bridge.osdTriggered.emit("☀️", "Display", bri)

                                if m_type == "BLUETOOTH_CONNECT" and "bluetooth" in data:
                                    devices = data["bluetooth"].get("connected_devices", [])
                                    if devices:
                                        dev = devices[0]
                                        sub = f"已连接 · 电量 {dev.get('battery', 100)}%" if dev.get('battery') is not None else "已连接"
                                        bridge.alertTriggered.emit("🎧", dev.get("name", "蓝牙设备"), sub, 2500, "")

                                if m_type == "VPN_CONNECTED" and "network" in data:
                                    net = data["network"]
                                    bridge.alertTriggered.emit("🛡️", "VPN 安全网络已接入", net.get("vpn_name", "VPN Active"), 2000, "")

                                if "notification" in data:
                                    noti = data["notification"]
                                    n_title = noti.get("title", "")
                                    n_content = noti.get("content", "")
                                    n_icon = noti.get("icon", "🔔")
                                    n_avatar = noti.get("avatar", "")
                                    if n_avatar:
                                        raw_p = n_avatar.replace("file://", "")
                                        import time
                                        n_avatar = f"file://{raw_p}?t={int(time.time()*1000)}"

                                    if m_type == "TEAMS_CALL_INCOMING":
                                        bridge.alertTriggered.emit(n_icon, n_title, n_content or "正在呼叫...", 0, n_avatar)
                                        bridge.forceRaise()
                                    elif m_type == "TEAMS_CALL_ENDED":
                                        bridge.alertTriggered.emit("📞", n_title or "Teams 通话", n_content or "呼叫已完成", 1500, "")
                                        bridge.callEndedTriggered.emit()
                                    elif m_type in ("TEAMS_NOTIFICATION", "BROWSER_NOTIFICATION"):
                                        bridge.alertTriggered.emit(n_icon, n_title, n_content, 4500, n_avatar)

                                bridge.syncDataUpdated.emit(data)

                            except Exception as err:
                                app_logger.error(f"[WS] 消息解析错误: {err}")

                    await asyncio.gather(sender(), receiver())
            except Exception as e:
                await asyncio.sleep(2)

    loop.run_until_complete(run())

def main():
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    install_qt_log_bridge()
    app_logger.info("Alcove Island 灵动岛核心启动中...")
    app = QApplication(sys.argv)
    config = ConfigManager()

    sigint_timer = QTimer()
    sigint_timer.start(300)
    sigint_timer.timeout.connect(lambda: None)

    view = QQuickView()
    view.setColor("transparent")

    # 移除禁止焦点属性
    view.setFlags(
        Qt.FramelessWindowHint 
        | Qt.WindowStaysOnTopHint 
        | Qt.Tool
    )

    bridge = IslandBridge(view)
    window_width, window_height = 460, 270

    def update_view_position():
        screen = app.primaryScreen()
        base_rect = screen.geometry() if config.anchorMode == "screen" else screen.availableGeometry()
        target_x = base_rect.x() + (base_rect.width() - window_width) // 2 + config.offsetX
        target_y = base_rect.y() + config.topMargin
        view.setGeometry(target_x, target_y, window_width, window_height)

    update_view_position()
    config.topMarginChanged.connect(lambda _: update_view_position())
    config.offsetXChanged.connect(lambda _: update_view_position())
    config.anchorModeChanged.connect(lambda _: update_view_position())

    view.rootContext().setContextProperty("Bridge", bridge)
    view.rootContext().setContextProperty("Config", config)

    base_dir = os.path.dirname(os.path.abspath(__file__))
    view.setSource(QUrl.fromLocalFile(os.path.join(base_dir, "Island.qml")))
    view.show()

    t = threading.Thread(target=ws_worker, args=(bridge,), daemon=True)
    t.start()

    sys.exit(app.exec())

if __name__ == "__main__":
    main()