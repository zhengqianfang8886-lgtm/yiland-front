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
    expandedTopMarginChanged = Signal(int)
    capsuleTopMarginChanged = Signal(int)

    showNetSpeedChanged = Signal(bool)
    showMediaTabChanged = Signal(bool)
    showCalendarTabChanged = Signal(bool)
    showWorkspaceTabChanged = Signal(bool)
    showNetworkTabChanged = Signal(bool)
    showClockTabChanged = Signal(bool)
    showBluetoothTabChanged = Signal(bool)
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
        
        # 🚀 默认悬停触发时间 240ms，大卡片距顶 16px，胶囊距顶 6px
        self._hoverDwellTime = 240
        self._expandedTopMargin = 16
        self._capsuleTopMargin = 6

        self._showNetSpeed = True
        self._showMediaTab = True
        self._showCalendarTab = True
        self._showWorkspaceTab = True
        self._showNetworkTab = True
        self._showClockTab = True
        self._showBluetoothTab = True
        self._savedClocks = list(DEFAULT_SAVED_CLOCKS)

        self._system_fonts = None
        self._world_cities = self._load_world_cities()
        self.load()

    def _load_world_cities(self):
        try:
            base_dir = os.path.dirname(os.path.abspath(__file__))
            json_path = os.path.join(base_dir, "world_cities.json")
            if os.path.exists(json_path):
                with open(json_path, "r", encoding="utf-8") as f:
                    return json.load(f)
        except Exception as e:
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
        except Exception as e:
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
        if not os.path.exists(CONFIG_FILE):
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
                self._expandedTopMargin = data.get("expandedTopMargin", 16)
                self._capsuleTopMargin = data.get("capsuleTopMargin", 6)

                self._showNetSpeed = data.get("showNetSpeed", True)
                self._showMediaTab = data.get("showMediaTab", True)
                self._showCalendarTab = data.get("showCalendarTab", True)
                self._showWorkspaceTab = data.get("showWorkspaceTab", True)
                self._showNetworkTab = data.get("showNetworkTab", True)
                self._showClockTab = data.get("showClockTab", True)
                self._showBluetoothTab = data.get("showBluetoothTab", True)
                self._savedClocks = self._migrate_clock_items(data.get("savedClocks", DEFAULT_SAVED_CLOCKS))
        except Exception as e:
            pass

    def save(self):
        try:
            os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump({
                    "timeFormat": self._timeFormat, "showSeconds": self._showSeconds, "showDate": self._showDate,
                    "topMargin": self._topMargin, "offsetX": self._offsetX, "anchorMode": self._anchorMode,
                    "fontFamily": self._fontFamily, "multiIslandExpandDirection": self._multiIslandExpandDirection,
                    "splitGap": self._splitGap, "animStyle": self._animStyle,
                    "hoverDwellTime": self._hoverDwellTime,
                    "expandedTopMargin": self._expandedTopMargin,
                    "capsuleTopMargin": self._capsuleTopMargin,
                    "showNetSpeed": self._showNetSpeed,
                    "showMediaTab": self._showMediaTab, "showCalendarTab": self._showCalendarTab,
                    "showWorkspaceTab": self._showWorkspaceTab, "showNetworkTab": self._showNetworkTab,
                    "showClockTab": self._showClockTab, "showBluetoothTab": self._showBluetoothTab,
                    "savedClocks": self._savedClocks
                }, f, indent=2, ensure_ascii=False)
        except Exception as e:
            pass

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

    @Property(bool, notify=showWorkspaceTabChanged)
    def showWorkspaceTab(self): return self._showWorkspaceTab
    @showWorkspaceTab.setter
    def showWorkspaceTab(self, val):
        if self._showWorkspaceTab != val:
            self._showWorkspaceTab = val; self.save(); self.showWorkspaceTabChanged.emit(val)

    @Property(bool, notify=showNetworkTabChanged)
    def showNetworkTab(self): return self._showNetworkTab
    @showNetworkTab.setter
    def showNetworkTab(self, val):
        if self._showNetworkTab != val:
            self._showNetworkTab = val; self.save(); self.showNetworkTabChanged.emit(val)

    @Property(bool, notify=showClockTabChanged)
    def showClockTab(self): return self._showClockTab
    @showClockTab.setter
    def showClockTab(self, val):
        if self._showClockTab != val:
            self._showClockTab = val; self.save(); self.showClockTabChanged.emit(val)

    @Property(bool, notify=showBluetoothTabChanged)
    def showBluetoothTab(self): return self._showBluetoothTab
    @showBluetoothTab.setter
    def showBluetoothTab(self, val):
        if self._showBluetoothTab != val:
            self._showBluetoothTab = val; self.save(); self.showBluetoothTabChanged.emit(val)

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
            self._multiIslandExpandDirection = val
            self.save()
            self.multiIslandExpandDirectionChanged.emit(val)

    @Property(list, notify=savedClocksChanged)
    def savedClocks(self): return self._savedClocks
    @savedClocks.setter
    def savedClocks(self, val):
        if self._savedClocks != val:
            self._savedClocks = list(val)
            self.save()
            self.savedClocksChanged.emit(self._savedClocks)

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