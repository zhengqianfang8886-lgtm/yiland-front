# =========================================================================
# 📄 File: backend/modules/netlink_speed.py
# 🌟 工业级自适应网络速率采样引擎 (路由感知防翻倍 · 时间补偿EMA · 宽动态范围版)
# =========================================================================
import os
import math
import time
from typing import Tuple, Dict, Optional


def format_speed_structured(bytes_per_sec: float) -> Dict[str, str]:
    """工业级结构化格式化：纯整数、平滑过渡、绝不粗暴吞噬低速流量"""
    # 🚀【合理底噪滤波】：仅过滤低于 256 B/s 的局域网杂乱心跳，保留真实的微弱流量
    if bytes_per_sec < 256:
        return {"full": "0 B/s", "val": "0", "unit": "B/s", "compact": "0B"}
    elif bytes_per_sec < 1024:
        # 显示真实字节
        val_str = str(int(round(bytes_per_sec)))
        return {"full": f"{val_str} B/s", "val": val_str, "unit": "B/s", "compact": f"{val_str}B"}
    elif bytes_per_sec < 1048576:
        # KB/s (1024 ~ 1MB)
        kb = int(round(bytes_per_sec / 1024.0))
        val_str = str(kb)
        return {"full": f"{val_str} KB/s", "val": val_str, "unit": "K/s", "compact": f"{val_str}K"}
    elif bytes_per_sec < 1073741824:
        # MB/s (1MB ~ 1GB)
        mb = int(round(bytes_per_sec / 1048576.0))
        val_str = str(mb)
        return {"full": f"{val_str} MB/s", "val": val_str, "unit": "M/s", "compact": f"{val_str}M"}
    else:
        # GB/s
        gb = int(round(bytes_per_sec / 1073741824.0))
        val_str = str(gb)
        return {"full": f"{val_str} GB/s", "val": val_str, "unit": "G/s", "compact": f"{val_str}G"}


