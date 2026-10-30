# ==========================================
# 📄 File: backend/core/state.py
# 🌟 全量系统状态单一事实源 (集成红点隐私+OBS独立托盘双轨状态版)
# ==========================================
import threading
from typing import Dict, Any, Optional, List, Tuple


class IslandStateSnapshot:
    def __init__(self, data: Dict[str, Any]):
        self.__dict__.update(data)

    def get_overlay_dict(self) -> Dict[str, Any]:
        return {
            "key": getattr(self, "overlay_key", ""),
            "icon": getattr(self, "overlay_icon", ""),
            "title": getattr(self, "overlay_title", ""),
            "subtitle": getattr(self, "overlay_subtitle", ""),
            "val": getattr(self, "overlay_val", 0),
            "duration": getattr(self, "overlay_duration_ms", 0),
            "avatar": getattr(self, "overlay_avatar", ""),
            "priority": getattr(self, "overlay_priority", 0),
            "voiceActive": getattr(self, "voice_input_active", False),
            "voiceText": getattr(self, "voice_input_text", ""),
            "voiceLevel": getattr(self, "voice_input_level", 0.1),
        }


class IslandState:
    def __init__(self):
        object.__setattr__(self, "_lock", threading.RLock())

        # 1. 虚拟桌面
        self.workspace_index: int = 1
        self.workspace_name: str = "Desktop 1"
        self.workspace_total: int = 1
        self.workspaces: List[Dict[str, Any]] = []
        self.is_desktop_grid_active: bool = False

        # 2. 媒体流与声谱
        self.active_player: Optional[str] = None
        self.playback_status: str = "Stopped"
        self.title: str = "等待播放媒体..."
        self.artist: str = "空闲"
        self.art_url: str = ""
        self.position: float = 0.0
        self.duration: float = 0.0
        self.dominant_color: str = "#22c55e"
        self.spectrum: Tuple[float, float, float, float] = (0.2, 0.2, 0.2, 0.2)

        # 3. 音量与亮度
        self.volume: int = 50
        self.is_muted: bool = False
        self.brightness: int = 100
        self.mic_volume: int = 80
        self.is_mic_muted: bool = False

        # 4. 键盘锁
        self.is_caps_lock: bool = False
        self.is_num_lock: bool = False

        # 5. 电源与硬件
        self.battery_pct: int = 100
        self.battery_charging: bool = False
        self.memory_percent: int = 0
        self.memory_used_gb: str = "0.0G"
        self.memory_total_gb: str = "0.0G"

        # 6. 网络状态
        self.net_down_speed: str = "0.0 B/s"
        self.net_up_speed: str = "0.0 B/s"
        self.net_down_val: str = "0"
        self.net_down_unit: str = "B/s"
        self.net_up_val: str = "0"
        self.net_up_unit: str = "B/s"
        self.net_down_compact: str = "0B"
        self.net_up_compact: str = "0B"
        self.local_ip: str = "127.0.0.1"

        # 7. 专注计时器核心状态
        self.timer_type: str = "countdown"
        self.timer_is_running: bool = False
        self.timer_is_paused: bool = False
        self.timer_is_completed: bool = False
        self.timer_is_overtime: bool = False
        self.timer_overtime_sec: int = 0
        self.timer_remaining_sec: int = 1500
        self.timer_total_sec: int = 1500
        self.timer_elapsed_sec: int = 0
        self.timer_mode: str = "focus"
        self.timer_laps: List[Dict[str, Any]] = []

        self.cd_is_running: bool = False
        self.cd_is_paused: bool = False
        self.cd_is_completed: bool = False
        self.cd_is_overtime: bool = False
        self.cd_overtime_sec: int = 0
        self.cd_remaining_sec: int = 1500
        self.cd_total_sec: int = 1500
        self.cd_mode: str = "focus"

        self.sw_is_running: bool = False
        self.sw_is_paused: bool = False
        self.sw_elapsed_sec: int = 0
        self.sw_laps: List[Dict[str, Any]] = []

        # 8. 通话与通知
        self.last_notify_title: str = ""
        self.last_notify_content: str = ""
        self.last_notify_icon: str = "💬"
        self.last_notify_avatar: str = ""
        self.notification_sender_bus: str = ""
        self.notification_id: int = 0

        # 9. 语音输入
        self.voice_input_active: bool = False
        self.voice_input_text: str = ""
        self.voice_input_level: float = 0.1

        # 10. 系统级暂态
        self.overlay_key: str = ""
        self.overlay_icon: str = ""
        self.overlay_title: str = ""
        self.overlay_subtitle: str = ""
        self.overlay_val: int = 0
        self.overlay_duration_ms: int = 0
        self.overlay_avatar: str = ""
        self.overlay_priority: int = 0

        self.ime_active: bool = False
        self.ime_name: str = "keyboard-us"
        self.ime_label: str = "英"
        self.ime_icon_url: str = ""
        self.ime_menu_items: List[Dict[str, Any]] = []

        # 🚀【双轨录制状态声明】
        # 轨道 1: 红色采音/录屏隐私指示器
        self.recording_active: bool = False
        self.recording_items: List[Dict[str, Any]] = []

        # 轨道 2: OBS 独立托盘与真实右键菜单
        self.obs_running: bool = False
        self.obs_icon_url: str = ""
        self.obs_menu_items: List[Dict[str, Any]] = []

    def __enter__(self):
        self._lock.acquire()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self._lock.release()

    def __setattr__(self, name: str, value: Any):
        if name == "_lock":
            object.__setattr__(self, name, value)
            return
        with self._lock:
            object.__setattr__(self, name, value)

    def __getattribute__(self, name: str) -> Any:
        if name in ("_lock", "__enter__", "__exit__", "batch_update", "snapshot",
                    "set_overlay", "clear_overlay", "get_overlay_dict", "__class__", "__dict__"):
            return object.__getattribute__(self, name)
        with object.__getattribute__(self, "_lock"):
            val = object.__getattribute__(self, name)
            if isinstance(val, list):
                return list(val)
            elif isinstance(val, dict):
                return dict(val)
            return val

    def batch_update(self, **kwargs):
        with self._lock:
            for k, v in kwargs.items():
                object.__setattr__(self, k, v)

    def snapshot(self) -> IslandStateSnapshot:
        with self._lock:
            data = {}
            for k, v in self.__dict__.items():
                if k == "_lock":
                    continue
                if isinstance(v, list):
                    data[k] = [dict(x) if isinstance(x, dict) else x for x in v]
                elif isinstance(v, dict):
                    data[k] = dict(v)
                else:
                    data[k] = v
            return IslandStateSnapshot(data)

    def set_overlay(self, key: str, title: str, subtitle: str = "",
                    icon: str = "🔔", duration_ms: int = 3500, avatar: str = "",
                    val: int = 0, priority: int = 40):
        with self._lock:
            if self.overlay_key and priority < self.overlay_priority:
                return
            self.overlay_key = key
            self.overlay_title = title
            self.overlay_subtitle = subtitle
            self.overlay_icon = icon
            self.overlay_duration_ms = duration_ms
            self.overlay_avatar = avatar
            self.overlay_val = val
            self.overlay_priority = priority

    def clear_overlay(self):
        with self._lock:
            self.overlay_key = ""
            self.overlay_icon = ""
            self.overlay_title = ""
            self.overlay_subtitle = ""
            self.overlay_val = 0
            self.overlay_duration_ms = 0
            self.overlay_avatar = ""
            self.overlay_priority = 0

    def get_overlay_dict(self) -> Dict[str, Any]:
        with self._lock:
            return {
                "key": self.overlay_key,
                "icon": self.overlay_icon,
                "title": self.overlay_title,
                "subtitle": self.overlay_subtitle,
                "val": self.overlay_val,
                "duration": self.overlay_duration_ms,
                "avatar": self.overlay_avatar,
                "priority": self.overlay_priority,
                "voiceActive": self.voice_input_active,
                "voiceText": self.voice_input_text,
                "voiceLevel": self.voice_input_level,
            }