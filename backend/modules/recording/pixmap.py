# ==========================================
# 📄 File: backend/modules/recording/pixmap.py
# 🌟 原生录制/OBS 托盘图标服务 (预检内存缓存 · 零渲染阻塞版)
# ==========================================
import os
import threading
from typing import List, Any
from PySide6.QtCore import Qt
from PySide6.QtGui import QImage, QPixmap, QIcon
from PySide6.QtQuick import QQuickImageProvider


class RecordingImageProvider(QQuickImageProvider):
    """
    提供 image://recording/current URL 直通显卡纹理协议
    关键设计：所有磁盘检查均在后台初始化完成，requestPixmap 仅进行 O(1) 内存提取
    """

    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Pixmap)
        self._current_pixmap: QPixmap = QPixmap()
        self._fallback_pixmap: QPixmap = QPixmap()
        self._last_raw_bytes: bytes = b""

        # 异步预加载备用图标，避免阻塞启动与渲染
        threading.Thread(target=self._precache_fallback_icon, daemon=True, name="ObsIconPrecache").start()

    def _precache_fallback_icon(self):
        """后台预先定位并解码备选 OBS 官方图标"""
        for icon_name in ["com.obsproject.Studio", "obs", "obs-studio"]:
            icon = QIcon.fromTheme(icon_name)
            if not icon.isNull():
                self._fallback_pixmap = icon.pixmap(32, 32)
                return

        known_paths = [
            os.path.expanduser("~/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps/com.obsproject.Studio.svg"),
            "/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/com.obsproject.Studio.svg",
            "/usr/share/icons/hicolor/scalable/apps/com.obsproject.Studio.svg",
            "/usr/share/pixmaps/obs.png",
            "/usr/share/icons/hicolor/256x256/apps/obs.png"
        ]
        for p in known_paths:
            if os.path.exists(p):
                pix = QPixmap(p)
                if not pix.isNull():
                    self._fallback_pixmap = pix.scaled(32, 32, Qt.KeepAspectRatio, Qt.SmoothTransformation)
                    return

    def requestPixmap(self, id: str, size, requestedSize) -> QPixmap:
        """运行于 Qt Quick 渲染线程：纯内存极速返回，严禁任何文件系统 I/O"""
        if not self._current_pixmap.isNull():
            return self._current_pixmap
        if not self._fallback_pixmap.isNull():
            return self._fallback_pixmap

        empty = QPixmap(1, 1)
        empty.fill(Qt.transparent)
        return empty

    def update_from_sni_pixmaps(self, pixmaps: List[Any]) -> bool:
        """从 DBus IconPixmap 二进制流直接构造 QPixmap (无 Base64/PNG 序列化)"""
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

            # ARGB -> RGBA 快速通道
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