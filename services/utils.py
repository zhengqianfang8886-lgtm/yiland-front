import os
import socket
import shutil
import hashlib
import urllib.parse
from logger import app_logger

AVATAR_CACHE_DIR = os.path.expanduser("~/.local/state/alcove_island/avatar_cache")
CAVA_CONFIG_PATH = f"/tmp/alcove_cava_{os.getuid()}_config"

CONCEAL_MIME_TYPES = {
    "application/x-vnd.passwordmanager-conceal",
    "x-kde-passwordManagerHint",
    "application/x-1password-conceal",
    "application/x-keepassxc-conceal",
    "application/x-encpass",
    "text/x-private",
    "application/x-moz-url-priv"
}


def process_notification_avatar(raw_avatar_url: str) -> str:
    if not raw_avatar_url:
        return ""
    try:
        parsed = urllib.parse.urlparse(raw_avatar_url)
        clean_path = parsed.path if parsed.scheme in ("file", "") else raw_avatar_url
        if parsed.scheme == "file" and not clean_path.startswith("/"):
            clean_path = "/" + clean_path
        if parsed.scheme in ("http", "https"):
            return raw_avatar_url
        if not os.path.exists(clean_path):
            return ""
        os.makedirs(AVATAR_CACHE_DIR, exist_ok=True)
        mtime = os.path.getmtime(clean_path)
        file_hash = hashlib.md5(f"{clean_path}_{mtime}".encode("utf-8")).hexdigest()[:12]
        cached_filename = f"avatar_circle_{file_hash}.png"
        cached_path = os.path.join(AVATAR_CACHE_DIR, cached_filename)

        if not os.path.exists(cached_path):
            try:
                from PIL import Image, ImageDraw
                im = Image.open(clean_path).convert("RGBA")
                size = min(im.size)
                left = (im.width - size) // 2
                top = (im.height - size) // 2
                im = im.crop((left, top, left + size, top + size))

                mask = Image.new("L", (size, size), 0)
                draw = ImageDraw.Draw(mask)
                draw.ellipse((0, 0, size, size), fill=255)
                im.putalpha(mask)
                im.save(cached_path, "PNG")
            except Exception:
                shutil.copy2(clean_path, cached_path)

        return f"file://{cached_path}"
    except Exception as e:
        app_logger.warning(f"处理头像缓存异常: {e}")
        return ""


def to_compact_speed(speed_str: str) -> str:
    if not speed_str:
        return "0.0 KB/s"
    parts = speed_str.strip().split()
    if len(parts) >= 2:
        val, unit = parts[0], parts[1].upper()
        try:
            f = float(val)
            if "M" in unit:
                return f"{f:.1f} MB/s"
            elif "K" in unit:
                return f"{int(f)} KB/s" if f >= 100 else f"{f:.1f} KB/s"
            elif "B" in unit:
                return f"{int(f)} B/s" if f > 0 else "0.0 KB/s"
        except ValueError:
            pass
    return speed_str if speed_str else "0.0 KB/s"


def get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def sanitize_time(val):
    if val is None:
        return None
    try:
        f = float(val)
        if f < 0:
            return 0.0
        if f >= 100_000:
            return f / 1_000_000.0
        return f
    except Exception:
        return None