# ==========================================
# 📄 File: backend/modules/mpris.py
# 🌟 统一 MPRIS 媒体流多播放源仲裁驱动 (多源智能切换 · 零脏数据 · 0% 能耗休眠)
# ==========================================
import os
import io
import time
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

from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class SinglePlayerRecord:
    """单一播放源状态容器"""
    def __init__(self, bus_name: str, unique_name: str = ""):
        self.bus_name: str = bus_name
        self.unique_name: str = unique_name
        self.playback_status: str = "Stopped"
        self.title: str = "等待播放媒体..."
        self.artist: str = "空闲"
        self.art_url: str = ""
        self.position: float = 0.0
        self.duration: float = 0.0
        self.dominant_color: str = "#22c55e"
        self.last_active_time: float = time.monotonic()


class MprisModule(BaseModule):
    def __init__(self, backend, state: IslandState, bus: MessageBus):
        super().__init__(backend, state)
        self.bus = bus

        # 🚀 多播放源统一管理池
        self._players: Dict[str, SinglePlayerRecord] = {}  # key: well-known name
        self._unique_to_wellknown: Dict[str, str] = {}    # :1.xxx -> org.mpris...

        self._ticker_task: Optional[asyncio.Task] = None
        self._last_emitted_signature = ""

        self._spectrum_running = False
        self._cava_proc: Optional[subprocess.Popen] = None
        self._spectrum_thread: Optional[threading.Thread] = None
        self._color_cache: Dict[str, str] = {}
        self._last_spec_cache = (0.2, 0.2, 0.2, 0.2)

        self._dormant_gate = threading.Event()
        self._dormant_gate.set()

        runtime_dir = os.environ.get("XDG_RUNTIME_DIR", f"/tmp/runtime-{os.getuid()}")
        os.makedirs(runtime_dir, exist_ok=True)
        self.cava_config_path = os.path.join(runtime_dir, "alcove_cava.conf")

    def set_active(self, active: bool) -> None:
        super().set_active(active)
        if active:
            if self._cava_proc and self._cava_proc.poll() is None:
                try:
                    import signal
                    os.kill(self._cava_proc.pid, signal.SIGCONT)
                except OSError:
                    pass
            if not self._dormant_gate.is_set():
                self._dormant_gate.set()
        else:
            if self._dormant_gate.is_set():
                self._dormant_gate.clear()
            if self._cava_proc and self._cava_proc.poll() is None:
                try:
                    import signal
                    os.kill(self._cava_proc.pid, signal.SIGSTOP)
                except OSError:
                    pass
            self._emit_spectrum_safe(0.2, 0.2, 0.2, 0.2)

    def _unwrap_variant(self, variant: Any) -> Any:
        if hasattr(variant, 'value'): return self._unwrap_variant(variant.value)
        if isinstance(variant, list): return [self._unwrap_variant(item) for item in variant]
        if isinstance(variant, dict): return {k: self._unwrap_variant(v) for k, v in variant.items()}
        return variant

    async def start(self) -> None:
        await self._setup_listeners()
        await self.discover_all_players()
        self._ticker_task = asyncio.create_task(self._progress_ticker())
        self._start_spectrum_engine()
        app_logger.info("✅ MPRIS 多媒体仲裁总线与自适应律动引擎已就绪")

    async def stop(self) -> None:
        self._spectrum_running = False
        self._dormant_gate.set()
        if self._cava_proc:
            try:
                self._cava_proc.terminate()
                self._cava_proc.wait(timeout=0.2)
            except (OSError, subprocess.TimeoutExpired):
                pass
            self._cava_proc = None

        if self._ticker_task and not self._ticker_task.done():
            self._ticker_task.cancel()

    # =========================================================================
    # 1. 多播放源生命周期维护与仲裁中枢
    # =========================================================================
    async def discover_all_players(self):
        """全量扫描系统当前所有的 MPRIS 播放器实例"""
        try:
            reply = await self.bus.call(
                Message(
                    destination="org.freedesktop.DBus",
                    path="/org/freedesktop/DBus",
                    interface="org.freedesktop.DBus",
                    member="ListNames"
                )
            )
            if reply.message_type == MessageType.ERROR or not reply.body:
                return

            current_names = [n for n in reply.body[0] if n.startswith("org.mpris.MediaPlayer2.")]
            
            # 清理已不存在的源
            dead_names = [n for n in self._players if n not in current_names]
            for d in dead_names:
                self._remove_player(d)

            for name in current_names:
                await self._track_player(name)

            await self._arbitrate_active_player(force_notify=True)
        except Exception as e:
            app_logger.debug(f"[MPRIS] 发现播放源异常: {e}")

    async def _track_player(self, bus_name: str):
        """跟踪单个播放源，建立唯一名映射并完整同步初态"""
        if not bus_name:
            return

        unique_owner = ""
        try:
            reply = await self.bus.call(
                Message(
                    destination="org.freedesktop.DBus",
                    path="/org/freedesktop/DBus",
                    interface="org.freedesktop.DBus",
                    member="GetNameOwner",
                    signature="s",
                    body=[bus_name]
                )
            )
            if reply.message_type != MessageType.ERROR and reply.body:
                unique_owner = str(reply.body[0])
                self._unique_to_wellknown[unique_owner] = bus_name
        except Exception:
            pass

        rec = self._players.get(bus_name)
        if not rec:
            rec = SinglePlayerRecord(bus_name, unique_owner)
            self._players[bus_name] = rec
        else:
            rec.unique_name = unique_owner

        await self._pull_player_full_properties(rec)

    def _remove_player(self, bus_name: str):
        """注销已关闭的播放源"""
        rec = self._players.pop(bus_name, None)
        if rec and rec.unique_name in self._unique_to_wellknown:
            self._unique_to_wellknown.pop(rec.unique_name, None)

        # 清除针对该播放器的唯一名映射残留
        keys_to_clean = [u for u, w in self._unique_to_wellknown.items() if w == bus_name]
        for k in keys_to_clean:
            self._unique_to_wellknown.pop(k, None)

    async def _pull_player_full_properties(self, rec: SinglePlayerRecord):
        """原子拉取指定播放源的所有元数据"""
        try:
            reply = await self.bus.call(
                Message(
                    destination=rec.bus_name,
                    path="/org/mpris/MediaPlayer2",
                    interface="org.freedesktop.DBus.Properties",
                    member="GetAll",
                    signature="s",
                    body=["org.mpris.MediaPlayer2.Player"]
                )
            )
            if reply.message_type == MessageType.ERROR or not reply.body:
                return

            all_props = self._unwrap_variant(reply.body[0])
            status = all_props.get("PlaybackStatus", "Stopped")
            if status != rec.playback_status:
                rec.playback_status = status
                rec.last_active_time = time.monotonic()

            if "Metadata" in all_props:
                self._parse_metadata_into_record(all_props["Metadata"], rec)

            rec.position = await self._fetch_position_for_bus(rec.bus_name)
        except Exception as e:
            app_logger.debug(f"[MPRIS] 拉取播放器 {rec.bus_name} 属性异常: {e}")

    def _parse_metadata_into_record(self, meta: Dict[str, Any], rec: SinglePlayerRecord):
        rec.title = meta.get("xesam:title", "未知曲目")
        artists = meta.get("xesam:artist", ["未知艺术家"])
        rec.artist = ", ".join(artists) if isinstance(artists, list) else str(artists)

        art_url = meta.get("mpris:artUrl", "") or meta.get("xesam:url", "")
        if art_url:
            art_url = str(art_url)
            if art_url.startswith("file://"):
                art_url = "file://" + urllib.parse.unquote(art_url[7:])
            elif art_url.startswith("/") and not art_url.startswith("file://"):
                art_url = "file://" + art_url
        rec.art_url = art_url

        length_us = meta.get("mpris:length", 0)
        rec.duration = round(float(length_us) / 1_000_000.0, 1) if length_us else 0.0

        if rec.art_url:
            self._extract_and_assign_color(rec.art_url, rec)
        else:
            rec.dominant_color = "#22c55e"

    async def _arbitrate_active_player(self, force_notify: bool = False):
        """
        🚀 核心仲裁器：在所有存活的播放源中智能决策最佳展示源
        权重排序：Playing 状态最优先；同状态下最近产生交互的播放源优先。
        """
        candidates = list(self._players.values())
        if not candidates:
            self._clear_player_state()
            return

        def _priority_score(item: SinglePlayerRecord):
            status_weight = 3 if item.playback_status == "Playing" else (2 if item.playback_status == "Paused" else 1)
            return (status_weight, item.last_active_time)

        best_player = max(candidates, key=_priority_score)

        # 检查是否需要切换展示源
        is_source_switched = (self.state.active_player != best_player.bus_name)
        self.state.active_player = best_player.bus_name
        self.state.playback_status = best_player.playback_status
        self.state.title = best_player.title
        self.state.artist = best_player.artist
        self.state.art_url = best_player.art_url
        self.state.duration = best_player.duration
        self.state.dominant_color = best_player.dominant_color
        self.state.position = best_player.position

        current_sig = f"{best_player.bus_name}|{best_player.title}|{best_player.artist}|{best_player.playback_status}|{best_player.art_url}"

        if force_notify or is_source_switched or (current_sig != self._last_emitted_signature):
            self._last_emitted_signature = current_sig
            self.notify("MEDIA_UPDATE")

    def _clear_player_state(self):
        self.state.active_player = None
        self.state.playback_status = "Stopped"
        self.state.title = "等待播放媒体..."
        self.state.artist = "空闲"
        self.state.art_url = ""
        self.state.position = 0.0
        self.state.duration = 0.0
        self.state.dominant_color = "#22c55e"
        self._last_emitted_signature = ""
        self.notify("MEDIA_UPDATE")

    # =========================================================================
    # 2. D-Bus 监听器处理
    # =========================================================================
    async def _setup_listeners(self):
        mpris_rule = "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/mpris/MediaPlayer2'"
        name_rule = "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'"

        def signal_handler(msg: Message):
            # 1. 播放器进程上线 / 下线
            if msg.member == "NameOwnerChanged" and msg.body:
                name, old_owner, new_owner = msg.body
                
                # 情况 A: 注册了新的 Well-known 播放器
                if name.startswith("org.mpris.MediaPlayer2."):
                    if new_owner and not old_owner:
                        async def on_new():
                            await self._track_player(name)
                            await self._arbitrate_active_player()
                        asyncio.create_task(on_new())
                        return
                    elif old_owner and not new_owner:
                        self._remove_player(name)
                        asyncio.create_task(self._arbitrate_active_player(force_notify=True))
                        return

                # 情况 B: Unique Name 断开
                if old_owner and not new_owner and old_owner in self._unique_to_wellknown:
                    well_name = self._unique_to_wellknown.get(old_owner)
                    if well_name:
                        self._remove_player(well_name)
                        asyncio.create_task(self._arbitrate_active_player(force_notify=True))
                    return

            # 2. 播放状态与曲目元数据突变
            if msg.interface == "org.freedesktop.DBus.Properties" and msg.member == "PropertiesChanged":
                interface_name, changed_props, _ = msg.body
                if interface_name == "org.mpris.MediaPlayer2.Player":
                    sender = msg.sender
                    # 定位发送信号的真实播放源
                    target_bus_name = self._unique_to_wellknown.get(sender)
                    if not target_bus_name and sender:
                        # 兼容部分未提前注册的播放器
                        for k, v in self._players.items():
                            if v.unique_name == sender:
                                target_bus_name = k
                                break

                    if not target_bus_name:
                        # 触发一次发现并同步
                        asyncio.create_task(self.discover_all_players())
                        return

                    rec = self._players.get(target_bus_name)
                    if not rec:
                        return

                    unwrapped = self._unwrap_variant(changed_props)
                    has_status_change = False

                    if "PlaybackStatus" in unwrapped:
                        st = unwrapped["PlaybackStatus"]
                        if rec.playback_status != st:
                            rec.playback_status = st
                            rec.last_active_time = time.monotonic()
                            has_status_change = True

                    if "Metadata" in unwrapped:
                        self._parse_metadata_into_record(unwrapped["Metadata"], rec)
                        rec.position = 0.0
                        rec.last_active_time = time.monotonic()

                    # 只要当前活跃播放器发生变动，或后台播放器切换至 Playing，执行仲裁
                    async def on_prop_changed():
                        if has_status_change or target_bus_name == self.state.active_player:
                            await self._arbitrate_active_player()
                    asyncio.create_task(on_prop_changed())

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

    async def _fetch_position_for_bus(self, bus_name: str) -> float:
        if not bus_name:
            return 0.0
        try:
            reply = await self.bus.call(
                Message(
                    destination=bus_name,
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
        return 0.0

    async def _progress_ticker(self):
        while True:
            await asyncio.sleep(2.0)
            if self._is_active and self.state.playback_status == "Playing" and self.state.active_player:
                self.state.position = await self._fetch_position_for_bus(self.state.active_player)
                self.notify("MEDIA_PROGRESS")

    # =========================================================================
    # 3. 播控动作下发与窗口聚焦
    # =========================================================================
    async def control(self, action: str):
        target_bus = self.state.active_player
        if not target_bus:
            await self.discover_all_players()
            target_bus = self.state.active_player
            if not target_bus:
                return

        try:
            await self.bus.call(
                Message(
                    destination=target_bus,
                    path="/org/mpris/MediaPlayer2",
                    interface="org.mpris.MediaPlayer2.Player",
                    member=action
                )
            )
            # 操作后主动更新该源的活跃时间
            if target_bus in self._players:
                self._players[target_bus].last_active_time = time.monotonic()
        except Exception as e:
            app_logger.debug(f"[MPRIS] 媒体指令 {action} 执行异常: {e}")

    async def raise_player(self) -> bool:
        target_bus = self.state.active_player
        if not target_bus:
            return False

        try:
            reply = await self.bus.call(
                Message(
                    destination=target_bus,
                    path="/org/mpris/MediaPlayer2",
                    interface="org.mpris.MediaPlayer2",
                    member="Raise"
                )
            )
            return reply.message_type != MessageType.ERROR
        except Exception:
            return False

    # =========================================================================
    # 4. 封面主导色提取与音频波形频谱
    # =========================================================================
    def _extract_and_assign_color(self, art_url: str, rec: SinglePlayerRecord):
        clean_url = art_url.strip().split("?")[0]
        if clean_url in self._color_cache:
            rec.dominant_color = self._color_cache[clean_url]
            if self.state.active_player == rec.bus_name:
                self.state.dominant_color = rec.dominant_color
                self.notify("MEDIA_UPDATE")
            return

        def _bg_calc():
            try:
                img_bytes = None
                if clean_url.startswith("http://") or clean_url.startswith("https://"):
                    req = urllib.request.Request(clean_url, headers={"User-Agent": "AlcoveIsland/2.0"})
                    with urllib.request.urlopen(req, timeout=1.5) as resp:
                        img_bytes = resp.read()
                else:
                    path = clean_url[7:] if clean_url.startswith("file://") else clean_url
                    path = urllib.parse.unquote(path)
                    if os.path.exists(path):
                        with open(path, "rb") as f:
                            img_bytes = f.read()

                if img_bytes:
                    from PIL import Image
                    im = Image.open(io.BytesIO(img_bytes)).convert("RGB").resize((36, 36))
                    quantized = im.quantize(colors=12)
                    palette = quantized.getpalette()
                    color_counts = quantized.getcolors() or []

                    best_color = None
                    max_score = -1.0

                    for count, idx in color_counts:
                        r = palette[idx * 3]
                        g = palette[idx * 3 + 1]
                        b = palette[idx * 3 + 2]

                        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
                        if v < 0.22 or s < 0.16:
                            continue

                        score = (s * 1.6 + v * 0.5) * (count ** 0.5)
                        if score > max_score:
                            max_score = score
                            best_color = (h, s, v)

                    if not best_color and color_counts:
                        top_idx = max(color_counts, key=lambda x: x[0])[1]
                        r = palette[top_idx * 3]
                        g = palette[top_idx * 3 + 1]
                        b = palette[top_idx * 3 + 2]
                        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
                        best_color = (h, s, max(v, 0.85))

                    if best_color:
                        h, s, v = best_color
                        s = max(s, 0.65)
                        v = max(v, 0.85)

                        final_r, final_g, final_b = colorsys.hsv_to_rgb(h, s, v)
                        hex_c = f"#{int(final_r * 255):02x}{int(final_g * 255):02x}{int(final_b * 255):02x}"
                        self._color_cache[clean_url] = hex_c
                        rec.dominant_color = hex_c
                        if self.state.active_player == rec.bus_name:
                            self.state.dominant_color = hex_c
                            self.notify("MEDIA_UPDATE")
                        return
            except Exception:
                pass

            rec.dominant_color = "#22c55e"
            if self.state.active_player == rec.bus_name:
                self.state.dominant_color = "#22c55e"
                self.notify("MEDIA_UPDATE")

        threading.Thread(target=_bg_calc, daemon=True).start()

    def _emit_spectrum_safe(self, s1: float, s2: float, s3: float, s4: float):
        if not self._spectrum_running:
            return

        ls1, ls2, ls3, ls4 = self._last_spec_cache
        if (abs(s1 - ls1) < 0.015 and 
            abs(s2 - ls2) < 0.015 and 
            abs(s3 - ls3) < 0.015 and 
            abs(s4 - ls4) < 0.015):
            return

        self._last_spec_cache = (s1, s2, s3, s4)
        self.state.spectrum = (s1, s2, s3, s4)
        self.backend.push_spectrum(s1, s2, s3, s4)

    def _start_spectrum_engine(self):
        self._spectrum_running = True
        self._dormant_gate.set()
        self._spectrum_thread = threading.Thread(
            target=self._spectrum_worker,
            daemon=True,
            name="AudioSpectrumWorker"
        )
        self._spectrum_thread.start()

    def _spectrum_worker(self):
        has_cava = bool(shutil.which("cava"))
        if has_cava:
            try:
                if not os.path.exists(self.cava_config_path):
                    cava_cfg = (
                        "[general]\n"
                        "bars = 4\n"
                        "framerate = 22\n"
                        "lower_cutoff_freq = 50\n"
                        "higher_cutoff_freq = 10000\n"
                        "[output]\n"
                        "method = raw\n"
                        "raw_target = /dev/stdout\n"
                        "data_format = binary\n"
                        "bit_format = 8bit\n"
                    )
                    with open(self.cava_config_path, "w", encoding="utf-8") as f:
                        f.write(cava_cfg)

                self._cava_proc = subprocess.Popen(
                    ["cava", "-p", self.cava_config_path],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL
                )

                chunk_size = 4
                was_playing = False
                while self._spectrum_running:
                    if self._cava_proc.poll() is not None:
                        break

                    if not self._is_active:
                        if was_playing:
                            was_playing = False
                            self._emit_spectrum_safe(0.2, 0.2, 0.2, 0.2)
                        self._dormant_gate.wait()
                        continue

                    if self.state.playback_status != "Playing":
                        if was_playing:
                            was_playing = False
                            self._emit_spectrum_safe(0.2, 0.2, 0.2, 0.2)
                        time.sleep(0.5)
                        continue

                    raw = self._cava_proc.stdout.read(chunk_size)
                    if len(raw) < 4:
                        break

                    was_playing = True
                    b1, b2, b3, b4 = struct.unpack("4B", raw)
                    s1 = round(0.18 + (b1 / 255.0) * 0.82, 2)
                    s2 = round(0.18 + (b2 / 255.0) * 0.82, 2)
                    s3 = round(0.18 + (b3 / 255.0) * 0.82, 2)
                    s4 = round(0.18 + (b4 / 255.0) * 0.82, 2)
                    self._emit_spectrum_safe(s1, s2, s3, s4)

                return
            except Exception as e:
                app_logger.debug(f"[MPRIS] CAVA 管道故障，降级拟真律动: {e}")

        # 保底呼吸拟真波形
        t = 0.0
        was_playing = False
        while self._spectrum_running:
            if not self._is_active:
                if was_playing:
                    was_playing = False
                    self._emit_spectrum_safe(0.2, 0.2, 0.2, 0.2)
                self._dormant_gate.wait()
                continue

            if self.state.playback_status == "Playing":
                was_playing = True
                t += 0.08
                s1 = round(max(0.2, min(0.95, 0.22 + 0.65 * abs(math.sin(t * 3.2)))), 2)
                s2 = round(max(0.2, min(1.00, 0.25 + 0.72 * abs(math.sin(t * 4.2 + 0.8)))), 2)
                s3 = round(max(0.2, min(0.92, 0.22 + 0.68 * abs(math.sin(t * 3.6 + 1.6)))), 2)
                s4 = round(max(0.2, min(0.85, 0.20 + 0.58 * abs(math.sin(t * 5.1 + 2.4)))), 2)
                self._emit_spectrum_safe(s1, s2, s3, s4)
                time.sleep(0.045)
            else:
                if was_playing:
                    was_playing = False
                    self._emit_spectrum_safe(0.2, 0.2, 0.2, 0.2)
                time.sleep(0.8)