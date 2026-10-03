"""
专职异步 Unix Domain Socket (AF_UNIX) 监听客户端
通过 Linux 内核内存页直接通信，延迟 < 10 微秒
"""
import os
import json
import asyncio
import threading
from bridge import IslandBridge
from logger import app_logger


def get_default_socket_path() -> str:
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    if runtime_dir and os.path.exists(runtime_dir):
        return os.path.join(runtime_dir, "alcove_island.sock")
    return f"/tmp/alcove_island_{os.getuid()}.sock"


class WebSocketDaemonClient:  # 保持类名兼容 main.py，无需修改 main.py 的引入
    def __init__(self, bridge: IslandBridge, socket_path: str = None):
        self.bridge = bridge
        self.socket_path = socket_path or get_default_socket_path()
        self.loop = None
        self.cmd_queue = None
        self.bridge.set_ipc_sender(self.send_command)

    def send_command(self, action: str, **kwargs):
        if self.cmd_queue and self.loop and self.loop.is_running():
            payload = json.dumps({"action": action, **kwargs}, ensure_ascii=False)
            asyncio.run_coroutine_threadsafe(self.cmd_queue.put(payload), self.loop)

    def start(self):
        worker = threading.Thread(target=self._run_loop, daemon=True, name="UdsDaemonThread")
        worker.start()

    def _run_loop(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        self.cmd_queue = asyncio.Queue()
        self.loop.run_until_complete(self._connect_and_listen())

    async def _connect_and_listen(self):
        while True:
            # 等待后端生成 socket 文件
            if not os.path.exists(self.socket_path):
                await asyncio.sleep(0.5)
                continue

            try:
                reader, writer = await asyncio.open_unix_connection(self.socket_path)
                app_logger.info(f"[UDS] 成功直连灵动岛后端 Unix Socket: {self.socket_path}")

                async def sender():
                    while True:
                        msg = await self.cmd_queue.get()
                        # NDJSON 规范：追加换行符作为数据包边界
                        writer.write((msg + "\n").encode("utf-8"))
                        await writer.drain()
                        self.cmd_queue.task_done()

                async def receiver():
                    while True:
                        line = await reader.readline()
                        if not line:
                            break  # 服务端断开
                        raw_str = line.decode("utf-8", errors="ignore").strip()
                        if raw_str:
                            self._route_to_main_thread(raw_str)

                # 并发维持收发通道
                sender_task = asyncio.create_task(sender())
                receiver_task = asyncio.create_task(receiver())

                done, pending = await asyncio.wait(
                    [sender_task, receiver_task],
                    return_when=asyncio.FIRST_COMPLETED
                )
                for task in pending:
                    task.cancel()

            except Exception as e:
                app_logger.warning(f"[UDS] 套接字连接中断: {e}，1秒后尝试自动重连...")
                await asyncio.sleep(1)

    def _route_to_main_thread(self, message: str):
        """轻量级解包并将数据直接递交 Qt 主线程排队"""
        try:
            msg = json.loads(message)
            m_type = msg.get("type", "")
            data_str = json.dumps(msg.get("data", {}), ensure_ascii=False)
            self.bridge.post_daemon_message(m_type, data_str)
        except Exception as err:
            app_logger.error(f"[UDS] 报文解包异常: {err}")