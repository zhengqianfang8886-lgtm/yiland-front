# =========================================================================
# 📄 File: backend/modules/netlink_speed.py
# 🌟 基于 Linux 原生 Netlink 的高精度测速器 (带 ifi_index 严密校验与防抖)
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
NLM_F_DUMP = 0x300
IFLA_STATS64 = 23


def format_speed_structured(bytes_per_sec: float) -> Dict[str, str]:
    if bytes_per_sec < 256:
        return {"full": "0 B/s", "val": "0", "unit": "B/s", "compact": "0B"}
    elif bytes_per_sec < 1024:
        val_str = str(int(bytes_per_sec))
        return {"full": f"{val_str} B/s", "val": val_str, "unit": "B/s", "compact": f"{val_str}B"}
    elif bytes_per_sec < 1048576:
        kb = bytes_per_sec / 1024.0
        val_str = f"{int(kb)}" if kb >= 100 else f"{kb:.1f}"
        return {"full": f"{kb:.1f} KB/s", "val": val_str, "unit": "K/s", "compact": f"{val_str}K"}
    elif bytes_per_sec < 1073741824:
        mb = bytes_per_sec / 1048576.0
        val_str = f"{mb:.1f}"
        return {"full": f"{mb:.1f} MB/s", "val": val_str, "unit": "M/s", "compact": f"{val_str}M"}
    else:
        gb = bytes_per_sec / 1073741824.0
        val_str = f"{gb:.1f}"
        return {"full": f"{gb:.2f} GB/s", "val": val_str, "unit": "G/s", "compact": f"{val_str}G"}


class NetlinkSpeedSampler:
    """Linux 原生 Netlink 流量采样器 (严格校验 ifi_index 与 Sequence)"""

    def __init__(self, window_span_sec: float = 1.0, socket_timeout: float = 0.08):
        self.window_span = window_span_sec
        self.socket_timeout = socket_timeout
        self.samples = collections.deque()
        self.last_iface = ""
        self.ifindex = 0
        self.seq = 1000
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

    def _query_stats64(self, target_ifindex: int) -> Optional[Tuple[int, int]]:
        """向内核下发 RTM_GETLINK 并严格匹配 target_ifindex 提取 rx/tx 字节数"""
        if not self.sock or target_ifindex <= 0:
            return None

        # 清除缓冲区可能积压的历史数据
        try:
            while True:
                self.sock.recv(4096, socket.MSG_DONTWAIT)
        except (BlockingIOError, OSError):
            pass

        self.seq += 1
        current_seq = self.seq

        # nlmsghdr (16B) + ifinfomsg (16B)
        nlmsg_len = 32
        req = struct.pack(
            "=IHHII B B H i I I",
            nlmsg_len, RTM_GETLINK, NLM_F_REQUEST, current_seq, 0,
            0, 0, 0, target_ifindex, 0, 0
        )
        try:
            self.sock.send(req)
            data = self.sock.recv(8192)
        except OSError:
            return None

        offset = 0
        data_len = len(data)

        # 遍历可能返回的 Netlink 多段消息
        while offset + 16 <= data_len:
            msg_len, msg_type, flags, msg_seq, pid = struct.unpack_from("=IHHII", data, offset)
            if msg_len < 16 or offset + msg_len > data_len:
                break

            # 校验 sequence 确保是当前请求的应答
            if msg_seq == current_seq and msg_type == RTM_NEWLINK and msg_len >= 32:
                # 🚀【核心修复】：读取 struct ifinfomsg 中的 ifi_index
                # ifinfomsg 偏移: offset + 16, 结构为: B(family), B(pad), H(type), i(ifi_index), I(flags), I(change)
                _, _, _, packet_ifindex, _, _ = struct.unpack_from("=BBHiII", data, offset + 16)

                # 必须与目标物理网卡严格匹配！绝不把其他接口（如 lo 的大流量）误当成本网卡！
                if packet_ifindex == target_ifindex:
                    rta_offset = offset + 32
                    payload_len = msg_len - 32
                    while payload_len >= 4:
                        rta_len, rta_type = struct.unpack_from("=HH", data, rta_offset)
                        if rta_len < 4 or rta_len > payload_len:
                            break

                        if rta_type == IFLA_STATS64 and rta_len >= 4 + 32:
                            # rtnl_link_stats64: 偏移 16 为 rx_bytes(8B), 偏移 24 为 tx_bytes(8B)
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
            if dt > 0.1 and newest[1] >= oldest[1] and newest[2] >= oldest[2]:
                rx_rate = (newest[1] - oldest[1]) / dt
                tx_rate = (newest[2] - oldest[2]) / dt

                # 🚀【防溢出卫语句】：物理网卡单机吞吐保护门限 (例如过滤大于 500MB/s 的单秒突变跳跃)
                if rx_rate > 500 * 1024 * 1024 or tx_rate > 500 * 1024 * 1024:
                    self.samples.clear()
                    return 0.0, 0.0

                return rx_rate, tx_rate

        return 0.0, 0.0