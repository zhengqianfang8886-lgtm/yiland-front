# ==========================================
# 📄 File: backend/modules/ime/pixmap.py
# 🌟 原生 QQuickImageProvider 零拷贝输入法图标服务
# ==========================================
from typing import List, Optional
from PySide6.QtGui import QImage, QPixmap
from PySide6.QtQuick import QQuickImageProvider


class ImeImageProvider(QQuickImageProvider):
    """
    提供 image://ime/current URL 直通显卡纹理协议
    彻底消灭 PNG 编码、Base64 字符串传输和 QML 再次解码的 CPU 损耗
    """

    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Pixmap)
        self._current_pixmap: QPixmap = QPixmap()
        self._last_raw_bytes: bytes = b""

    def requestPixmap(self, id: str, size, requestedSize) -> QPixmap:
        if self._current_pixmap.isNull():
            empty = QPixmap(1, 1)
            empty.fill(Qt.transparent)
            return empty
        return self._current_pixmap

    def update_from_sni_pixmaps(self, pixmaps: List[any]) -> bool:
        """从 SNI 的 IconPixmap 二进制数组提取最优位图并生成 QPixmap"""
        if not isinstance(pixmaps, list) or len(pixmaps) == 0:
            return False

        try:
            best_pix = max(pixmaps, key=lambda p: p[0] if isinstance(p, (list, tuple)) else 0)
            decoded_w = int(best_pix[0])
            decoded_h = int(best_pix[1])
            raw_bytes = bytes(best_pix[2])

            if raw_bytes == self._last_raw_bytes:
                return False

            self._last_raw_bytes = raw_bytes

            # ARGB 转换 RGBA
            buf = bytearray(len(raw_bytes))
            buf[0::4] = raw_bytes[1::4]
            buf[1::4] = raw_bytes[2::4]
            buf[2::4] = raw_bytes[3::4]
            buf[3::4] = raw_bytes[0::4]

            qimg = QImage(bytes(buf), decoded_w, decoded_h, decoded_w * 4, QImage.Format.Format_RGBA8888)
            self._current_pixmap = QPixmap.fromImage(qimg)
            return True
        except Exception:
            return False