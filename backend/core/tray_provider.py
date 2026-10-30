# ==========================================
# 📄 File: backend/core/tray_provider.py
# 🌟 全局统一托盘显存纹理直通服务 (支持动态多服务·零拷贝版)
# ==========================================
from typing import Dict, Any, List
from PySide6.QtCore import Qt
from PySide6.QtGui import QImage, QPixmap
from PySide6.QtQuick import QQuickImageProvider


class UniversalTrayImageProvider(QQuickImageProvider):
    """
    统一管理系统所有托盘位图（IME、OBS、Telegram、Clash等）
    支持 URL:
      - 统一规范: image://tray/{service_id}?r={rev}
      - 兼容旧版: image://ime/current?rev={rev}
      - 兼容旧版: image://recording/current?r={rev}
    """

    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Pixmap)
        self._pixmap_cache: Dict[str, QPixmap] = {}
        self._last_raw_bytes: Dict[str, bytes] = {}

    def update_from_sni_pixmaps(self, service_id: str, pixmaps: List[Any]) -> bool:
        """公用 ARGB 二进制流 -> RGBA 显存纹理快速通道"""
        if not isinstance(pixmaps, list) or len(pixmaps) == 0:
            return False

        try:
            best_pix = max(pixmaps, key=lambda p: p[0] if isinstance(p, (list, tuple)) else 0)
            decoded_w = int(best_pix[0])
            decoded_h = int(best_pix[1])
            raw_bytes = bytes(best_pix[2])

            if self._last_raw_bytes.get(service_id) == raw_bytes:
                return False

            self._last_raw_bytes[service_id] = raw_bytes

            # ARGB -> RGBA 极速通道 (零第三方依赖)
            buf = bytearray(len(raw_bytes))
            buf[0::4] = raw_bytes[1::4]  # R
            buf[1::4] = raw_bytes[2::4]  # G
            buf[2::4] = raw_bytes[3::4]  # B
            buf[3::4] = raw_bytes[0::4]  # A

            qimg = QImage(bytes(buf), decoded_w, decoded_h, decoded_w * 4, QImage.Format.Format_RGBA8888)
            self._pixmap_cache[service_id] = QPixmap.fromImage(qimg)
            return True
        except Exception:
            return False

    def requestPixmap(self, id_str: str, size, requestedSize) -> QPixmap:
        """QML 渲染线程回调：O(1) 纯显存提取"""
        # 解析 service_id: "obs", "fcitx5", "current", 等
        clean_id = id_str.split("?")[0].strip("/")
        if clean_id.startswith("current"):
            # 兼容旧路径处理
            clean_id = clean_id.replace("current", "").strip("/") or "default"

        pix = self._pixmap_cache.get(clean_id)
        if pix and not pix.isNull():
            return pix

        empty = QPixmap(1, 1)
        empty.fill(Qt.transparent)
        return empty