# =========================================================================
# 📄 File: backend/modules/netlink_speed.py
# 🌟 基于 Linux 原生 Netlink (RTM_GETLINK / IFLA_STATS64) 的滑动窗口测速器
# =========================================================================
import socket
import struct
import time
import collections

# Linux Netlink 内核常量
RTM_GETLINK = 18
RTM_NEWLINK = 16
NLM_F_REQUEST = 1
IFLA_STATS64 = 23

class NetlinkSpeedSampler:
    def __init__(self, window_span_sec=1.0):
        self.window_span = window_span_sec
        self.samples = collections.deque()
        self.last_iface = ""
        self.ifindex = 0
        self.sock = None
        self._init_socket()

    def _init_socket(self):
        try:
            # 建立专用的 NETLINK_ROUTE 套接字
            self.sock = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, socket.NETLINK_ROUTE)
            self.sock.settimeout(0.1)
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
        """从内核路由表快速获取默认出口物理网卡"""
        try:
            with open("/proc/net/route", "r", encoding="ascii") as f:
                for line in f:
                    parts = line.split()
                    if len(parts) >= 2 and parts[1] == "00000000":
                        return parts[0]
        except OSError:
            pass
        return ""

    def _query_stats64(self, ifindex: int):
        """向内核下发 RTM_GETLINK 并解析 IFLA_STATS64 结构体"""
        if not self.sock or ifindex <= 0:
            return None

        # 构造 nlmsghdr + ifinfomsg 请求包
        # struct nlmsghdr (16 bytes): len(4B), type(2B), flags(2B), seq(4B), pid(4B)
        # struct ifinfomsg (16 bytes): family(1B), pad(1B), type(2B), index(4B), flags(4B), change(4B)
        nlmsg_len = 32
        req = struct.pack("=IHHII B B H i I I",
                          nlmsg_len, RTM_GETLINK, NLM_F_REQUEST, 1, 0,
                          0, 0, 0, ifindex, 0, 0)
        try:
            self.sock.send(req)
            data = self.sock.recv(4096)
        except OSError:
            return None

        # 遍历解析返回的 Netlink 消息链
        offset = 0
        while offset + 16 <= len(data):
            msg_len, msg_type, _, _, _ = struct.unpack_from("=IHHII", data, offset)
            if msg_type == RTM_NEWLINK and offset + 32 <= len(data):
                # 步进到 rtattr 属性链
                rta_offset = offset + 32
                payload_len = msg_len - 32
                while payload_len >= 4:
                    rta_len, rta_type = struct.unpack_from("=HH", data, rta_offset)
                    if rta_len < 4 or rta_len > payload_len:
                        break
                    
                    if rta_type == IFLA_STATS64 and rta_len >= 4 + 192:
                        # struct rtnl_link_stats64: 前 8 字节是 rx_packets, 随后 rx_bytes 是第 24 字节开始
                        # rx_bytes 在 offset+4+24，tx_bytes 在 offset+4+40
                        rx_bytes = struct.unpack_from("=Q", data, rta_offset + 4 + 24)[0]
                        tx_bytes = struct.unpack_from("=Q", data, rta_offset + 4 + 40)[0]
                        return rx_bytes, tx_bytes

                    aligned_len = (rta_len + 3) & ~3
                    rta_offset += aligned_len
                    payload_len -= aligned_len

            aligned_msg_len = (msg_len + 3) & ~3
            offset += aligned_msg_len

        return None

    def tick(self) -> tuple[float, float]:
        """
        每次心跳调用：获取瞬时平滑速率 (rx_rate, tx_rate)，单位：字节/秒
        """
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

        # 剔除超出滑动窗口的时间切片
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