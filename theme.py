# ==========================================
# 📄 File: theme.py
# ==========================================
from PySide6.QtCore import QObject, Property, Signal
from PySide6.QtGui import QColor


class ThemeManager(QObject):
    fontChanged = Signal()

    def __init__(self, config=None):
        super().__init__()
        self._config = None
        if config:
            self.set_config(config)

    def set_config(self, config):
        self._config = config
        if self._config:
            self._config.fontFamilyChanged.connect(self.fontChanged)

    # 🚀 全局普通文本动态字体：选特定字体立即生效，选默认时返回空让系统匹配
    @Property(str, notify=fontChanged)
    def activeFont(self):
        if self._config and self._config.fontFamily and "系统默认" not in self._config.fontFamily:
            return self._config.fontFamily
        return ""

    # 🚀 全局等宽/数字动态字体：指定字体后全盘跟从，未指定时安全回退 Monospace
    @Property(str, notify=fontChanged)
    def displayMonoFont(self):
        f = self.activeFont
        return f if f else "Monospace"

    @Property(str, constant=True)
    def defaultFontFamily(self): return ""

    @Property(str, constant=True)
    def defaultMonoFamily(self): return "Monospace"

    # 1. 核心模块色彩 Tokens
    @Property(QColor, constant=True)
    def workspace(self): return QColor("#a855f7")

    @Property(QColor, constant=True)
    def media(self): return QColor("#22c55e")

    @Property(QColor, constant=True)
    def calendar(self): return QColor("#38bdf8")

    @Property(QColor, constant=True)
    def timer(self): return QColor("#f97316")

    @Property(QColor, constant=True)
    def stopwatch(self): return QColor("#38bdf8")

    @Property(QColor, constant=True)
    def notification(self): return QColor("#818cf8")

    @Property(QColor, constant=True)
    def bluetooth(self): return QColor("#60a5fa")

    @Property(QColor, constant=True)
    def network(self): return QColor("#34d399")

    @Property(QColor, constant=True)
    def clock(self): return QColor("#f59e0b")

    @Property(QColor, constant=True)
    def danger(self): return QColor("#ef4444")

    # 2. 表面材质与半透明通道 (Surfaces)
    @Property(QColor, constant=True)
    def bgCapsule(self): return QColor(20, 20, 26, int(0.96 * 255))

    @Property(QColor, constant=True)
    def bgCardItem(self): return QColor(255, 255, 255, int(0.04 * 255))

    @Property(QColor, constant=True)
    def bgCardHover(self): return QColor(255, 255, 255, int(0.08 * 255))

    @Property(QColor, constant=True)
    def borderSubtle(self): return QColor(255, 255, 255, int(0.10 * 255))

    @Property(QColor, constant=True)
    def borderFocus(self): return QColor(255, 255, 255, int(0.24 * 255))

    # 3. 文本层级
    @Property(QColor, constant=True)
    def textPrimary(self): return QColor("#ffffff")

    @Property(QColor, constant=True)
    def textSecondary(self): return QColor(255, 255, 255, int(0.75 * 255))

    @Property(QColor, constant=True)
    def textMuted(self): return QColor(255, 255, 255, int(0.45 * 255))

    # 4. 统一动效物理常数
    @Property(int, constant=True)
    def animInstant(self): return 100

    @Property(int, constant=True)
    def animFast(self): return 140

    @Property(int, constant=True)
    def animNormal(self): return 200

    @Property(int, constant=True)
    def animSpring(self): return 220

    @Property(int, constant=True)
    def animSlow(self): return 280

    @Property(float, constant=True)
    def springOvershootSubtle(self): return 1.08

    @Property(float, constant=True)
    def springOvershoot(self): return 1.15

    @Property(float, constant=True)
    def springOvershootNormal(self): return 1.15

    @Property(float, constant=True)
    def springOvershootFirm(self): return 1.25

    # 5. 几何规格
    @Property(int, constant=True)
    def radiusCapsule(self): return 18

    @Property(int, constant=True)
    def radiusCard(self): return 16

    @Property(int, constant=True)
    def radiusItem(self): return 8


theme = ThemeManager()