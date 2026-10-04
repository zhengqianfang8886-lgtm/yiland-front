# ==========================================
# 📄 File: services/typing_flow.py (抗抖动与鼠标严格过滤版)
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

# 检查 32/64 位环境对应的 input_event 结构体
IS_64BIT = struct.calcsize("P") == 8
# Linux input_event: timeval (2 longs), type (__u16), code (__u16), value (__s32)
EVENT_FORMAT = "qqHHi" if IS_64BIT else "iiHHi"
EVENT_SIZE = struct.calcsize(EVENT_FORMAT)


def find_system_keyboards() -> list:
    """精准解析内核 /proc/bus/input/devices，严密排除所有鼠标、触控板及复合宏设备"""
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
                    # 严密排除各类鼠标、触控板、指针、数位板、合盖及系统按键
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
                    # 只要 Handler 中挂载了 mouse、js(摇杆)，无论名称如何一律视作鼠标
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
    # active, color_hex, s1, s2, s3, s4, kps
    typingUpdated = Signal(bool, str, float, float, float, float, float)

    # 意图识别常量
    ACTIVATION_STROKE_COUNT = 3     # 1秒内需达到连续敲击至少 3 次才激活（过滤偶发误触）
    INTENT_EVAL_WINDOW = 0.95       # 评估敲击意图的时间滑动窗口 (秒)
    REST_IDLE_TIMEOUT = 1.85        # 打字停顿超过此时间才判定意图结束并平滑退出 (秒)
    MIN_DISPLAY_DURATION = 1.8      # 激活后的最短驻留时间，彻底消除抽搐闪现 (秒)

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

        # 平滑滤波后的四频段频谱波高（用于插值消除生硬跳跃）
        self._s1_smooth = 0.18
        self._s2_smooth = 0.18
        self._s3_smooth = 0.18
        self._s4_smooth = 0.18

        self._tick_timer = QTimer(self)
        self._tick_timer.setInterval(33)  # 30 FPS 物理渲染时钟
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
        """主监听引擎：直接挂载原生 /dev/input 并严格过滤鼠标按键码"""
        kbd_paths = find_system_keyboards()
        open_fds = {}

        for path in kbd_paths:
            try:
                fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                open_fds[fd] = path
                app_logger.info(f"✨ [TypingFlow] 成功挂载纯净键盘节点: {path}")
            except PermissionError:
                pass
            except Exception:
                pass

        if open_fds:
            while not self._stop_event.is_set():
                try:
                    r_list, _, _ = select.select(list(open_fds.keys()), [], [], 0.1)
                    for fd in r_list:
                        data = os.read(fd, EVENT_SIZE)
                        if len(data) >= EVENT_SIZE:
                            _, _, ev_type, code, val = struct.unpack(EVENT_FORMAT, data[:EVENT_SIZE])

                            # 🚀【核心防护 1】：必须为 EV_KEY (1) 且仅响应按下 (val == 1)
                            if ev_type != 1 or val != 1:
                                continue

                            # 🚀【核心防护 2】：代码级严密剔除鼠标按键
                            # Linux input-event-codes 中：
                            # 0x100(256) - 0x1ff(511) 全部为 BTN_* 系列（包括 BTN_LEFT/RIGHT/MIDDLE、手柄等）
                            # 键盘常规键位严格分布在 1 <= code <= 255 范围内
                            if code >= 0x100:
                                continue

                            # 排除休眠、唤醒、亮度、静音等硬件扩展功能键
                            if code in (113, 114, 115, 142, 143, 224, 225):
                                continue

                            self._record_stroke()
                except Exception:
                    time.sleep(0.02)

            for fd in open_fds:
                try:
                    os.close(fd)
                except Exception:
                    pass
            return

        # 引擎 2：X11 桌面环境降级通道 (xinput test-xi2)
        if os.environ.get("DISPLAY") and shutil.which("xinput"):
            try:
                app_logger.info("[TypingFlow] 降级进入 X11 xinput 监听通道...")
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
                    # 严禁匹配 ButtonPress/RawButtonPress（鼠标操作）
                    if "RawButton" in line or "ButtonPress" in line:
                        continue
                    if "EVENT type 2 (KeyPress)" in line or "RawKeyPress" in line:
                        self._record_stroke()
                proc.terminate()
                return
            except Exception as e:
                app_logger.warning(f"[TypingFlow] xinput 监听失败: {e}")

        # 引擎 3：pynput 兜底通道（仅监听 keyboard，绝不挂载 mouse）
        try:
            from pynput import keyboard

            def on_press(key):
                self._record_stroke()

            with keyboard.Listener(on_press=on_press) as listener:
                app_logger.info("[TypingFlow] 启动 pynput 单纯键盘监听模式")
                self._stop_event.wait()
                listener.stop()
            return
        except Exception:
            pass

        app_logger.warning("⚠️ [TypingFlow] 缺少键盘读取权限。请执行: sudo usermod -aG input $USER，注销后重新登录即可。")

    def _record_stroke(self):
        """记录有效键盘敲击"""
        if self._is_media_playing:
            return
        if self._config and hasattr(self._config, "typingVisualizerEnabled") and not self._config.typingVisualizerEnabled:
            return

        now = time.monotonic()
        self._keystrokes.append(now)
        self._last_key_time = now
        # 动能适度增益，防过载
        self._energy = min(1.0, self._energy + 0.35)

    def _physics_tick(self):
        """动效物理节拍与智能意图状态机"""
        if self._is_media_playing:
            return

        now = time.monotonic()

        # 淘汰滑动窗口之外的过期敲击记录 (1.0 秒前)
        while self._keystrokes and (now - self._keystrokes[0]) > 1.0:
            self._keystrokes.popleft()

        kps = len(self._keystrokes)
        self._current_kps = kps
        idle_duration = (now - self._last_key_time) if self._last_key_time > 0 else 999.0

        # 自然阻尼衰减
        self._energy *= 0.88

        # ---------------------------------------------------------------------
        # 🚀 意图判定核心机制：
        # 1. 只有最近 INTENT_EVAL_WINDOW 时间内敲击数达到 ACTIVATION_STROKE_COUNT (>= 3 次)
        # 2. 且两次按键间隔小于 0.65 秒（具有连贯打字语义，排除偶发触碰）
        # ---------------------------------------------------------------------
        if not self._active:
            if len(self._keystrokes) >= self.ACTIVATION_STROKE_COUNT:
                # 检验最近两次敲击间隔，确保具有持续打字的节奏
                recent_gap = self._keystrokes[-1] - self._keystrokes[-2]
                if recent_gap < 0.65 and idle_duration < 0.4:
                    self._active = True
                    self._activated_at = now

        # ---------------------------------------------------------------------
        # 🚀 退场判定防抽搐机制：
        # 1. 停手时长超过 REST_IDLE_TIMEOUT (1.85 秒)，给用户留出充分的短暂停顿思考时间
        # 2. 必须满足最小展示时长 MIN_DISPLAY_DURATION (1.8 秒)，绝不允许刚弹现就立刻缩回
        # ---------------------------------------------------------------------
        if self._active:
            is_timeout = (idle_duration >= self.REST_IDLE_TIMEOUT)
            is_min_time_passed = (now - self._activated_at >= self.MIN_DISPLAY_DURATION)

            if is_timeout and is_min_time_passed:
                # 能量衰减至极低水平时平滑退场
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

        # ---------------------------------------------------------------------
        # 频谱流体算法与柔和插值计算
        # ---------------------------------------------------------------------
        phase = now * 13.0
        target_w1 = 0.18 + min(0.70, (kps / 9.5) * 0.55 + self._energy * 0.28 + math.sin(phase) * 0.05)
        target_w2 = 0.18 + min(0.82, (kps / 8.5) * 0.65 + self._energy * 0.35 + math.sin(phase + 1.2) * 0.07)
        target_w3 = 0.18 + min(0.80, (kps / 9.0) * 0.60 + self._energy * 0.32 + math.cos(phase + 2.3) * 0.06)
        target_w4 = 0.18 + min(0.75, (kps / 10.5) * 0.50 + self._energy * 0.38 + math.sin(phase * 1.4) * 0.08)

        # 低通插值平滑，彻底消除波条抽搐
        lerp_factor = 0.35
        self._s1_smooth = self._s1_smooth * (1.0 - lerp_factor) + target_w1 * lerp_factor
        self._s2_smooth = self._s2_smooth * (1.0 - lerp_factor) + target_w2 * lerp_factor
        self._s3_smooth = self._s3_smooth * (1.0 - lerp_factor) + target_w3 * lerp_factor
        self._s4_smooth = self._s4_smooth * (1.0 - lerp_factor) + target_w4 * lerp_factor

        # 随手速动态渐变主色（冰蓝 -> 梦幻紫 -> 热情珊瑚红）
        if kps >= 7.5:
            color = "#f43f5e"
        elif kps >= 3.5:
            color = "#a855f7"
        else:
            color = "#38bdf8"

        self.typingUpdated.emit(
            True,
            color,
            max(0.18, min(1.0, round(self._s1_smooth, 3))),
            max(0.18, min(1.0, round(self._s2_smooth, 3))),
            max(0.18, min(1.0, round(self._s3_smooth, 3))),
            max(0.18, min(1.0, round(self._s4_smooth, 3))),
            round(kps, 1)
        )

    def cleanup(self):
        self._stop_event.set()