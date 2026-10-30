# ==========================================
# 📄 File: backend/modules/recording/pixmap.py
# 🌟 原生录制托盘图标服务 (原生主题图标提取 + SNI 裸位图双引擎版)
# ==========================================
from typing import List
from PySide6.QtCore import Qt
from PySide6.QtGui import QImage, QPixmap, QIcon
from PySide6.QtQuick import QQuickImageProvider


class RecordingImageProvider(QQuickImageProvider):
    """
    提供 image://recording/current 零拷贝纹理服务
    优先使用系统原生 hicolor 主题图标，完美呈现官方 OBS 标志
    """

    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Pixmap)
        self._current_pixmap: QPixmap = QPixmap()
        self._last_raw_bytes: bytes = b""

    def requestPixmap(self, id: str, size, requestedSize) -> QPixmap:
        if self._current_pixmap.isNull():
            # 🚀【核心保证】：如果未拉取到 SNI，直接从系统当前桌面主题提取原生 OBS 官方图标
            for icon_name in ["com.obsproject.Studio", "obs", "obs-studio", "audio-input-microphone"]:
                icon = QIcon.fromTheme(icon_name)
                if not icon.isNull():
                    return icon.pixmap(32, 32)

            empty = QPixmap(1, 1)
            empty.fill(Qt.transparent)
            return empty

        return self._current_pixmap

    def set_system_theme_icon(self, icon_name: str) -> bool:
        icon = QIcon.fromTheme(icon_name)
        if not icon.isNull():
            self._current_pixmap = icon.pixmap(32, 32)
            return True
        return False

    def update_from_sni_pixmaps(self, pixmaps: List[any]) -> bool:
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

    def clear(self):
        self._current_pixmap = QPixmap()
        self._last_raw_bytes = b""