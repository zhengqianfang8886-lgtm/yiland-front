# ==========================================
# 📄 File: backend/modules/mpris.py
# 🌟 MPRIS 媒体驱动 (补全 Seeked 监听 · 完美支持直播流版)
# ==========================================
import os
import io
import time
import math
import struct
import shutil
import asyncio
import threading
import subprocess
import urllib.parse
import urllib.request
from typing import Dict, Any, Optional

from PySide6.QtGui import QImage, QColor
from PySide6.QtCore import Qt

from dbus_next.aio import MessageBus
from dbus_next import Message, MessageType

from backend.logger import app_logger
from backend.core.base import BaseModule
from backend.core.state import IslandState


class SinglePlayerRecord:
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

        self._players: Dict[str, SinglePlayerRecord] = {}
        self._unique_to_wellknown: Dict[str, str] = {}

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
        app_logger.info("✅ MPRIS 仲裁总线就绪 (已挂载进度心跳与 Seeked 监听)")

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

    async def discover_all_players(self):
        try:
            reply = await self.bus.call(Message(
                destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                interface="org.freedesktop.DBus", member="ListNames"
            ))
            if reply.message_type == MessageType.ERROR or not reply.body: return
            current_names = [n for n in reply.body[0] if n.startswith("org.mpris.MediaPlayer2.")]
            dead_names = [n for n in self._players if n not in current_names]
            for d in dead_names: self._remove_player(d)
            for name in current_names: await self._track_player(name)
            await self._arbitrate_active_player(force_notify=True)
        except Exception:
            pass

    async def _track_player(self, bus_name: str):
        if not bus_name: return
        unique_owner = ""
        try:
            reply = await self.bus.call(Message(
                destination="org.freedesktop.DBus", path="/org/freedesktop/DBus",
                interface="org.freedesktop.DBus", member="GetNameOwner", signature="s", body=[bus_name]
            ))
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
        rec = self._players.pop(bus_name, None)
        if rec and rec.unique_name in self._unique_to_wellknown:
            self._unique_to_wellknown.pop(rec.unique_name, None)
        keys_to_clean = [u for u, w in self._unique_to_wellknown.items() if w == bus_name]
        for k in keys_to_clean: self._unique_to_wellknown.pop(k, None)

    async def _pull_player_full_properties(self, rec: SinglePlayerRecord):
        try:
            reply = await self.bus.call(Message(
                destination=rec.bus_name, path="/org/mpris/MediaPlayer2",
                interface="org.freedesktop.DBus.Properties", member="GetAll",
                signature="s", body=["org.mpris.MediaPlayer2.Player"]
            ))
            if reply.message_type == MessageType.ERROR or not reply.body: return
            all_props = self._unwrap_variant(reply.body[0])
            status = all_props.get("PlaybackStatus", "Stopped")
            if status != rec.playback_status:
                rec.playback_status = status
                rec.last_active_time = time.monotonic()
            if "Metadata" in all_props:
                self._parse_metadata_into_record(all_props["Metadata"], rec)
            rec.position = await self._fetch_position_for_bus(rec.bus_name)
        except Exception:
            pass

    def _parse_metadata_into_record(self, meta: Dict[str, Any], rec: SinglePlayerRecord):
        rec.title = meta.get("xesam:title", "未知曲目")
        artists = meta.get("xesam:artist", ["未知艺术家"])
        rec.artist = ", ".join(artists) if isinstance(artists, list) else str(artists)

        art_url = meta.get("mpris:artUrl", "") or meta.get("xesam:url", "")
        if art_url:
            art_url = str(art_url)
            if art_url.startswith("file://"): art_url = "file://" + urllib.parse.unquote(art_url[7:])
            elif art_url.startswith("/") and not art_url.startswith("file://"): art_url = "file://" + art_url
        
        if art_url != rec.art_url:
            rec.art_url = art_url
            if rec.art_url:
                self._extract_and_assign_color(rec.art_url, rec)
            else:
                rec.dominant_color = "#38bdf8"

        # 🚀【核心修复】：识别 Chrome 网页直播的 INT64_MAX (25亿小时) 伪无穷大时长
        length_us = meta.get("mpris:length", 0)
        raw_dur = round(float(length_us) / 1_000_000.0, 1) if (length_us and length_us > 0) else 0.0

        # 超过 24 小时 (86400秒) 的媒体在物理上必然是直播流，直接强制归零为直播！
        if raw_dur >= 86400:
            rec.duration = 0.0
        else:
            rec.duration = raw_dur

    async def _arbitrate_active_player(self, force_notify: bool = False):
        candidates = list(self._players.values())
        if not candidates:
            self._clear_player_state()
            return
        def _priority_score(item: SinglePlayerRecord):
            status_weight = 3 if item.playback_status == "Playing" else (2 if item.playback_status == "Paused" else 1)
            return (status_weight, item.last_active_time)
        best = max(candidates, key=_priority_score)

        is_switched = (self.state.active_player != best.bus_name)
        self.state.batch_update(
            active_player=best.bus_name,
            playback_status=best.playback_status,
            title=best.title,
            artist=best.artist,
            art_url=best.art_url,
            duration=best.duration,
            dominant_color=best.dominant_color,
            position=best.position
        )
        current_sig = f"{best.bus_name}|{best.title}|{best.artist}|{best.playback_status}|{best.art_url}|{best.duration}"
        if force_notify or is_switched or (current_sig != self._last_emitted_signature):
            self._last_emitted_signature = current_sig
            self.notify("MEDIA_UPDATE")

    def _clear_player_state(self):
        self.state.batch_update(
            active_player=None, playback_status="Stopped", title="等待播放媒体...",
            artist="空闲", art_url="", position=0.0, duration=0.0, dominant_color="#38bdf8"
        )
        self._last_emitted_signature = ""
        self.notify("MEDIA_UPDATE")

    # =========================================================================
    # 🚀【核心加固：新增 Seeked 信号监听】
    # =========================================================================
    async def _setup_listeners(self):
        rules = [
            "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/mpris/MediaPlayer2'",
            "type='signal',interface='org.mpris.MediaPlayer2.Player',member='Seeked',path='/org/mpris/MediaPlayer2'", # 🚀 进度条跳转瞬时捕获
            "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'"
        ]

        def signal_handler(msg: Message):
            # 1. 播放器关闭/创建
            if msg.member == "NameOwnerChanged" and msg.body:
                name, old_owner, new_owner = msg.body
                if name.startswith("org.mpris.MediaPlayer2."):
                    if new_owner and not old_owner:
                        asyncio.create_task(self._on_new_player(name))
                    elif old_owner and not new_owner:
                        self._remove_player(name)
                        asyncio.create_task(self._arbitrate_active_player(force_notify=True))

            # 2. 拖动进度条跳转信号 (Seeked)
            if msg.member == "Seeked" and msg.body:
                pos_us = self._unwrap_variant(msg.body[0])
                current_sec = round(float(pos_us) / 1_000_000.0, 2)
                self.state.position = current_sec
                self.notify("MEDIA_PROGRESS")
                return

            # 3. 属性变动 (PropertiesChanged)
            if msg.interface == "org.freedesktop.DBus.Properties" and msg.member == "PropertiesChanged":
                interface_name, changed_props, _ = msg.body
                if interface_name == "org.mpris.MediaPlayer2.Player":
                    target = self._unique_to_wellknown.get(msg.sender)
                    if not target:
                        for k, v in self._players.items():
                            if v.unique_name == msg.sender: target = k; break
                    if not target:
                        asyncio.create_task(self.discover_all_players())
                        return
                    rec = self._players.get(target)
                    if not rec: return
                    unwrapped = self._unwrap_variant(changed_props)
                    has_st_change = False
                    if "PlaybackStatus" in unwrapped:
                        st = unwrapped["PlaybackStatus"]
                        if rec.playback_status != st:
                            rec.playback_status = st
                            rec.last_active_time = time.monotonic()
                            has_st_change = True
                    if "Metadata" in unwrapped:
                        self._parse_metadata_into_record(unwrapped["Metadata"], rec)
                        rec.position = 0.0
                        rec.last_active_time = time.monotonic()
                    if has_st_change or target == self.state.active_player:
                        asyncio.create_task(self._arbitrate_active_player())

        for r in rules:
            await self.bus.call(Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus", interface="org.freedesktop.DBus", member="AddMatch", signature="s", body=[r]))
        self.bus.add_message_handler(signal_handler)

    async def _on_new_player(self, name):
        await self._track_player(name)
        await self._arbitrate_active_player()

    async def _fetch_position_for_bus(self, bus_name: str) -> float:
        if not bus_name: return 0.0
        try:
            r = await self.bus.call(Message(destination=bus_name, path="/org/mpris/MediaPlayer2", interface="org.freedesktop.DBus.Properties", member="Get", signature="ss", body=["org.mpris.MediaPlayer2.Player", "Position"]))
            if r.message_type != MessageType.ERROR and r.body:
                pos = self._unwrap_variant(r.body[0])
                return round(float(pos) / 1_000_000.0, 2)
        except Exception: pass
        return 0.0

    # 🚀【核心加固：平滑进度心跳，由 2 秒缩短至 1 秒，消除延迟感】
    async def _progress_ticker(self):
        while True:
            await asyncio.sleep(1.0)
            if self._is_active and self.state.playback_status == "Playing" and self.state.active_player:
                # 只有在非零总时长（普通歌曲）或报告了有效 Position 时才更新
                current_pos = await self._fetch_position_for_bus(self.state.active_player)
                self.state.position = current_pos
                self.notify("MEDIA_PROGRESS")

    async def control(self, action: str):
        target = self.state.active_player
        if not target: return
        try:
            await self.bus.call(Message(destination=target, path="/org/mpris/MediaPlayer2", interface="org.mpris.MediaPlayer2.Player", member=action))
            if target in self._players: self._players[target].last_active_time = time.monotonic()
        except Exception: pass

    async def raise_player(self) -> bool:
        target = self.state.active_player
        if not target: return False
        try:
            r = await self.bus.call(Message(destination=target, path="/org/mpris/MediaPlayer2", interface="org.mpris.MediaPlayer2", member="Raise"))
            return r.message_type != MessageType.ERROR
        except Exception: return False

    def _extract_and_assign_color(self, art_url: str, rec: SinglePlayerRecord):
        clean_url = art_url.strip().split("?")[0]
        if clean_url in self._color_cache:
            rec.dominant_color = self._color_cache[clean_url]
            if self.state.active_player == rec.bus_name:
                self.state.dominant_color = rec.dominant_color
                self.notify("MEDIA_UPDATE")
            return

        def _calc_color_safe():
            t0 = time.time()
            try:
                img_bytes = None
                if clean_url.startswith("http://") or clean_url.startswith("https://"):
                    req = urllib.request.Request(clean_url, headers={"User-Agent": "AlcoveIsland/Media"})
                    with urllib.request.urlopen(req, timeout=2.0) as resp:
                        img_bytes = resp.read()
                else:
                    path = urllib.parse.unquote(clean_url[7:] if clean_url.startswith("file://") else clean_url)
                    if os.path.exists(path):
                        with open(path, "rb") as f:
                            img_bytes = f.read()

                if not img_bytes:
                    raise ValueError("封面字节为空")

                qimg = QImage()
                qimg.loadFromData(img_bytes)
                if qimg.isNull():
                    raise ValueError("QImage 解析失败")

                qimg = qimg.scaled(32, 32, Qt.IgnoreAspectRatio, Qt.SmoothTransformation)

                margin_x = int(qimg.width() * 0.15)
                margin_y = int(qimg.height() * 0.15)

                buckets: Dict[int, list] = {}
                fallback_pixels = []

                for y in range(margin_y, qimg.height() - margin_y):
                    for x in range(margin_x, qimg.width() - margin_x):
                        c: QColor = qimg.pixelColor(x, y)
                        r, g, b = c.red(), c.green(), c.blue()
                        fallback_pixels.append((r, g, b))

                        max_c = max(r, g, b)
                        min_c = min(r, g, b)
                        v = max_c / 255.0
                        delta = max_c - min_c
                        s = (delta / max_c) if max_c > 0 else 0.0

                        if v < 0.15: continue
                        if v > 0.95 and s < 0.08: continue

                        qr = (r & 0xF0)
                        qg = (g & 0xF0)
                        qb = (b & 0xF0)
                        key = (qr << 16) | (qg << 8) | qb

                        if key not in buckets:
                            buckets[key] = [0, r, g, b, s, v]
                        buckets[key][0] += 1

                if not buckets:
                    if fallback_pixels:
                        r, g, b = max(fallback_pixels, key=lambda p: max(p))
                    else:
                        r, g, b = (226, 232, 240)
                else:
                    best_key = None
                    best_score = -1.0
                    for key, val in buckets.items():
                        count, pr, pg, pb, s, v = val
                        score = count * (1.0 + s * 1.2)
                        if score > best_score:
                            best_score = score
                            best_key = key

                    best_val = buckets[best_key]
                    r, g, b = best_val[1], best_val[2], best_val[3]

                max_val = max(r, g, b)
                delta_val = max_val - min(r, g, b)
                sat = (delta_val / max_val) if max_val > 0 else 0.0

                if max_val < 120:
                    if sat > 0.12 and max_val > 0:
                        scale_factor = 180.0 / float(max_val)
                        r = min(255, int(r * scale_factor))
                        g = min(255, int(g * scale_factor))
                        b = min(255, int(b * scale_factor))
                    else:
                        r, g, b = (226, 232, 240)

                hex_c = f"#{r:02x}{g:02x}{b:02x}"
                self._color_cache[clean_url] = hex_c
                rec.dominant_color = hex_c

                if self.state.active_player == rec.bus_name:
                    self.state.dominant_color = hex_c
                    self.notify("MEDIA_UPDATE")

                t1 = time.time()
                app_logger.info(f"[MPRIS] 🎨 封面主色提取成功 -> {hex_c} (耗时: {(t1-t0)*1000:.1f}ms, URL: {clean_url[:40]})")
                return

            except Exception as e:
                app_logger.debug(f"[MPRIS] 封面取色异常: {e}")

            rec.dominant_color = "#38bdf8"
            if self.state.active_player == rec.bus_name:
                self.state.dominant_color = "#38bdf8"
                self.notify("MEDIA_UPDATE")

        threading.Thread(target=_calc_color_safe, daemon=True, name="MediaColorExtractor").start()

    def _emit_spectrum_safe(self, s1: float, s2: float, s3: float, s4: float):
        if not self._spectrum_running: return
        ls1, ls2, ls3, ls4 = self._last_spec_cache
        if abs(s1-ls1)<0.015 and abs(s2-ls2)<0.015 and abs(s3-ls3)<0.015 and abs(s4-ls4)<0.015: return
        self._last_spec_cache = (s1, s2, s3, s4)
        self.state.spectrum = (s1, s2, s3, s4)
        self.backend.push_spectrum(s1, s2, s3, s4)

    def _start_spectrum_engine(self):
        self._spectrum_running = True
        self._dormant_gate.set()
        self._spectrum_thread = threading.Thread(target=self._spectrum_worker, daemon=True, name="AudioSpectrumWorker")
        self._spectrum_thread.start()

    def _spectrum_worker(self):
        has_cava = bool(shutil.which("cava"))
        if has_cava:
            try:
                if not os.path.exists(self.cava_config_path):
                    with open(self.cava_config_path, "w", encoding="utf-8") as f:
                        f.write("[general]\nbars = 4\nframerate = 22\nlower_cutoff_freq = 50\nhigher_cutoff_freq = 10000\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = binary\nbit_format = 8bit\n")
                self._cava_proc = subprocess.Popen(["cava", "-p", self.cava_config_path], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                was_playing = False
                while self._spectrum_running:
                    if self._cava_proc.poll() is not None: break
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
                    raw = self._cava_proc.stdout.read(4)
                    if len(raw) < 4: break
                    was_playing = True
                    b1, b2, b3, b4 = struct.unpack("4B", raw)
                    self._emit_spectrum_safe(round(0.18+(b1/255.0)*0.82,2), round(0.18+(b2/255.0)*0.82,2), round(0.18+(b3/255.0)*0.82,2), round(0.18+(b4/255.0)*0.82,2))
                return
            except Exception: pass

        t = 0.0; was_playing = False
        while self._spectrum_running:
            if not self._is_active:
                if was_playing: was_playing = False; self._emit_spectrum_safe(0.2, 0.2, 0.2, 0.2)
                self._dormant_gate.wait()
                continue
            if self.state.playback_status == "Playing":
                was_playing = True; t += 0.08
                self._emit_spectrum_safe(
                    round(max(0.2, min(0.95, 0.22 + 0.65 * abs(math.sin(t * 3.2)))), 2),
                    round(max(0.2, min(1.00, 0.25 + 0.72 * abs(math.sin(t * 4.2 + 0.8)))), 2),
                    round(max(0.2, min(0.92, 0.22 + 0.68 * abs(math.sin(t * 3.6 + 1.6)))), 2),
                    round(max(0.2, min(0.85, 0.20 + 0.58 * abs(math.sin(t * 5.1 + 2.4)))), 2)
                )
                time.sleep(0.045)
            else:
                if was_playing: was_playing = False; self._emit_spectrum_safe(0.2, 0.2, 0.2, 0.2)
                time.sleep(0.8)