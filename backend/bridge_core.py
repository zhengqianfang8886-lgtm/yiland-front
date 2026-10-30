# ==========================================
# 📄 File: backend/bridge_core.py
# 🌟 Qt 桥接基础设施微内核 (跨线程通信·异步执行·通用RPC网关)
# ==========================================
import atexit
import asyncio
import inspect
from concurrent.futures import ThreadPoolExecutor
from typing import Optional, Any

from PySide6.QtCore import QObject, Signal, Slot, Qt, QEvent
from backend.models import NotificationListModel
from backend.window import WindowManagerService
from backend.logger import app_logger


class WindowEventFilter(QObject):
    def __init__(self, bridge):
        super().__init__()
        self.bridge = bridge

    def eventFilter(self, watched, event):
        if event.type() == QEvent.Type.WindowDeactivate:
            self.bridge.windowDeactivated.emit()
        return super().eventFilter(watched, event)


class BridgeCore(QObject):
    _sig_inproc_event = Signal(str, object)
    _sig_spectrum_event = Signal(float, float, float, float)
    moduleUpdated = Signal(str, "QVariantMap")
    windowDeactivated = Signal()

    def __init__(self, view, config=None):
        super().__init__()
        self.view = view
        self.config = config
        self._pool = ThreadPoolExecutor(max_workers=2, thread_name_prefix="BridgeWorker")

        self._backend = None
        self._async_loop: Optional[asyncio.AbstractEventLoop] = None
        self._notif_model = NotificationListModel(self)
        self.wm = WindowManagerService(self.view, self._pool, self.config, self)

        self._event_filter = WindowEventFilter(self)
        self.view.installEventFilter(self._event_filter)
        self.windowDeactivated.connect(self._on_window_deactivated)

        atexit.register(self.cleanup)

    def _on_window_deactivated(self):
        if self._backend and hasattr(self._backend, "ime") and self._backend.ime:
            self._backend.ime.trigger_sync()

    def set_backend(self, backend, loop):
        self._backend = backend
        self._async_loop = loop

    def run_async(self, coro):
        if self._async_loop and self._async_loop.is_running():
            asyncio.run_coroutine_threadsafe(coro, self._async_loop)

    def cleanup(self):
        if hasattr(self, "_notif_model"):
            self._notif_model.clearAll()
        self._pool.shutdown(wait=False, cancel_futures=True)

    def post_inproc_event(self, event_type: str, state_obj):
        try:
            self._sig_inproc_event.emit(event_type, state_obj)
        except RuntimeError:
            pass

    def post_spectrum_event(self, s1: float, s2: float, s3: float, s4: float):
        try:
            self._sig_spectrum_event.emit(s1, s2, s3, s4)
        except RuntimeError:
            pass

    def _call_backend(self, module_name: str, method_name: str, *args):
        if not self._backend:
            return
        mod = getattr(self._backend, module_name, None)
        if not mod:
            return
        method = getattr(mod, method_name, None)
        if not method or not callable(method):
            return

        if inspect.iscoroutinefunction(method):
            self.run_async(method(*args))
        else:
            method(*args)

    def _state_val(self, key: str, default: Any = None) -> Any:
        if not self._backend or not self._backend.state:
            return default
        return getattr(self._backend.state, key, default)

    @Slot(str)
    @Slot(str, "QVariant")
    def invoke(self, action_path: str, payload=None):
        if not self._backend:
            return

        async def _do():
            try:
                if payload is not None:
                    await self._backend.dispatch_action(action_path, payload)
                else:
                    await self._backend.dispatch_action(action_path)
            except Exception as e:
                app_logger.warning(f"[Bridge RPC] 调用 {action_path} 异常: {e}")

        self.run_async(_do())

    @Slot(str, result="QVariantMap")
    def getModule(self, module_name: str) -> dict:
        if self._backend and hasattr(self._backend.state, "get_module_data"):
            return self._backend.state.get_module_data(module_name)
        return {}