import os
import gc
import json
import time
import glob
import socket
import shutil
import struct
import atexit
import hashlib
import urllib.parse
import urllib.request
import subprocess
from concurrent.futures import ThreadPoolExecutor

from PySide6.QtCore import (
    QObject, Signal, Slot, Property, QRect, QTimer,
    QDateTime, QTimeZone, QByteArray, Qt
)
from PySide6.QtGui import QRegion, QPainterPath, QGuiApplication
from logger import app_logger
from models import NotificationListModel, BluetoothListModel

AVATAR_CACHE_DIR = os.path.expanduser("~/.local/state/alcove_island/avatar_cache")
CAVA_CONFIG_PATH = f"/tmp/alcove_cava_{os.getuid()}_config"

CONCEAL_MIME_TYPES = {
    "application/x-vnd.passwordmanager-conceal",
    "x-kde-passwordManagerHint",
    "application/x-1password-conceal",
    "application/x-keepassxc-conceal",
    "application/x-encpass",
    "text/x-private",
    "application/x-moz-url-priv"
}


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

                mask = Image.new("L", (size, size), 0)
                draw = ImageDraw.Draw(mask)
                draw.ellipse((0, 0, size, size), fill=255)
                im.putalpha(mask)
                im.save(cached_path, "PNG")
            except Exception:
                shutil.copy2(clean_path, cached_path)

        return f"file://{cached_path}"
    except Exception as e:
        app_logger.warning(f"处理头像缓存异常: {e}")
        return ""


