# ==========================================
# 📄 File: ws_client.py
# ==========================================
"""
智能双模自适应 IPC 客户端：
优先直连后端 WebSocket 服务 (ws://127.0.0.1:8765)，
若运行在纯 Unix Domain Socket (AF_UNIX) 模式下则自动平滑降级。
"""
import os
import json
import asyncio
import threading
from bridge import IslandBridge
from logger import app_logger

try:
    import websockets
    HAS_WEBSOCKETS = True
except ImportError:
    HAS_WEBSOCKETS = False


def get_default_socket_path() -> str:
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
    if runtime_dir and os.path.exists(runtime_dir):
        return os.path.join(runtime_dir, "alcove_island.sock")
    return f"/tmp/alcove_island_{os.getuid()}.sock"


class WebSocketDaemonClient:
    def __init__(self, bridge: IslandBridge, socket_path: str = None, ws_url: str = "ws://127.0.0.1:8765"):
        self.bridge = bridge
        self.socket_path = socket_path or get_default_socket_path()
        self.ws_url = ws_url
        self.loop = None
        self.cmd_queue = None
        self.bridge.set_ipc_sender(self.send_command)

    def send_command(self, action: str, **kwargs):
        if self.cmd_queue and self.loop and self.loop.is_running():
            payload = json.dumps({"action": action, **kwargs}, ensure_ascii=False)
            asyncio.run_coroutine_threadsafe(self.cmd_queue.put(payload), self.loop)

    def start(self):
        worker = threading.Thread(target=self._run_loop, daemon=True, name="IpcClientThread")
        worker.start()

    def _run_loop(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        self.cmd_queue = asyncio.Queue()
        self.loop.run_until_complete(self._connect_and_listen())

    async def _connect_and_listen(self):
        while True:
            # 模式 1：优先尝试对接后端的 WebSocket (127.0.0.1:8765)
            if HAS_WEBSOCKETS:
                try:
                    async with websockets.connect(self.ws_url, ping_interval=10, ping_timeout=5) as ws:
                        app_logger.info(f"✨ 成功接入灵动岛后端 WebSocket IPC: {self.ws_url}")

                        async def ws_sender():
                            while True:
                                msg = await self.cmd_queue.get()
                                await ws.send(msg)
                                self.cmd_queue.task_done()

                        async def ws_receiver():
                            while True:
                                raw_str = await ws.recv()
                                if raw_str:
                                    self._route_to_main_thread(raw_str)

                        s_task = asyncio.create_task(ws_sender())
                        r_task = asyncio.create_task(ws_receiver())

                        done, pending = await asyncio.wait(
                            [s_task, r_task],
                            return_when=asyncio.FIRST_COMPLETED
                        )
                        for task in pending:
                            task.cancel()
                        continue
                except (OSError, Exception):
                    pass

            # 模式 2：降级尝试对接 Unix Domain Socket (UDS)
            if os.path.exists(self.socket_path):
                try:
                    reader, writer = await asyncio.open_unix_connection(self.socket_path)
                    app_logger.info(f"✨ 成功直连灵动岛后端 Unix Socket: {self.socket_path}")

                    async def uds_sender():
                        while True:
                            msg = await self.cmd_queue.get()
                            writer.write((msg + "\n").encode("utf-8"))
                            await writer.drain()
                            self.cmd_queue.task_done()

                    async def uds_receiver():
                        while True:
                            line = await reader.readline()
                            if not line:
                                break
                            raw_str = line.decode("utf-8", errors="ignore").strip()
                            if raw_str:
                                self._route_to_main_thread(raw_str)

                    s_task = asyncio.create_task(uds_sender())
                    r_task = asyncio.create_task(uds_receiver())

                    done, pending = await asyncio.wait(
                        [s_task, r_task],
                        return_when=asyncio.FIRST_COMPLETED
                    )
                    for task in pending:
                        task.cancel()
                    continue

                except ConnectionRefusedError:
                    # 🚀【核心优化 2】：遇到连不上的 socket 仅延时重试，决不允许客户端擅自删除服务端的套接字文件
                    await asyncio.sleep(1.0)
                except Exception:
                    await asyncio.sleep(1.0)

            # 后端未开启时静默休眠等待，不再刷新日志
            await asyncio.sleep(1.0)

    def _route_to_main_thread(self, message: str):
        try:
            msg = json.loads(message)
            m_type = msg.get("type", "")
            data_str = json.dumps(msg.get("data", {}), ensure_ascii=False)
            self.bridge.post_daemon_message(m_type, data_str)
        except Exception as err:
            app_logger.error(f"[IPC] 报文解包异常: {err}")