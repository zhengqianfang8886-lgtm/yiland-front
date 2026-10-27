# ==========================================
# 📄 File: backend/bridge_mixins.py
# 🌟 Qt / QML 交互领域功能切片 (Mixins 架构版)
# ==========================================
from PySide6.QtCore import Property, Slot, QObject
from backend.utils import get_world_time, get_tz_offset_str


class ImeBridgeMixin:
    """输入法中枢领域切片"""
    @Property(bool, notify=lambda self: self.imeUpdated)
    def isImeActive(self):
        return self._backend.state.ime_active if self._backend else False

    @Property(str, notify=lambda self: self.imeUpdated)
    def imeLabel(self):
        return self._backend.state.ime_label if self._backend else "英"

    @Property(str, notify=lambda self: self.imeUpdated)
    def imeName(self):
        return self._backend.state.ime_name if self._backend else ""

    @Slot()
    def toggleIme(self):
        if self._backend and self._backend.ime:
            self.run_async(self._backend.ime.toggle())

    @Slot(str)
    def switchImeTo(self, im_name: str):
        if self._backend and self._backend.ime:
            self.run_async(self._backend.ime.switch_to_im(im_name))

    @Slot()
    def openImeConfig(self):
        if self._backend and self._backend.ime:
            self.run_async(self._backend.ime.open_config())


class HardwareBridgeMixin:
    """音频、背光、锁键与硬件监视领域切片"""
    @Property(int, notify=lambda self: self.volumeChanged)
    def currentVolume(self):
        return self._backend.state.volume if self._backend else 50

    @Property(int, notify=lambda self: self.brightnessChanged)
    def currentBrightness(self):
        return self._backend.state.brightness if self._backend else 100

    @Property(bool, notify=lambda self: self.capsLockChanged)
    def isCapsLock(self):
        return self._backend.state.is_caps_lock if self._backend else False

    @Property(bool, notify=lambda self: self.numLockChanged)
    def isNumLock(self):
        return self._backend.state.is_num_lock if self._backend else False

    @Property(int, notify=lambda self: self.batteryUpdated)
    def systemBattery(self):
        return self._backend.state.battery_pct if self._backend else 100

    @Property(bool, notify=lambda self: self.batteryUpdated)
    def isSystemCharging(self):
        return self._backend.state.battery_charging if self._backend else False

    @Slot(int, int)
    def adjustHardware(self, mode: int, delta: int):
        if not self._backend: return
        if mode == 0 and self._backend.audio:
            self.run_async(self._backend.audio.set_delta(delta))
        elif mode == 1 and self._backend.brightness:
            self.run_async(self._backend.brightness.set_delta(delta))

    @Slot(int, int)
    def setHardware(self, mode: int, target_val: int):
        if not self._backend: return
        if mode == 0 and self._backend.audio:
            self.run_async(self._backend.audio.set_volume(target_val))
        elif mode == 1 and self._backend.brightness:
            self.run_async(self._backend.brightness.set_brightness(target_val))

    @Slot(int)
    def toggleHardwareMute(self, mode: int):
        if not self._backend or not self._backend.audio: return
        if mode == 0:
            self.run_async(self._backend.audio.toggle_mute())
        elif mode == 2:
            self.run_async(self._backend.audio.toggle_mic_mute())

    @Slot(result="QVariantMap")
    def getSystemHealth(self):
        import shutil
        return {
            "platform": self.wm.platform.platform_name,
            "kwinWorking": bool(self.wm.platform.platform_name.startswith("KDE")),
            "audioWorking": bool(self._backend and self._backend.audio and self._backend.audio._running),
            "brightnessWorking": bool(self._backend and self._backend.brightness and self._backend.brightness.bus is not None),
            "cavaInstalled": bool(shutil.which("cava")),
            "wlPasteInstalled": bool(shutil.which("wl-paste")),
            "dbConnected": bool(self._backend and self._backend.habits)
        }


class TimerBridgeMixin:
    """专注计时器与番茄钟领域切片"""
    @Property(str, notify=lambda self: self.timerUpdated)
    def timerType(self): return self._backend.state.timer_type if self._backend else "countdown"

    @Property(bool, notify=lambda self: self.timerUpdated)
    def timerIsRunning(self): return self._backend.state.timer_is_running if self._backend else False

    @Property(bool, notify=lambda self: self.timerUpdated)
    def timerIsPaused(self): return self._backend.state.timer_is_paused if self._backend else False

    @Property(bool, notify=lambda self: self.timerUpdated)
    def timerIsCompleted(self): return self._backend.state.timer_is_completed if self._backend else False

    @Property(int, notify=lambda self: self.timerUpdated)
    def timerRemainingSec(self): return self._backend.state.timer_remaining_sec if self._backend else 1500

    @Property(int, notify=lambda self: self.timerUpdated)
    def timerTotalSec(self): return self._backend.state.timer_total_sec if self._backend else 1500

    @Property(int, notify=lambda self: self.timerUpdated)
    def timerElapsedSec(self): return self._backend.state.timer_elapsed_sec if self._backend else 0

    @Property(str, notify=lambda self: self.timerUpdated)
    def timerMode(self): return self._backend.state.timer_mode if self._backend else "focus"

    @Property(list, notify=lambda self: self.timerUpdated)
    def timerLaps(self): return self._backend.state.timer_laps if self._backend else []

    @Slot(str)
    def switchTimerType(self, t_type: str):
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.switch_type(t_type))

    @Slot()
    def toggleTimerPause(self):
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.toggle_pause())

    @Slot(int, str)
    def startTimerPreset(self, sec: int, mode: str):
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.start_preset(sec, mode))

    @Slot(int)
    def adjustTimerTime(self, delta_sec: int):
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.adjust_time(delta_sec))

    @Slot()
    def recordTimerLap(self):
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.record_lap())

    @Slot()
    def resetTimer(self):
        if self._backend and self._backend.timer:
            self.run_async(self._backend.timer.reset())


