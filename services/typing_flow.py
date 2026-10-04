# ==========================================
# 📄 File: services/typing_flow.py (全架构精准捕获修复版)
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


def find_system_keyboards() -> list:
    """精准解析内核 /proc/bus/input/devices，锁定所有真实键盘 event 节点"""
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
                    # 坚决排除电源键、休眠键、视频总线、合盖传感器等干扰项
                    if any(bad in name for bad in ["power", "sleep", "lid", "video", "button", "switch"]):
                        is_ignored = True
                        break
                    if "keyboard" in name or "kbd" in name or "at translated" in name:
                        has_kbd = True

                elif line.startswith("H: Handlers="):
                    parts = line.split("=", 1)[1].split()
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
        app_logger.warning(f"[TypingFlow] 解析输入设备异常: {e}")

    return list(set(keyboards))


class TypingFlowService(QObject):
    # active, color_hex, s1, s2, s3, s4, kps
    typingUpdated = Signal(bool, str, float, float, float, float, float)

    def __init__(self, executor, config=None, parent=None):
        super().__init__(parent)
        self._pool = executor
        self._config = config
        self._is_media_playing = False

        self._keystrokes = deque(maxlen=64)
        self._last_key_time = 0.0

        self._energy = 0.0
        self._active = False
        self._current_kps = 0.0

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
        # 引擎 1：Linux 内核 /dev/input 多键盘联合捕获（原生通用，延迟 <1ms）
        kbd_paths = find_system_keyboards()
        open_fds = {}

        for path in kbd_paths:
            try:
                fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                open_fds[fd] = path
                app_logger.info(f"✨ [TypingFlow] 成功挂载键盘事件节点: {path}")
            except PermissionError:
                pass
            except Exception:
                pass

        if open_fds:
            # 64-bit Linux input_event struct: 16B timeval + 2B type + 2B code + 4B value = 24B
            event_format = "qqHHi"
            event_size = struct.calcsize(event_format)

            while not self._stop_event.is_set():
                try:
                    r_list, _, _ = select.select(list(open_fds.keys()), [], [], 0.1)
                    for fd in r_list:
                        data = os.read(fd, event_size)
                        if len(data) >= event_size:
                            _, _, ev_type, _, val = struct.unpack(event_format, data[:event_size])
                            # EV_KEY (1) 且 KeyDown (1)
                            if ev_type == 1 and val == 1:
                                self._record_stroke()
                except Exception:
                    time.sleep(0.02)

            for fd in open_fds:
                try:
                    os.close(fd)
                except Exception:
                    pass
            return

        # 引擎 2：X11 桌面免权限降级通道 (xinput test-xi2)
        if os.environ.get("DISPLAY") and shutil.which("xinput"):
            try:
                app_logger.info("[TypingFlow] 尝试启动 X11 xinput 免权限全局事件监听...")
                proc = subprocess.Popen(
                    ["xinput", "test-xi2", "--root"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True,
                    bufsize=1
                )
                while not self._stop_event.is_set() and proc.poll() is None:
                    line = proc.stdout.readline()
                    if not line:
                        break
                    if "EVENT type 2 (KeyPress)" in line or "RawKeyPress" in line:
                        self._record_stroke()
                proc.terminate()
                return
            except Exception as e:
                app_logger.warning(f"[TypingFlow] xinput 监听失败: {e}")

        # 引擎 3：pynput 兜底
        try:
            from pynput import keyboard

            def on_press(key):
                self._record_stroke()

            with keyboard.Listener(on_press=on_press) as listener:
                app_logger.info("[TypingFlow] 启动 pynput 监听模式")
                self._stop_event.wait()
                listener.stop()
            return
        except Exception:
            pass

        # 若三道防线全部受阻，打印明确指引
        app_logger.warning("⚠️ [TypingFlow] 无法直接读取键盘事件。如果你在 Wayland 下，请在终端执行: sudo usermod -aG input $USER ，然后注销重新登录即可激活打字心流岛！")

    def _record_stroke(self):
        if self._is_media_playing:
            return
        if self._config and hasattr(self._config, "typingVisualizerEnabled") and not self._config.typingVisualizerEnabled:
            return

        now = time.monotonic()
        self._keystrokes.append(now)
        self._last_key_time = now
        self._energy = min(1.0, self._energy + 0.38)

    def _physics_tick(self):
        if self._is_media_playing:
            return

        now = time.monotonic()
        while self._keystrokes and (now - self._keystrokes[0]) > 1.0:
            self._keystrokes.popleft()

        kps = len(self._keystrokes)
        self._current_kps = kps
        idle_duration = now - self._last_key_time if self._last_key_time > 0 else 999.0

        self._energy *= 0.86

        # 敲击第 1 下键盘即刻弹现
        if not self._active and kps >= 1 and idle_duration < 0.8:
            self._active = True

        # 停手 1.2 秒平滑休眠缩回
        if self._active and (idle_duration >= 1.2 or (kps == 0 and self._energy < 0.05)):
            self._active = False
            self.typingUpdated.emit(False, "#38bdf8", 0.18, 0.18, 0.18, 0.18, 0.0)
            return

        if not self._active:
            return

        phase = now * 14.0
        wave1 = 0.18 + min(0.72, (kps / 10.0) * 0.65 + self._energy * 0.25 + math.sin(phase) * 0.06)
        wave2 = 0.18 + min(0.82, (kps / 9.0) * 0.75 + self._energy * 0.35 + math.sin(phase + 1.2) * 0.08)
        wave3 = 0.18 + min(0.80, (kps / 9.5) * 0.70 + self._energy * 0.30 + math.cos(phase + 2.4) * 0.07)
        wave4 = 0.18 + min(0.75, (kps / 11.0) * 0.60 + self._energy * 0.40 + math.sin(phase * 1.5) * 0.09)

        if kps >= 7.5:
            color = "#f43f5e"
        elif kps >= 3.5:
            color = "#a855f7"
        else:
            color = "#38bdf8"

        self.typingUpdated.emit(
            True,
            color,
            max(0.18, min(1.0, wave1)),
            max(0.18, min(1.0, wave2)),
            max(0.18, min(1.0, wave3)),
            max(0.18, min(1.0, wave4)),
            round(kps, 1)
        )

    def cleanup(self):
        self._stop_event.set()