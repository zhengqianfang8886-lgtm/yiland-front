# ==========================================
# 📄 File: modules/mpris.py
# 🌟 原生 MPRIS 媒体控制 + 声学跳动引擎 (真实CAVA + 拟真自愈保底 + 封面取色)
# ==========================================
import os
import re
import io
import math
import struct
import shutil
import asyncio
import colorsys
import threading
import subprocess
import urllib.parse
import urllib.request
from typing import Dict, Any, Optional, List
try:
    from loguru import logger
except ImportError:
    from logger import app_logger as logger

from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType
from core.state import IslandState

CAVA_CONFIG_PATH = f"/tmp/alcove_cava_{os.getuid()}_config"


class MprisModule:
    def __init__(self, bus: MessageBus, state: IslandState, dispatcher):
        self.bus = bus
        self.state = state
        self.dispatcher = dispatcher
        self.log = logger.bind(module="MPRIS")

        self._ticker_task: Optional[asyncio.Task] = None
        self._last_emitted_state = ("", "", "", 0.0, "")

        # 频谱与跳动引擎控制
        self._spectrum_running = False
        self._cava_proc: Optional[subprocess.Popen] = None
        self._spectrum_thread: Optional[threading.Thread] = None
        self._color_cache: Dict[str, str] = {}

    def _unwrap_variant(self, variant: Any) -> Any:
        if hasattr(variant, 'value'): return self._unwrap_variant(variant.value)
        if isinstance(variant, list): return [self._unwrap_variant(item) for item in variant]
        if isinstance(variant, dict): return {k: self._unwrap_variant(v) for k, v in variant.items()}
        return variant

    async def init(self):
        await self._setup_listeners()
        await self.discover_players()
        self._ticker_task = asyncio.create_task(self._progress_ticker())

        # 启动后台声学跳动线程
        self._start_spectrum_engine()

    async def close(self):
        self._spectrum_running = False
        if self._cava_proc:
            try:
                self._cava_proc.terminate()
                self._cava_proc.wait(timeout=0.3)
            except Exception:
                pass
            self._cava_proc = None

        if self._ticker_task and not self._ticker_task.done():
            self._ticker_task.cancel()

    # =========================================================================
    # 🚀 核心跳动引擎：真实 CAVA 采样 + 免装 CAVA 优雅拟真自愈保底
    # =========================================================================
    def _emit_spectrum_safe(self, s1: float, s2: float, s3: float, s4: float):
        if self.dispatcher and hasattr(self.dispatcher, "bridge") and self.dispatcher.bridge:
            try:
                self.dispatcher.bridge.audioSpectrumUpdated.emit(s1, s2, s3, s4)
            except Exception:
                pass

    def _start_spectrum_engine(self):
        self._spectrum_running = True
        self._spectrum_thread = threading.Thread(
            target=self._spectrum_worker,
            daemon=True,
            name="AudioSpectrumWorker"
        )
        self._spectrum_thread.start()

    # ==========================================
    # 📄 File: modules/mpris.py 核心片段替换
    # 替换 _spectrum_worker 方法
    # ==========================================
    def _spectrum_worker(self):
        has_cava = bool(shutil.which("cava"))

        if has_cava:
            try:
                cava_cfg = (
                    "[general]\n"
                    "bars = 4\n"
                    "framerate = 30\n"
                    "lower_cutoff_freq = 50\n"
                    "higher_cutoff_freq = 10000\n"
                    "[output]\n"
                    "method = raw\n"
                    "raw_target = /dev/stdout\n"
                    "data_format = binary\n"
                    "bit_format = 8bit\n"
                )
                with open(CAVA_CONFIG_PATH, "w", encoding="utf-8") as f:
                    f.write(cava_cfg)

                self._cava_proc = subprocess.Popen(
                    ["cava", "-p", CAVA_CONFIG_PATH],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL
                )

                chunk_size = 4
                was_playing = False
                while self._spectrum_running:
                    if self._cava_proc.poll() is not None:
                        break
                    raw = self._cava_proc.stdout.read(chunk_size)
                    if len(raw) < 4:
                        break

                    if self.state.playback_status == "Playing":
                        was_playing = True
                        b1, b2, b3, b4 = struct.unpack("4B", raw)
                        if (b1 + b2 + b3 + b4) > 10:
                            s1 = round(0.18 + (b1 / 255.0) * 0.82, 2)
                            s2 = round(0.18 + (b2 / 255.0) * 0.82, 2)
                            s3 = round(0.18 + (b3 / 255.0) * 0.82, 2)
                            s4 = round(0.18 + (b4 / 255.0) * 0.82, 2)
                            self._emit_spectrum_safe(s1, s2, s3, s4)
                            continue
                    elif was_playing:
                        # 仅在刚暂停的这一帧归位，随后不再重复占用总线
                        was_playing = False
                        self._emit_spectrum_safe(0.2, 0.2, 0.2, 0.2)

            except Exception as e:
                self.log.debug(f"CAVA 引擎降级: {e}")

        # 保底拟真跳动发生器（修复空转问题）
        self.log.info("启用自愈节律引擎（智能休眠模式）")
        t = 0.0
        was_playing = False

        while self._spectrum_running:
            if self.state.playback_status == "Playing":
                was_playing = True
                t += 0.08
                s1 = round(max(0.2, min(0.95, 0.22 + 0.65 * abs(math.sin(t * 3.8)))), 2)
                s2 = round(max(0.2, min(1.00, 0.25 + 0.72 * abs(math.sin(t * 5.2 + 0.8)))), 2)
                s3 = round(max(0.2, min(0.92, 0.22 + 0.68 * abs(math.sin(t * 4.1 + 1.7)))), 2)
                s4 = round(max(0.2, min(0.85, 0.20 + 0.58 * abs(math.sin(t * 6.3 + 2.5)))), 2)
                self._emit_spectrum_safe(s1, s2, s3, s4)
                threading.Event().wait(0.04) # ~25 FPS
            else:
                if was_playing:
                    # 暂停时只归零一次，不持续轰炸 QML
                    was_playing = False
                    self._emit_spectrum_safe(0.2, 0.2, 0.2, 0.2)
                # 🚀 未播放时深度睡眠 1 秒，不消耗 CPU
                threading.Event().wait(1.0)
    # =========================================================================
    # 🎨 封面主色调提取（让跳动的音柱具有专辑氛围色彩）
    # =========================================================================
    def _extract_and_emit_dominant_color(self, art_url: str):
        if not art_url:
            self._emit_color_safe("#22c55e")
            return

        clean_url = art_url.strip().split("?")[0]
        if clean_url in self._color_cache:
            self._emit_color_safe(self._color_cache[clean_url])
            return

        def _bg_calc():
            try:
                img_bytes = None
                if clean_url.startswith("http://") or clean_url.startswith("https://"):
                    req = urllib.request.Request(clean_url, headers={"User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(req, timeout=1.8) as resp:
                        img_bytes = resp.read()
                else:
                    path = clean_url[7:] if clean_url.startswith("file://") else clean_url
                    path = urllib.parse.unquote(path)
                    if os.path.exists(path):
                        with open(path, "rb") as f:
                            img_bytes = f.read()

                if img_bytes:
                    from PIL import Image
                    im = Image.open(io.BytesIO(img_bytes)).convert("RGB").resize((24, 24))
                    pixels = list(im.getdata())
                    candidates = []
                    for r, g, b in pixels:
                        h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
                        if l < 0.18 or l > 0.85 or s < 0.22:
                            continue
                        score = (s ** 1.5) * 3.0 + (1.0 - abs(l - 0.58)) * 2.0
                        candidates.append((score, h, s, l))

                    if candidates:
                        candidates.sort(key=lambda x: x[0], reverse=True)
                        _, h, s, l = candidates[0]
                        fr, fg, fb = colorsys.hls_to_rgb(h, max(0.55, min(0.68, l)), max(0.75, min(1.0, s * 1.15)))
                        hex_c = f"#{int(fr*255):02x}{int(fg*255):02x}{int(fb*255):02x}"
                        self._color_cache[clean_url] = hex_c
                        self._emit_color_safe(hex_c)
                        return
            except Exception:
                pass
            self._emit_color_safe("#22c55e")

        threading.Thread(target=_bg_calc, daemon=True).start()

    def _emit_color_safe(self, hex_color: str):
        if self.dispatcher and hasattr(self.dispatcher, "bridge") and self.dispatcher.bridge:
            try:
                self.dispatcher.bridge.dominantColorUpdated.emit(hex_color)
            except Exception:
                pass

    # =========================================================================
    # MPRIS 原生 D-Bus 事件与控制
    # =========================================================================
    async def _fetch_position(self) -> float:
        if not self.state.active_player:
            return self.state.position
        try:
            reply = await self.bus.call(
                Message(
                    destination=self.state.active_player,
                    path="/org/mpris/MediaPlayer2",
                    interface="org.freedesktop.DBus.Properties",
                    member="Get",
                    signature="ss",
                    body=["org.mpris.MediaPlayer2.Player", "Position"]
                )
            )
            if reply.message_type != MessageType.ERROR and reply.body:
                pos_us = self._unwrap_variant(reply.body[0])
                return round(float(pos_us) / 1_000_000.0, 2)
        except Exception:
            pass
        return self.state.position

    async def discover_players(self) -> List[str]:
        try:
            reply = await self.bus.call(
                Message(
                    destination="org.freedesktop.DBus",
                    path="/org/freedesktop/DBus",
                    interface="org.freedesktop.DBus",
                    member="ListNames"
                )
            )
            players = [n for n in reply.body[0] if n.startswith("org.mpris.MediaPlayer2.")]
            if players:
                if not self.state.active_player or self.state.active_player not in players:
                    await self.attach_player(players[0])
                return players
            else:
                self._clear_player_state()
                return []
        except Exception as e:
            self.log.error(f"播放器扫描异常: {e}")
            return []

    def _clear_player_state(self):
        self.state.active_player = None
        self.state.playback_status = "Stopped"
        self.state.title = "等待播放媒体..."
        self.state.artist = "空闲"
        self.state.art_url = ""
        self.state.position = 0.0
        self.state.duration = 0.0
        self._last_emitted_state = ("", "", "", 0.0, "")
        self.dispatcher.broadcast("MEDIA_UPDATE")

    async def attach_player(self, bus_name: str):
        if not bus_name:
            return
        self.state.active_player = bus_name
        try:
            reply = await self.bus.call(
                Message(
                    destination=bus_name,
                    path="/org/mpris/MediaPlayer2",
                    interface="org.freedesktop.DBus.Properties",
                    member="GetAll",
                    signature="s",
                    body=["org.mpris.MediaPlayer2.Player"]
                )
            )
            if reply.message_type == MessageType.ERROR:
                return

            all_props = self._unwrap_variant(reply.body[0])
            self.state.playback_status = all_props.get("PlaybackStatus", "Stopped")

            if "Metadata" in all_props:
                self._parse_metadata(all_props["Metadata"])

            self._last_emitted_state = (
                self.state.title, self.state.artist, self.state.playback_status, self.state.duration, self.state.art_url
            )
            self.dispatcher.broadcast("MEDIA_UPDATE")
            self.state.position = await self._fetch_position()
        except Exception as e:
            self.log.error(f"绑定播放器 {bus_name} 异常: {e}")

    def _parse_metadata(self, meta: Dict[str, Any]):
        self.state.title = meta.get("xesam:title", "未知曲目")
        artists = meta.get("xesam:artist", ["未知艺术家"])
        self.state.artist = ", ".join(artists) if isinstance(artists, list) else str(artists)

        art_url = meta.get("mpris:artUrl", "") or meta.get("xesam:url", "")
        if art_url:
            art_url = str(art_url)
            if art_url.startswith("file://"):
                art_url = "file://" + urllib.parse.unquote(art_url[7:])
            elif art_url.startswith("/") and not art_url.startswith("file://"):
                art_url = "file://" + art_url
        self.state.art_url = art_url

        # 异步提取专辑主色调
        self._extract_and_emit_dominant_color(art_url)

        length_us = meta.get("mpris:length", 0)
        self.state.duration = round(float(length_us) / 1_000_000.0, 1) if length_us else 0.0

    async def _setup_listeners(self):
        mpris_rule = "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/mpris/MediaPlayer2'"
        name_rule = "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'"

        def signal_handler(msg: Message):
            if msg.member == "NameOwnerChanged" and msg.body:
                name, old_owner, new_owner = msg.body
                if name.startswith("org.mpris.MediaPlayer2."):
                    if new_owner and not old_owner:
                        asyncio.create_task(self.attach_player(name))
                    elif old_owner and not new_owner:
                        if self.state.active_player == name or self.state.active_player == old_owner:
                            asyncio.create_task(self.discover_players())
                return

            if msg.interface == "org.freedesktop.DBus.Properties" and msg.member == "PropertiesChanged":
                interface_name, changed_props, _ = msg.body
                if interface_name == "org.mpris.MediaPlayer2.Player":
                    unwrapped = self._unwrap_variant(changed_props)
                    sender_bus = msg.sender

                    new_status = unwrapped.get("PlaybackStatus")
                    if not self.state.active_player or new_status == "Playing":
                        if sender_bus and self.state.active_player != sender_bus:
                            self.state.active_player = sender_bus

                    if new_status:
                        self.state.playback_status = new_status

                    if "Metadata" in unwrapped:
                        self._parse_metadata(unwrapped["Metadata"])
                        self.state.position = 0.0

                    curr_state = (
                        self.state.title,
                        self.state.artist,
                        self.state.playback_status,
                        self.state.duration,
                        self.state.art_url
                    )

                    if curr_state != self._last_emitted_state:
                        self._last_emitted_state = curr_state
                        self.dispatcher.broadcast("MEDIA_UPDATE")

        for rule in [mpris_rule, name_rule]:
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
        self.bus.add_message_handler(signal_handler)

    async def _progress_ticker(self):
        while True:
            await asyncio.sleep(1.0)
            if self.state.playback_status == "Playing" and self.state.active_player:
                self.state.position = await self._fetch_position()
                self.dispatcher.broadcast("MEDIA_PROGRESS")

    async def control(self, action: str):
        if not self.state.active_player:
            players = await self.discover_players()
            if not players or not self.state.active_player:
                return

        try:
            await self.bus.call(
                Message(
                    destination=self.state.active_player,
                    path="/org/mpris/MediaPlayer2",
                    interface="org.mpris.MediaPlayer2.Player",
                    member=action
                )
            )
        except Exception as e:
            self.log.error(f"执行媒体指令失败: {e}")

    # =========================================================================
    # 窗口置顶与唤醒
    # =========================================================================
    async def _get_player_pid(self, bus_name: str) -> Optional[int]:
        if m := re.search(r"instance(\d+)", bus_name):
            return int(m.group(1))

        try:
            reply = await self.bus.call(
                Message(
                    destination="org.freedesktop.DBus",
                    path="/org/freedesktop/DBus",
                    interface="org.freedesktop.DBus",
                    member="GetConnectionUnixProcessID",
                    signature="s",
                    body=[bus_name]
                )
            )
            if reply.message_type != MessageType.ERROR and reply.body:
                return int(reply.body[0])
        except Exception:
            pass
        return None

    async def raise_player(self) -> bool:
        target_bus = self.state.active_player
        if not target_bus:
            players = await self.discover_players()
            target_bus = self.state.active_player if players else None

        if not target_bus:
            return False

        try:
            await self.bus.call(
                Message(
                    destination=target_bus,
                    path="/org/mpris/MediaPlayer2",
                    interface="org.mpris.MediaPlayer2",
                    member="Raise"
                )
            )
        except Exception:
            pass

        pid = await self._get_player_pid(target_bus)

        if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
            if pid:
                proc = await asyncio.create_subprocess_shell(
                    f"hyprctl dispatch focuswindow pid:{pid}",
                    stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL
                )
                await proc.communicate()
                if proc.returncode == 0: return True

            if self.state.title and self.state.title != "等待播放媒体...":
                clean_title = re.escape(self.state.title.split(" - ")[0].strip()[:10])
                proc = await asyncio.create_subprocess_shell(
                    f"hyprctl dispatch focuswindow 'title:^(.*{clean_title}.*)$'",
                    stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL
                )
                await proc.communicate()
                if proc.returncode == 0: return True

        if os.environ.get("SWAYSOCK") and pid:
            proc = await asyncio.create_subprocess_shell(
                f"swaymsg '[pid={pid}] focus'",
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL
            )
            await proc.communicate()
            if proc.returncode == 0: return True

        if pid and shutil.which("xdotool"):
            cmd = f"WID=$(xdotool search --pid {pid} 2>/dev/null | tail -n 1); [ -n \"$WID\" ] && xdotool windowactivate --sync \"$WID\""
            proc = await asyncio.create_subprocess_shell(cmd)
            await proc.communicate()
            if proc.returncode == 0: return True

        if pid and shutil.which("wmctrl"):
            proc = await asyncio.create_subprocess_exec("wmctrl", "-lp", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
            out, _ = await proc.communicate()
            for line in out.decode(errors="ignore").splitlines():
                parts = line.split()
                if len(parts) >= 3 and parts[2] == str(pid):
                    await asyncio.create_subprocess_exec("wmctrl", "-i", "-a", parts[0])
                    return True

        if self.state.title and self.state.title != "等待播放媒体..." and shutil.which("wmctrl"):
            clean_title = self.state.title.split(" - ")[0].strip()
            proc = await asyncio.create_subprocess_shell(f'wmctrl -a "{clean_title}"')
            await proc.communicate()
            if proc.returncode == 0: return True

        return False