"""
专职异步 WebSocket 监听守护服务
纯粹网络层实现：不承载业务逻辑，直接将原始文本帧通过 Qt 队列排入主线程，确保零线程竞争
"""
import json
import asyncio
import threading
from bridge import IslandBridge
from logger import app_logger


class WebSocketDaemonClient:
    def __init__(self, bridge: IslandBridge, uri="ws://127.0.0.1:8765"):
        self.bridge = bridge
        self.uri = uri
        self.loop = None
        self.cmd_queue = None
        self.bridge.set_ipc_sender(self.send_command)

    def send_command(self, action: str, **kwargs):
        if self.cmd_queue and self.loop and self.loop.is_running():
            payload = json.dumps({"action": action, **kwargs})
            asyncio.run_coroutine_threadsafe(self.cmd_queue.put(payload), self.loop)

    def start(self):
        worker = threading.Thread(target=self._run_loop, daemon=True, name="WsDaemonThread")
        worker.start()

    def _run_loop(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        self.cmd_queue = asyncio.Queue()
        self.loop.run_until_complete(self._connect_and_listen())

    async def _connect_and_listen(self):
        import websockets
        while True:
            try:
                async with websockets.connect(self.uri) as ws:
                    app_logger.info(f"[WS] 成功直连灵动岛后端守护进程: {self.uri}")

                    async def sender():
                        while True:
                            msg = await self.cmd_queue.get()
                            await ws.send(msg)
                            self.cmd_queue.task_done()

                    async def receiver():
                        async for message in ws:
                            self._route_to_main_thread(message)

                    await asyncio.gather(sender(), receiver())
            except Exception as e:
                app_logger.warning(f"[WS] 连接断开: {e}，2秒后尝试自动重连...")
                await asyncio.sleep(2)

    def _route_to_main_thread(self, message: str):
        """轻量级解包并将数据直接递交 Qt 主线程排队，绝不在本异步线程执行业务变更"""
        try:
            msg = json.loads(message)
            m_type = msg.get("type", "")
            # 将原始 data 重新转为 JSON 字符串，保证跨线程深拷贝安全性
            data_str = json.dumps(msg.get("data", {}))
            self.bridge.post_daemon_message(m_type, data_str)
        except Exception as err:
            app_logger.error(f"[WS] 报文投递异常: {err}")