# ==========================================
# 📄 File: config.py
# 🌟 补齐 apps 副岛默认项 · 完整自愈加载
# ==========================================
import os
import json
from PySide6.QtCore import QObject, Signal, Property
from PySide6.QtGui import QFontDatabase
from logger import app_logger

CONFIG_FILE = os.path.expanduser("~/.config/alcove_island_config.json")

DEFAULT_SAVED_CLOCKS = [
    {"name": "伦敦", "en": "London", "country": "英国", "iso": "GB", "tz": "Europe/London"},
    {"name": "纽约", "en": "New York", "country": "美国", "iso": "US", "tz": "America/New_York"},
    {"name": "旧金山", "en": "San Francisco", "country": "美国", "iso": "US", "tz": "America/Los_Angeles"},
    {"name": "东京", "en": "Tokyo", "country": "日本", "iso": "JP", "tz": "Asia/Tokyo"}
]

DEFAULT_TAB_ORDER = [
    "time", "hardware", "workspace", "media", "calendar",
    "timer", "clock", "network", "bluetooth", "notification", "process"
]

CONFIG_SCHEMA = {
    # [1] 几何布局
    "topMargin": {"default": 0, "val": lambda v: int(v)},
    "offsetX": {"default": 0, "val": lambda v: int(v)},
    "anchorMode": {"default": "screen", "val": lambda v: str(v) if v in ("screen", "window") else "screen"},
    "capsuleTopMargin": {"default": 6, "val": lambda v: max(0, min(50, int(v)))},
    "expandedTopMargin": {"default": 16, "val": lambda v: max(0, min(100, int(v)))},

    # [2] 字体排版
    "fontFamily": {"default": "系统默认 (Default)", "val": lambda v: str(v)},

    # [3] 常态时钟与网络
    "timeFormat": {"default": "12h", "val": lambda v: str(v) if v in ("12h", "24h") else "12h"},
    "showSeconds": {"default": False, "val": lambda v: bool(v)},
    "showDate": {"default": False, "val": lambda v: bool(v)},
    "showNetSpeed": {"default": True, "val": lambda v: bool(v)},
    "savedClocks": {"default": DEFAULT_SAVED_CLOCKS, "val": lambda v: list(v) if isinstance(v, list) else DEFAULT_SAVED_CLOCKS},

    # [4] 灵动副岛与律动（🚀【关键点】：默认包含 apps）
    "splitGap": {"default": 8, "val": lambda v: max(2, min(24, int(v)))},
    "subIslandsLeft": {"default": ["lofi", "apps", "memory", "music"], "val": lambda v: list(v)},
    "subIslandsRight": {"default": ["hardware", "timer", "notification"], "val": lambda v: list(v)},
    "showAppsBubble": {"default": True, "val": lambda v: bool(v)},
    "multiIslandExpandDirection": {"default": "right", "val": lambda v: str(v)},
    "showHardwareBubble": {"default": True, "val": lambda v: bool(v)},
    "musicVisualizerBars": {"default": 5, "val": lambda v: max(5, min(10, int(v)))},
    "typingVisualizerEnabled": {"default": True, "val": lambda v: bool(v)},
    "typingBubbleMode": {"default": "keycaps", "val": lambda v: str(v) if v in ("bars", "keycaps") else "keycaps"},
    "tourbillonAnimationEnabled": {"default": True, "val": lambda v: bool(v)},

    # Lofi 动态副岛控制项
    "showLofiBubble": {"default": True, "val": lambda v: bool(v)},
    "lofiSceneIndex": {"default": 0, "val": lambda v: max(0, min(10, int(v)))},
    "lofiCustomPath": {"default": "", "val": lambda v: str(v)},

    # [5] 健康与系统监控
    "showMemoryBubble": {"default": True, "val": lambda v: bool(v)},
    "memoryThreshold": {"default": 75, "val": lambda v: max(0, min(95, int(v)))},
    "sedentaryReminderEnabled": {"default": True, "val": lambda v: bool(v)},
    "sedentaryIntervalMinutes": {"default": 45, "val": lambda v: max(5, min(180, int(v)))},
    "sedentarySnoozeMinutes": {"default": 5, "val": lambda v: max(1, min(30, int(v)))},
    "volumeStep": {"default": 5, "val": lambda v: max(1, min(20, int(v)))},
    "clipboardMonitorEnabled": {"default": True, "val": lambda v: bool(v)},

    # [6] 交互与动效
    "animStyle": {"default": "precision", "val": lambda v: str(v) if v in ("precision", "jelly") else "precision"},
    "hoverDwellTime": {"default": 240, "val": lambda v: max(50, min(2000, int(v)))},
    "hoverExpandEnabled": {"default": True, "val": lambda v: bool(v)},
    "autoHideDurationSeconds": {"default": 5, "val": lambda v: max(1, min(60, int(v)))},

    # [7] 展开卡片导航
    "tabOrder": {"default": DEFAULT_TAB_ORDER, "val": lambda v: list(v)},
    "showHardwareTab": {"default": True, "val": lambda v: bool(v)},
    "showWorkspaceTab": {"default": True, "val": lambda v: bool(v)},
    "showMediaTab": {"default": True, "val": lambda v: bool(v)},
    "showCalendarTab": {"default": True, "val": lambda v: bool(v)},
    "showTimerTab": {"default": True, "val": lambda v: bool(v)},
    "showClockTab": {"default": True, "val": lambda v: bool(v)},
    "showNetworkTab": {"default": True, "val": lambda v: bool(v)},
    "showBluetoothTab": {"default": True, "val": lambda v: bool(v)},
    "showNotificationTab": {"default": True, "val": lambda v: bool(v)},
    "showProcessTab": {"default": True, "val": lambda v: bool(v)},

    # [8] 消息通知与隐私防窥管理
    "dndEnabled": {"default": False, "val": lambda v: bool(v)},
    "dndAllowCalls": {"default": True, "val": lambda v: bool(v)},
    "notificationPrivacyMode": {"default": False, "val": lambda v: bool(v)},

    "showBattery": {"default": True, "val": lambda v: bool(v)},
}


