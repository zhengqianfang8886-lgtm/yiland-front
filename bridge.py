# ==========================================
# 📄 File: bridge.py (已修复 QWidget 崩溃与选择器超时)
# ==========================================
import os
import gc
import json
import time
import atexit
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor

from PySide6.QtCore import QObject, Signal, Slot, Property, Qt
from logger import app_logger
from models import NotificationListModel, BluetoothListModel, ProcessListModel
from services import (
    HardwareService,
    MediaService,
    WindowManagerService,
    TypingFlowService,
    get_world_time,
    get_tz_offset_str,
    process_notification_avatar,
    to_compact_speed,
    get_local_ip,
)
from services.process_mgr import ProcessManagerService


class IslandBridge(QObject):
    mediaUpdated = Signal(str, str, str, str, float, float)
    progressUpdated = Signal(float, float, float)
    audioSpectrumUpdated = Signal(float, float, float, float)
    dominantColorUpdated = Signal(str)

    typingSpectrumUpdated = Signal(bool, str, float, float, float, float, float)

    osdTriggered = Signal(str, str, int)
    hardwareMuteStateChanged = Signal(bool, bool)
    volumeChanged = Signal(int)
    brightnessChanged = Signal(int)
    capsLockChanged = Signal(bool)
    numLockChanged = Signal(bool)
    memoryUpdated = Signal(int, str, str)
    clipboardTriggered = Signal(str, str, str, int)

    workspaceTriggered = Signal(int, int, str)
    workspaceListUpdated = Signal("QVariantList")
    alertTriggered = Signal(str, str, str, int, str)
    callIncomingTriggered = Signal(str, str, str)
    callEndedTriggered = Signal()
    syncDataUpdated = Signal("QVariantMap")
    netSpeedUpdated = Signal(str, str, str, str, str)
    bluetoothStateChanged = Signal(bool)
    unreadCountChanged = Signal(int)

    _sig_daemon_payload = Signal(str, str)

    def __init__(self, view, config=None):
        super().__init__()
        self.view = view
        self.config = config
        self._ipc_sender = None
        self._pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="SubprocessWorker")

        self._notif_model = NotificationListModel(self)
        self._bt_model = BluetoothListModel(self)
        self._notif_model.unreadCountChanged.connect(self.unreadCountChanged)

        self.proc_mgr = ProcessManagerService(self)
        self._proc_model = ProcessListModel(self.proc_mgr, self)

        self._bluetooth_powered = True
        self._known_devices_state = {}
        self._first_poll = True
        self._cached_ip = get_local_ip()

        self.hardware = HardwareService(self._pool, self.sendIpcCmd, self)
        self.media = MediaService(self._pool, self.sendIpcCmd, self)
        self.wm = WindowManagerService(self.view, self._pool, self.config, self)
        self.typing_flow = TypingFlowService(self._pool, self.config, self)

        self._bind_service_signals()
        self._sig_daemon_payload.connect(self._handle_daemon_payload, Qt.ConnectionType.QueuedConnection)
        atexit.register(self.cleanup)

    # 找到 _bind_service_signals 方法，修改连接方式以打点：
    def _bind_service_signals(self):
        self.hardware.volumeChanged.connect(self.volumeChanged)
        self.hardware.brightnessChanged.connect(self.brightnessChanged)
        self.hardware.hardwareMuteStateChanged.connect(self.hardwareMuteStateChanged)
        self.hardware.capsLockChanged.connect(self.capsLockChanged)
        self.hardware.numLockChanged.connect(self.numLockChanged)
        self.hardware.memoryUpdated.connect(self.memoryUpdated)
        self.hardware.osdTriggered.connect(self.osdTriggered)

        self.media.mediaUpdated.connect(self._on_media_state_changed)
        self.media.progressUpdated.connect(self.progressUpdated)
        self.media.audioSpectrumUpdated.connect(self.audioSpectrumUpdated)
        self.media.dominantColorUpdated.connect(self.dominantColorUpdated)

        self.wm.clipboardTriggered.connect(self.clipboardTriggered)
        
        # 🔍【追踪打点 2】：确认 Python 核心信号总线是否收到打字信号并成功转发
        def _on_typing_data(active, color, s1, s2, s3, s4, kps):
            # if active:
            #     print(f"\033[36m[Bridge 转发] 转发 typingSpectrumUpdated 给 QML! (KPS: {kps}, 颜色: {color})\033[0m")
            self.typingSpectrumUpdated.emit(active, color, s1, s2, s3, s4, kps)

        self.typing_flow.typingUpdated.connect(_on_typing_data)

    def _on_media_state_changed(self, title, artist, status, art, pos, dur):
        self.mediaUpdated.emit(title, artist, status, art, pos, dur)
        self.typing_flow.set_media_playing(status == "Playing")

    def cleanup(self):
        self.typing_flow.cleanup()
        self.media.cleanup()
        self.proc_mgr.cleanup()
        self._pool.shutdown(wait=False, cancel_futures=True)

    @Property(QObject, constant=True)
    def notificationModel(self): return self._notif_model

    @Property(QObject, constant=True)
    def bluetoothModel(self): return self._bt_model

    @Property(QObject, constant=True)
    def processModel(self): return self._proc_model

    @Property(int, notify=volumeChanged)
    def currentVolume(self): return self.hardware.current_volume

    @Property(int, notify=brightnessChanged)
    def currentBrightness(self): return self.hardware.current_brightness

    @Property(bool, notify=capsLockChanged)
    def isCapsLock(self): return self.hardware.is_caps_lock

    @Property(bool, notify=numLockChanged)
    def isNumLock(self): return self.hardware.is_num_lock

    @Property(bool, notify=bluetoothStateChanged)
    def isBluetoothPowered(self): return self._bluetooth_powered

    @Slot(str)
    def startProcessTask(self, tid: str): self.proc_mgr.start_task(tid)

    @Slot(str)
    def stopProcessTask(self, tid: str): self.proc_mgr.stop_task(tid)

    @Slot()
    def startAllProcessTasks(self): self.proc_mgr.start_all()

    @Slot()
    def stopAllProcessTasks(self): self.proc_mgr.stop_all()

    @Slot(str, str, str)
    @Slot(str, str, str, str)
    def addProcessTask(self, name: str, cwd: str, cmd: str, icon: str = ""):
        self.proc_mgr.add_task(name, cwd, cmd, icon)

    @Slot(str, str, str, str)
    @Slot(str, str, str, str, str)
    def updateProcessTask(self, tid: str, name: str, cwd: str, cmd: str, icon: str = ""):
        self.proc_mgr.update_task(tid, name, cwd, cmd, icon)

    @Slot(str)
    def deleteProcessTask(self, tid: str): self.proc_mgr.delete_task(tid)

    # 🚀 纯粹安全的目录选择（严禁使用 QWidget/QFileDialog 防止崩溃）
    @Slot(result=str)
    def selectLocalDirectory(self) -> str:
        try:
            if shutil.which("zenity"):
                res = subprocess.run(
                    ["zenity", "--file-selection", "--directory", "--title=选择任务工作目录"],
                    capture_output=True, text=True, timeout=60
                )
                if res.returncode == 0 and res.stdout.strip():
                    return res.stdout.strip()
            elif shutil.which("kdialog"):
                res = subprocess.run(
                    ["kdialog", "--getexistingdirectory", os.path.expanduser("~"), "--title", "选择任务工作目录"],
                    capture_output=True, text=True, timeout=60
                )
                if res.returncode == 0 and res.stdout.strip():
                    return res.stdout.strip()
        except Exception as e:
            app_logger.warning(f"目录选择器调用异常: {e}")
        return ""

    # 🚀 纯粹安全的图片文件选择（严禁导入 QFileDialog，绝无 Core Dump）
    @Slot(result=str)
    def selectLocalImageFile(self) -> str:
        try:
            if shutil.which("zenity"):
                # 使用通用的标准文件过滤器，去除易发生语法歧义的管道符
                res = subprocess.run(
                    [
                        "zenity", "--file-selection",
                        "--title=选择服务图标图片",
                        "--file-filter=*.png *.jpg *.jpeg *.svg *.webp *.ico"
                    ],
                    capture_output=True, text=True, timeout=60
                )
                if res.returncode == 0 and res.stdout.strip():
                    return res.stdout.strip()

            elif shutil.which("kdialog"):
                res = subprocess.run(
                    [
                        "kdialog", "--getopenfilename", os.path.expanduser("~"),
                        "*.png *.jpg *.jpeg *.svg *.webp *.ico"
                    ],
                    capture_output=True, text=True, timeout=60
                )
                if res.returncode == 0 and res.stdout.strip():
                    return res.stdout.strip()

        except Exception as e:
            app_logger.warning(f"图片选择器调用异常: {e}")

        return ""

    @Slot(int, int)
    def adjustHardware(self, mode: int, delta: int): self.hardware.adjust_hardware(mode, delta)

    @Slot(int)
    def toggleHardwareMute(self, mode: int): self.hardware.toggle_hardware_mute(mode)

    @Slot(int)
    def adjustVolume(self, delta_pct: int): self.hardware.adjust_hardware(0, delta_pct)

    @Slot("QVariantList")
    def updateCompositeMask(self, rects): self.wm.update_composite_mask(rects)

    @Slot()
    def setPassthrough(self): self.wm.set_passthrough()

    @Slot()
    def clearMask(self): self.wm.clear_mask()

    @Slot()
    def forceClearWindow(self): self.view.requestUpdate()

    @Slot(result=str)
    def getLatestNotificationAvatar(self): return self._notif_model.latestAvatar

    @Slot()
    def forceRaise(self): self.view.raise_()

    @Slot()
    def requestWindowFocus(self):
        self.view.show()
        self.view.raise_()
        self.view.requestActivate()
        try:
            wid = int(self.view.winId())
            if os.environ.get("DISPLAY") and shutil.which("xdotool"):
                subprocess.Popen(
                    ["xdotool", "windowactivate", "--sync", str(wid)],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                )
        except Exception:
            pass

    @Slot()
    def onIslandCollapsed(self):
        gc.collect(generation=1)
        if hasattr(self.view, "engine") and hasattr(self.view.engine(), "trimComponentCache"):
            self.view.engine().trimComponentCache()

    def set_ipc_sender(self, sender_func): self._ipc_sender = sender_func

    def sendIpcCmd(self, action: str, **kwargs):
        if self._ipc_sender:
            self._ipc_sender(action, **kwargs)

    @Slot(str)
    def sendMediaCmd(self, action: str): self.sendIpcCmd(action)

    @Slot(int)
    @Slot(str)
    def switchWorkspace(self, target): self.sendIpcCmd("WORKSPACE_SWITCH", target=target)

    @Slot()
    def switchWorkspacePrev(self): self.sendIpcCmd("WORKSPACE_PREV")

    @Slot()
    def switchWorkspaceNext(self): self.sendIpcCmd("WORKSPACE_NEXT")

    @Slot(str)
    def executePowerAction(self, action: str):
        app_logger.info(f"触发系统电源/会话管理指令 -> {action}")
        self.sendIpcCmd(action)

    @Slot()
    def answerTeamsCall(self): self.sendIpcCmd("TEAMS_ANSWER")

    @Slot()
    def rejectTeamsCall(self): self.sendIpcCmd("TEAMS_REJECT")

    @Slot()
    def focusTeamsWindow(self): self.sendIpcCmd("TEAMS_FOCUS"); self.wm.focus_teams_window()

    @Slot()
    def openSystemMonitor(self): self.wm.open_system_monitor()

    @Slot(str, str)
    def focusMediaWindow(self, title="", artist=""): self.media.focus_media_window()

    @Slot(str, bool, result=dict)
    def getWorldTime(self, tz_name, is_24h=True): return get_world_time(tz_name, is_24h)

    @Slot(str, result=str)
    def getTzOffsetStr(self, tz_name): return get_tz_offset_str(tz_name)

    @Slot(str)
    def connectBluetooth(self, mac): self.wm.connect_bluetooth(mac)

    @Slot(str)
    def disconnectBluetooth(self, mac): self.wm.disconnect_bluetooth(mac)

    @Slot()
    def openBluetoothSettings(self): self.wm.open_bluetooth_settings()

    def post_daemon_message(self, msg_type: str, data_json_str: str):
        self._sig_daemon_payload.emit(msg_type, data_json_str)

    @Slot(str, str)
    def _handle_daemon_payload(self, m_type: str, data_str: str):
        try:
            data = json.loads(data_str) if data_str else {}
        except Exception as e:
            app_logger.error(f"解析报文异常: {e}")
            return

        if m_type in ("MEDIA_PROGRESS", "MEDIA_TICK") and "media" in data:
            m = data["media"]
            self.media.apply_media_progress(m.get("position"), m.get("duration"), float(m.get("progress", -1.0)))

        elif m_type in ("MEDIA_UPDATE", "FULL_SYNC") and "media" in data:
            m = data["media"]
            raw_art = m.get("art_url") or m.get("artUrl") or m.get("mpris:artUrl") or m.get("cover") or m.get("thumbnail") or ""
            art = ("file://" + raw_art) if (raw_art and raw_art.startswith("/") and not raw_art.startswith("file://")) else raw_art
            self.media.apply_media_state(m.get("title", "等待播放..."), m.get("artist", "未知歌手"), m.get("status", "Paused"), art, m.get("position"), m.get("duration"))

        if m_type in ("WORKSPACE_CHANGED", "FULL_SYNC") and "workspace" in data:
            ws_info = data["workspace"]
            self.workspaceTriggered.emit(int(ws_info.get("current_index", 1)), int(ws_info.get("total", 4)), str(ws_info.get("current_name", "")))
            if "list" in ws_info:
                self.workspaceListUpdated.emit(ws_info.get("list", []))

        if (m_type in ("VOLUME_UPDATE", "FULL_SYNC")) and "system" in data:
            sys_info = data["system"]
            self.hardware.apply_daemon_volume(max(0, min(100, int(sys_info.get("volume", self.hardware.current_volume)))), bool(sys_info.get("muted", False)), m_type)

        elif m_type == "BRIGHTNESS_UPDATE" and "system" in data:
            self.hardware.apply_daemon_brightness(int(data["system"].get("brightness", 100)))

        if "bluetooth" in data:
            b_info = data["bluetooth"]
            devices = b_info.get("connected_devices", [])
            powered = b_info.get("powered", True)
            self._bluetooth_powered = powered

            alerts = []
            if not self._first_poll and m_type in ("BLUETOOTH_CONNECT", "BLUETOOTH_DISCONNECT", "BLUETOOTH_BATTERY"):
                for dev in devices:
                    mac, conn, bat, name = dev.get("mac"), dev.get("connected", False), dev.get("battery"), dev.get("name", "蓝牙设备")
                    prev_conn, _ = self._known_devices_state.get(mac, (None, None))
                    if prev_conn is not None and prev_conn != conn:
                        emoji = "🎧" if any(w in name.lower() for w in ["buds", "pods", "wh-", "head", "audio"]) else "蓝牙"
                        status_str = f"已连接 · 🔋 电量 {bat}%" if (conn and bat is not None) else ("已连接" if conn else "已断开连接")
                        alerts.append((emoji, name, status_str, 2500, ""))
                    self._known_devices_state[mac] = (conn, bat)
            else:
                for dev in devices:
                    self._known_devices_state[dev.get("mac")] = (dev.get("connected", False), dev.get("battery"))
            self._first_poll = False
            self._bt_model.sync_devices(devices)
            self.bluetoothStateChanged.emit(powered)
            for alert in alerts:
                self.alertTriggered.emit(*alert)

        if "network" in data:
            net_info = data["network"]
            rx_str, tx_str = net_info.get("rx_speed", "0 B/s"), net_info.get("tx_speed", "0 B/s")
            self.netSpeedUpdated.emit(rx_str, tx_str, to_compact_speed(rx_str), to_compact_speed(tx_str), self._cached_ip)
            if m_type == "VPN_CONNECTED":
                self.alertTriggered.emit("🛡️", "VPN 安全网络已接入", net_info.get("vpn_name", "VPN Active"), 2000, "")
            elif m_type == "VPN_DISCONNECTED":
                self.alertTriggered.emit("⚠️", "VPN 网络已断开", "恢复公网直连模式", 2000, "")

        if m_type == "TEAMS_CALL_INCOMING":
            if "notification" in data:
                noti = data["notification"]
                self.callIncomingTriggered.emit(noti.get("title", "").strip() or "Teams 来电", noti.get("content", "").strip() or "正在呼叫...", process_notification_avatar(noti.get("avatar", "")))
                self.view.raise_()

        elif m_type in ("TEAMS_NOTIFICATION", "BROWSER_NOTIFICATION") and "notification" in data:
            noti = data["notification"]
            t_title, t_sub = noti.get("title", "").strip(), noti.get("content", "").strip()
            avatar = process_notification_avatar(noti.get("avatar", ""))
            if t_title or t_sub:
                self._notif_model.add_notification({"id": int(time.time() * 1000), "icon": noti.get("icon", "💬"), "title": t_title or "新通知", "content": t_sub or "", "avatar": avatar, "time": time.strftime("%H:%M"), "read": False})
                self.alertTriggered.emit(noti.get("icon", "🔔"), t_title, t_sub, 4500, avatar)

        elif m_type == "TEAMS_CALL_ENDED":
            self.callEndedTriggered.emit()

        self.syncDataUpdated.emit(data)