# ==========================================
# 📄 File: services/media.py
# 🌟 HSL 感知色彩提取 · 视频源封面过滤与系统缩略图自动匹配完整版
# ==========================================
import io
import os
import struct
import shutil
import hashlib
import subprocess
import urllib.parse
import urllib.request
import colorsys
from collections import OrderedDict
from PySide6.QtCore import QObject, QTimer, Signal
from logger import app_logger
from services.utils import CAVA_CONFIG_PATH, sanitize_time

VIDEO_EXTENSIONS = {".mp4", ".mkv", ".avi", ".mov", ".flv", ".wmv", ".m4v", ".webm", ".ts"}


def find_system_video_thumbnail(video_path: str) -> str:
    """遵循 Freedesktop 规范查找系统现成的视频缩略图缓存"""
    try:
        clean_path = os.path.abspath(video_path)
        if not os.path.exists(clean_path):
            return ""
        file_uri = "file://" + urllib.parse.quote(clean_path)
        md5_hash = hashlib.md5(file_uri.encode("utf-8")).hexdigest()
        
        cache_dirs = [
            os.path.expanduser("~/.cache/thumbnails/large"),
            os.path.expanduser("~/.cache/thumbnails/normal"),
            os.path.expanduser("~/.cache/thumbnails/x-large")
        ]
        for cdir in cache_dirs:
            thumb = os.path.join(cdir, f"{md5_hash}.png")
            if os.path.exists(thumb):
                return f"file://{thumb}"
    except Exception:
        pass
    return ""