class HabitsBridgeMixin:
    """日历与习惯日程领域切片"""
    @Slot()
    def requestHabits(self):
        if not self._backend or not self._backend.habits:
            self.habitsLoaded.emit([]); return
        async def _run():
            data = await self._backend.habits.fetch_habits_async()
            self.habitsLoaded.emit(data)
        self.run_async(_run())

    @Slot(str, str)
    def requestAddHabit(self, name: str, icon: str = "📌"):
        if not self._backend or not self._backend.habits: return
        async def _run():
            data = await self._backend.habits.add_habit_async(name, icon)
            self.habitsLoaded.emit(data)
        self.run_async(_run())

    @Slot(str)
    def requestDeleteHabit(self, habit_id: str):
        if not self._backend or not self._backend.habits: return
        async def _run():
            data = await self._backend.habits.delete_habit_async(habit_id)
            self.habitsLoaded.emit(data)
        self.run_async(_run())

    @Slot(str, int, int)
    def requestMonthRecords(self, habit_id: str, year: int, month: int):
        if not self._backend or not self._backend.habits:
            self.monthRecordsLoaded.emit(habit_id, year, month, {}); return
        async def _run():
            data = await self._backend.habits.fetch_month_records_async(habit_id, year, month)
            self.monthRecordsLoaded.emit(habit_id, year, month, data)
        self.run_async(_run())

    @Slot(str, str)
    def requestToggleRecord(self, habit_id: str, date_str: str):
        if not self._backend or not self._backend.habits: return
        async def _run():
            is_checked = await self._backend.habits.toggle_record_async(habit_id, date_str)
            self.habitRecordToggled.emit(habit_id, date_str, is_checked)
        self.run_async(_run())

    @Slot(int, int, str)
    def requestCalendarGrid(self, year: int, month: int, habit_id: str):
        if not self._backend or not self._backend.habits:
            self.calendarGridLoaded.emit(year, month, []); return
        async def _run():
            grid = await self._backend.habits.generate_calendar_grid_async(year, month, habit_id)
            self.calendarGridLoaded.emit(year, month, grid)
        self.run_async(_run())


class WorkspaceMediaBridgeMixin:
    """工作区切换、平铺网格与 MPRIS 播控切片"""
    @Property(bool, notify=lambda self: self.gridActiveChanged)
    def isGridActive(self):
        return self._backend.state.is_desktop_grid_active if self._backend else False

    @Slot(int)
    @Slot(str)
    def switchWorkspace(self, target):
        if self._backend and self._backend.workspace:
            self.run_async(self._backend.workspace.switch_workspace(target))

    @Slot()
    def switchWorkspacePrev(self):
        if self._backend and self._backend.workspace:
            self.run_async(self._backend.workspace.switch_workspace("prev"))

    @Slot()
    def switchWorkspaceNext(self):
        if self._backend and self._backend.workspace:
            self.run_async(self._backend.workspace.switch_workspace("next"))

    @Slot()
    def toggleDesktopGrid(self):
        if self._backend and self._backend.workspace:
            self.run_async(self._backend.workspace.toggle_desktop_grid())

    @Slot(str)
    def sendMediaCmd(self, action: str):
        if not self._backend or not self._backend.mpris: return
        action_map = {"MEDIA_PLAY_PAUSE": "PlayPause", "MEDIA_NEXT": "Next", "MEDIA_PREV": "Previous"}
        cmd = action_map.get(action, action)
        self.run_async(self._backend.mpris.control(cmd))

    @Slot(str, str)
    def focusMediaWindow(self, title="", artist=""):
        if self._backend and self._backend.mpris:
            self.run_async(self._backend.mpris.raise_player())

    @Slot(str, bool, result=dict)
    def getWorldTime(self, tz_name, is_24h=True): return get_world_time(tz_name, is_24h)

    @Slot(str, result=str)
    def getTzOffsetStr(self, tz_name): return get_tz_offset_str(tz_name)