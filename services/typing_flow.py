# ==========================================
# 📄 File: services/typing_flow.py
# 🌟 修复跨线程 QTimer 启动冲突 · 线程安全唤醒
# ==========================================
import os
import time
import select
import struct
import shutil
import subprocess
import threading
import re
from collections import deque
from PySide6.QtCore import QObject, QTimer, Signal, Qt

IS_64BIT = struct.calcsize("P") == 8
EVENT_FORMAT = "qqHHi" if IS_64BIT else "iiHHi"
EVENT_SIZE = struct.calcsize(EVENT_FORMAT)

EVDEV_KEY_MAP = {
    1: "Esc", 2: "1", 3: "2", 4: "3", 5: "4", 6: "5", 7: "6", 8: "7", 9: "8", 10: "9", 11: "0",
    12: "-", 13: "=", 14: "Bksp", 15: "Tab",
    16: "Q", 17: "W", 18: "E", 19: "R", 20: "T", 21: "Y", 22: "U", 23: "I", 24: "O", 25: "P",
    26: "[", 27: "]", 28: "Enter",
    30: "A", 31: "S", 32: "D", 33: "F", 34: "G", 35: "H", 36: "J", 37: "K", 38: "L",
    39: ";", 40: "'", 41: "`",
    43: "\\", 44: "Z", 45: "X", 46: "C", 47: "V", 48: "B", 49: "N", 50: "M",
    51: ",", 52: ".", 53: "/", 57: "Space",
    59: "F1", 60: "F2", 61: "F3", 62: "F4", 63: "F5", 64: "F6",
    65: "F7", 66: "F8", 67: "F9", 68: "F10", 87: "F11", 88: "F12",
    103: "Up", 105: "Left", 106: "Right", 108: "Down",
    111: "Del"
}

MODIFIER_KEY_MAP = {
    29: "Ctrl", 97: "Ctrl",
    42: "Shift", 54: "Shift",
    56: "Alt", 100: "Alt",
    125: "Win", 126: "Win",
}

LEFT_OUTER_KEYS = {1, 41, 2, 3, 15, 16, 17, 58, 30, 31, 42, 44, 45, 29, 125}
LEFT_INNER_KEYS = {4, 5, 6, 18, 19, 20, 32, 33, 34, 46, 47, 48, 56}
RIGHT_INNER_KEYS = {7, 8, 21, 22, 35, 36, 49, 50, 100}
RIGHT_OUTER_KEYS = {
    9, 10, 11, 12, 13, 14, 23, 24, 25, 26, 27, 28,
    37, 38, 39, 40, 43, 51, 52, 53, 54, 97,
    103, 105, 106, 108, 102, 104, 107, 109, 110, 111
}
SPACE_KEY = 57


