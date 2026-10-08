# ==========================================
# 📄 File: bridge.py
# 🌟 增加 QML 毫秒级直通日志探针
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
from models import NotificationListModel, BluetoothListModel, ProcessListModel, AppListModel
from services import (
    HardwareService,
    MediaService,
    WindowManagerService,
    TypingFlowService,
    AppLauncherService,
    get_world_time,
    get_tz_offset_str,
    process_notification_avatar,
    to_compact_speed,
    get_local_ip,
)
from services.process_mgr import ProcessManagerService


class IslandBridge(QObject):
    # 1. 媒体与声学频谱
    mediaUpdated = Signal(str, str, str, str, float, float)
    progressUpdated = Signal(float, float, float)
    audioSpectrumUpdated = Signal(float, float, float, float)
    dominantColorUpdated = Signal(str)

    # 2. 击键心流与物理脉冲
    typingSpectrumUpdated = Signal(bool, str, float, float, float, float, float, str, str)
    keyStrokeTriggered = Signal(str, str, int)

    # 3. 硬件中控、系统 OSD 与电池电源
    osdTriggered = Signal(str, str, int)
    hardwareMuteStateChanged = Signal(bool, bool)
    volumeChanged = Signal(int)
    brightnessChanged = Signal(int)
    capsLockChanged = Signal(bool)
    numLockChanged = Signal(bool)
    memoryUpdated = Signal(int, str, str)
    batteryUpdated = Signal(int, bool)
    clipboardTriggered = Signal(str, str, str, int)

    # 4. 工作区与通知会话
    workspaceTriggered = Signal(int, int, str)
    workspaceListUpdated = Signal("QVariantList")
    alertTriggered = Signal(str, str, str, int, str)
    callIncomingTriggered = Signal(str, str, str)
    callEndedTriggered = Signal()
    syncDataUpdated = Signal("QVariantMap")
    netSpeedUpdated = Signal(str, str, str, str, str)
    bluetoothStateChanged = Signal(bool)
    unreadCountChanged = Signal(int)

    # 5. 异步非阻塞文件选取与应用管理回调
    localDirectorySelected = Signal(str)
    localImageFileSelected = Signal(str)
    localAppFileSelected = Signal(str)
    appManagerRequested = Signal()

    _sig_daemon_payload = Signal(str, str)

    def __init__(self, view, config=None):
        super().__init__()
        self.view = view
        self.config = config
        self._ipc_sender = None
        self._pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="SubprocessWorker")

        # 数据模型实例化
        self._notif_model = NotificationListModel(self)
        self._bt_model = BluetoothListModel(self)
        self._notif_model.unreadCountChanged.connect(self.unreadCountChanged)

        self.proc_mgr = ProcessManagerService(self)
        self._proc_model = ProcessListModel(self.proc_mgr, self)

        # 程序岛服务与模型
        self.app_launcher = AppLauncherService(self._pool, self)
        self._app_model = AppListModel(self.app_launcher, self)

        # 状态缓存
        self._bluetooth_powered = True
        self._known_devices_state = {}
        self._first_poll = True
        self._cached_ip = get_local_ip()

        # 底层微服务初始化
        self.hardware = HardwareService(self._pool, self.sendIpcCmd, self)
        self.media = MediaService(self._pool, self.sendIpcCmd, self)
        self.wm = WindowManagerService(self.view, self._pool, self.config, self)
        self.typing_flow = TypingFlowService(self._pool, self.config, self)

        self._bind_service_signals()
        self._sig_daemon_payload.connect(self._handle_daemon_payload, Qt.ConnectionType.QueuedConnection)
        atexit.register(self.cleanup)

    # 🚀【核心诊断探针】：直通控制台高亮输出，毫秒级抓现行
    @Slot(str, str)
    def traceLog(self, tag: str, msg: str):
        ts = time.strftime("%H:%M:%S") + f".{int(time.time()*1000)%1000:03d}"
        color = "\033[93m" if "COLLAPSE" in tag else ("\033[96m" if "EXPAND" in tag else "\033[95m")
        print(f"{color}[{ts}] [{tag}]\033[0m {msg}", flush=True)

    def _bind_service_signals(self):
        self.hardware.volumeChanged.connect(self.volumeChanged)
        self.hardware.brightnessChanged.connect(self.brightnessChanged)
        self.hardware.hardwareMuteStateChanged.connect(self.hardwareMuteStateChanged)
        self.hardware.capsLockChanged.connect(self.capsLockChanged)
        self.hardware.numLockChanged.connect(self.numLockChanged)
        self.hardware.memoryUpdated.connect(self.memoryUpdated)
        self.hardware.osdTriggered.connect(self.osdTriggered)
        self.hardware.batteryUpdated.connect(self.batteryUpdated)

        self.media.mediaUpdated.connect(self._on_media_state_changed)
        self.media.progressUpdated.connect(self.progressUpdated)
        self.media.audioSpectrumUpdated.connect(self.audioSpectrumUpdated)
        self.media.dominantColorUpdated.connect(self.dominantColorUpdated)

        self.wm.clipboardTriggered.connect(self.clipboardTriggered)

        def _on_typing_data(*args):
            if len(args) == 7:
                self.typingSpectrumUpdated.emit(args[0], args[1], args[2], args[3], args[4], args[5], args[6], "", "")
            elif len(args) >= 9:
                self.typingSpectrumUpdated.emit(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8])

        self.typing_flow.typingUpdated.connect(_on_typing_data)
        self.typing_flow.keyStrokeTriggered.connect(self.keyStrokeTriggered)

    def _on_media_state_changed(self, title, artist, status, art, pos, dur):
        self.mediaUpdated.emit(title, artist, status, art, pos, dur)
        self.typing_flow.set_media_playing(status == "Playing")

    def cleanup(self):
        if hasattr(self, "_notif_model"):
            self._notif_model.clearAll()
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

    @Property(QObject, constant=True)
    def appModel(self): return self._app_model

    @Property(int, notify=volumeChanged)
    def currentVolume(self): return self.hardware.current_volume

    @Property(int, notify=brightnessChanged)
    def currentBrightness(self): return self.hardware.current_brightness

    @Property(bool, notify=capsLockChanged)
    def isCapsLock(self): return self.hardware.is_caps_lock

    @Property(bool, notify=numLockChanged)
    def isNumLock(self): return self.hardware.is_num_lock

    @Property(int, notify=batteryUpdated)
    def systemBattery(self): return self.hardware.current_battery

    @Property(bool, notify=batteryUpdated)
    def isSystemCharging(self): return self.hardware.is_charging

    @Property(bool, notify=bluetoothStateChanged)
    def isBluetoothPowered(self): return self._bluetooth_powered

    @Slot(str)
    def launchApp(self, app_id: str):
        app_logger.info(f"⚡ [Bridge] 转发启动请求给 AppLauncherService -> {app_id}")
        self.app_launcher.launch_app(app_id)

    @Slot(str)
    def deleteApp(self, app_id: str):
        self.app_launcher.delete_app(app_id)

    @Slot(str, str, str)
    def addAppManual(self, name: str, exec_cmd: str, icon: str):
        self.app_launcher.add_app(name, exec_cmd, icon)

    @Slot()
    def openAppManagerWindow(self):
        app_logger.info("🖥️ [Bridge] 请求打开独立程序岛应用管理窗口")
        self.appManagerRequested.emit()

    @Slot(result="QVariantList")
    def getSystemInstalledApps(self):
        return self.app_launcher.scan_system_desktop_apps()

    @Slot(str, result="QVariantMap")
    def parseDesktopFileInfo(self, path: str):
        name, exec_cmd, icon = "", "", ""
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith("Name=") and not name:
                            name = line.split("=", 1)[1]
                        elif line.startswith("Exec=") and not exec_cmd:
                            raw_e = line.split("=", 1)[1]
                            exec_cmd = " ".join([p for p in raw_e.split() if not p.startswith("%")])
                        elif line.startswith("Icon=") and not icon:
                            icon = line.split("=", 1)[1]
            except Exception:
                pass
        if not name:
            name = os.path.splitext(os.path.basename(path))[0]
        if not exec_cmd:
            exec_cmd = path
        resolved_icon = self.app_launcher._resolve_icon_to_file(icon) if hasattr(self.app_launcher, "_resolve_icon_to_file") else ""
        return {"name": name, "exec": exec_cmd, "raw_icon": icon, "icon": resolved_icon}

    @Slot()
    def selectLocalExecutableOrDesktop(self):
        def _pick():
            chosen = ""
            if shutil.which("zenity"):
                res = subprocess.run([
                    "zenity", "--file-selection",
                    "--title=选择应用程序或可执行文件",
                    "--file-filter=桌面快捷方式与程序 (*.desktop *) | *.desktop *",
                    "--file-filter=所有文件 (*) | *"
                ], capture_output=True, text=True, timeout=120)
                if res.returncode == 0 and res.stdout.strip():
                    chosen = res.stdout.strip()
            elif shutil.which("kdialog"):
                res = subprocess.run([
                    "kdialog", "--getopenfilename", "/usr/share/applications",
                    "*.desktop"
                ], capture_output=True, text=True, timeout=120)
                if res.returncode == 0 and res.stdout.strip():
                    chosen = res.stdout.strip()
            if chosen:
                self.localAppFileSelected.emit(chosen)
        self._pool.submit(_pick)

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

    @Slot()
    def selectLocalDirectory(self):
        def _pick():
            chosen = ""
            if shutil.which("zenity"):
                res = subprocess.run(["zenity", "--file-selection", "--directory", "--title=选择任务工作目录"], capture_output=True, text=True, timeout=120)
                if res.returncode == 0 and res.stdout.strip(): chosen = res.stdout.strip()
            elif shutil.which("kdialog"):
                res = subprocess.run(["kdialog", "--getexistingdirectory", os.path.expanduser("~"), "--title", "选择任务工作目录"], capture_output=True, text=True, timeout=120)
                if res.returncode == 0 and res.stdout.strip(): chosen = res.stdout.strip()
            if chosen: self.localDirectorySelected.emit(chosen)
        self._pool.submit(_pick)

    @Slot()
    def selectLocalImageFile(self):
        def _pick():
            chosen = ""
            if shutil.which("zenity"):
                res = subprocess.run([
                    "zenity", "--file-selection", "--title=选择服务图标图片",
                    "--file-filter=图片文件 (*.png *.jpg *.jpeg *.svg *.webp *.ico) | *.png *.jpg *.jpeg *.svg *.webp *.ico",
                    "--file-filter=所有文件 (*) | *"
                ], capture_output=True, text=True, timeout=120)
                if res.returncode == 0 and res.stdout.strip(): chosen = res.stdout.strip()
            elif shutil.which("kdialog"):
                res = subprocess.run(["kdialog", "--getopenfilename", os.path.expanduser("~"), "*.png *.jpg *.jpeg *.svg *.webp *.ico"], capture_output=True, text=True, timeout=120)
                if res.returncode == 0 and res.stdout.strip(): chosen = res.stdout.strip()
            if chosen: self.localImageFileSelected.emit(chosen)
        self._pool.submit(_pick)

    @Slot(int, int)
    def adjustHardware(self, mode: int, delta: int): self.hardware.adjust_hardware(mode, delta)

    @Slot(int)
    def toggleHardwareMute(self, mode: int): self.hardware.toggle_hardware_mute(mode)

    @Slot(int)
    def adjustVolume(self, delta_pct: int): self.hardware.adjust_hardware(0, delta_pct)

    @Slot()
    def togglePowerSaveMode(self): pass

    @Slot()
    def openPowerSettings(self): pass

    @Slot(result=list)
    def scanLofiAnimations(self):
        lofi_dir = os.path.expanduser("~/.config/alcove_island/lofi")
        if not os.path.exists(lofi_dir) or not os.path.isdir(lofi_dir): return []
        valid_exts = {".webp", ".gif", ".png", ".jpg", ".jpeg"}
        files = []
        try:
            for fname in sorted(os.listdir(lofi_dir)):
                ext = os.path.splitext(fname)[1].lower()
                if ext in valid_exts: files.append(os.path.join(lofi_dir, fname))
        except Exception: pass
        return files

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
        self.view.show(); self.view.raise_(); self.view.requestActivate()

    @Slot()
    def onIslandCollapsed(self):
        gc.collect(generation=1)
        if hasattr(self.view, "engine") and hasattr(self.view.engine(), "trimComponentCache"):
            self.view.engine().trimComponentCache()

    def set_ipc_sender(self, sender_func): self._ipc_sender = sender_func

    def sendIpcCmd(self, action: str, **kwargs):
        if self._ipc_sender: self._ipc_sender(action, **kwargs)

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
    def executePowerAction(self, action: str): self.sendIpcCmd(action)

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
        try: data = json.loads(data_str) if data_str else {}
        except Exception: return
        if m_type in ("MEDIA_PROGRESS", "MEDIA_TICK") and "media" in data:
            m = data["media"]
            self.media.apply_media_progress(m.get("position"), m.get("duration"), float(m.get("progress", -1.0)))
        elif m_type in ("MEDIA_UPDATE", "FULL_SYNC") and "media" in data:
            m = data["media"]
            raw_art = m.get("art_url") or m.get("artUrl") or ""
            art = ("file://" + raw_art) if (raw_art and raw_art.startswith("/") and not raw_art.startswith("file://")) else raw_art
            self.media.apply_media_state(m.get("title", "等待播放..."), m.get("artist", "未知歌手"), m.get("status", "Paused"), art, m.get("position"), m.get("duration"))
        elif m_type in ("WORKSPACE_CHANGED", "FULL_SYNC") and "workspace" in data:
            ws_info = data["workspace"]
            self.workspaceTriggered.emit(int(ws_info.get("current_index", 1)), int(ws_info.get("total", 4)), str(ws_info.get("current_name", "")))
            if "list" in ws_info: self.workspaceListUpdated.emit(ws_info.get("list", []))
        elif (m_type in ("VOLUME_UPDATE", "FULL_SYNC")) and "system" in data:
            sys_info = data["system"]
            self.hardware.apply_daemon_volume(max(0, min(100, int(sys_info.get("volume", self.hardware.current_volume)))), bool(sys_info.get("muted", False)), m_type)
        elif m_type == "BRIGHTNESS_UPDATE" and "system" in data:
            self.hardware.apply_daemon_brightness(int(data["system"].get("brightness", 100)))
        elif "bluetooth" in data:
            b_info = data["bluetooth"]
            devices = b_info.get("connected_devices", [])
            self._bluetooth_powered = b_info.get("powered", True)
            self._bt_model.sync_devices(devices)
            self.bluetoothStateChanged.emit(self._bluetooth_powered)
        elif "network" in data:
            net_info = data["network"]
            self.netSpeedUpdated.emit(net_info.get("rx_speed", "0 B/s"), net_info.get("tx_speed", "0 B/s"), to_compact_speed(net_info.get("rx_speed", "")), to_compact_speed(net_info.get("tx_speed", "")), self._cached_ip)
        elif m_type == "TEAMS_CALL_INCOMING":
            noti = data.get("notification", {})
            self.callIncomingTriggered.emit(noti.get("title", "Teams 来电"), noti.get("content", "呼叫中..."), process_notification_avatar(noti.get("avatar", "")))
            self.view.raise_()
        elif m_type == "TEAMS_CALL_ENDED":
            self.callEndedTriggered.emit()
        elif "notification" in data:
            noti = data["notification"]
            t_title = (noti.get("title") or noti.get("summary") or "新通知").strip()
            t_sub = (noti.get("content") or noti.get("body") or "").strip()
            avatar = process_notification_avatar(noti.get("avatar") or noti.get("icon") or "")
            if t_title or t_sub:
                self._notif_model.add_notification({
                    "id": int(time.time() * 1000), "icon": noti.get("icon", "💬"),
                    "title": t_title, "content": t_sub, "avatar": avatar, "time": time.strftime("%H:%M"), "read": False
                })
        self.syncDataUpdated.emit(data)