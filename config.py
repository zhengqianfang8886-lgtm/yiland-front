# ==========================================
# 📄 File: config.py
# ==========================================
import os
import json
from PySide6.QtCore import QObject, Signal, Property
from PySide6.QtGui import QFontDatabase
from logger import app_logger

CONFIG_FILE = os.path.expanduser("~/.config/alcove_island_config.json")

DEFAULT_SAVED_CLOCKS = [
    { "name": "伦敦", "en": "London", "country": "英国", "iso": "GB", "tz": "Europe/London" },
    { "name": "纽约", "en": "New York", "country": "美国", "iso": "US", "tz": "America/New_York" },
    { "name": "旧金山", "en": "San Francisco", "country": "美国", "iso": "US", "tz": "America/Los_Angeles" },
    { "name": "东京", "en": "Tokyo", "country": "日本", "iso": "JP", "tz": "Asia/Tokyo" }
]

class ConfigManager(QObject):
    timeFormatChanged = Signal(str)
    showSecondsChanged = Signal(bool)
    showDateChanged = Signal(bool)
    topMarginChanged = Signal(int)
    offsetXChanged = Signal(int)
    anchorModeChanged = Signal(str)
    fontFamilyChanged = Signal(str)
    multiIslandExpandDirectionChanged = Signal(str)
    splitGapChanged = Signal(int)
    animStyleChanged = Signal(str)

    hoverDwellTimeChanged = Signal(int)
    hoverExpandEnabledChanged = Signal(bool)
    typingVisualizerEnabledChanged = Signal(bool)

    expandedTopMarginChanged = Signal(int)
    capsuleTopMarginChanged = Signal(int)

    showNetSpeedChanged = Signal(bool)
    clipboardMonitorEnabledChanged = Signal(bool)

    showHardwareBubbleChanged = Signal(bool)
    volumeStepChanged = Signal(int)
    autoHideDurationSecondsChanged = Signal(int)

    showMemoryBubbleChanged = Signal(bool)
    memoryThresholdChanged = Signal(int)
    sedentaryReminderEnabledChanged = Signal(bool)
    sedentaryIntervalMinutesChanged = Signal(int)
    sedentarySnoozeMinutesChanged = Signal(int)

    subIslandsLeftChanged = Signal(list)
    subIslandsRightChanged = Signal(list)

    showWorkspaceTabChanged = Signal(bool)
    showMediaTabChanged = Signal(bool)
    showCalendarTabChanged = Signal(bool)
    showTimerTabChanged = Signal(bool)
    showClockTabChanged = Signal(bool)
    showNetworkTabChanged = Signal(bool)
    showBluetoothTabChanged = Signal(bool)
    showNotificationTabChanged = Signal(bool)

    savedClocksChanged = Signal(list)

    def __init__(self):
        super().__init__()
        self._timeFormat = "12h"
        self._showSeconds = False
        self._showDate = False
        self._topMargin = 0
        self._offsetX = 0
        self._anchorMode = "screen"
        self._fontFamily = "系统默认 (Default)"
        self._multiIslandExpandDirection = "right"
        self._splitGap = 8
        self._animStyle = "precision"

        self._hoverDwellTime = 240
        self._hoverExpandEnabled = True
        self._typingVisualizerEnabled = True

        self._expandedTopMargin = 16
        self._capsuleTopMargin = 6

        self._showNetSpeed = True
        self._clipboardMonitorEnabled = True
        self._showHardwareBubble = True
        self._volumeStep = 5
        self._autoHideDurationSeconds = 5

        self._showMemoryBubble = True
        self._memoryThreshold = 75
        self._sedentaryReminderEnabled = True
        self._sedentaryIntervalMinutes = 45
        self._sedentarySnoozeMinutes = 5

        self._subIslandsLeft = ["memory", "music"]
        self._subIslandsRight = ["hardware", "timer", "notification"]

        self._showWorkspaceTab = True
        self._showMediaTab = True
        self._showCalendarTab = True
        self._showTimerTab = True
        self._showClockTab = True
        self._showNetworkTab = True
        self._showBluetoothTab = True
        self._showNotificationTab = True

        self._savedClocks = list(DEFAULT_SAVED_CLOCKS)

        self._system_fonts = None
        self._world_cities = self._load_world_cities()
        self.load()

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

    def load(self):
        if not os.path.exists(CONFIG_FILE) or os.path.getsize(CONFIG_FILE) == 0:
            return
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                self._timeFormat = data.get("timeFormat", "12h")
                self._showSeconds = data.get("showSeconds", False)
                self._showDate = data.get("showDate", False)
                self._topMargin = data.get("topMargin", 0)
                self._offsetX = data.get("offsetX", 0)
                self._anchorMode = data.get("anchorMode", "screen")
                self._fontFamily = data.get("fontFamily", "系统默认 (Default)")
                self._multiIslandExpandDirection = data.get("multiIslandExpandDirection", "right")
                self._splitGap = data.get("splitGap", 8)
                self._animStyle = data.get("animStyle", "precision")

                self._hoverDwellTime = data.get("hoverDwellTime", 240)
                self._hoverExpandEnabled = data.get("hoverExpandEnabled", True)
                self._typingVisualizerEnabled = data.get("typingVisualizerEnabled", True)

                self._expandedTopMargin = data.get("expandedTopMargin", 16)
                self._capsuleTopMargin = data.get("capsuleTopMargin", 6)

                self._showNetSpeed = data.get("showNetSpeed", True)
                self._clipboardMonitorEnabled = data.get("clipboardMonitorEnabled", True)
                self._showHardwareBubble = data.get("showHardwareBubble", True)
                self._volumeStep = data.get("volumeStep", 5)
                self._autoHideDurationSeconds = data.get("autoHideDurationSeconds", 5)

                self._showMemoryBubble = data.get("showMemoryBubble", True)
                self._memoryThreshold = data.get("memoryThreshold", 75)
                self._sedentaryReminderEnabled = data.get("sedentaryReminderEnabled", True)
                self._sedentaryIntervalMinutes = data.get("sedentaryIntervalMinutes", 45)
                self._sedentarySnoozeMinutes = data.get("sedentarySnoozeMinutes", 5)

                self._subIslandsLeft = data.get("subIslandsLeft", ["memory", "music"])
                self._subIslandsRight = data.get("subIslandsRight", ["hardware", "timer", "notification"])
                if "hardware" not in self._subIslandsRight and "hardware" not in self._subIslandsLeft:
                    self._subIslandsRight.insert(0, "hardware")

                self._showWorkspaceTab = data.get("showWorkspaceTab", True)
                self._showMediaTab = data.get("showMediaTab", True)
                self._showCalendarTab = data.get("showCalendarTab", True)
                self._showTimerTab = data.get("showTimerTab", True)
                self._showClockTab = data.get("showClockTab", True)
                self._showNetworkTab = data.get("showNetworkTab", True)
                self._showBluetoothTab = data.get("showBluetoothTab", True)
                self._showNotificationTab = data.get("showNotificationTab", True)

                self._savedClocks = self._migrate_clock_items(data.get("savedClocks", DEFAULT_SAVED_CLOCKS))
        except Exception as e:
            app_logger.warning(f"读取配置失败: {e}")

    def save(self):
        try:
            os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
            tmp_file = CONFIG_FILE + ".tmp"
            with open(tmp_file, "w", encoding="utf-8") as f:
                json.dump({
                    "timeFormat": self._timeFormat,
                    "showSeconds": self._showSeconds,
                    "showDate": self._showDate,
                    "topMargin": self._topMargin,
                    "offsetX": self._offsetX,
                    "anchorMode": self._anchorMode,
                    "fontFamily": self._fontFamily,
                    "multiIslandExpandDirection": self._multiIslandExpandDirection,
                    "splitGap": self._splitGap,
                    "animStyle": self._animStyle,
                    "hoverDwellTime": self._hoverDwellTime,
                    "hoverExpandEnabled": self._hoverExpandEnabled,
                    "typingVisualizerEnabled": self._typingVisualizerEnabled,

                    "expandedTopMargin": self._expandedTopMargin,
                    "capsuleTopMargin": self._capsuleTopMargin,
                    "showNetSpeed": self._showNetSpeed,
                    "clipboardMonitorEnabled": self._clipboardMonitorEnabled,
                    "showHardwareBubble": self._showHardwareBubble,
                    "volumeStep": self._volumeStep,
                    "autoHideDurationSeconds": self._autoHideDurationSeconds,

                    "showMemoryBubble": self._showMemoryBubble,
                    "memoryThreshold": self._memoryThreshold,
                    "sedentaryReminderEnabled": self._sedentaryReminderEnabled,
                    "sedentaryIntervalMinutes": self._sedentaryIntervalMinutes,
                    "sedentarySnoozeMinutes": self._sedentarySnoozeMinutes,

                    "subIslandsLeft": self._subIslandsLeft,
                    "subIslandsRight": self._subIslandsRight,

                    "showWorkspaceTab": self._showWorkspaceTab,
                    "showMediaTab": self._showMediaTab,
                    "showCalendarTab": self._showCalendarTab,
                    "showTimerTab": self._showTimerTab,
                    "showClockTab": self._showClockTab,
                    "showNetworkTab": self._showNetworkTab,
                    "showBluetoothTab": self._showBluetoothTab,
                    "showNotificationTab": self._showNotificationTab,

                    "savedClocks": self._savedClocks
                }, f, indent=2, ensure_ascii=False)
            os.replace(tmp_file, CONFIG_FILE)
        except Exception as e:
            app_logger.warning(f"保存配置失败: {e}")

    # 🚀 悬停展开灵动岛开关
    @Property(bool, notify=hoverExpandEnabledChanged)
    def hoverExpandEnabled(self): return self._hoverExpandEnabled
    @hoverExpandEnabled.setter
    def hoverExpandEnabled(self, val):
        if self._hoverExpandEnabled != val:
            self._hoverExpandEnabled = bool(val); self.save(); self.hoverExpandEnabledChanged.emit(self._hoverExpandEnabled)

    # 🚀 打字心流岛功能开关
    @Property(bool, notify=typingVisualizerEnabledChanged)
    def typingVisualizerEnabled(self): return self._typingVisualizerEnabled
    @typingVisualizerEnabled.setter
    def typingVisualizerEnabled(self, val):
        if self._typingVisualizerEnabled != val:
            self._typingVisualizerEnabled = bool(val); self.save(); self.typingVisualizerEnabledChanged.emit(self._typingVisualizerEnabled)

    @Property(int, notify=autoHideDurationSecondsChanged)
    def autoHideDurationSeconds(self): return self._autoHideDurationSeconds
    @autoHideDurationSeconds.setter
    def autoHideDurationSeconds(self, val):
        val = max(1, min(60, int(val)))
        if self._autoHideDurationSeconds != val:
            self._autoHideDurationSeconds = val; self.save(); self.autoHideDurationSecondsChanged.emit(self._autoHideDurationSeconds)

    @Property(int, notify=volumeStepChanged)
    def volumeStep(self): return self._volumeStep
    @volumeStep.setter
    def volumeStep(self, val):
        val = max(1, min(20, int(val)))
        if self._volumeStep != val:
            self._volumeStep = val; self.save(); self.volumeStepChanged.emit(self._volumeStep)

    @Property(bool, notify=showHardwareBubbleChanged)
    def showHardwareBubble(self): return self._showHardwareBubble
    @showHardwareBubble.setter
    def showHardwareBubble(self, val):
        if self._showHardwareBubble != val:
            self._showHardwareBubble = bool(val); self.save(); self.showHardwareBubbleChanged.emit(self._showHardwareBubble)

    @Property(bool, notify=clipboardMonitorEnabledChanged)
    def clipboardMonitorEnabled(self): return self._clipboardMonitorEnabled
    @clipboardMonitorEnabled.setter
    def clipboardMonitorEnabled(self, val):
        if self._clipboardMonitorEnabled != val:
            self._clipboardMonitorEnabled = bool(val); self.save(); self.clipboardMonitorEnabledChanged.emit(self._clipboardMonitorEnabled)

    @Property(int, notify=memoryThresholdChanged)
    def memoryThreshold(self): return self._memoryThreshold
    @memoryThreshold.setter
    def memoryThreshold(self, val):
        val = max(0, min(95, int(val)))
        if self._memoryThreshold != val:
            self._memoryThreshold = val; self.save(); self.memoryThresholdChanged.emit(val)

    @Property(list, notify=subIslandsLeftChanged)
    def subIslandsLeft(self): return self._subIslandsLeft
    @subIslandsLeft.setter
    def subIslandsLeft(self, val):
        if self._subIslandsLeft != val:
            self._subIslandsLeft = list(val); self.save(); self.subIslandsLeftChanged.emit(self._subIslandsLeft)

    @Property(list, notify=subIslandsRightChanged)
    def subIslandsRight(self): return self._subIslandsRight
    @subIslandsRight.setter
    def subIslandsRight(self, val):
        if self._subIslandsRight != val:
            self._subIslandsRight = list(val); self.save(); self.subIslandsRightChanged.emit(self._subIslandsRight)

    @Property(bool, notify=showMemoryBubbleChanged)
    def showMemoryBubble(self): return self._showMemoryBubble
    @showMemoryBubble.setter
    def showMemoryBubble(self, val):
        if self._showMemoryBubble != val:
            self._showMemoryBubble = val; self.save(); self.showMemoryBubbleChanged.emit(val)

    @Property(bool, notify=sedentaryReminderEnabledChanged)
    def sedentaryReminderEnabled(self): return self._sedentaryReminderEnabled
    @sedentaryReminderEnabled.setter
    def sedentaryReminderEnabled(self, val):
        if self._sedentaryReminderEnabled != val:
            self._sedentaryReminderEnabled = val; self.save(); self.sedentaryReminderEnabledChanged.emit(val)

    @Property(int, notify=sedentaryIntervalMinutesChanged)
    def sedentaryIntervalMinutes(self): return self._sedentaryIntervalMinutes
    @sedentaryIntervalMinutes.setter
    def sedentaryIntervalMinutes(self, val):
        val = max(5, min(180, int(val)))
        if self._sedentaryIntervalMinutes != val:
            self._sedentaryIntervalMinutes = val; self.save(); self.sedentaryIntervalMinutesChanged.emit(val)

    @Property(int, notify=sedentarySnoozeMinutesChanged)
    def sedentarySnoozeMinutes(self): return self._sedentarySnoozeMinutes
    @sedentarySnoozeMinutes.setter
    def sedentarySnoozeMinutes(self, val):
        val = max(1, min(30, int(val)))
        if self._sedentarySnoozeMinutes != val:
            self._sedentarySnoozeMinutes = val; self.save(); self.sedentarySnoozeMinutesChanged.emit(val)

    @Property(int, notify=hoverDwellTimeChanged)
    def hoverDwellTime(self): return self._hoverDwellTime
    @hoverDwellTime.setter
    def hoverDwellTime(self, val):
        val = max(50, min(2000, int(val)))
        if self._hoverDwellTime != val:
            self._hoverDwellTime = val; self.save(); self.hoverDwellTimeChanged.emit(val)

    @Property(int, notify=expandedTopMarginChanged)
    def expandedTopMargin(self): return self._expandedTopMargin
    @expandedTopMargin.setter
    def expandedTopMargin(self, val):
        val = max(0, min(100, int(val)))
        if self._expandedTopMargin != val:
            self._expandedTopMargin = val; self.save(); self.expandedTopMarginChanged.emit(val)

    @Property(int, notify=capsuleTopMarginChanged)
    def capsuleTopMargin(self): return self._capsuleTopMargin
    @capsuleTopMargin.setter
    def capsuleTopMargin(self, val):
        val = max(0, min(50, int(val)))
        if self._capsuleTopMargin != val:
            self._capsuleTopMargin = val; self.save(); self.capsuleTopMarginChanged.emit(val)

    @Property(str, notify=animStyleChanged)
    def animStyle(self): return self._animStyle
    @animStyle.setter
    def animStyle(self, val):
        if val in ("precision", "jelly") and self._animStyle != val:
            self._animStyle = val; self.save(); self.animStyleChanged.emit(val)

    @Property(str, notify=timeFormatChanged)
    def timeFormat(self): return self._timeFormat
    @timeFormat.setter
    def timeFormat(self, val):
        if self._timeFormat != val:
            self._timeFormat = val; self.save(); self.timeFormatChanged.emit(val)

    @Property(bool, notify=showSecondsChanged)
    def showSeconds(self): return self._showSeconds
    @showSeconds.setter
    def showSeconds(self, val):
        if self._showSeconds != val:
            self._showSeconds = val; self.save(); self.showSecondsChanged.emit(val)

    @Property(bool, notify=showDateChanged)
    def showDate(self): return self._showDate
    @showDate.setter
    def showDate(self, val):
        if self._showDate != val:
            self._showDate = val; self.save(); self.showDateChanged.emit(val)

    @Property(bool, notify=showNetSpeedChanged)
    def showNetSpeed(self): return self._showNetSpeed
    @showNetSpeed.setter
    def showNetSpeed(self, val):
        if self._showNetSpeed != val:
            self._showNetSpeed = val; self.save(); self.showNetSpeedChanged.emit(val)

    @Property(bool, notify=showWorkspaceTabChanged)
    def showWorkspaceTab(self): return self._showWorkspaceTab
    @showWorkspaceTab.setter
    def showWorkspaceTab(self, val):
        if self._showWorkspaceTab != val:
            self._showWorkspaceTab = val; self.save(); self.showWorkspaceTabChanged.emit(val)

    @Property(bool, notify=showMediaTabChanged)
    def showMediaTab(self): return self._showMediaTab
    @showMediaTab.setter
    def showMediaTab(self, val):
        if self._showMediaTab != val:
            self._showMediaTab = val; self.save(); self.showMediaTabChanged.emit(val)

    @Property(bool, notify=showCalendarTabChanged)
    def showCalendarTab(self): return self._showCalendarTab
    @showCalendarTab.setter
    def showCalendarTab(self, val):
        if self._showCalendarTab != val:
            self._showCalendarTab = val; self.save(); self.showCalendarTabChanged.emit(val)

    @Property(bool, notify=showTimerTabChanged)
    def showTimerTab(self): return self._showTimerTab
    @showTimerTab.setter
    def showTimerTab(self, val):
        if self._showTimerTab != val:
            self._showTimerTab = val; self.save(); self.showTimerTabChanged.emit(val)

    @Property(bool, notify=showClockTabChanged)
    def showClockTab(self): return self._showClockTab
    @showClockTab.setter
    def showClockTab(self, val):
        if self._showClockTab != val:
            self._showClockTab = val; self.save(); self.showClockTabChanged.emit(val)

    @Property(bool, notify=showNetworkTabChanged)
    def showNetworkTab(self): return self._showNetworkTab
    @showNetworkTab.setter
    def showNetworkTab(self, val):
        if self._showNetworkTab != val:
            self._showNetworkTab = val; self.save(); self.showNetworkTabChanged.emit(val)

    @Property(bool, notify=showBluetoothTabChanged)
    def showBluetoothTab(self): return self._showBluetoothTab
    @showBluetoothTab.setter
    def showBluetoothTab(self, val):
        if self._showBluetoothTab != val:
            self._showBluetoothTab = val; self.save(); self.showBluetoothTabChanged.emit(val)

    @Property(bool, notify=showNotificationTabChanged)
    def showNotificationTab(self): return self._showNotificationTab
    @showNotificationTab.setter
    def showNotificationTab(self, val):
        if self._showNotificationTab != val:
            self._showNotificationTab = val; self.save(); self.showNotificationTabChanged.emit(val)

    @Property(int, notify=splitGapChanged)
    def splitGap(self): return self._splitGap
    @splitGap.setter
    def splitGap(self, val):
        val = max(2, min(24, int(val)))
        if self._splitGap != val:
            self._splitGap = val; self.save(); self.splitGapChanged.emit(val)

    @Property(int, notify=topMarginChanged)
    def topMargin(self): return self._topMargin
    @topMargin.setter
    def topMargin(self, val):
        val = int(val)
        if self._topMargin != val:
            self._topMargin = val; self.save(); self.topMarginChanged.emit(val)

    @Property(int, notify=offsetXChanged)
    def offsetX(self): return self._offsetX
    @offsetX.setter
    def offsetX(self, val):
        val = int(val)
        if self._offsetX != val:
            self._offsetX = val; self.save(); self.offsetXChanged.emit(val)

    @Property(str, notify=anchorModeChanged)
    def anchorMode(self): return self._anchorMode
    @anchorMode.setter
    def anchorMode(self, val):
        if self._anchorMode != val:
            self._anchorMode = val; self.save(); self.anchorModeChanged.emit(val)

    @Property(str, notify=multiIslandExpandDirectionChanged)
    def multiIslandExpandDirection(self): return self._multiIslandExpandDirection
    @multiIslandExpandDirection.setter
    def multiIslandExpandDirection(self, val):
        if self._multiIslandExpandDirection != val:
            self._multiIslandExpandDirection = val; self.save(); self.multiIslandExpandDirectionChanged.emit(val)

    @Property(list, notify=savedClocksChanged)
    def savedClocks(self): return self._savedClocks
    @savedClocks.setter
    def savedClocks(self, val):
        if self._savedClocks != val:
            self._savedClocks = list(val); self.save(); self.savedClocksChanged.emit(self._savedClocks)

    @Property(list, constant=True)
    def systemFonts(self):
        if self._system_fonts is None:
            self._system_fonts = self._load_system_fonts()
        return self._system_fonts

    @Property(list, constant=True)
    def worldCities(self): return self._world_cities

    @Property(str, notify=fontFamilyChanged)
    def fontFamily(self): return self._fontFamily
    @fontFamily.setter
    def fontFamily(self, val):
        if self._fontFamily != val:
            self._fontFamily = val; self.save(); self.fontFamilyChanged.emit(val)