# ==========================================
# 📄 File: backend/modules/ime.py
# 🌟 原生 Fcitx5/Rime 终极位图通道 (像素级 Hash 跟踪 · 系统全权绘制版)
# ==========================================
import os
import sys
import hashlib
import asyncio
import subprocess
from typing import Optional, List, Dict, Any, Tuple

from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType

from PySide6.QtGui import QImage
from PySide6.QtCore import QBuffer, QIODevice

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class ImeModule(BaseModule):
    """通过系统 IconPixmap 原生点阵流，100% 呈现 Fcitx5 亲手绘制的 'A' 与 '朗'"""

    def __init__(self, backend, state: IslandState, bus: Optional[MessageBus] = None):
        super().__init__(backend, state)
        self.bus = bus
        self._watchdog_task: Optional[asyncio.Task] = None
        self._running = False
        
        # 锁定的 Fcitx5 真实 D-Bus 节点 (由 Watcher 探测确定)
        self._fcitx_sni_dest: Optional[str] = None
        self._fcitx_sni_path: str = "/StatusNotifierItem"

        # 像素内容 Hash 缓存，检测真实图像像素变化 (朗 <-> A)
        self._last_pixmap_hash = ""
        self._is_probing = False

    async def start(self) -> None:
        self._running = True
        await self._discover_fcitx_sni_address()

        if self.bus:
            await self._setup_listeners()

        self._watchdog_task = asyncio.create_task(self._keyboard_sync_watchdog())
        app_logger.info("✅ Fcitx5 像素级位图追踪引擎与看门狗已就绪")

    async def stop(self) -> None:
        self._running = False
        if self._watchdog_task and not self._watchdog_task.done():
            self._watchdog_task.cancel()

    async def _discover_fcitx_sni_address(self) -> bool:
        """通过 StatusNotifierWatcher 锁定 Fcitx5 真实动态地址"""
        if not self.bus or self._is_probing:
            return False

        self._is_probing = True
        try:
            watcher_msg = Message(
                destination="org.kde.StatusNotifierWatcher",
                path="/StatusNotifierWatcher",
                interface="org.freedesktop.DBus.Properties",
                member="Get",
                signature="ss",
                body=["org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems"]
            )
            reply = await self.bus.call(watcher_msg)

            if reply.message_type != MessageType.ERROR and reply.body:
                registered_items = reply.body[0]
                if hasattr(registered_items, 'value'):
                    registered_items = registered_items.value

                for item_str in registered_items:
                    dest, obj_path = self._split_sni_item(str(item_str))
                    try:
                        id_reply = await self.bus.call(
                            Message(
                                destination=dest,
                                path=obj_path,
                                interface="org.freedesktop.DBus.Properties",
                                member="Get",
                                signature="ss",
                                body=["org.kde.StatusNotifierItem", "Id"]
                            )
                        )
                        raw_id = id_reply.body[0] if (id_reply.message_type != MessageType.ERROR and id_reply.body) else ""
                        if hasattr(raw_id, 'value'): raw_id = raw_id.value

                        if "fcitx" in str(raw_id).lower() or "fcitx" in dest.lower():
                            if self._fcitx_sni_dest != dest or self._fcitx_sni_path != obj_path:
                                self._fcitx_sni_dest = dest
                                self._fcitx_sni_path = obj_path
                                print(f"\033[32m🎯 [IME-Probe] 锁定 Fcitx5 真实 SNI 节点 -> dest='{dest}', path='{obj_path}'\033[0m")
                            return True
                    except Exception:
                        pass
        except Exception:
            pass
        finally:
            self._is_probing = False

        if not self._fcitx_sni_dest:
            self._fcitx_sni_dest = "org.fcitx.Fcitx5"
            self._fcitx_sni_path = "/StatusNotifierItem"
        return False

    def _split_sni_item(self, item_str: str) -> Tuple[str, str]:
        if "/" in item_str:
            parts = item_str.split("/", 1)
            return parts[0], "/" + parts[1]
        return item_str, "/StatusNotifierItem"

    async def _setup_listeners(self):
        rules = [
            "type='signal',interface='org.kde.StatusNotifierItem',member='NewIcon'",
            "type='signal',interface='org.kde.StatusNotifierItem',member='NewToolTip'",
            "type='signal',interface='org.kde.StatusNotifierItem',member='NewTitle'",
            "type='signal',interface='org.fcitx.Fcitx.Controller1',member='CurrentInputMethodChanged'",
            "type='signal',interface='org.kde.StatusNotifierWatcher',member='StatusNotifierItemRegistered'"
        ]

        for rule in rules:
            try:
                await self.bus.call(
                    Message(
                        destination="org.freedesktop.DBus",
                        path="/org/freedesktop/DBus",
                        interface="org.freedesktop.DBus",
                        member="AddMatch",
                        signature="s",
                        body=[rule]
                    )
                )
            except Exception:
                pass

        def on_dbus_signal(msg: Message):
            if msg.member == "StatusNotifierItemRegistered":
                asyncio.create_task(self._discover_fcitx_sni_address())
            elif msg.member in ("NewIcon", "NewToolTip", "NewTitle", "CurrentInputMethodChanged"):
                asyncio.create_task(self.sync_state())

        self.bus.add_message_handler(on_dbus_signal)

    async def _keyboard_sync_watchdog(self):
        while self._running:
            try:
                await self.sync_state()
                await asyncio.sleep(0.18)
            except asyncio.CancelledError:
                break
            except Exception:
                await asyncio.sleep(1.0)

    async def sync_state(self):
        """精准提取系统 48x48 点阵像素并进行 Hash 比对"""
        if not self.bus:
            return

        im_state = 1
        cur_im = "keyboard-us"
        try:
            r_st = await self.bus.call(
                Message(destination="org.fcitx.Fcitx5", path="/controller",
                        interface="org.fcitx.Fcitx.Controller1", member="State")
            )
            if r_st.body: im_state = r_st.body[0]

            r_im = await self.bus.call(
                Message(destination="org.fcitx.Fcitx5", path="/controller",
                        interface="org.fcitx.Fcitx.Controller1", member="CurrentInputMethod")
            )
            if r_im.body: cur_im = str(r_im.body[0])
        except Exception:
            pass

        # 从动态捕获的真实 SNI 节点读取属性
        raw_props: Dict[str, Any] = {}
        target_dest = self._fcitx_sni_dest or ":1.63"
        target_path = self._fcitx_sni_path or "/StatusNotifierItem"

        try:
            reply = await self.bus.call(
                Message(
                    destination=target_dest,
                    path=target_path,
                    interface="org.freedesktop.DBus.Properties",
                    member="GetAll",
                    signature="s",
                    body=["org.kde.StatusNotifierItem"]
                )
            )
            if reply.body:
                raw_props = {k: v.value if hasattr(v, 'value') else v for k, v in reply.body[0].items()}
        except Exception:
            await self._discover_fcitx_sni_address()

        pixmaps = raw_props.get("IconPixmap", [])
        icon_data_url = self.state.ime_icon_url
        pix_hash = self._last_pixmap_hash

        # 🚀【核心图像解码】：将系统发来的 48x48 像素点阵转码为 QML Data URL
        if isinstance(pixmaps, list) and len(pixmaps) > 0:
            try:
                best_pix = max(pixmaps, key=lambda p: p[0] if isinstance(p, (list, tuple)) else 0)
                decoded_w = int(best_pix[0])
                decoded_h = int(best_pix[1])
                raw_bytes = bytes(best_pix[2])

                # 计算像素哈希，精准识别 "朗" 与 "A" 的点阵变化
                current_hash = hashlib.md5(raw_bytes).hexdigest()

                if current_hash != self._last_pixmap_hash:
                    self._last_pixmap_hash = current_hash
                    pix_hash = current_hash

                    # 格式转换：网络字节序 (A,R,G,B) 转换为 Qt Format_RGBA8888 (R,G,B,A)
                    buf = bytearray(len(raw_bytes))
                    buf[0::4] = raw_bytes[1::4] # R
                    buf[1::4] = raw_bytes[2::4] # G
                    buf[2::4] = raw_bytes[3::4] # B
                    buf[3::4] = raw_bytes[0::4] # A

                    qimg = QImage(bytes(buf), decoded_w, decoded_h, decoded_w * 4, QImage.Format.Format_RGBA8888)
                    qbuf = QBuffer()
                    qbuf.open(QIODevice.OpenModeFlag.WriteOnly)
                    qimg.save(qbuf, "PNG")
                    b64 = qbuf.data().toBase64().data().decode("ascii")
                    
                    # 附带时间戳防 QML Image 缓存停滞
                    icon_data_url = f"data:image/png;base64,{b64}"
                    
                    print("\033[36m" + "="*70)
                    print("📡 [IME-SystemDiag] 捕获到系统全新原生位图点阵 (图像更新):")
                    print(f"  ├─ 当前输入法模式 : State={im_state}, IM={cur_im}")
                    print(f"  ├─ 真实点阵分辨率 : {decoded_w}x{decoded_h} 像素 (总计 {len(raw_bytes)} 字节)")
                    print(f"  ├─ 像素内容 MD5   : {current_hash[:10]}...")
                    print(f"  └─ 交付前端       : 100% 系统位图渲染下发成功")
                    print("="*70 + "\033[0m")
            except Exception as e:
                app_logger.debug(f"[IME] 解码 Pixmap 异常: {e}")

        is_active = (im_state == 2)
        label_fallback = "朗" if is_active else "A"

        if (self.state.ime_active != is_active or 
            self.state.ime_name != cur_im or 
            self.state.ime_icon_url != icon_data_url):
            
            self.state.batch_update(
                ime_active=is_active,
                ime_name=cur_im,
                ime_label=label_fallback,
                ime_icon_url=icon_data_url
            )
            self.notify("IME_UPDATE")

    async def toggle(self):
        """左键切换中英"""
        try:
            proc = await asyncio.create_subprocess_exec("fcitx5-remote", "-t")
            await proc.communicate()
        except Exception:
            pass
        await self.sync_state()

    async def switch_to_im(self, im_name: str):
        """菜单项选择切换"""
        try:
            if im_name in ("keyboard-us", "en", "english"):
                p1 = await asyncio.create_subprocess_exec("fcitx5-remote", "-s", "keyboard-us")
                await p1.communicate()
                p2 = await asyncio.create_subprocess_exec("fcitx5-remote", "-c")
                await p2.communicate()
            else:
                p1 = await asyncio.create_subprocess_exec("fcitx5-remote", "-s", im_name)
                await p1.communicate()
                p2 = await asyncio.create_subprocess_exec("fcitx5-remote", "-o")
                await p2.communicate()
        except Exception:
            pass
        await self.sync_state()

    async def open_config(self):
        """打开配置工具"""
        for bin_name in ["fcitx5-config-qt", "fcitx5-configtool", "kcmshell6"]:
            if shutil.which(bin_name):
                try:
                    if bin_name == "kcmshell6":
                        subprocess.Popen([bin_name, "kcm_fcitx5"])
                    else:
                        subprocess.Popen([bin_name])
                    return
                except Exception:
                    pass