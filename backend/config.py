# ==========================================
# 📄 File: backend/config.py
# 🌟 生产级配置中心 (接入 CPU 告警调控)
# ==========================================
import os
import json
from PySide6.QtCore import QObject, Signal, Property, QTimer
from PySide6.QtGui import QFontDatabase
from backend.logger import app_logger

CONFIG_FILE = os.path.expanduser("~/.config/alcove_island_config.json")

DEFAULT_SAVED_CLOCKS = [
    {"name": "伦敦", "en": "London", "country": "英国", "iso": "GB", "tz": "Europe/London"},
    {"name": "纽约", "en": "New York", "country": "美国", "iso": "US", "tz": "America/New_York"},
    {"name": "旧金山", "en": "San Francisco", "country": "美国", "iso": "US", "tz": "America/Los_Angeles"},
    {"name": "东京", "en": "Tokyo", "country": "日本", "iso": "JP", "tz": "Asia/Tokyo"}
]

DEFAULT_TAB_ORDER = [
    "workspace", "media", "calendar",
    "timer", "clock", "notification"
]

CONFIG_SCHEMA = {
    "topMargin": {"default": 0, "val": lambda v: int(v)},
    "offsetX": {"default": 0, "val": lambda v: int(v)},
    "anchorMode": {"default": "screen", "val": lambda v: str(v) if v in ("screen", "window") else "screen"},
    "capsuleTopMargin": {"default": 6, "val": lambda v: max(0, min(50, int(v)))},
    "capsuleHeight": {"default": 36, "val": lambda v: 32 if int(v) <= 33 else (42 if int(v) >= 40 else 36)},
    "expandedTopMargin": {"default": 16, "val": lambda v: max(0, min(100, int(v)))},
    "fontFamily": {"default": "系统默认 (Default)", "val": lambda v: str(v)},
    "timeFormat": {"default": "12h", "val": lambda v: str(v) if v in ("12h", "24h") else "12h"},
    "showSeconds": {"default": False, "val": lambda v: bool(v)},
    "showDate": {"default": False, "val": lambda v: bool(v)},
    "showNetSpeed": {"default": True, "val": lambda v: bool(v)},
    "showWorkspaceName": {"default": True, "val": lambda v: bool(v)},
    "savedClocks": {"default": DEFAULT_SAVED_CLOCKS, "val": lambda v: list(v) if isinstance(v, list) else DEFAULT_SAVED_CLOCKS},
    "musicVisualizerBars": {"default": 5, "val": lambda v: max(3, min(8, int(v)))},
    
    # 🚀 替换为 CPU
    "showCpuBubble": {"default": True, "val": lambda v: bool(v)},
    "cpuThreshold": {"default": 75, "val": lambda v: max(0, min(95, int(v)))},
    
    "sedentaryReminderEnabled": {"default": True, "val": lambda v: bool(v)},
    "sedentaryIntervalMinutes": {"default": 45, "val": lambda v: max(5, min(180, int(v)))},
    "sedentarySnoozeMinutes": {"default": 5, "val": lambda v: max(1, min(30, int(v)))},
    "volumeStep": {"default": 5, "val": lambda v: max(1, min(20, int(v)))},
    "animStyle": {"default": "precision", "val": lambda v: str(v) if v in ("precision", "jelly") else "precision"},
    "hoverDwellTime": {"default": 240, "val": lambda v: max(50, min(2000, int(v)))},
    "hoverExpandEnabled": {"default": True, "val": lambda v: bool(v)},
    "stealthTuckEnabled": {"default": False, "val": lambda v: bool(v)},
    "autoHideDurationSeconds": {"default": 5, "val": lambda v: max(1, min(60, int(v)))},
    "tabOrder": {"default": DEFAULT_TAB_ORDER, "val": lambda v: list(v)},
    "showWorkspaceTab": {"default": True, "val": lambda v: bool(v)},
    "showMediaTab": {"default": True, "val": lambda v: bool(v)},
    "showCalendarTab": {"default": True, "val": lambda v: bool(v)},
    "showTimerTab": {"default": True, "val": lambda v: bool(v)},
    "showClockTab": {"default": True, "val": lambda v: bool(v)},
    "showNotificationTab": {"default": True, "val": lambda v: bool(v)},
    "dndEnabled": {"default": False, "val": lambda v: bool(v)},
    "dndAllowCalls": {"default": True, "val": lambda v: bool(v)},
}


