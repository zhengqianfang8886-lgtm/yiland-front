# ==========================================
# 📄 File: theme.py (中央动效物理引擎与统一定义)
# ==========================================
from PySide6.QtCore import QObject, Property, Signal
from PySide6.QtGui import QColor


class ThemeManager(QObject):
    fontChanged = Signal()
    motionChanged = Signal()

    def __init__(self, config=None):
        super().__init__()
        self._config = None
        if config:
            self.set_config(config)

    def set_config(self, config):
        self._config = config
        if self._config:
            self._config.fontFamilyChanged.connect(self.fontChanged)
            if hasattr(self._config, "animStyleChanged"):
                self._config.animStyleChanged.connect(self.motionChanged)

    # =========================================================================
    # 1. 字体排版系统 Token
    # =========================================================================
    @Property(str, notify=fontChanged)
    def activeFont(self):
        if self._config and self._config.fontFamily and "系统默认" not in self._config.fontFamily:
            return self._config.fontFamily
        return ""

    @Property(str, notify=fontChanged)
    def displayMonoFont(self):
        f = self.activeFont
        return f if f else "Monospace"

    @Property(str, constant=True)
    def defaultFontFamily(self): return ""

    @Property(str, constant=True)
    def defaultMonoFamily(self): return "Monospace"

    # =========================================================================
    # 2. 核心模块色彩 Tokens
    # =========================================================================
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

    # =========================================================================
    # 3. 材质表面 Tokens
    # =========================================================================
    @Property(QColor, constant=True)
    def bgCapsule(self): return QColor(13, 15, 22, int(0.89 * 255))

    @Property(QColor, constant=True)
    def bgCapsuleSecondary(self): return QColor(20, 24, 34, int(0.65 * 255))

    @Property(QColor, constant=True)
    def glassOuterBorder(self): return QColor(255, 255, 255, int(0.20 * 255))

    @Property(QColor, constant=True)
    def glassInnerRim(self): return QColor(255, 255, 255, int(0.12 * 255))

    @Property(QColor, constant=True)
    def bgCardItem(self): return QColor(255, 255, 255, int(0.045 * 255))

    @Property(QColor, constant=True)
    def bgCardHover(self): return QColor(255, 255, 255, int(0.085 * 255))

    @Property(QColor, constant=True)
    def borderSubtle(self): return QColor(255, 255, 255, int(0.10 * 255))

    @Property(QColor, constant=True)
    def borderFocus(self): return QColor(255, 255, 255, int(0.24 * 255))

    @Property(QColor, constant=True)
    def textPrimary(self): return QColor("#ffffff")

    @Property(QColor, constant=True)
    def textSecondary(self): return QColor(255, 255, 255, int(0.75 * 255))

    @Property(QColor, constant=True)
    def textMuted(self): return QColor(255, 255, 255, int(0.45 * 255))

    # =========================================================================
    # 4. 中央物理动效引擎核心 (Motion Engine)
    # =========================================================================
    @Property(bool, notify=motionChanged)
    def isJellyMode(self):
        if self._config and hasattr(self._config, "animStyle"):
            return self._config.animStyle == "jelly"
        return False

    @Property(int, notify=motionChanged)
    def animInstant(self): return 90 if not self.isJellyMode else 110

    @Property(int, notify=motionChanged)
    def animFast(self): return 140 if not self.isJellyMode else 170

    @Property(int, notify=motionChanged)
    def animNormal(self): return 200 if not self.isJellyMode else 240

    @Property(int, notify=motionChanged)
    def animSpring(self): return 220 if not self.isJellyMode else 280

    @Property(int, notify=motionChanged)
    def animSlow(self): return 280 if not self.isJellyMode else 340

    @Property(float, notify=motionChanged)
    def springOvershootSubtle(self): return 1.04 if not self.isJellyMode else 1.08

    @Property(float, notify=motionChanged)
    def springOvershootNormal(self): return 1.08 if not self.isJellyMode else 1.18

    @Property(float, notify=motionChanged)
    def springOvershootFirm(self): return 1.14 if not self.isJellyMode else 1.28

    @Property(int, notify=motionChanged)
    def curveDecel(self): return 6  # Easing.OutCubic

    @Property(int, notify=motionChanged)
    def curveFluid(self): return 2  # Easing.OutQuad

    @Property(int, notify=motionChanged)
    def curveSpring(self): return 9 if self.isJellyMode else 6

    # =========================================================================
    # 5. 几何规格
    # =========================================================================
    @Property(int, constant=True)
    def radiusCapsule(self): return 18

    @Property(int, constant=True)
    def radiusCard(self): return 16

    @Property(int, constant=True)
    def radiusItem(self): return 8


theme = ThemeManager()