class ConfigManager(QObject):
    topMarginChanged = Signal(int)
    offsetXChanged = Signal(int)
    anchorModeChanged = Signal(str)
    capsuleTopMarginChanged = Signal(int)
    expandedTopMarginChanged = Signal(int)
    fontFamilyChanged = Signal(str)
    timeFormatChanged = Signal(str)
    showSecondsChanged = Signal(bool)
    showDateChanged = Signal(bool)
    showNetSpeedChanged = Signal(bool)
    savedClocksChanged = Signal(list)
    splitGapChanged = Signal(int)
    subIslandsLeftChanged = Signal(list)
    subIslandsRightChanged = Signal(list)
    multiIslandExpandDirectionChanged = Signal(str)
    showHardwareBubbleChanged = Signal(bool)
    musicVisualizerBarsChanged = Signal(int)
    typingVisualizerEnabledChanged = Signal(bool)
    typingBubbleModeChanged = Signal(str)
    tourbillonAnimationEnabledChanged = Signal(bool)
    showLofiBubbleChanged = Signal(bool)
    lofiSceneIndexChanged = Signal(int)
    lofiCustomPathChanged = Signal(str)
    showMemoryBubbleChanged = Signal(bool)
    memoryThresholdChanged = Signal(int)
    sedentaryReminderEnabledChanged = Signal(bool)
    sedentaryIntervalMinutesChanged = Signal(int)
    sedentarySnoozeMinutesChanged = Signal(int)
    volumeStepChanged = Signal(int)
    clipboardMonitorEnabledChanged = Signal(bool)
    animStyleChanged = Signal(str)
    hoverDwellTimeChanged = Signal(int)
    hoverExpandEnabledChanged = Signal(bool)
    autoHideDurationSecondsChanged = Signal(int)
    tabOrderChanged = Signal(list)
    showHardwareTabChanged = Signal(bool)
    showWorkspaceTabChanged = Signal(bool)
    showMediaTabChanged = Signal(bool)
    showCalendarTabChanged = Signal(bool)
    showTimerTabChanged = Signal(bool)
    showClockTabChanged = Signal(bool)
    showNetworkTabChanged = Signal(bool)
    showBluetoothTabChanged = Signal(bool)
    showNotificationTabChanged = Signal(bool)
    showProcessTabChanged = Signal(bool)
    dndEnabledChanged = Signal(bool)
    dndAllowCallsChanged = Signal(bool)
    notificationPrivacyModeChanged = Signal(bool)
    showBatteryChanged = Signal(bool)

    def __init__(self):
        super().__init__()
        self._system_fonts = None
        self._world_cities = self._load_world_cities()

        for key, meta in CONFIG_SCHEMA.items():
            val = meta["default"]
            setattr(self, f"_{key}", list(val) if isinstance(val, list) else val)

        self.load()

    def _set_value(self, key: str, new_val, signal: Signal) -> bool:
        meta = CONFIG_SCHEMA.get(key)
        if meta and "val" in meta:
            new_val = meta["val"](new_val)

        old_val = getattr(self, f"_{key}")
        if old_val != new_val:
            setattr(self, f"_{key}", new_val)
            self.save()
            signal.emit(new_val)
            return True
        return False

    def load(self):
        if not os.path.exists(CONFIG_FILE) or os.path.getsize(CONFIG_FILE) == 0:
            return
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)

            for key, meta in CONFIG_SCHEMA.items():
                if key in data:
                    raw_val = data[key]
                    val = meta["val"](raw_val) if "val" in meta else raw_val
                    setattr(self, f"_{key}", val)

            # 🚀 自愈修复：确保 apps 与 lofi 均完整存在于副岛映射列表中
            if "apps" not in self._subIslandsLeft and "apps" not in self._subIslandsRight:
                self._subIslandsLeft.insert(1, "apps")

            if "lofi" not in self._subIslandsLeft and "lofi" not in self._subIslandsRight:
                self._subIslandsLeft.insert(0, "lofi")

            if "hardware" not in self._subIslandsRight and "hardware" not in self._subIslandsLeft:
                self._subIslandsRight.insert(0, "hardware")

            for item in DEFAULT_TAB_ORDER:
                if item not in self._tabOrder:
                    self._tabOrder.append(item)

            self._savedClocks = self._migrate_clock_items(self._savedClocks)

        except Exception as e:
            app_logger.warning(f"[Config] 配置文件解析异常，已启用自愈默认配置: {e}")

    def save(self):
        try:
            os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
            dump_data = {key: getattr(self, f"_{key}") for key in CONFIG_SCHEMA}

            tmp_file = CONFIG_FILE + ".tmp"
            with open(tmp_file, "w", encoding="utf-8") as f:
                json.dump(dump_data, f, indent=2, ensure_ascii=False)
            os.replace(tmp_file, CONFIG_FILE)
        except Exception as e:
            app_logger.warning(f"[Config] 保存配置失败: {e}")

    @Property(int, notify=topMarginChanged)
    def topMargin(self): return self._topMargin
    @topMargin.setter
    def topMargin(self, val): self._set_value("topMargin", val, self.topMarginChanged)

    @Property(int, notify=offsetXChanged)
    def offsetX(self): return self._offsetX
    @offsetX.setter
    def offsetX(self, val): self._set_value("offsetX", val, self.offsetXChanged)

    @Property(str, notify=anchorModeChanged)
    def anchorMode(self): return self._anchorMode
    @anchorMode.setter
    def anchorMode(self, val): self._set_value("anchorMode", val, self.anchorModeChanged)

    @Property(int, notify=capsuleTopMarginChanged)
    def capsuleTopMargin(self): return self._capsuleTopMargin
    @capsuleTopMargin.setter
    def capsuleTopMargin(self, val): self._set_value("capsuleTopMargin", val, self.capsuleTopMarginChanged)

    @Property(int, notify=expandedTopMarginChanged)
    def expandedTopMargin(self): return self._expandedTopMargin
    @expandedTopMargin.setter
    def expandedTopMargin(self, val): self._set_value("expandedTopMargin", val, self.expandedTopMarginChanged)

    @Property(str, notify=fontFamilyChanged)
    def fontFamily(self): return self._fontFamily
    @fontFamily.setter
    def fontFamily(self, val): self._set_value("fontFamily", val, self.fontFamilyChanged)

    @Property(str, notify=fontFamilyChanged)
    def activeFont(self):
        if not self._fontFamily or "系统默认" in self._fontFamily:
            return ""
        return self._fontFamily

    @Property(str, notify=fontFamilyChanged)
    def numberFont(self):
        if not self._fontFamily or "系统默认" in self._fontFamily:
            return "Monospace"
        return self._fontFamily

    @Property(list, constant=True)
    def systemFonts(self):
        if self._system_fonts is None:
            self._system_fonts = self._load_system_fonts()
        return self._system_fonts

    @Property(str, notify=timeFormatChanged)
    def timeFormat(self): return self._timeFormat
    @timeFormat.setter
    def timeFormat(self, val): self._set_value("timeFormat", val, self.timeFormatChanged)

    @Property(bool, notify=showSecondsChanged)
    def showSeconds(self): return self._showSeconds
    @showSeconds.setter
    def showSeconds(self, val): self._set_value("showSeconds", val, self.showSecondsChanged)

    @Property(bool, notify=showDateChanged)
    def showDate(self): return self._showDate
    @showDate.setter
    def showDate(self, val): self._set_value("showDate", val, self.showDateChanged)

    @Property(bool, notify=showNetSpeedChanged)
    def showNetSpeed(self): return self._showNetSpeed
    @showNetSpeed.setter
    def showNetSpeed(self, val): self._set_value("showNetSpeed", val, self.showNetSpeedChanged)

    @Property(list, notify=savedClocksChanged)
    def savedClocks(self): return self._savedClocks
    @savedClocks.setter
    def savedClocks(self, val): self._set_value("savedClocks", val, self.savedClocksChanged)

    @Property(list, constant=True)
    def worldCities(self): return self._world_cities

    @Property(int, notify=splitGapChanged)
    def splitGap(self): return self._splitGap
    @splitGap.setter
    def splitGap(self, val): self._set_value("splitGap", val, self.splitGapChanged)

    @Property(list, notify=subIslandsLeftChanged)
    def subIslandsLeft(self): return self._subIslandsLeft
    @subIslandsLeft.setter
    def subIslandsLeft(self, val): self._set_value("subIslandsLeft", val, self.subIslandsLeftChanged)

    @Property(list, notify=subIslandsRightChanged)
    def subIslandsRight(self): return self._subIslandsRight
    @subIslandsRight.setter
    def subIslandsRight(self, val): self._set_value("subIslandsRight", val, self.subIslandsRightChanged)

    @Property(str, notify=multiIslandExpandDirectionChanged)
    def multiIslandExpandDirection(self): return self._multiIslandExpandDirection
    @multiIslandExpandDirection.setter
    def multiIslandExpandDirection(self, val): self._set_value("multiIslandExpandDirection", val, self.multiIslandExpandDirectionChanged)

    @Property(bool, notify=showHardwareBubbleChanged)
    def showHardwareBubble(self): return self._showHardwareBubble
    @showHardwareBubble.setter
    def showHardwareBubble(self, val): self._set_value("showHardwareBubble", val, self.showHardwareBubbleChanged)

    @Property(int, notify=musicVisualizerBarsChanged)
    def musicVisualizerBars(self): return self._musicVisualizerBars
    @musicVisualizerBars.setter
    def musicVisualizerBars(self, val): self._set_value("musicVisualizerBars", val, self.musicVisualizerBarsChanged)

    @Property(bool, notify=typingVisualizerEnabledChanged)
    def typingVisualizerEnabled(self): return self._typingVisualizerEnabled
    @typingVisualizerEnabled.setter
    def typingVisualizerEnabled(self, val): self._set_value("typingVisualizerEnabled", val, self.typingVisualizerEnabledChanged)

    @Property(str, notify=typingBubbleModeChanged)
    def typingBubbleMode(self): return self._typingBubbleMode
    @typingBubbleMode.setter
    def typingBubbleMode(self, val): self._set_value("typingBubbleMode", val, self.typingBubbleModeChanged)

    @Property(bool, notify=tourbillonAnimationEnabledChanged)
    def tourbillonAnimationEnabled(self): return self._tourbillonAnimationEnabled
    @tourbillonAnimationEnabled.setter
    def tourbillonAnimationEnabled(self, val): self._set_value("tourbillonAnimationEnabled", val, self.tourbillonAnimationEnabledChanged)

    @Property(bool, notify=showLofiBubbleChanged)
    def showLofiBubble(self): return self._showLofiBubble
    @showLofiBubble.setter
    def showLofiBubble(self, val): self._set_value("showLofiBubble", val, self.showLofiBubbleChanged)

    @Property(int, notify=lofiSceneIndexChanged)
    def lofiSceneIndex(self): return self._lofiSceneIndex
    @lofiSceneIndex.setter
    def lofiSceneIndex(self, val): self._set_value("lofiSceneIndex", val, self.lofiSceneIndexChanged)

    @Property(str, notify=lofiCustomPathChanged)
    def lofiCustomPath(self): return self._lofiCustomPath
    @lofiCustomPath.setter
    def lofiCustomPath(self, val): self._set_value("lofiCustomPath", val, self.lofiCustomPathChanged)

    @Property(bool, notify=showMemoryBubbleChanged)
    def showMemoryBubble(self): return self._showMemoryBubble
    @showMemoryBubble.setter
    def showMemoryBubble(self, val): self._set_value("showMemoryBubble", val, self.showMemoryBubbleChanged)

    @Property(int, notify=memoryThresholdChanged)
    def memoryThreshold(self): return self._memoryThreshold
    @memoryThreshold.setter
    def memoryThreshold(self, val): self._set_value("memoryThreshold", val, self.memoryThresholdChanged)

    @Property(bool, notify=sedentaryReminderEnabledChanged)
    def sedentaryReminderEnabled(self): return self._sedentaryReminderEnabled
    @sedentaryReminderEnabled.setter
    def sedentaryReminderEnabled(self, val): self._set_value("sedentaryReminderEnabled", val, self.sedentaryReminderEnabledChanged)

    @Property(int, notify=sedentaryIntervalMinutesChanged)
    def sedentaryIntervalMinutes(self): return self._sedentaryIntervalMinutes
    @sedentaryIntervalMinutes.setter
    def sedentaryIntervalMinutes(self, val): self._set_value("sedentaryIntervalMinutes", val, self.sedentaryIntervalMinutesChanged)

    @Property(int, notify=sedentarySnoozeMinutesChanged)
    def sedentarySnoozeMinutes(self): return self._sedentarySnoozeMinutes
    @sedentarySnoozeMinutes.setter
    def sedentarySnoozeMinutes(self, val): self._set_value("sedentarySnoozeMinutes", val, self.sedentarySnoozeMinutesChanged)

    @Property(int, notify=volumeStepChanged)
    def volumeStep(self): return self._volumeStep
    @volumeStep.setter
    def volumeStep(self, val): self._set_value("volumeStep", val, self.volumeStepChanged)

    @Property(bool, notify=clipboardMonitorEnabledChanged)
    def clipboardMonitorEnabled(self): return self._clipboardMonitorEnabled
    @clipboardMonitorEnabled.setter
    def clipboardMonitorEnabled(self, val): self._set_value("clipboardMonitorEnabled", val, self.clipboardMonitorEnabledChanged)

    @Property(str, notify=animStyleChanged)
    def animStyle(self): return self._animStyle
    @animStyle.setter
    def animStyle(self, val): self._set_value("animStyle", val, self.animStyleChanged)

    @Property(int, notify=hoverDwellTimeChanged)
    def hoverDwellTime(self): return self._hoverDwellTime
    @hoverDwellTime.setter
    def hoverDwellTime(self, val): self._set_value("hoverDwellTime", val, self.hoverDwellTimeChanged)

    @Property(bool, notify=hoverExpandEnabledChanged)
    def hoverExpandEnabled(self): return self._hoverExpandEnabled
    @hoverExpandEnabled.setter
    def hoverExpandEnabled(self, val): self._set_value("hoverExpandEnabled", val, self.hoverExpandEnabledChanged)

    @Property(int, notify=autoHideDurationSecondsChanged)
    def autoHideDurationSeconds(self): return self._autoHideDurationSeconds
    @autoHideDurationSeconds.setter
    def autoHideDurationSeconds(self, val): self._set_value("autoHideDurationSeconds", val, self.autoHideDurationSecondsChanged)

    @Property(list, notify=tabOrderChanged)
    def tabOrder(self): return self._tabOrder
    @tabOrder.setter
    def tabOrder(self, val): self._set_value("tabOrder", val, self.tabOrderChanged)

    @Property(bool, notify=showHardwareTabChanged)
    def showHardwareTab(self): return self._showHardwareTab
    @showHardwareTab.setter
    def showHardwareTab(self, val): self._set_value("showHardwareTab", val, self.showHardwareTabChanged)

    @Property(bool, notify=showWorkspaceTabChanged)
    def showWorkspaceTab(self): return self._showWorkspaceTab
    @showWorkspaceTab.setter
    def showWorkspaceTab(self, val): self._set_value("showWorkspaceTab", val, self.showWorkspaceTabChanged)

    @Property(bool, notify=showMediaTabChanged)
    def showMediaTab(self): return self._showMediaTab
    @showMediaTab.setter
    def showMediaTab(self, val): self._set_value("showMediaTab", val, self.showMediaTabChanged)

    @Property(bool, notify=showCalendarTabChanged)
    def showCalendarTab(self): return self._showCalendarTab
    @showCalendarTab.setter
    def showCalendarTab(self, val): self._set_value("showCalendarTab", val, self.showCalendarTabChanged)

    @Property(bool, notify=showTimerTabChanged)
    def showTimerTab(self): return self._showTimerTab
    @showTimerTab.setter
    def showTimerTab(self, val): self._set_value("showTimerTab", val, self.showTimerTabChanged)

    @Property(bool, notify=showClockTabChanged)
    def showClockTab(self): return self._showClockTab
    @showClockTab.setter
    def showClockTab(self, val): self._set_value("showClockTab", val, self.showClockTabChanged)

    @Property(bool, notify=showNetworkTabChanged)
    def showNetworkTab(self): return self._showNetworkTab
    @showNetworkTab.setter
    def showNetworkTab(self, val): self._set_value("showNetworkTab", val, self.showNetworkTabChanged)

    @Property(bool, notify=showBluetoothTabChanged)
    def showBluetoothTab(self): return self._showBluetoothTab
    @showBluetoothTab.setter
    def showBluetoothTab(self, val): self._set_value("showBluetoothTab", val, self.showBluetoothTabChanged)

    @Property(bool, notify=showNotificationTabChanged)
    def showNotificationTab(self): return self._showNotificationTab
    @showNotificationTab.setter
    def showNotificationTab(self, val): self._set_value("showNotificationTab", val, self.showNotificationTabChanged)

    @Property(bool, notify=showProcessTabChanged)
    def showProcessTab(self): return self._showProcessTab
    @showProcessTab.setter
    def showProcessTab(self, val): self._set_value("showProcessTab", val, self.showProcessTabChanged)

    @Property(bool, notify=dndEnabledChanged)
    def dndEnabled(self): return self._dndEnabled
    @dndEnabled.setter
    def dndEnabled(self, val): self._set_value("dndEnabled", val, self.dndEnabledChanged)

    @Property(bool, notify=dndAllowCallsChanged)
    def dndAllowCalls(self): return self._dndAllowCalls
    @dndAllowCalls.setter
    def dndAllowCalls(self, val): self._set_value("dndAllowCalls", val, self.dndAllowCallsChanged)

    @Property(bool, notify=notificationPrivacyModeChanged)
    def notificationPrivacyMode(self): return self._notificationPrivacyMode
    @notificationPrivacyMode.setter
    def notificationPrivacyMode(self, val): self._set_value("notificationPrivacyMode", val, self.notificationPrivacyModeChanged)

    @Property(bool, notify=showBatteryChanged)
    def showBattery(self): return self._showBattery
    @showBattery.setter
    def showBattery(self, val): self._set_value("showBattery", val, self.showBatteryChanged)

    def _load_world_cities(self):
        try:
            base_dir = os.path.dirname(os.path.abspath(__file__))
            json_path = os.path.join(base_dir, "world_cities.json")
            if os.path.exists(json_path):
                with open(json_path, "r", encoding="utf-8") as f:
                    return json.load(f)
        except Exception:
            pass
        return []

    def _load_system_fonts(self):
        try:
            try:
                families = QFontDatabase.families()
            except TypeError:
                families = QFontDatabase.families(QFontDatabase.WritingSystem.Any)
            families = sorted(list(set(families)))
            return ["系统默认 (Default)"] + families
        except Exception:
            return ["系统默认 (Default)"]

    def _migrate_clock_items(self, clock_list):
        if not clock_list or not isinstance(clock_list, list):
            return list(DEFAULT_SAVED_CLOCKS)
        city_lookup = {c.get("name"): c for c in self._world_cities} if self._world_cities else {}
        migrated = []
        for item in clock_list:
            if not isinstance(item, dict):
                continue
            if not item.get("tz") and item.get("name") in city_lookup:
                item = dict(city_lookup[item["name"]])
            migrated.append(item)
        return migrated if migrated else list(DEFAULT_SAVED_CLOCKS)