def to_compact_speed(speed_str: str) -> str:
    if not speed_str:
        return "0.0 KB/s"
    parts = speed_str.strip().split()
    if len(parts) >= 2:
        val, unit = parts[0], parts[1].upper()
        try:
            f = float(val)
            if "M" in unit:
                return f"{f:.1f} MB/s"
            elif "K" in unit:
                return f"{int(f)} KB/s" if f >= 100 else f"{f:.1f} KB/s"
            elif "B" in unit:
                return f"{int(f)} B/s" if f > 0 else "0.0 KB/s"
        except ValueError:
            pass
    return speed_str if speed_str else "0.0 KB/s"


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
    callIncomingTriggered = Signal(str, str, str)
    callEndedTriggered = Signal()
    syncDataUpdated = Signal("QVariantMap")
    netSpeedUpdated = Signal(str, str, str, str, str)
    memoryUpdated = Signal(int, str, str)

    audioSpectrumUpdated = Signal(float, float, float, float)
    dominantColorUpdated = Signal(str)
    clipboardTriggered = Signal(str, str, str, int)

    bluetoothStateChanged = Signal(bool)
    unreadCountChanged = Signal(int)

    hardwareMuteStateChanged = Signal(bool, bool)
    volumeChanged = Signal(int)

    # 🚀 大写锁定状态变更信号
    capsLockChanged = Signal(bool)

    _sig_daemon_payload = Signal(str, str)

    def __init__(self, view, config=None):
        super().__init__()
        self.view = view
        self.config = config

        self._curr_title = ""
        self._curr_artist = ""
        self._curr_pos = 0.0
        self._curr_dur = 0.0
        self._curr_status = "Paused"
        self._curr_art = ""
        self._curr_dominant_color = "#22c55e"

        self._cached_volume = 50
        self._vol_muted = False
        self._cached_brightness = 70
        self._prev_brightness = 70
        self._cached_mic = 80
        self._mic_muted = False

        self._last_user_vol_adjust_time = 0.0
        self._last_user_bright_adjust_time = 0.0
        self._last_user_mic_adjust_time = 0.0

        # 大写锁定状态机与物理文件路径缓存
        self._is_caps_lock = False
        self._caps_led_paths = []
        self._init_caps_lock_monitor()

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

        self._memory_timer = QTimer(self)
        self._memory_timer.setInterval(2000)
        self._memory_timer.timeout.connect(self._poll_memory_usage)
        self._memory_timer.start()

        self._vol_flush_timer = QTimer(self)
        self._vol_flush_timer.setSingleShot(True)
        self._vol_flush_timer.setInterval(25)
        self._vol_flush_timer.timeout.connect(self._flush_volume_to_hardware)

        self._sig_daemon_payload.connect(self._handle_daemon_payload, Qt.ConnectionType.QueuedConnection)

        self._last_clip_hash = ""
        self._setup_clipboard_listener()

        self._last_applied_mask = QRegion()

        self._cava_proc = None
        self._start_cava_spectrum_monitor()

        atexit.register(self.cleanup)

    def _init_caps_lock_monitor(self):
        self._refresh_caps_paths()
        self._caps_timer = QTimer(self)
        self._caps_timer.setInterval(150)  # 150ms 极速物理轮询，单次耗时 < 0.02ms
        self._caps_timer.timeout.connect(self._check_caps_lock)
        self._caps_timer.start()

    def _refresh_caps_paths(self):
        try:
            self._caps_led_paths = glob.glob("/sys/class/leds/*capslock*/brightness")
        except Exception:
            self._caps_led_paths = []

    def _check_caps_lock(self):
        if not self._caps_led_paths:
            self._refresh_caps_paths()

        active = False
        found = False
        for p in self._caps_led_paths:
            try:
                with open(p, "r") as fp:
                    val = fp.read().strip()
                    found = True
                    if val and int(val) > 0:
                        active = True
                        break
            except Exception:
                continue

        # 针对部分虚拟机或特殊键盘驱动的备用检测
        if not found and shutil.which("xset"):
            try:
                res = subprocess.run(["xset", "q"], capture_output=True, text=True, timeout=0.3)
                if "Caps Lock:   on" in res.stdout:
                    active = True
            except Exception:
                pass

        if active != self._is_caps_lock:
            self._is_caps_lock = active
            self.capsLockChanged.emit(self._is_caps_lock)

    @Property(bool, notify=capsLockChanged)
    def isCapsLock(self):
        return self._is_caps_lock

    @Property(int, notify=volumeChanged)
    def currentVolume(self):
        return self._cached_volume

    def cleanup(self):
        if self._cava_proc:
            try:
                if self._cava_proc.poll() is None:
                    self._cava_proc.terminate()
                    self._cava_proc.wait(timeout=0.5)
            except Exception:
                try:
                    self._cava_proc.kill()
                except Exception:
                    pass
            self._cava_proc = None
        try:
            if os.path.exists(CAVA_CONFIG_PATH):
                os.remove(CAVA_CONFIG_PATH)
        except Exception:
            pass
        self._pool.shutdown(wait=False, cancel_futures=True)

    def _start_cava_spectrum_monitor(self):
        if not shutil.which("cava"):
            return

        def _cava_worker():
            try:
                cava_cfg = (
                    "[general]\n"
                    "bars = 4\n"
                    "framerate = 30\n"
                    "lower_cutoff_freq = 50\n"
                    "higher_cutoff_freq = 12000\n"
                    "[output]\n"
                    "method = raw\n"
                    "raw_target = /dev/stdout\n"
                    "data_format = binary\n"
                    "bit_format = 8bit\n"
                )
                with open(CAVA_CONFIG_PATH, "w", encoding="utf-8") as f:
                    f.write(cava_cfg)

                self._cava_proc = subprocess.Popen(
                    ["cava", "-p", CAVA_CONFIG_PATH],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL
                )

                chunk_size = 4
                while True:
                    if not self._cava_proc or self._cava_proc.poll() is not None:
                        break
                    raw = self._cava_proc.stdout.read(chunk_size)
                    if len(raw) < 4:
                        break
                    b1, b2, b3, b4 = struct.unpack("4B", raw)
                    s1 = round(0.15 + (b1 / 255.0) * 0.85, 2)
                    s2 = round(0.15 + (b2 / 255.0) * 0.85, 2)
                    s3 = round(0.15 + (b3 / 255.0) * 0.85, 2)
                    s4 = round(0.15 + (b4 / 255.0) * 0.85, 2)

                    if self._curr_status == "Playing":
                        self.audioSpectrumUpdated.emit(s1, s2, s3, s4)
                    else:
                        self.audioSpectrumUpdated.emit(0.2, 0.2, 0.2, 0.2)
            except Exception:
                pass

        self._pool.submit(_cava_worker)

    @Slot(int, int)
    def adjustHardware(self, mode: int, delta: int):
        now = time.monotonic()
        if mode == 0:
            self._last_user_vol_adjust_time = now
            if self._vol_muted:
                self._vol_muted = False
                self.hardwareMuteStateChanged.emit(self._vol_muted, self._mic_muted)
                self._execute_local_volume_mute(False)
                if self._cached_volume == 0:
                    self._cached_volume = 15
                    self.volumeChanged.emit(self._cached_volume)

            if delta > 0 and self._cached_volume >= 100:
                self.osdTriggered.emit("🔊", "Volume", 100)
                return
            if delta < 0 and self._cached_volume <= 0:
                self.osdTriggered.emit("🔈", "Volume", 0)
                return

            new_val = max(0, min(100, self._cached_volume + delta))
            self._cached_volume = new_val
            self.volumeChanged.emit(self._cached_volume)
            icon = "🔈" if new_val == 0 else "🔊"
            self.osdTriggered.emit(icon, "Volume", new_val)
            self._vol_flush_timer.start()

        elif mode == 1:
            self._last_user_bright_adjust_time = now
            new_val = max(5, min(100, self._cached_brightness + delta))
            self._cached_brightness = new_val
            self.osdTriggered.emit("☀️", "Display", new_val)
            self.sendIpcCmd("BRIGHTNESS_DELTA", delta=delta)
            self._execute_local_brightness(new_val)

        elif mode == 2:
            self._last_user_mic_adjust_time = now
            if self._mic_muted:
                self._mic_muted = False
                self.hardwareMuteStateChanged.emit(self._vol_muted, self._mic_muted)
                self._execute_local_mic_mute(False)

            new_val = max(0, min(100, self._cached_mic + delta))
            self._cached_mic = new_val
            self.osdTriggered.emit("🎙️", "Microphone", new_val)
            self.sendIpcCmd("MIC_DELTA", delta=delta)
            self._execute_local_mic_volume(new_val)

    @Slot(int)
    def toggleHardwareMute(self, mode: int):
        now = time.monotonic()
        if mode == 0:
            self._last_user_vol_adjust_time = now
            self._vol_muted = not self._vol_muted
            self.hardwareMuteStateChanged.emit(self._vol_muted, self._mic_muted)

            if self._vol_muted:
                self.osdTriggered.emit("🔇", "Volume", 0)
                self.sendIpcCmd("VOLUME_MUTE_TOGGLE")
                self._execute_local_volume_mute(True)
            else:
                if self._cached_volume == 0:
                    self._cached_volume = 20
                    self.volumeChanged.emit(self._cached_volume)
                self.osdTriggered.emit("🔊", "Volume", self._cached_volume)
                self.sendIpcCmd("VOLUME_MUTE_TOGGLE")
                self._execute_local_volume_mute(False)
                self._execute_local_volume(self._cached_volume)

        elif mode == 1:
            self._last_user_bright_adjust_time = now
            if self._cached_brightness > 15:
                self._prev_brightness = self._cached_brightness
                self._cached_brightness = 5
            else:
                self._cached_brightness = max(20, min(100, self._prev_brightness))
            self.osdTriggered.emit("☀️", "Display", self._cached_brightness)
            self.sendIpcCmd("BRIGHTNESS_SET", value=self._cached_brightness)
            self._execute_local_brightness(self._cached_brightness)

        elif mode == 2:
            self._last_user_mic_adjust_time = now
            self._mic_muted = not self._mic_muted
            self.hardwareMuteStateChanged.emit(self._vol_muted, self._mic_muted)
            disp_val = 0 if self._mic_muted else min(100, max(0, self._cached_mic))
            self.osdTriggered.emit("🚫" if self._mic_muted else "🎙️", "Microphone", disp_val)
            self.sendIpcCmd("MIC_MUTE_TOGGLE")
            self._execute_local_mic_mute(self._mic_muted)

    def _flush_volume_to_hardware(self):
        final_val = self._cached_volume
        self.sendIpcCmd("VOLUME_SET", value=final_val)
        self._execute_local_volume(final_val)

    @Slot(int)
    def adjustVolume(self, delta_pct: int):
        self.adjustHardware(0, delta_pct)

    def _execute_local_volume(self, val: int):
        val = max(0, min(100, val))
        def _run():
            if shutil.which("wpctl"):
                subprocess.run(
                    ["wpctl", "set-volume", "--limit", "1.0", "@DEFAULT_AUDIO_SINK@", f"{val/100.0:.2f}"],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                )
            elif shutil.which("pamixer"):
                subprocess.run(["pamixer", "--set-volume", str(val)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif shutil.which("amixer"):
                subprocess.run(["amixer", "-D", "pulse", "sset", "Master", f"{val}%"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self._pool.submit(_run)

    def _execute_local_brightness(self, val: int):
        val = max(5, min(100, val))
        def _run():
            if shutil.which("brightnessctl"):
                subprocess.run(["brightnessctl", "set", f"{val}%"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self._pool.submit(_run)

    def _execute_local_volume_mute(self, is_mute: bool):
        def _run():
            if shutil.which("wpctl"):
                subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1" if is_mute else "0"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif shutil.which("pamixer"):
                subprocess.run(["pamixer", "-m" if is_mute else "-u"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self._pool.submit(_run)

    def _execute_local_mic_volume(self, val: int):
        val = max(0, min(100, val))
        def _run():
            if shutil.which("wpctl"):
                subprocess.run(["wpctl", "set-volume", "--limit", "1.0", "@DEFAULT_AUDIO_SOURCE@", f"{val/100.0:.2f}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif shutil.which("pamixer"):
                subprocess.run(["pamixer", "--default-source", "--set-volume", str(val)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self._pool.submit(_run)

    def _execute_local_mic_mute(self, is_mute: bool):
        def _run():
            if shutil.which("wpctl"):
                subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "1" if is_mute else "0"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif shutil.which("pamixer"):
                subprocess.run(["pamixer", "--default-source", "-m" if is_mute else "-u"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self._pool.submit(_run)

    def _extract_cover_color(self, art_url: str):
        if not art_url:
            self.dominantColorUpdated.emit("#22c55e")
            return

        def _extract():
            try:
                clean_url = art_url.strip().split("?")[0]
                img_bytes = None

                if clean_url.startswith("http://") or clean_url.startswith("https://"):
                    req = urllib.request.Request(clean_url, headers={"User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(req, timeout=3.0) as resp:
                        img_bytes = resp.read()
                else:
                    local_path = clean_url[7:] if clean_url.startswith("file://") else clean_url
                    local_path = urllib.parse.unquote(local_path)
                    if os.path.exists(local_path):
                        with open(local_path, "rb") as f:
                            img_bytes = f.read()

                if not img_bytes:
                    return

                try:
                    import io
                    from PIL import Image
                    im = Image.open(io.BytesIO(img_bytes)).convert("RGB").resize((24, 24))
                    colors = im.getcolors(maxcolors=576) or []
                    best_col = None
                    max_score = -1.0
                    for count, (r, g, b) in colors:
                        lum = 0.299 * r + 0.587 * g + 0.114 * b
                        if lum < 35 or lum > 225:
                            continue
                        sat = max(r, g, b) - min(r, g, b)
                        if sat < 25:
                            continue
                        score = (sat * 2.0 + (255 - abs(lum - 128))) * (1.0 + (count / 576.0))
                        if score > max_score:
                            max_score = score
                            best_col = (r, g, b)

                    if best_col:
                        hex_c = f"#{best_col[0]:02x}{best_col[1]:02x}{best_col[2]:02x}"
                        self._curr_dominant_color = hex_c
                        self.dominantColorUpdated.emit(hex_c)
                        return
                except Exception:
                    pass

                self.dominantColorUpdated.emit("#22c55e")
            except Exception as e:
                app_logger.warning(f"主色调解析异常: {e}")

        self._pool.submit(_extract)

    def _setup_clipboard_listener(self):
        clipboard = QGuiApplication.clipboard()
        clipboard.dataChanged.connect(self._on_clipboard_changed)

    def _on_clipboard_changed(self):
        if self.config and not self.config.clipboardMonitorEnabled:
            return

        clipboard = QGuiApplication.clipboard()
        mime = clipboard.mimeData()
        if not mime:
            return

        formats = set(mime.formats())
        if formats.intersection(CONCEAL_MIME_TYPES):
            app_logger.info("捕获到受密码管理器保护的剪贴板更新，已触发隐私掩码。")
            self.clipboardTriggered.emit("🔐", "密码凭据", "已安全复制保密数据 · [已脱敏]", 1400)
            return

        if mime.hasImage():
            self.clipboardTriggered.emit("🖼️", "截图/图像", "已复制到剪贴板", 1300)
            return

        if mime.hasText():
            raw_text = clipboard.text()
            if not raw_text:
                return

            content_hash = hashlib.sha256(raw_text.encode("utf-8")).hexdigest()[:16]
            if content_hash == self._last_clip_hash:
                return
            self._last_clip_hash = content_hash

            clean_text = raw_text.strip()
            count = len(clean_text)
            if count == 0:
                return

            preview = clean_text.replace("\n", " ").replace("\r", " ").strip()
            if len(preview) > 16:
                preview = preview[:14] + "..."

            detail_str = f"已复制 {count} 字符 · \"{preview}\""
            self.clipboardTriggered.emit("📋", "剪贴板", detail_str, 1300)

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

    def _poll_memory_usage(self):
        try:
            total_kb, avail_kb = 0, 0
            with open("/proc/meminfo", "r", encoding="utf-8") as f:
                for line in f:
                    if line.startswith("MemTotal:"):
                        total_kb = int(line.split()[1])
                    elif line.startswith("MemAvailable:"):
                        avail_kb = int(line.split()[1])
                    if total_kb and avail_kb:
                        break

            if total_kb > 0:
                used_kb = max(0, total_kb - avail_kb)
                pct = int(round((used_kb / total_kb) * 100))
                used_gb = f"{used_kb / (1024 * 1024):.1f}G"
                total_gb = f"{total_kb / (1024 * 1024):.1f}G"
                self.memoryUpdated.emit(pct, used_gb, total_gb)
        except Exception:
            pass

    @Slot(str, str)
    def _handle_daemon_payload(self, m_type: str, data_str: str):
        try:
            data = json.loads(data_str) if data_str else {}
        except Exception as e:
            app_logger.error(f"解析报文异常: {e}")
            return

        now = time.monotonic()

        if m_type in ("MEDIA_PROGRESS", "MEDIA_TICK") and "media" in data:
            m = data["media"]
            self._apply_media_progress(m.get("position"), m.get("duration"), float(m.get("progress", -1.0)))

        elif m_type in ("MEDIA_UPDATE", "FULL_SYNC") and "media" in data:
            m = data["media"]
            raw_art = m.get("art_url") or m.get("artUrl") or m.get("mpris:artUrl") or m.get("cover") or m.get("thumbnail") or ""
            art = raw_art
            if art and art.startswith("/") and not art.startswith("file://"):
                art = "file://" + art

            title = m.get("title", "等待播放...")
            artist = m.get("artist", "未知歌手")
            status = m.get("status", "Paused")

            self._apply_media_state(
                title,
                artist,
                status,
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

        if (m_type in ("VOLUME_UPDATE", "FULL_SYNC")) and "system" in data:
            sys_info = data["system"]
            raw_vol = int(sys_info.get("volume", self._cached_volume))
            real_vol = max(0, min(100, raw_vol))
            is_muted = bool(sys_info.get("muted", False))

            if (now - self._last_user_vol_adjust_time) > 0.6:
                if self._cached_volume != real_vol:
                    self._cached_volume = real_vol
                    self.volumeChanged.emit(self._cached_volume)
                self._vol_muted = is_muted
                self.hardwareMuteStateChanged.emit(self._vol_muted, self._mic_muted)
                if m_type == "VOLUME_UPDATE":
                    self.osdTriggered.emit("🔇" if is_muted else "🔊", "Volume", real_vol)

        elif m_type == "BRIGHTNESS_UPDATE" and "system" in data:
            if (now - self._last_user_bright_adjust_time) > 0.6:
                b_val = max(5, min(100, int(data["system"].get("brightness", self._cached_brightness))))
                self._cached_brightness = b_val
                self.osdTriggered.emit("☀️", "Display", b_val)

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

        if m_type == "TEAMS_CALL_INCOMING":
            if "notification" in data:
                noti = data["notification"]
                t_title = noti.get("title", "").strip() or "Teams 来电"
                t_sub = noti.get("content", "").strip() or "正在呼叫..."
                raw_avatar = noti.get("avatar", "")
                safe_avatar = process_notification_avatar(raw_avatar) if raw_avatar else ""
                self.callIncomingTriggered.emit(t_title, t_sub, safe_avatar)
                self.view.raise_()

        elif m_type in ("TEAMS_NOTIFICATION", "BROWSER_NOTIFICATION"):
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
                    self.alertTriggered.emit(noti.get("icon", "🔔"), t_title, t_sub, 4500, safe_avatar)

        elif m_type == "TEAMS_CALL_ENDED":
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

        if is_track_changed or (art and art != self._curr_art):
            self._curr_art = art
            if art:
                self._extract_cover_color(art)
            else:
                self.dominantColorUpdated.emit("#22c55e")

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

    @Slot("QVariantList")
    def updateCompositeMask(self, rects):
        if not rects:
            self.setPassthrough()
            return

        composite = QRegion()
        vw = self.view.width()
        vh = self.view.height()

        for r in rects:
            rx = max(0, int(r.get("x", 0)))
            ry = max(0, int(r.get("y", 0)))
            rw = min(vw - rx, int(r.get("w", 0)))
            rh = min(vh - ry, int(r.get("h", 0)))
            radius = int(r.get("r", 0))

            if rw <= 0 or rh <= 0:
                continue

            if radius <= 0:
                composite = composite.united(QRect(rx, ry, rw, rh))
            else:
                path = QPainterPath()
                path.addRoundedRect(rx, ry, rw, rh, radius, radius)
                poly = path.toFillPolygon().toPolygon()
                composite = composite.united(QRegion(poly))

        if not composite.isEmpty():
            if composite != self._last_applied_mask:
                self._last_applied_mask = composite
                self.view.setMask(composite)
                self.view.requestUpdate()
        else:
            self.setPassthrough()

    @Slot()
    def setPassthrough(self):
        passthrough_region = QRegion(-10, -10, 1, 1)
        if self._last_applied_mask != passthrough_region:
            self._last_applied_mask = passthrough_region
            self.view.setMask(passthrough_region)
            self.view.requestUpdate()

    @Slot()
    def clearMask(self):
        self._last_applied_mask = QRegion()
        self.view.setMask(QRegion())
        self.view.requestUpdate()

    @Slot()
    def forceClearWindow(self):
        self.view.requestUpdate()

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

    @Slot(str)
    def executePowerAction(self, action: str):
        app_logger.info(f"触发系统电源/会话管理指令 -> {action}")
        self.sendIpcCmd(action)

    @Slot()
    def answerTeamsCall(self):
        self.sendIpcCmd("TEAMS_ANSWER")

    @Slot()
    def rejectTeamsCall(self):
        self.sendIpcCmd("TEAMS_REJECT")

    @Slot()
    def focusTeamsWindow(self):
        self.sendIpcCmd("TEAMS_FOCUS")
        def _focus():
            candidates = ["teams-for-linux", "Microsoft Teams", "crx_cifhbcnohmdccbgoicgdjpfamggdegmo"]
            for kw in candidates:
                try:
                    if shutil.which("wmctrl"):
                        if subprocess.run(["wmctrl", "-x", "-a", kw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0).returncode == 0:
                            return
                    if shutil.which("hyprctl"):
                        res = subprocess.run(["hyprctl", "dispatch", "focuswindow", f"class:(.*{kw}.*)"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0)
                        if res.returncode == 0:
                            return
                    if shutil.which("swaymsg"):
                        if subprocess.run(["swaymsg", f'[class="(?i).*{kw}.*"] focus'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0).returncode == 0:
                            return
                    if shutil.which("xdotool"):
                        res = subprocess.run(["xdotool", "search", "--onlyvisible", "--class", kw, "windowactivate"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0)
                        if res.returncode == 0:
                            return
                except subprocess.TimeoutExpired:
                    continue
        self._pool.submit(_focus)

    @Slot()
    def openSystemMonitor(self):
        def _open():
            gui_candidates = ["mission-center", "resources", "gnome-system-monitor", "plasma-systemmonitor", "mate-system-monitor", "xfce4-taskmanager"]
            for cmd in gui_candidates:
                if shutil.which(cmd):
                    try:
                        subprocess.Popen([cmd])
                        return
                    except Exception as e:
                        app_logger.warning(f"唤起任务管理器异常: {e}")

            terminal_emulators = ["kitty", "alacritty", "foot", "wezterm", "gnome-terminal", "konsole", "xterm"]
            tui_monitors = ["btop", "htop", "top"]
            for term in terminal_emulators:
                if shutil.which(term):
                    for mon in tui_monitors:
                        if shutil.which(mon):
                            try:
                                subprocess.Popen([term, "-e", mon])
                                return
                            except Exception:
                                pass
        self._pool.submit(_open)

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
        self.sendIpcCmd("MEDIA_FOCUS")

        def _focus():
            try:
                if shutil.which("playerctl"):
                    subprocess.run(["playerctl", "raise"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0)
            except Exception:
                pass

            pure_players = [
                "Spotify",
                "spotify",
                "netease-cloud-music",
                "yesplaymusic",
                "qqmusic",
                "QQMusic",
                "cloud-music",
                "com.netease.cloudmusic",
                "vlc",
                "rhythmbox",
                "audacious",
                "feishin"
            ]

            for kw in pure_players:
                try:
                    if shutil.which("hyprctl"):
                        res = subprocess.run(["hyprctl", "dispatch", "focuswindow", f"class:^(?i)({kw})"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.8)
                        if res.returncode == 0:
                            return
                    if shutil.which("swaymsg"):
                        if subprocess.run(["swaymsg", f'[app_id="(?i).*{kw}.*"] focus'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.8).returncode == 0:
                            return
                    if shutil.which("wmctrl"):
                        if subprocess.run(["wmctrl", "-x", "-a", kw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.8).returncode == 0:
                            return
                except Exception:
                    continue

        self._pool.submit(_focus)