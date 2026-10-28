# ==========================================
# 📄 File: backend/modules/ime/pixmap.py
# 🌟 输入法状态图标 ARGB 裸内存转 Base64 解码器
# ==========================================
import hashlib
from typing import List, Optional

from PySide6.QtGui import QImage
from PySide6.QtCore import QBuffer, QIODevice


class ImePixmapDecoder:
    """负责将 SNI IconPixmap 解码为前端可直接渲染的 Base64 Data URL"""

    def __init__(self):
        self._last_pixmap_hash = ""

    def decode_best_pixmap(self, pixmaps: List[any]) -> Optional[str]:
        if not isinstance(pixmaps, list) or len(pixmaps) == 0:
            return None

        try:
            # 选取分辨率最高的位图
            best_pix = max(pixmaps, key=lambda p: p[0] if isinstance(p, (list, tuple)) else 0)
            decoded_w = int(best_pix[0])
            decoded_h = int(best_pix[1])
            raw_bytes = bytes(best_pix[2])

            current_hash = hashlib.md5(raw_bytes).hexdigest()
            # 若图标内容未变动，直接跳过计算
            if current_hash == self._last_pixmap_hash:
                return None

            self._last_pixmap_hash = current_hash
            
            # ARGB 转 RGBA 内存重排
            buf = bytearray(len(raw_bytes))
            buf[0::4] = raw_bytes[1::4]
            buf[1::4] = raw_bytes[2::4]
            buf[2::4] = raw_bytes[3::4]
            buf[3::4] = raw_bytes[0::4]

            qimg = QImage(bytes(buf), decoded_w, decoded_h, decoded_w * 4, QImage.Format.Format_RGBA8888)
            qbuf = QBuffer()
            qbuf.open(QIODevice.OpenModeFlag.WriteOnly)
            qimg.save(qbuf, "PNG")
            b64 = qbuf.data().toBase64().data().decode("ascii")
            return f"data:image/png;base64,{b64}"
        except Exception:
            return None