# ==========================================
# 📄 File: core/state.py
# 🌟 全量系统信息内存数据结构（单进程共享模型）
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

        # 4. 蓝牙设备
        self.bt_powered: bool = True
        self.bt_devices: List[Dict[str, Any]] = []

        # 5. 电池与电源状态 (UPower 原生)
        self.battery_pct: int = 100
        self.battery_charging: bool = False
        self.power_profile: str = "balanced"

        # 6. 网络与 VPN
        self.net_connected: bool = False
        self.net_type: str = "none"
        self.net_name: str = "Disconnected"
        self.net_strength: int = 0
        self.net_rx_speed: str = "0.0 B/s"
        self.net_tx_speed: str = "0.0 B/s"
        self.vpn_active: bool = False
        self.vpn_name: str = ""
        self.vpn_type: str = ""

        # 7. 通知模块
        self.last_notify_title: str = ""
        self.last_notify_content: str = ""
        self.last_notify_icon: str = "💬"
        self.last_notify_avatar: str = ""