class MediaService(QObject):
    mediaUpdated = Signal(str, str, str, str, float, float)
    progressUpdated = Signal(float, float, float)
    audioSpectrumUpdated = Signal(float, float, float, float)
    dominantColorUpdated = Signal(str)

    def __init__(self, executor, send_ipc_func, parent=None):
        super().__init__(parent)
        self._pool = executor
        self._send_ipc = send_ipc_func

        self._curr_title = ""
        self._curr_artist = ""
        self._curr_pos = 0.0
        self._curr_dur = 0.0
        self._curr_status = "Paused"
        self._curr_art = ""
        self._curr_dominant_color = "#22c55e"

        self._color_lru_cache = OrderedDict()
        self._cache_limit = 64

        self._local_media_timer = QTimer(self)
        self._local_media_timer.setInterval(1000)
        self._local_media_timer.timeout.connect(self._on_local_media_tick)

        self._cava_proc = None
        self._start_cava_spectrum_monitor()

    def cleanup(self):
        if self._cava_proc:
            try:
                if self._cava_proc.poll() is None:
                    self._cava_proc.terminate()
                    self._cava_proc.wait(timeout=0.5)
            except Exception:
                try:
                    self._cava_proc.kill()
                except Exception:
                    pass
            self._cava_proc = None
        try:
            if os.path.exists(CAVA_CONFIG_PATH):
                os.remove(CAVA_CONFIG_PATH)
        except Exception:
            pass

    def _start_cava_spectrum_monitor(self):
        if not shutil.which("cava"):
            return

        def _cava_worker():
            try:
                cava_cfg = (
                    "[general]\n"
                    "bars = 4\n"
                    "framerate = 30\n"
                    "lower_cutoff_freq = 50\n"
                    "higher_cutoff_freq = 12000\n"
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
                while True:
                    if not self._cava_proc or self._cava_proc.poll() is not None:
                        break
                    raw = self._cava_proc.stdout.read(chunk_size)
                    if len(raw) < 4:
                        break
                    b1, b2, b3, b4 = struct.unpack("4B", raw)
                    s1 = round(0.15 + (b1 / 255.0) * 0.85, 2)
                    s2 = round(0.15 + (b2 / 255.0) * 0.85, 2)
                    s3 = round(0.15 + (b3 / 255.0) * 0.85, 2)
                    s4 = round(0.15 + (b4 / 255.0) * 0.85, 2)

                    if self._curr_status == "Playing":
                        self.audioSpectrumUpdated.emit(s1, s2, s3, s4)
                    else:
                        self.audioSpectrumUpdated.emit(0.2, 0.2, 0.2, 0.2)
            except Exception:
                pass

        self._pool.submit(_cava_worker)

    def apply_media_state(self, title, artist, status, art, pos_val, dur_val):
        pos = sanitize_time(pos_val)
        dur = sanitize_time(dur_val)
        is_track_changed = (title != self._curr_title) or (artist != self._curr_artist)
        self._curr_status = status

        # 🚀【视频封面净化拦截】
        resolved_art = art or ""
        clean_ext = os.path.splitext(resolved_art.split("?")[0])[1].lower()
        if clean_ext in VIDEO_EXTENSIONS:
            local_vpath = resolved_art[7:] if resolved_art.startswith("file://") else resolved_art
            local_vpath = urllib.parse.unquote(local_vpath)
            # 尝试查系统生成的缩略图缓存，若无则安全置空
            resolved_art = find_system_video_thumbnail(local_vpath)

        if is_track_changed:
            self._curr_title = title
            self._curr_artist = artist
            self._curr_dur = dur if (dur and dur > 0) else 0.0
            self._curr_pos = pos if (pos and pos >= 0) else 0.0
        else:
            if dur and dur > 0:
                self._curr_dur = dur
            if pos and pos > 0:
                self._curr_pos = pos

        if is_track_changed or (resolved_art and resolved_art != self._curr_art):
            self._curr_art = resolved_art
            if resolved_art:
                self._extract_cover_color(resolved_art)
            else:
                self.dominantColorUpdated.emit("#22c55e")

        if status == "Playing":
            if not self._local_media_timer.isActive():
                self._local_media_timer.start()
        else:
            if self._local_media_timer.isActive():
                self._local_media_timer.stop()

        self.mediaUpdated.emit(title, artist, status, self._curr_art, self._curr_pos, self._curr_dur)

    def apply_media_progress(self, pos_val, dur_val, prog):
        pos = sanitize_time(pos_val)
        dur = sanitize_time(dur_val)
        if dur and dur > 0:
            self._curr_dur = dur
        if pos and pos >= 0:
            self._curr_pos = pos

        actual_prog = prog
        if actual_prog < 0:
            actual_prog = min(1.0, max(0.0, self._curr_pos / self._curr_dur)) if self._curr_dur > 0 else 0.0

        self.progressUpdated.emit(self._curr_pos, self._curr_dur, actual_prog)

    def _on_local_media_tick(self):
        if self._curr_status == "Playing" and self._curr_dur > 0:
            if self._curr_pos < self._curr_dur:
                self._curr_pos += 1.0
                prog = min(1.0, max(0.0, self._curr_pos / self._curr_dur))
                self.progressUpdated.emit(self._curr_pos, self._curr_dur, prog)

    def _extract_cover_color(self, art_url: str):
        if not art_url:
            self.dominantColorUpdated.emit("#22c55e")
            return

        clean_url = art_url.strip().split("?")[0]
        # 若是视频格式，直接给默认主题色退出
        if os.path.splitext(clean_url)[1].lower() in VIDEO_EXTENSIONS:
            self.dominantColorUpdated.emit("#22c55e")
            return

        if clean_url in self._color_lru_cache:
            color = self._color_lru_cache[clean_url]
            self._color_lru_cache.move_to_end(clean_url)
            self._curr_dominant_color = color
            self.dominantColorUpdated.emit(color)
            return

        def _extract():
            try:
                img_bytes = None
                if clean_url.startswith("http://") or clean_url.startswith("https://"):
                    req = urllib.request.Request(clean_url, headers={"User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(req, timeout=2.5) as resp:
                        img_bytes = resp.read()
                else:
                    local_path = clean_url[7:] if clean_url.startswith("file://") else clean_url
                    local_path = urllib.parse.unquote(local_path)
                    if os.path.exists(local_path):
                        with open(local_path, "rb") as f:
                            img_bytes = f.read()

                if not img_bytes:
                    return

                try:
                    from PIL import Image
                    im = Image.open(io.BytesIO(img_bytes)).convert("RGB").resize((32, 32))
                    pixels = list(im.getdata())

                    candidates = []
                    for r, g, b in pixels:
                        h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
                        if l < 0.16 or l > 0.88 or s < 0.20:
                            continue
                        light_comfort = 1.0 - abs(l - 0.58) * 1.6
                        vibrancy_score = (s ** 1.6) * 3.2 + light_comfort * 2.0
                        candidates.append((vibrancy_score, h, s, l))

                    if candidates:
                        candidates.sort(key=lambda x: x[0], reverse=True)
                        _, best_h, best_s, best_l = candidates[0]
                        safe_s = max(0.75, min(1.0, best_s * 1.15))
                        safe_l = max(0.58, min(0.70, best_l * 1.08))
                        final_r, final_g, final_b = colorsys.hls_to_rgb(best_h, safe_l, safe_s)
                        hex_c = f"#{int(final_r * 255):02x}{int(final_g * 255):02x}{int(final_b * 255):02x}"

                        self._curr_dominant_color = hex_c
                        self._color_lru_cache[clean_url] = hex_c
                        if len(self._color_lru_cache) > self._cache_limit:
                            self._color_lru_cache.popitem(last=False)

                        self.dominantColorUpdated.emit(hex_c)
                        return
                except Exception:
                    pass

                self.dominantColorUpdated.emit("#22c55e")
            except Exception as e:
                app_logger.warning(f"主色调提取异常: {e}")

        self._pool.submit(_extract)

    def focus_media_window(self):
        self._send_ipc("MEDIA_FOCUS")
        def _focus():
            try:
                if shutil.which("playerctl"):
                    subprocess.run(["playerctl", "raise"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0)
            except Exception:
                pass

            pure_players = ["Spotify", "spotify", "netease-cloud-music", "yesplaymusic", "qqmusic", "QQMusic", "cloud-music", "vlc", "rhythmbox", "audacious", "feishin"]
            for kw in pure_players:
                try:
                    if shutil.which("hyprctl"):
                        if subprocess.run(["hyprctl", "dispatch", "focuswindow", f"class:^(?i)({kw})"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.8).returncode == 0:
                            return
                    if shutil.which("swaymsg"):
                        if subprocess.run(["swaymsg", f'[app_id="(?i).*{kw}.*"] focus'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.8).returncode == 0:
                            return
                    if shutil.which("wmctrl"):
                        if subprocess.run(["wmctrl", "-x", "-a", kw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.8).returncode == 0:
                            return
                except subprocess.TimeoutExpired:
                    continue
        self._pool.submit(_focus)