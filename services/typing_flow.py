# ==========================================
# 📄 File: services/typing_flow.py
# ==========================================
import os
import sys
import time
import math
import select
import struct
import shutil
import subprocess
import threading
from collections import deque
from PySide6.QtCore import QObject, QTimer, Signal
from logger import app_logger

IS_64BIT = struct.calcsize("P") == 8
EVENT_FORMAT = "qqHHi" if IS_64BIT else "iiHHi"
EVENT_SIZE = struct.calcsize(EVENT_FORMAT)


def find_system_keyboards() -> list:
    keyboards = []
    try:
        if not os.path.exists("/proc/bus/input/devices"):
            return keyboards

        with open("/proc/bus/input/devices", "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        for section in content.split("\n\n"):
            has_kbd = False
            event_node = None
            is_ignored = False

            for line in section.split("\n"):
                line = line.strip()
                if line.startswith("N: Name="):
                    name = line.split("=", 1)[1].strip('"').lower()
                    excluded_words = [
                        "mouse", "touchpad", "trackpoint", "pointer",
                        "wacom", "stylus", "finger", "touchscreen",
                        "power", "sleep", "lid", "video", "button",
                        "switch", "consumer control", "system control"
                    ]
                    if any(bad in name for bad in excluded_words):
                        is_ignored = True
                        break
                    if "keyboard" in name or "kbd" in name or "at translated" in name:
                        has_kbd = True

                elif line.startswith("H: Handlers="):
                    parts = line.split("=", 1)[1].split()
                    if any(p.startswith("mouse") or p.startswith("js") for p in parts):
                        is_ignored = True
                        break
                    if "kbd" in parts:
                        has_kbd = True
                    for p in parts:
                        if p.startswith("event"):
                            event_node = p

            if has_kbd and event_node and not is_ignored:
                node_path = f"/dev/input/{event_node}"
                if os.path.exists(node_path):
                    keyboards.append(node_path)
    except Exception as e:
        app_logger.warning(f"[TypingFlow] 解析输入设备列表异常: {e}")

    return list(set(keyboards))


class TypingFlowService(QObject):
    typingUpdated = Signal(bool, str, float, float, float, float, float)

    ACTIVATION_STROKE_COUNT = 3
    INTENT_EVAL_WINDOW = 0.95
    REST_IDLE_TIMEOUT = 1.85
    MIN_DISPLAY_DURATION = 1.8

    def __init__(self, executor, config=None, parent=None):
        super().__init__(parent)
        self._pool = executor
        self._config = config
        self._is_media_playing = False

        self._keystrokes = deque(maxlen=64)
        self._last_key_time = 0.0
        self._activated_at = 0.0

        self._energy = 0.0
        self._active = False
        self._current_kps = 0.0

        self._s1_smooth = 0.18
        self._s2_smooth = 0.18
        self._s3_smooth = 0.18
        self._s4_smooth = 0.18

        self._tick_timer = QTimer(self)
        self._tick_timer.setInterval(33)
        self._tick_timer.timeout.connect(self._physics_tick)
        self._tick_timer.start()

        self._stop_event = threading.Event()
        self._pool.submit(self._start_keyboard_listener)

    def set_media_playing(self, playing: bool):
        self._is_media_playing = playing
        if playing and self._active:
            self._active = False
            self.typingUpdated.emit(False, "#38bdf8", 0.18, 0.18, 0.18, 0.18, 0.0)

    def _start_keyboard_listener(self):
        kbd_paths = find_system_keyboards()
        open_fds = {}

        for path in kbd_paths:
            try:
                fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                open_fds[fd] = path
                app_logger.info(f"✨ [TypingFlow] 成功挂载键盘节点: {path}")
            except Exception:
                pass

        if open_fds:
            while not self._stop_event.is_set():
                if not open_fds:
                    break
                try:
                    r_list, _, _ = select.select(list(open_fds.keys()), [], [], 0.1)
                    for fd in r_list:
                        try:
                            data = os.read(fd, EVENT_SIZE)
                            if len(data) >= EVENT_SIZE:
                                _, _, ev_type, code, val = struct.unpack(EVENT_FORMAT, data[:EVENT_SIZE])
                                if ev_type != 1 or val != 1:
                                    continue
                                if code >= 0x100:  # 过滤非键盘实体按键
                                    continue
                                if code in (113, 114, 115, 142, 143, 224, 225):
                                    continue
                                self._record_stroke()
                        except (OSError, Exception) as read_err:
                            # 🚀【关键修复】：外设拔除或报错时立即清理破损句柄，绝不引起 CPU 盲轮询
                            app_logger.info(f"[TypingFlow] 输入节点已断开，安全释放: {open_fds.get(fd)}")
                            try:
                                os.close(fd)
                            except Exception:
                                pass
                            open_fds.pop(fd, None)
                except Exception:
                    time.sleep(0.05)

            for fd in list(open_fds.keys()):
                try:
                    os.close(fd)
                except Exception:
                    pass
            if not self._stop_event.is_set():
                # 若所有节点因拔出失效，等待后可重新探测
                time.sleep(2.0)
                if not self._stop_event.is_set():
                    self._pool.submit(self._start_keyboard_listener)
            return

        # 降级模式 2：X11 xinput
        if os.environ.get("DISPLAY") and shutil.which("xinput"):
            try:
                app_logger.info("[TypingFlow] 降级至 X11 xinput 监听通道")
                proc = subprocess.Popen(
                    ["xinput", "test-xi2", "--root"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True,
                    bufsize=1
                )
                while not self._stop_event.is_set() and proc.poll() is None:
                    line = proc.stdout.readline()
                    if not line: break
                    if "RawButton" in line or "ButtonPress" in line: continue
                    if "EVENT type 2 (KeyPress)" in line or "RawKeyPress" in line:
                        self._record_stroke()
                proc.terminate()
                return
            except Exception as e:
                app_logger.warning(f"[TypingFlow] xinput 通道异常: {e}")

        # 降级模式 3：pynput
        try:
            from pynput import keyboard
            def on_press(key):
                self._record_stroke()
            with keyboard.Listener(on_press=on_press) as listener:
                app_logger.info("[TypingFlow] 启动 pynput 兜底键盘监听")
                self._stop_event.wait()
                listener.stop()
            return
        except Exception:
            pass

        app_logger.warning("⚠️ [TypingFlow] 缺少 input 设备权限。运行: sudo usermod -aG input $USER")

    def _record_stroke(self):
        if self._is_media_playing:
            return
        if self._config and hasattr(self._config, "typingVisualizerEnabled") and not self._config.typingVisualizerEnabled:
            return

        now = time.monotonic()
        self._keystrokes.append(now)
        self._last_key_time = now
        self._energy = min(1.0, self._energy + 0.35)

    def _physics_tick(self):
        if self._is_media_playing:
            return

        now = time.monotonic()
        while self._keystrokes and (now - self._keystrokes[0]) > 1.0:
            self._keystrokes.popleft()

        kps = len(self._keystrokes)
        self._current_kps = kps
        idle_duration = (now - self._last_key_time) if self._last_key_time > 0 else 999.0
        self._energy *= 0.88

        if not self._active:
            if len(self._keystrokes) >= self.ACTIVATION_STROKE_COUNT:
                recent_gap = self._keystrokes[-1] - self._keystrokes[-2]
                if recent_gap < 0.65 and idle_duration < 0.4:
                    self._active = True
                    self._activated_at = now

        if self._active:
            is_timeout = (idle_duration >= self.REST_IDLE_TIMEOUT)
            is_min_time_passed = (now - self._activated_at >= self.MIN_DISPLAY_DURATION)

            if is_timeout and is_min_time_passed:
                if self._energy < 0.08 or kps == 0:
                    self._active = False
                    self._s1_smooth = 0.18
                    self._s2_smooth = 0.18
                    self._s3_smooth = 0.18
                    self._s4_smooth = 0.18
                    self.typingUpdated.emit(False, "#38bdf8", 0.18, 0.18, 0.18, 0.18, 0.0)
                    return

        if not self._active:
            return

        phase = now * 13.0
        target_w1 = 0.18 + min(0.70, (kps / 9.5) * 0.55 + self._energy * 0.28 + math.sin(phase) * 0.05)
        target_w2 = 0.18 + min(0.82, (kps / 8.5) * 0.65 + self._energy * 0.35 + math.sin(phase + 1.2) * 0.07)
        target_w3 = 0.18 + min(0.80, (kps / 9.0) * 0.60 + self._energy * 0.32 + math.cos(phase + 2.3) * 0.06)
        target_w4 = 0.18 + min(0.75, (kps / 10.5) * 0.50 + self._energy * 0.38 + math.sin(phase * 1.4) * 0.08)

        lerp_factor = 0.35
        self._s1_smooth = self._s1_smooth * (1.0 - lerp_factor) + target_w1 * lerp_factor
        self._s2_smooth = self._s2_smooth * (1.0 - lerp_factor) + target_w2 * lerp_factor
        self._s3_smooth = self._s3_smooth * (1.0 - lerp_factor) + target_w3 * lerp_factor
        self._s4_smooth = self._s4_smooth * (1.0 - lerp_factor) + target_w4 * lerp_factor

        if kps >= 7.5: color = "#f43f5e"
        elif kps >= 3.5: color = "#a855f7"
        else: color = "#38bdf8"

        self.typingUpdated.emit(
            True, color,
            max(0.18, min(1.0, round(self._s1_smooth, 3))),
            max(0.18, min(1.0, round(self._s2_smooth, 3))),
            max(0.18, min(1.0, round(self._s3_smooth, 3))),
            max(0.18, min(1.0, round(self._s4_smooth, 3))),
            round(kps, 1)
        )

    def cleanup(self):
        self._stop_event.set()