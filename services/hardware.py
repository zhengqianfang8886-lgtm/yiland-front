# ==========================================
# 📄 File: services/hardware.py
# ==========================================
import os
import glob
import time
import shutil
import subprocess
import re
from PySide6.QtCore import QObject, QTimer, Signal


class HardwareService(QObject):
    volumeChanged = Signal(int)
    brightnessChanged = Signal(int)
    hardwareMuteStateChanged = Signal(bool, bool)
    capsLockChanged = Signal(bool)
    memoryUpdated = Signal(int, str, str)
    osdTriggered = Signal(str, str, int)

    def __init__(self, executor, send_ipc_func, parent=None):
        super().__init__(parent)
        self._pool = executor
        self._send_ipc = send_ipc_func

        self._cached_volume = 50
        self._vol_muted = False
        
        self._cached_brightness = self._read_system_brightness()
        self._prev_brightness = self._cached_brightness
        self._cached_mic = 80
        self._mic_muted = False

        self._last_user_vol_adjust_time = 0.0
        self._last_user_bright_adjust_time = 0.0
        self._last_user_mic_adjust_time = 0.0

        # 音量写回防抖定时器
        self._vol_flush_timer = QTimer(self)
        self._vol_flush_timer.setSingleShot(True)
        self._vol_flush_timer.setInterval(25)
        self._vol_flush_timer.timeout.connect(self._flush_volume_to_hardware)

        # 内存监控 (2秒周期)
        self._mem_timer = QTimer(self)
        self._mem_timer.setInterval(2000)
        self._mem_timer.timeout.connect(self._poll_memory_usage)
        self._mem_timer.start()

        # 大写锁监控状态与防抖节流
        self._is_caps_lock = False
        self._caps_led_paths = []
        self._last_xset_poll_time = 0.0
        self._refresh_caps_paths()
        
        self._caps_timer = QTimer(self)
        self._caps_timer.setInterval(150)
        self._caps_timer.timeout.connect(self._check_caps_lock)
        self._caps_timer.start()

        # 硬件亮度轮询 (1.5秒周期)
        self._hw_poll_timer = QTimer(self)
        self._hw_poll_timer.setInterval(1500)
        self._hw_poll_timer.timeout.connect(self._poll_system_brightness)
        self._hw_poll_timer.start()

    @property
    def current_volume(self) -> int:
        return self._cached_volume

    @property
    def current_brightness(self) -> int:
        return self._cached_brightness

    @property
    def is_caps_lock(self) -> bool:
        return self._is_caps_lock

    def _read_system_brightness(self) -> int:
        try:
            backlight_dirs = glob.glob("/sys/class/backlight/*")
            for b_dir in backlight_dirs:
                cur_path = os.path.join(b_dir, "brightness")
                max_path = os.path.join(b_dir, "max_brightness")
                if os.path.exists(cur_path) and os.path.exists(max_path):
                    with open(cur_path, "r") as f_cur, open(max_path, "r") as f_max:
                        cur = float(f_cur.read().strip())
                        max_b = float(f_max.read().strip())
                        if max_b > 0:
                            return max(5, min(100, int(round((cur / max_b) * 100))))
        except Exception:
            pass

        if shutil.which("brightnessctl"):
            try:
                res = subprocess.run(["brightnessctl", "info"], capture_output=True, text=True, timeout=0.4)
                m = re.search(r"\((\d+)%\)", res.stdout)
                if m:
                    return max(5, min(100, int(m.group(1))))
            except Exception:
                pass
        return 100

    def _poll_system_brightness(self):
        if (time.monotonic() - self._last_user_bright_adjust_time) < 1.8:
            return
        real_val = self._read_system_brightness()
        if abs(real_val - self._cached_brightness) >= 1:
            self._cached_brightness = real_val
            self.brightnessChanged.emit(self._cached_brightness)

    def adjust_hardware(self, mode: int, delta: int):
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
            self.brightnessChanged.emit(self._cached_brightness)
            self.osdTriggered.emit("☀️", "Display", new_val)
            self._send_ipc("BRIGHTNESS_DELTA", delta=delta)
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
            self._send_ipc("MIC_DELTA", delta=delta)
            self._execute_local_mic_volume(new_val)

    def toggle_hardware_mute(self, mode: int):
        now = time.monotonic()
        if mode == 0:
            self._last_user_vol_adjust_time = now
            self._vol_muted = not self._vol_muted
            self.hardwareMuteStateChanged.emit(self._vol_muted, self._mic_muted)

            if self._vol_muted:
                self.osdTriggered.emit("🔇", "Volume", 0)
                self._send_ipc("VOLUME_MUTE_TOGGLE")
                self._execute_local_volume_mute(True)
            else:
                if self._cached_volume == 0:
                    self._cached_volume = 20
                    self.volumeChanged.emit(self._cached_volume)
                self.osdTriggered.emit("🔊", "Volume", self._cached_volume)
                self._send_ipc("VOLUME_MUTE_TOGGLE")
                self._execute_local_volume_mute(False)
                self._execute_local_volume(self._cached_volume)

        elif mode == 1:
            self._last_user_bright_adjust_time = now
            if self._cached_brightness > 15:
                self._prev_brightness = self._cached_brightness
                self._cached_brightness = 5
            else:
                self._cached_brightness = max(20, min(100, self._prev_brightness))
            self.brightnessChanged.emit(self._cached_brightness)
            self.osdTriggered.emit("☀️", "Display", self._cached_brightness)
            self._send_ipc("BRIGHTNESS_SET", value=self._cached_brightness)
            self._execute_local_brightness(self._cached_brightness)

        elif mode == 2:
            self._last_user_mic_adjust_time = now
            self._mic_muted = not self._mic_muted
            self.hardwareMuteStateChanged.emit(self._vol_muted, self._mic_muted)
            disp_val = 0 if self._mic_muted else min(100, max(0, self._cached_mic))
            self.osdTriggered.emit("🚫" if self._mic_muted else "🎙️", "Microphone", disp_val)
            self._send_ipc("MIC_MUTE_TOGGLE")
            self._execute_local_mic_mute(self._mic_muted)

    def apply_daemon_volume(self, real_vol: int, is_muted: bool, m_type: str):
        if (time.monotonic() - self._last_user_vol_adjust_time) > 0.6:
            if self._cached_volume != real_vol:
                self._cached_volume = real_vol
                self.volumeChanged.emit(self._cached_volume)
            self._vol_muted = is_muted
            self.hardwareMuteStateChanged.emit(self._vol_muted, self._mic_muted)
            if m_type == "VOLUME_UPDATE":
                self.osdTriggered.emit("🔇" if is_muted else "🔊", "Volume", real_vol)

    def apply_daemon_brightness(self, b_val: int):
        if (time.monotonic() - self._last_user_bright_adjust_time) > 0.6:
            b_val = max(5, min(100, b_val))
            if self._cached_brightness != b_val:
                self._cached_brightness = b_val
                self.brightnessChanged.emit(self._cached_brightness)
            self.osdTriggered.emit("☀️", "Display", b_val)

    def _flush_volume_to_hardware(self):
        val = self._cached_volume
        self._send_ipc("VOLUME_SET", value=val)
        self._execute_local_volume(val)

    def _execute_local_volume(self, val: int):
        val = max(0, min(100, val))
        def _run():
            if shutil.which("wpctl"):
                subprocess.run(["wpctl", "set-volume", "--limit", "1.0", "@DEFAULT_AUDIO_SINK@", f"{val/100.0:.2f}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
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

    def _refresh_caps_paths(self):
        try:
            self._caps_led_paths = glob.glob("/sys/class/leds/*capslock*/brightness")
        except Exception:
            self._caps_led_paths = []

    # 🚀【核心优化 1】：根除 150ms xset 子进程死循环炸弹
    def _check_caps_lock(self):
        if not self._caps_led_paths:
            self._refresh_caps_paths()

        active = False
        found = False

        # 优先走内核 sysfs 文件直接读取（纯内存级 I/O，150ms 零性能损耗）
        if self._caps_led_paths:
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

        # 降级模式：没有 sysfs 节点时才尝试 xset，并施加 1500ms 强制节流，绝不狂拉进程
        if not found and shutil.which("xset"):
            now = time.monotonic()
            if (now - self._last_xset_poll_time) >= 1.5:
                self._last_xset_poll_time = now
                try:
                    res = subprocess.run(["xset", "q"], capture_output=True, text=True, timeout=0.2)
                    if "Caps Lock:   on" in res.stdout:
                        active = True
                except Exception:
                    pass
            else:
                # 在节流周期内保留上一次探测的状态，不进行高频探测
                active = self._is_caps_lock

        if active != self._is_caps_lock:
            self._is_caps_lock = active
            self.capsLockChanged.emit(self._is_caps_lock)

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