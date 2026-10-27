# =========================================================================
# 📄 File: backend/modules/netlink_speed.py
# 🌟 基于 Linux 原生 Netlink (RTM_GETLINK / IFLA_STATS64) 的滑动窗口测速器 (DRY 统一收敛版)
# =========================================================================
import socket
import struct
import time
import collections
from typing import Optional, Tuple, Dict

# Linux Netlink 内核常量
RTM_GETLINK = 18
RTM_NEWLINK = 16
NLM_F_REQUEST = 1
IFLA_STATS64 = 23


def format_speed_structured(bytes_per_sec: float) -> Dict[str, str]:
    """
    结构化格式化：
    同时输出全量字符串、纯数值、纯单位与微缩显示标签，前端无需正则切片。
    """
    if bytes_per_sec < 256:
        return {
            "full": "0 B/s",
            "val": "0",
            "unit": "B/s",
            "compact": "0B"
        }
    elif bytes_per_sec < 1024:
        val_str = str(int(bytes_per_sec))
        return {
            "full": f"{val_str} B/s",
            "val": val_str,
            "unit": "B/s",
            "compact": f"{val_str}B"
        }
    elif bytes_per_sec < 1048576:
        kb = bytes_per_sec / 1024.0
        val_str = f"{int(kb)}" if kb >= 100 else f"{kb:.1f}"
        return {
            "full": f"{kb:.1f} KB/s",
            "val": val_str,
            "unit": "K/s",
            "compact": f"{val_str}K"
        }
    elif bytes_per_sec < 1073741824:
        mb = bytes_per_sec / 1048576.0
        val_str = f"{mb:.1f}"
        return {
            "full": f"{mb:.1f} MB/s",
            "val": val_str,
            "unit": "M/s",
            "compact": f"{val_str}M"
        }
    else:
        gb = bytes_per_sec / 1073741824.0
        val_str = f"{gb:.1f}"
        return {
            "full": f"{gb:.2f} GB/s",
            "val": val_str,
            "unit": "G/s",
            "compact": f"{val_str}G"
        }


class NetlinkSpeedSampler:
    """Linux 原生 Netlink 内核流量滑动窗口采样器"""

    def __init__(self, window_span_sec: float = 1.0, socket_timeout: float = 0.08):
        self.window_span = window_span_sec
        self.socket_timeout = socket_timeout
        self.samples = collections.deque()
        self.last_iface = ""
        self.ifindex = 0
        self.sock: Optional[socket.socket] = None
        self._init_socket()

    def _init_socket(self):
        try:
            self.sock = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, socket.NETLINK_ROUTE)
            self.sock.settimeout(self.socket_timeout)
        except OSError:
            self.sock = None

    def close(self):
        if self.sock:
            try:
                self.sock.close()
            except OSError:
                pass
            self.sock = None

    @staticmethod
    def get_default_interface() -> str:
        """从内核路由表获取默认出口物理网卡名"""
        try:
            with open("/proc/net/route", "r", encoding="ascii") as f:
                for line in f:
                    parts = line.split()
                    if len(parts) >= 2 and parts[1] == "00000000":
                        return parts[0]
        except OSError:
            pass
        return ""

    def _query_stats64(self, ifindex: int) -> Optional[Tuple[int, int]]:
        """向内核下发 RTM_GETLINK 并解析 IFLA_STATS64 结构体中的 rx_bytes / tx_bytes"""
        if not self.sock or ifindex <= 0:
            return None

        # 构造 nlmsghdr (16B) + ifinfomsg (16B) 请求包
        nlmsg_len = 32
        req = struct.pack(
            "=IHHII B B H i I I",
            nlmsg_len, RTM_GETLINK, NLM_F_REQUEST, 1, 0,
            0, 0, 0, ifindex, 0, 0
        )
        try:
            self.sock.send(req)
            data = self.sock.recv(4096)
        except OSError:
            return None

        offset = 0
        data_len = len(data)
        while offset + 16 <= data_len:
            msg_len, msg_type, _, _, _ = struct.unpack_from("=IHHII", data, offset)
            if msg_type == RTM_NEWLINK and offset + 32 <= data_len:
                rta_offset = offset + 32
                payload_len = msg_len - 32
                while payload_len >= 4:
                    rta_len, rta_type = struct.unpack_from("=HH", data, rta_offset)
                    if rta_len < 4 or rta_len > payload_len:
                        break

                    # struct rtnl_link_stats64:
                    # 4B 头部后: rx_packets(8B), tx_packets(8B), rx_bytes(8B), tx_bytes(8B)...
                    # 正确物理偏移: rx_bytes 在 +16，tx_bytes 在 +24
                    if rta_type == IFLA_STATS64 and rta_len >= 4 + 32:
                        rx_bytes, tx_bytes = struct.unpack_from("=QQ", data, rta_offset + 4 + 16)
                        return rx_bytes, tx_bytes

                    aligned_len = (rta_len + 3) & ~3
                    rta_offset += aligned_len
                    payload_len -= aligned_len

            aligned_msg_len = (msg_len + 3) & ~3
            offset += aligned_msg_len

        return None

    def tick(self) -> Tuple[float, float]:
        """获取瞬时平滑速率 (rx_rate, tx_rate)，单位：字节/秒"""
        cur_iface = self.get_default_interface()
        if not cur_iface:
            self.samples.clear()
            return 0.0, 0.0

        if cur_iface != self.last_iface:
            try:
                self.ifindex = socket.if_nametoindex(cur_iface)
                self.last_iface = cur_iface
            except OSError:
                self.ifindex = 0
            self.samples.clear()

        stats = self._query_stats64(self.ifindex)
        if not stats:
            return 0.0, 0.0

        rx, tx = stats
        now = time.monotonic()
        self.samples.append((now, rx, tx))

        while len(self.samples) > 2:
            if now - self.samples[0][0] > self.window_span:
                self.samples.popleft()
            else:
                break

        if len(self.samples) >= 2:
            oldest = self.samples[0]
            newest = self.samples[-1]
            dt = newest[0] - oldest[0]
            if dt > 0.05 and newest[1] >= oldest[1] and newest[2] >= oldest[2]:
                rx_rate = (newest[1] - oldest[1]) / dt
                tx_rate = (newest[2] - oldest[2]) / dt
                return rx_rate, tx_rate

        return 0.0, 0.0