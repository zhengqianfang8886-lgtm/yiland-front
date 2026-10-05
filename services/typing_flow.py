# ==========================================
# 📄 File: services/typing_flow.py (平滑 Intensity 与迟滞防抖引擎)
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
        app_logger.warning(f"[TypingFlow] 设备解析异常: {e}")

    return list(set(keyboards))


# 🚀 色彩多段连续线性插值辅助函数 (蓝 -> 紫 -> 橙 -> 绯红)
def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    r = int(c1[0] + (c2[0] - c1[0]) * t)
    g = int(c1[1] + (c2[1] - c1[1]) * t)
    b = int(c1[2] + (c2[2] - c1[2]) * t)
    return f"#{r:02x}{g:02x}{b:02x}"


COLOR_BLUE   = (56, 189, 248)  # #38bdf8
COLOR_PURPLE = (168, 85, 247)  # #a855f7
COLOR_ORANGE = (249, 115, 22)  # #f97316
COLOR_RED    = (244, 63, 94)   # #f43f5e


def interpolate_typing_color(intensity: float) -> str:
    if intensity <= 0.35:
        # 0.0 ~ 0.35: 蓝 -> 紫
        return lerp_color(COLOR_BLUE, COLOR_PURPLE, intensity / 0.35)
    elif intensity <= 0.70:
        # 0.35 ~ 0.70: 紫 -> 橙
        return lerp_color(COLOR_PURPLE, COLOR_ORANGE, (intensity - 0.35) / 0.35)
    else:
        # 0.70 ~ 1.0: 橙 -> 绯红
        return lerp_color(COLOR_ORANGE, COLOR_RED, (intensity - 0.70) / 0.30)


class TypingFlowService(QObject):
    typingUpdated = Signal(bool, str, float, float, float, float, float)

    def __init__(self, executor, config=None, parent=None):
        super().__init__(parent)
        self._pool = executor
        self._config = config
        self._is_media_playing = False

        self._keystrokes = deque(maxlen=64)
        self._last_key_time = 0.0

        # 按键反馈层：4 颗键各自独立的物理冲程 (0.0 ~ 1.0)
        self._strokes = [0.0, 0.0, 0.0, 0.0]
        self._key_rotation = 0

        # 状态反馈层：平滑 intensity (0.0 ~ 1.0) 与迟滞状态
        self._smooth_intensity = 0.0
        self._in_rage_state = False

        self._tick_timer = QTimer(self)
        self._tick_timer.setInterval(25)  # 40 FPS 连续平滑模拟
        self._tick_timer.timeout.connect(self._physics_tick)
        self._tick_timer.start()

        self._stop_event = threading.Event()
        self._pool.submit(self._start_keyboard_listener)

    def set_media_playing(self, playing: bool):
        self._is_media_playing = playing

    def _start_keyboard_listener(self):
        kbd_paths = find_system_keyboards()
        open_fds = {}

        for path in kbd_paths:
            try:
                fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                open_fds[fd] = path
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
                                if ev_type != 1 or val != 1 or code >= 0x100:
                                    continue
                                if code in (113, 114, 115, 142, 143, 224, 225):
                                    continue
                                self._record_stroke()
                        except (OSError, Exception):
                            try: os.close(fd)
                            except Exception: pass
                            open_fds.pop(fd, None)
                except Exception:
                    time.sleep(0.05)
            return

        if os.environ.get("DISPLAY") and shutil.which("xinput"):
            try:
                proc = subprocess.Popen(
                    ["xinput", "test-xi2", "--root"],
                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1
                )
                while not self._stop_event.is_set() and proc.poll() is None:
                    line = proc.stdout.readline()
                    if not line: break
                    if "EVENT type 2 (KeyPress)" in line or "RawKeyPress" in line:
                        self._record_stroke()
                proc.terminate()
            except Exception:
                pass

    def _record_stroke(self):
        if self._config and hasattr(self._config, "typingVisualizerEnabled") and not self._config.typingVisualizerEnabled:
            return

        now = time.monotonic()
        self._keystrokes.append(now)
        self._last_key_time = now

        # 【按键反馈】：按下的单键瞬间获取 1.0 冲量，相邻键极其轻微带动 (0.15)
        idx = self._key_rotation
        self._strokes[idx] = 1.0
        self._strokes[(idx - 1) % 4] = min(1.0, self._strokes[(idx - 1) % 4] + 0.15)
        self._strokes[(idx + 1) % 4] = min(1.0, self._strokes[(idx + 1) % 4] + 0.15)
        self._key_rotation = (self._key_rotation + 1) % 4

    def _physics_tick(self):
        now = time.monotonic()
        while self._keystrokes and (now - self._keystrokes[0]) > 1.0:
            self._keystrokes.popleft()

        kps = float(len(self._keystrokes))
        idle_duration = (now - self._last_key_time) if self._last_key_time > 0 else 999.0

        # 1. 瞬态按键阻尼衰减（慢打时回落）
        for i in range(4):
            self._strokes[i] *= 0.80
            if self._strokes[i] < 0.005:
                self._strokes[i] = 0.0

        # 2. 计算目标 intensity (0.0 ~ 1.0)
        if idle_duration > 1.4:
            target_intensity = 0.0
        else:
            # 0~10 KPS 平滑映射到 0.0 ~ 1.0
            target_intensity = min(1.0, max(0.05, kps / 10.0))

        # 3. 对 intensity 做低通平滑滤波 (EMA: 上升灵敏 0.25，回落柔和 0.08)
        lerp_rate = 0.25 if target_intensity > self._smooth_intensity else 0.08
        self._smooth_intensity += (target_intensity - self._smooth_intensity) * lerp_rate
        if self._smooth_intensity < 0.005:
            self._smooth_intensity = 0.0

        # 4. Hysteresis (迟滞区间判定)：防超频档位抖动
        if not self._in_rage_state and self._smooth_intensity >= 0.85:
            self._in_rage_state = True
        elif self._in_rage_state and self._smooth_intensity < 0.68:
            self._in_rage_state = False

        # 5. 高速心流时的键帽交替起伏叠加
        if self._smooth_intensity > 0.35:
            freq = 9.0 + self._smooth_intensity * 14.0
            phase = now * freq
            wave_amp = (self._smooth_intensity - 0.35) * 0.9
            self._strokes[0] = max(self._strokes[0], (math.sin(phase) * 0.5 + 0.5) * wave_amp)
            self._strokes[1] = max(self._strokes[1], (math.sin(phase + 1.57) * 0.5 + 0.5) * wave_amp)
            self._strokes[2] = max(self._strokes[2], (math.sin(phase + 3.14) * 0.5 + 0.5) * wave_amp)
            self._strokes[3] = max(self._strokes[3], (math.sin(phase + 4.71) * 0.5 + 0.5) * wave_amp)

        is_active = (self._smooth_intensity > 0.01) or (idle_duration < 1.4)
        continuous_color = interpolate_typing_color(self._smooth_intensity)

        # 将 smooth_intensity 通过原有的 kps 接口透传（乘以 10 保持量纲与兼容）
        self.typingUpdated.emit(
            is_active, continuous_color,
            round(self._strokes[0], 3),
            round(self._strokes[1], 3),
            round(self._strokes[2], 3),
            round(self._strokes[3], 3),
            round(self._smooth_intensity * 10.0, 2)
        )

    def cleanup(self):
        self._stop_event.set()