class ConfigManager(QObject):
    topMarginChanged = Signal(int)
    offsetXChanged = Signal(int)
    anchorModeChanged = Signal(str)
    capsuleTopMarginChanged = Signal(int)
    capsuleHeightChanged = Signal(int)
    expandedTopMarginChanged = Signal(int)
    fontFamilyChanged = Signal(str)
    timeFormatChanged = Signal(str)
    showSecondsChanged = Signal(bool)
    showDateChanged = Signal(bool)
    showNetSpeedChanged = Signal(bool)
    showWorkspaceNameChanged = Signal(bool)
    savedClocksChanged = Signal(list)
    musicVisualizerBarsChanged = Signal(int)
    
    # 🚀 CPU 信号
    showCpuBubbleChanged = Signal(bool)
    cpuThresholdChanged = Signal(int)
    
    sedentaryReminderEnabledChanged = Signal(bool)
    sedentaryIntervalMinutesChanged = Signal(int)
    sedentarySnoozeMinutesChanged = Signal(int)
    volumeStepChanged = Signal(int)
    animStyleChanged = Signal(str)
    hoverDwellTimeChanged = Signal(int)
    hoverExpandEnabledChanged = Signal(bool)
    stealthTuckEnabledChanged = Signal(bool)
    autoHideDurationSecondsChanged = Signal(int)
    tabOrderChanged = Signal(list)
    showWorkspaceTabChanged = Signal(bool)
    showMediaTabChanged = Signal(bool)
    showCalendarTabChanged = Signal(bool)
    showTimerTabChanged = Signal(bool)
    showClockTabChanged = Signal(bool)
    showNotificationTabChanged = Signal(bool)
    dndEnabledChanged = Signal(bool)
    dndAllowCallsChanged = Signal(bool)

    def __init__(self):
        super().__init__()
        self._system_fonts = None
        self._world_cities = self._load_world_cities()

        for key, meta in CONFIG_SCHEMA.items():
            val = meta["default"]
            setattr(self, f"_{key}", list(val) if isinstance(val, list) else val)

        self._save_debounce_timer = QTimer(self)
        self._save_debounce_timer.setSingleShot(True)
        self._save_debounce_timer.setInterval(400)
        self._save_debounce_timer.timeout.connect(self._do_atomic_save)

        self.load()

    def _set_value(self, key: str, new_val, signal: Signal) -> bool:
        meta = CONFIG_SCHEMA.get(key)
        if meta and "val" in meta:
            new_val = meta["val"](new_val)

        old_val = getattr(self, f"_{key}")
        if old_val != new_val:
            setattr(self, f"_{key}", new_val)
            self._save_debounce_timer.start()
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

            self._tabOrder = [t for t in self._tabOrder if t in DEFAULT_TAB_ORDER]
            for item in DEFAULT_TAB_ORDER:
                if item not in self._tabOrder:
                    self._tabOrder.append(item)

            self._savedClocks = self._migrate_clock_items(self._savedClocks)
        except Exception as e:
            app_logger.warning(f"[Config] 配置文件解析异常: {e}")

    def save(self):
        self._save_debounce_timer.start()

    def _do_atomic_save(self):
        try:
            os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
            dump_data = {key: getattr(self, f"_{key}") for key in CONFIG_SCHEMA}
            tmp_file = CONFIG_FILE + ".tmp"
            with open(tmp_file, "w", encoding="utf-8") as f:
                json.dump(dump_data, f, indent=2, ensure_ascii=False)
            os.replace(tmp_file, CONFIG_FILE)
            app_logger.debug("[Config] 配置数据已安全原子落盘")
        except Exception as e:
            app_logger.error(f"[Config] 保存配置失败: {e}")

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

    @Property(int, notify=capsuleHeightChanged)
    def capsuleHeight(self): return self._capsuleHeight
    @capsuleHeight.setter
    def capsuleHeight(self, val): self._set_value("capsuleHeight", val, self.capsuleHeightChanged)

    @Property(int, notify=expandedTopMarginChanged)
    def expandedTopMargin(self): return self._expandedTopMargin
    @expandedTopMargin.setter
    def expandedTopMargin(self, val): self._set_value("expandedTopMargin", val, self.expandedTopMarginChanged)

    @Property(str, notify=fontFamilyChanged)
    def fontFamily(self): return self._fontFamily
    @fontFamily.setter
    def fontFamily(self, val): self._set_value("fontFamily", val, self.fontFamilyChanged)

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

    @Property(bool, notify=showWorkspaceNameChanged)
    def showWorkspaceName(self): return self._showWorkspaceName
    @showWorkspaceName.setter
    def showWorkspaceName(self, val): self._set_value("showWorkspaceName", val, self.showWorkspaceNameChanged)

    @Property(list, notify=savedClocksChanged)
    def savedClocks(self): return self._savedClocks
    @savedClocks.setter
    def savedClocks(self, val): self._set_value("savedClocks", val, self.savedClocksChanged)

    @Property(list, constant=True)
    def worldCities(self): return self._world_cities

    @Property("QStringList", constant=True)
    def systemFonts(self):
        if self._system_fonts is None:
            try:
                families = QFontDatabase.families()
                cleaned = ["系统默认 (Default)"]
                seen = set()
                for fam in families:
                    name = str(fam).strip()
                    if name and name not in seen and not name.startswith("."):
                        seen.add(name)
                        cleaned.append(name)
                self._system_fonts = cleaned
            except Exception as e:
                self._system_fonts = ["系统默认 (Default)"]
        return self._system_fonts

    @Property(int, notify=musicVisualizerBarsChanged)
    def musicVisualizerBars(self): return self._musicVisualizerBars
    @musicVisualizerBars.setter
    def musicVisualizerBars(self, val): self._set_value("musicVisualizerBars", val, self.musicVisualizerBarsChanged)

    # 🚀 CPU
    @Property(bool, notify=showCpuBubbleChanged)
    def showCpuBubble(self): return self._showCpuBubble
    @showCpuBubble.setter
    def showCpuBubble(self, val): self._set_value("showCpuBubble", val, self.showCpuBubbleChanged)

    @Property(int, notify=cpuThresholdChanged)
    def cpuThreshold(self): return self._cpuThreshold
    @cpuThreshold.setter
    def cpuThreshold(self, val): self._set_value("cpuThreshold", val, self.cpuThresholdChanged)

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

    @Property(bool, notify=stealthTuckEnabledChanged)
    def stealthTuckEnabled(self): return self._stealthTuckEnabled
    @stealthTuckEnabled.setter
    def stealthTuckEnabled(self, val): self._set_value("stealthTuckEnabled", val, self.stealthTuckEnabledChanged)

    @Property(int, notify=autoHideDurationSecondsChanged)
    def autoHideDurationSeconds(self): return self._autoHideDurationSeconds
    @autoHideDurationSeconds.setter
    def autoHideDurationSeconds(self, val): self._set_value("autoHideDurationSeconds", val, self.autoHideDurationSecondsChanged)

    @Property(list, notify=tabOrderChanged)
    def tabOrder(self): return self._tabOrder
    @tabOrder.setter
    def tabOrder(self, val): self._set_value("tabOrder", val, self.tabOrderChanged)

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

    @Property(bool, notify=showNotificationTabChanged)
    def showNotificationTab(self): return self._showNotificationTab
    @showNotificationTab.setter
    def showNotificationTab(self, val): self._set_value("showNotificationTab", val, self.showNotificationTabChanged)

    @Property(bool, notify=dndEnabledChanged)
    def dndEnabled(self): return self._dndEnabled
    @dndEnabled.setter
    def dndEnabled(self, val): self._set_value("dndEnabled", val, self.dndEnabledChanged)

    @Property(bool, notify=dndAllowCallsChanged)
    def dndAllowCalls(self): return self._dndAllowCalls
    @dndAllowCalls.setter
    def dndAllowCalls(self, val): self._set_value("dndAllowCalls", val, self.dndAllowCallsChanged)

    def _load_world_cities(self):
        try:
            base_dir = os.path.dirname(os.path.abspath(__file__))
            json_path = os.path.join(os.path.dirname(base_dir), "assets", "world_cities.json")
            if os.path.exists(json_path):
                with open(json_path, "r", encoding="utf-8") as f:
                    return json.load(f)
        except Exception:
            pass
        return []

    def _migrate_clock_items(self, clock_list):
        if not clock_list or not isinstance(clock_list, list): return list(DEFAULT_SAVED_CLOCKS)
        city_lookup = {c.get("name"): c for c in self._world_cities} if self._world_cities else {}
        migrated = []
        for item in clock_list:
            if not isinstance(item, dict): continue
            if not item.get("tz") and item.get("name") in city_lookup: item = dict(city_lookup[item["name"]])
            migrated.append(item)
        return migrated if migrated else list(DEFAULT_SAVED_CLOCKS)