class NetlinkSpeedSampler:
    """
    工业级 Linux 网络流量采样引擎
    核心特性：
      1. 动态默认网关路由感知：杜绝 VPN/TUN 代理模式导致的 200% 流量双重统计
      2. 时间补偿型自适应 EMA：消除线程休眠抖动带来的计算失真
      3. /sys/class/net 极速统计读取，避免解析整个 /proc 产生的冗余开销
    """

    def __init__(self, window_span_sec: float = 1.0, socket_timeout: float = 0.08):
        self._last_time: float = 0.0
        self._last_rx_bytes: int = 0
        self._last_tx_bytes: int = 0
        self._initialized: bool = False

        # EMA 滤波状态
        self._ema_rx: float = 0.0
        self._ema_tx: float = 0.0

        # 当前锁定的主网络接口 (如 eth0, wlan0)
        self._primary_iface: Optional[str] = None
        self._last_route_check_time: float = 0.0

        # 滤波时间常数 tau (秒)，越小响应越灵敏，越大越平滑；1.0s 为视觉黄金平衡
        self._time_constant: float = 1.0

    def close(self):
        pass

    def _get_default_gateway_interface(self) -> Optional[str]:
        """从 /proc/net/route 中嗅探当前承担全局默认网关出口的主网卡"""
        try:
            with open("/proc/net/route", "r", encoding="ascii") as f:
                lines = f.readlines()[1:]
                for line in lines:
                    fields = line.strip().split()
                    if len(fields) >= 2:
                        iface = fields[0]
                        dest = fields[1]
                        # 00000000 表示默认网关 0.0.0.0
                        if dest == "00000000":
                            return iface
        except Exception:
            pass
        return None

    def _read_interface_counters(self, iface: str) -> Tuple[int, int]:
        """直接从 sysfs 高速通道读取单网卡的 64 位精准计数器，速度比解析整个 /proc 快数倍"""
        base_path = f"/sys/class/net/{iface}/statistics"
        try:
            with open(f"{base_path}/rx_bytes", "r", encoding="ascii") as f_rx:
                rx = int(f_rx.read().strip())
            with open(f"{base_path}/tx_bytes", "r", encoding="ascii") as f_tx:
                tx = int(f_tx.read().strip())
            return rx, tx
        except (OSError, ValueError):
            return 0, 0

    def _read_total_transfer_fallback(self) -> Tuple[int, int]:
        """兜底方案：遍历 /proc/net/dev，仅排除明确的虚拟环回接口"""
        total_rx = 0
        total_tx = 0
        ignored = ("lo", "docker", "veth", "virbr", "br-", "vmnet")
        try:
            with open("/proc/net/dev", "r", encoding="ascii", errors="ignore") as f:
                lines = f.readlines()[2:]
                for line in lines:
                    colon_idx = line.find(":")
                    if colon_idx == -1:
                        continue
                    iface = line[:colon_idx].strip()
                    if any(iface.startswith(prefix) for prefix in ignored):
                        continue
                    parts = line[colon_idx + 1:].split()
                    if len(parts) >= 9:
                        total_rx += int(parts[0])
                        total_tx += int(parts[8])
        except Exception:
            pass
        return total_rx, total_tx

    def _get_current_bytes(self) -> Tuple[int, int]:
        now = time.monotonic()
        # 每 5 秒对账一次主路由网卡，以防 WiFi 切换或网线拔插
        if now - self._last_route_check_time > 5.0 or not self._primary_iface:
            self._primary_iface = self._get_default_gateway_interface()
            self._last_route_check_time = now

        if self._primary_iface:
            rx, tx = self._read_interface_counters(self._primary_iface)
            if rx > 0 or tx > 0:
                return rx, tx

        # 无默认路由时（如内网多网卡并发），降级到多网卡汇总
        return self._read_total_transfer_fallback()

    def tick(self) -> Tuple[float, float]:
        now = time.monotonic()
        cur_rx, cur_tx = self._get_current_bytes()

        if not self._initialized:
            self._last_time = now
            self._last_rx_bytes = cur_rx
            self._last_tx_bytes = cur_tx
            self._initialized = True
            return 0.0, 0.0

        dt = now - self._last_time
        # 防止过频调用引发除以零错误
        if dt < 0.2:
            return self._ema_rx, self._ema_tx

        delta_rx = cur_rx - self._last_rx_bytes
        delta_tx = cur_tx - self._last_tx_bytes

        # 网卡重连重置或计数器回绕保护
        if delta_rx < 0 or delta_tx < 0:
            self._last_rx_bytes = cur_rx
            self._last_tx_bytes = cur_tx
            self._last_time = now
            return 0.0, 0.0

        raw_rx_rate = delta_rx / dt
        raw_tx_rate = delta_tx / dt

        self._last_rx_bytes = cur_rx
        self._last_tx_bytes = cur_tx
        self._last_time = now

        # 🚀【核心算法改进：时间补偿型自适应 EMA】
        # 无论线程是 0.9s 还是 1.2s 唤醒一次，物理平滑效果保持严格一致
        alpha = 1.0 - math.exp(-dt / self._time_constant)

        # 动态跟手加速：当瞬时速度远超当前平均值时（如下载突发），加大 alpha 极速响应
        alpha_rx = min(1.0, alpha * (1.8 if raw_rx_rate > self._ema_rx * 2 else 1.0))
        alpha_tx = min(1.0, alpha * (1.8 if raw_tx_rate > self._ema_tx * 2 else 1.0))

        # 更新 EMA
        self._ema_rx = alpha_rx * raw_rx_rate + (1.0 - alpha_rx) * self._ema_rx
        self._ema_tx = alpha_tx * raw_tx_rate + (1.0 - alpha_tx) * self._ema_tx

        # 自然归零：若瞬时无流量，平滑衰减到 128 B/s 以下时迅速置零，杜绝久久不灭
        if raw_rx_rate < 128 and self._ema_rx < 256:
            self._ema_rx = 0.0
        if raw_tx_rate < 128 and self._ema_tx < 256:
            self._ema_tx = 0.0

        return self._ema_rx, self._ema_tx