def find_system_keyboards() -> list:
    keyboards = []
    try:
        if not os.path.exists("/proc/bus/input/devices"):
            return keyboards
        with open("/proc/bus/input/devices", "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        for section in content.split("\n\n"):
            has_kbd, event_node, is_ignored = False, None, False
            for line in section.split("\n"):
                line = line.strip()
                if line.startswith("N: Name="):
                    name = line.split("=", 1)[1].strip('"').lower()
                    if any(bad in name for bad in ["mouse", "touchpad", "trackpoint", "pointer", "stylus", "finger", "touchscreen", "power", "sleep"]):
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
    except Exception:
        pass
    return list(set(keyboards))


def lerp_color(c1, c2, t):
    t = max(0.0, min(1.0, t))
    r = int(c1[0] + (c2[0] - c1[0]) * t)
    g = int(c1[1] + (c2[1] - c1[1]) * t)
    b = int(c1[2] + (c2[2] - c1[2]) * t)
    return f"#{r:02x}{g:02x}{b:02x}"


COLOR_BLUE   = (56, 189, 248)
COLOR_PURPLE = (168, 85, 247)
COLOR_ORANGE = (249, 115, 22)
COLOR_RED    = (244, 63, 94)


def interpolate_typing_color(intensity: float) -> str:
    if intensity <= 0.35:
        return lerp_color(COLOR_BLUE, COLOR_PURPLE, intensity / 0.35)
    elif intensity <= 0.70:
        return lerp_color(COLOR_PURPLE, COLOR_ORANGE, (intensity - 0.35) / 0.35)
    else:
        return lerp_color(COLOR_ORANGE, COLOR_RED, (intensity - 0.70) / 0.30)


class TypingFlowService(QObject):
    typingUpdated = Signal(bool, str, float, float, float, float, float, str, str)
    keyStrokeTriggered = Signal(str, str, int)
    # 🚀 内部跨线程信号：安全通知主线程启动定时器
    _sig_wake_timer = Signal()

    def __init__(self, executor, config=None, parent=None):
        super().__init__(parent)
        self._pool = executor
        self._config = config
        self._is_media_playing = False

        self._keystrokes = deque(maxlen=64)
        self._last_key_time = 0.0

        self._strokes = [0.0, 0.0, 0.0, 0.0]
        self._fallback_rotation = 0
        self._smooth_intensity = 0.0
        self._in_rage_state = False

        self._active_mods = set()
        self._latest_mod = ""
        self._latest_key = ""
        self._stroke_counter = 0

        self._tick_timer = QTimer(self)
        self._tick_timer.setInterval(25)
        self._tick_timer.timeout.connect(self._physics_tick)

        # 🚀 队列连接：当后台线程发射信号时，在主线程槽函数内安全拉起定时器
        self._sig_wake_timer.connect(self._safe_start_timer, Qt.ConnectionType.QueuedConnection)

        self._stop_event = threading.Event()
        self._pool.submit(self._start_keyboard_listener)

    def _safe_start_timer(self):
        if not self._tick_timer.isActive():
            self._tick_timer.start()

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
                                if ev_type == 1:
                                    self._handle_raw_key_event(code, val)
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
                    if "RawKeyPress" in line or "EVENT type 2 (KeyPress)" in line:
                        detail_match = re.search(r"detail:\s*(\d+)", line)
                        if detail_match:
                            ev_code = max(0, int(detail_match.group(1)) - 8)
                            self._handle_raw_key_event(ev_code, 1)
                    elif "RawKeyRelease" in line or "EVENT type 3 (KeyRelease)" in line:
                        detail_match = re.search(r"detail:\s*(\d+)", line)
                        if detail_match:
                            ev_code = max(0, int(detail_match.group(1)) - 8)
                            self._handle_raw_key_event(ev_code, 0)
                proc.terminate()
            except Exception:
                pass

    def _handle_raw_key_event(self, code: int, val: int):
        if self._config and hasattr(self._config, "typingVisualizerEnabled") and not self._config.typingVisualizerEnabled:
            return

        if code in MODIFIER_KEY_MAP:
            mod_name = MODIFIER_KEY_MAP[code]
            if val == 1:
                self._active_mods.add(mod_name)
            elif val == 0:
                self._active_mods.discard(mod_name)

        if val != 1 or code >= 0x100:
            return
        if code in (113, 114, 115, 142, 143, 224, 225):
            return

        now = time.monotonic()
        self._keystrokes.append(now)
        self._last_key_time = now

        # 🚀 线程安全唤醒：通过信号委托给主线程开启 QTimer
        self._sig_wake_timer.emit()

        if code == SPACE_KEY:
            self._strokes[1] = max(self._strokes[1], 0.85)
            self._strokes[2] = max(self._strokes[2], 0.85)
            self._strokes[0] = min(1.0, self._strokes[0] + 0.12)
            self._strokes[3] = min(1.0, self._strokes[3] + 0.12)
        elif code in LEFT_OUTER_KEYS:
            self._strokes[0] = 1.0
            self._strokes[1] = min(1.0, self._strokes[1] + 0.16)
        elif code in LEFT_INNER_KEYS:
            self._strokes[1] = 1.0
            self._strokes[0] = min(1.0, self._strokes[0] + 0.16)
            self._strokes[2] = min(1.0, self._strokes[2] + 0.08)
        elif code in RIGHT_INNER_KEYS:
            self._strokes[2] = 1.0
            self._strokes[3] = min(1.0, self._strokes[3] + 0.16)
            self._strokes[1] = min(1.0, self._strokes[1] + 0.08)
        elif code in RIGHT_OUTER_KEYS:
            self._strokes[3] = 1.0
            self._strokes[2] = min(1.0, self._strokes[2] + 0.16)
        else:
            idx = self._fallback_rotation
            self._strokes[idx] = 1.0
            self._fallback_rotation = (self._fallback_rotation + 1) % 4

        key_str = EVDEV_KEY_MAP.get(code, MODIFIER_KEY_MAP.get(code, ""))
        if not key_str:
            return

        ordered_mods = []
        for m in ["Win", "Ctrl", "Alt", "Shift"]:
            if m in self._active_mods and m != key_str:
                ordered_mods.append(m)
        resolved_mod = "+".join(ordered_mods)

        self._latest_mod = resolved_mod
        self._latest_key = key_str
        self._stroke_counter = (self._stroke_counter + 1) % 1000000

        self.keyStrokeTriggered.emit(resolved_mod, key_str, self._stroke_counter)

    def _physics_tick(self):
        now = time.monotonic()
        while self._keystrokes and (now - self._keystrokes[0]) > 1.0:
            self._keystrokes.popleft()

        kps = float(len(self._keystrokes))
        idle_duration = (now - self._last_key_time) if self._last_key_time > 0 else 999.0

        for i in range(4):
            self._strokes[i] *= 0.78
            if self._strokes[i] < 0.005:
                self._strokes[i] = 0.0

        if idle_duration > 0.4:
            target_intensity = 0.0
            lerp_rate = 0.16
        else:
            target_intensity = min(1.0, max(0.05, kps / 10.0))
            lerp_rate = 0.28

        self._smooth_intensity += (target_intensity - self._smooth_intensity) * lerp_rate
        if self._smooth_intensity < 0.025:
            self._smooth_intensity = 0.0

        if not self._in_rage_state and self._smooth_intensity >= 0.85:
            self._in_rage_state = True
        elif self._in_rage_state and self._smooth_intensity < 0.68:
            self._in_rage_state = False

        is_active = (self._smooth_intensity > 0.005) or (idle_duration < 1.2)
        continuous_color = interpolate_typing_color(self._smooth_intensity)

        if idle_duration > 2.0:
            self._latest_mod = ""
            self._latest_key = ""

        self.typingUpdated.emit(
            is_active, continuous_color,
            round(self._strokes[0], 3),
            round(self._strokes[1], 3),
            round(self._strokes[2], 3),
            round(self._strokes[3], 3),
            round(self._smooth_intensity * 10.0, 2),
            self._latest_mod,
            self._latest_key
        )

        # 闲置智能挂起（此函数在主线程执行，直接调用 stop() 绝对安全）
        if idle_duration > 2.2 and self._smooth_intensity == 0.0 and all(s == 0.0 for s in self._strokes):
            self._tick_timer.stop()

    def cleanup(self):
        self._stop_event.set()
        self._tick_timer.stop()
        self._latest_mod = ""
        self._latest_key = ""