# ==========================================
# 📄 File: backend/modules/ime/controller.py
# 🌟 Fcitx5 状态读写与原生进程控制器
# ==========================================
import shutil
import asyncio
import subprocess
from typing import Tuple, Optional

from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType

from backend.logger import app_logger


class FcitxController:
    """专职与 Fcitx5 控制器接口以及 fcitx5-remote 命令行交互"""

    def __init__(self, bus: Optional[MessageBus]):
        self.bus = bus

    async def toggle(self) -> None:
        """左键单次切换：优先执行命令行，失败降级 D-Bus，严防连调抵消"""
        try:
            proc = await asyncio.create_subprocess_exec("fcitx5-remote", "-t")
            await proc.communicate()
            return
        except Exception:
            pass

        if self.bus:
            try:
                await self.bus.call(
                    Message(
                        destination="org.fcitx.Fcitx5",
                        path="/controller",
                        interface="org.fcitx.Fcitx.Controller1",
                        member="Toggle"
                    )
                )
            except Exception as e:
                app_logger.warning(f"[IME Controller] Toggle 异常: {e}")

    async def switch_im_native(self, target_im: str) -> None:
        """切换至指定输入法并确保其中英状态同步"""
        if not target_im:
            return

        # 1. 尝试 D-Bus 控制器接口
        if self.bus:
            try:
                await self.bus.call(
                    Message(
                        destination="org.fcitx.Fcitx5",
                        path="/controller",
                        interface="org.fcitx.Fcitx.Controller1",
                        member="SetCurrentIM",
                        signature="s",
                        body=[target_im]
                    )
                )
            except Exception:
                pass

        # 2. 命令行强力穿透执行
        try:
            if target_im == "keyboard-us":
                proc = await asyncio.create_subprocess_exec("fcitx5-remote", "-c")
                await proc.communicate()
            else:
                proc1 = await asyncio.create_subprocess_exec("fcitx5-remote", "-s", target_im)
                await proc1.communicate()
                proc2 = await asyncio.create_subprocess_exec("fcitx5-remote", "-o")
                await proc2.communicate()
        except Exception as e:
            app_logger.warning(f"[IME Controller] fcitx5-remote 执行异常: {e}")

    async def get_state_and_im(self) -> Tuple[int, str]:
        """查询底层 Fcitx5 的当前状态 (1英文/2中文) 及激活的输入法标识"""
        im_state = 1
        cur_im = "keyboard-us"

        if not self.bus:
            return im_state, cur_im

        try:
            msg_st = Message(destination="org.fcitx.Fcitx5", path="/controller",
                             interface="org.fcitx.Fcitx.Controller1", member="State")
            msg_im = Message(destination="org.fcitx.Fcitx5", path="/controller",
                             interface="org.fcitx.Fcitx.Controller1", member="CurrentInputMethod")

            results = await asyncio.gather(
                self.bus.call(msg_st),
                self.bus.call(msg_im),
                return_exceptions=True
            )

            r_st, r_im = results[0], results[1]
            if not isinstance(r_st, Exception) and r_st.body:
                im_state = r_st.body[0]
            if not isinstance(r_im, Exception) and r_im.body:
                cur_im = str(r_im.body[0])
        except Exception:
            pass

        return im_state, cur_im

    def open_config(self) -> None:
        """异步拉起 Fcitx5 偏好设置"""
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