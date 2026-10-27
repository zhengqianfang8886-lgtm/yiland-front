# ==========================================
# 📄 File: backend/core/state.py
# 🌟 全量系统状态单一事实源 (集成平铺网格时序状态)
# ==========================================
from typing import Dict, Any, Optional, List


class IslandState:
    def __init__(self):
        # 1. 虚拟桌面
        self.workspace_index: int = 1
        self.workspace_name: str = "Desktop 1"
        self.workspace_total: int = 1
        self.workspaces: List[Dict[str, Any]] = []

        # 🚀 平铺网格特效活跃状态标志
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
        self.spectrum: tuple[float, float, float, float] = (0.2, 0.2, 0.2, 0.2)

        # 3. 音量、亮度与麦克风
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
        self.timer_remaining_sec: int = 1500
        self.timer_total_sec: int = 1500
        self.timer_elapsed_sec: int = 0
        self.timer_mode: str = "focus"
        self.timer_laps: List[Dict[str, Any]] = []

        # 8. 通话与通知
        self.last_notify_title: str = ""
        self.last_notify_content: str = ""
        self.last_notify_icon: str = "💬"
        self.last_notify_avatar: str = ""
        self.notification_sender_bus: str = ""
        self.notification_id: int = 0

        # 9. 端侧语音输入核心状态
        self.voice_input_active: bool = False
        self.voice_input_text: str = ""
        self.voice_input_level: float = 0.1

        # 10. 系统级暂态打断单一事实源
        self.overlay_key: str = ""
        self.overlay_icon: str = ""
        self.overlay_title: str = ""
        self.overlay_subtitle: str = ""
        self.overlay_val: int = 0
        self.overlay_duration_ms: int = 0
        self.overlay_avatar: str = ""
        self.overlay_priority: int = 0

    def set_overlay(self, key: str, title: str, subtitle: str = "",
                    icon: str = "🔔", duration_ms: int = 3500, avatar: str = "",
                    val: int = 0, priority: int = 40):
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
        self.overlay_key = ""
        self.overlay_icon = ""
        self.overlay_title = ""
        self.overlay_subtitle = ""
        self.overlay_val = 0
        self.overlay_duration_ms = 0
        self.overlay_avatar = ""
        self.overlay_priority = 0

    def get_overlay_dict(self) -> Dict[str, Any]:
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