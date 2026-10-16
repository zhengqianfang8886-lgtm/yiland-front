# ==========================================
# 📄 File: core/state.py
# 🌟 全量系统信息内存数据结构（单进程单一事实源）
# ==========================================
from typing import Dict, Any, Optional, List


class IslandState:
    def __init__(self):
        # 1. 虚拟桌面
        self.workspace_index: int = 1
        self.workspace_name: str = "Desktop 1"
        self.workspace_total: int = 1
        self.workspaces: List[Dict[str, Any]] = []

        # 2. 媒体播放
        self.active_player: Optional[str] = None
        self.playback_status: str = "Stopped"
        self.title: str = "等待播放媒体..."
        self.artist: str = "空闲"
        self.art_url: str = ""
        self.position: float = 0.0
        self.duration: float = 0.0

        # 3. 音量、亮度与麦克风
        self.volume: int = 50
        self.is_muted: bool = False
        self.brightness: int = 100
        self.mic_volume: int = 80
        self.is_mic_muted: bool = False

        # 4. 键盘锁状态
        self.is_caps_lock: bool = False
        self.is_num_lock: bool = False

        # 5. 电池与电源状态
        self.battery_pct: int = 100
        self.battery_charging: bool = False

        # 6. 系统性能与网络
        self.memory_percent: int = 0
        self.memory_used_gb: str = "0.0G"
        self.memory_total_gb: str = "0.0G"
        self.net_down_speed: str = "0.0 B/s"
        self.net_up_speed: str = "0.0 B/s"
        self.net_down_compact: str = "0K"
        self.net_up_compact: str = "0K"
        self.local_ip: str = "127.0.0.1"

        # 7. 蓝牙设备
        self.bt_powered: bool = True
        self.bt_devices: List[Dict[str, Any]] = []

        # 8. 通知与呼叫
        self.last_notify_title: str = ""
        self.last_notify_content: str = ""
        self.last_notify_icon: str = "💬"
        self.last_notify_avatar: str = ""