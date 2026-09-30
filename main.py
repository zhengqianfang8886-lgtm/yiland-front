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

    @Slot()
    def forceRaise(self):
        self.view.raise_()

    @Slot(int, int, int, int)
    def updateMask(self, x, y, width, height):
        if width > 0 and height > 0:
            region = QRegion(QRect(x, y, width, height))
            self.view.setMask(region)

    @Slot(str)
    def sendMediaCmd(self, action):
        global cmd_queue, loop_holder
        if cmd_queue and loop_holder:
            payload = json.dumps({"action": action})
            asyncio.run_coroutine_threadsafe(cmd_queue.put(payload), loop_holder)

    @Slot()
    def focusTeamsWindow(self):
        """Teams 穿梭门：跨虚拟桌面定位并激活 Teams / Chrome 通话窗口"""
        def _focus():
            import subprocess, shutil
            app_logger.info("[Portal] 穿梭门触发：正在跨桌面搜寻并聚焦 Teams 窗口...")
            # 1. 优先尝试 wmctrl (X11/XWayland 标准工具：-a 参数自动跨桌面切换并激活窗口)
            if shutil.which("wmctrl"):
                for kw in ["Teams", "Microsoft Teams"]:
                    if subprocess.run(["wmctrl", "-a", kw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                        app_logger.info(f"[Portal] 成功通过 wmctrl 唤起窗口: {kw}")
                        return
            # 2. 尝试 xdotool
            if shutil.which("xdotool"):
                if subprocess.run(["xdotool", "search", "--onlyvisible", "--name", "Teams", "windowactivate"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                    app_logger.info("[Portal] 成功通过 xdotool 唤起 Teams")
                    return
            # 3. 兼容 Wayland 原生合流器 (Hyprland / Sway)
            if shutil.which("hyprctl"):
                if subprocess.run(["hyprctl", "dispatch", "focuswindow", "title:(.*Teams.*)"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                    app_logger.info("[Portal] 成功通过 hyprctl 聚焦 Teams")
                    return
            if shutil.which("swaymsg"):
                if subprocess.run(["swaymsg", '[title="(?i).*teams.*"] focus'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                    app_logger.info("[Portal] 成功通过 swaymsg 聚焦 Teams")
                    return
            app_logger.warning("[Portal] 未搜寻到处于运行状态的 Teams / Chrome 窗口")

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
                app_logger.debug(f"[WS] 正在尝试连接 WebSocket: {uri} ...")
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

                                if m_type == "MEDIA_PROGRESS" and "media" in data:
                                    m = data["media"]
                                    pos = float(m.get("position", 0.0) or 0.0)
                                    dur = float(m.get("duration", 0.0) or 0.0)
                                    prog = float(m.get("progress", 0.0) or (pos / dur if dur > 0 else 0.0))
                                    bridge.progressUpdated.emit(pos, dur, prog)

                                elif m_type in ("MEDIA_UPDATE", "FULL_SYNC") and "media" in data:
                                    m = data["media"]
                                    art = m.get("art_url", "")
                                    if art and art.startswith("/") and not art.startswith("file://"):
                                        art = "file://" + art
                                    pos = float(m.get("position", 0.0) or 0.0)
                                    dur = float(m.get("duration", 0.0) or 0.0)
                                    bridge.mediaUpdated.emit(
                                        m.get("title", "等待播放..."),
                                        m.get("artist", "未知歌手"),
                                        m.get("status", "Paused"),
                                        art, pos, dur
                                    )

                                if m_type == "WORKSPACE_CHANGED" and "workspace" in data:
                                    ws_info = data["workspace"]
                                    c_idx = int(ws_info.get("current_index", 1))
                                    t_tot = int(ws_info.get("total", 4))
                                    c_name = str(ws_info.get("current_name", ""))
                                    app_logger.info(f"\033[1;33m[DIAG-WS] 收到切屏事件 -> Index:{c_idx}, Total:{t_tot}, Name:'{c_name}'\033[0m")
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
                app_logger.warning(f"[WS] 连接异常断开: {e}，2秒后尝试重连...")
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
    view.setFlags(
        Qt.FramelessWindowHint 
        | Qt.WindowStaysOnTopHint 
        | Qt.Tool
        | Qt.BypassWindowManagerHint
        | Qt.WindowDoesNotAcceptFocus
    )

    bridge = IslandBridge(view)
    window_width, window_height = 420, 240

    def update_view_position():
        screen = app.primaryScreen()
        base_rect = screen.geometry() if config.anchorMode == "screen" else screen.availableGeometry()
        target_x = base_rect.x() + (base_rect.width() - window_width) // 2 + config.offsetX
        target_y = base_rect.y() + config.topMargin
        view.setGeometry(target_x, target_y, window_width, window_height)
        app_logger.info(f"[Window] 物理窗口已定位 -> X:{target_x}, Y:{target_y} (基准: {config.anchorMode}, 顶距: {config.topMargin})")

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
