// ==========================================
// 📄 File: ui/components/pages/CalendarPage.qml
// 🌟 纯数据模型驱动日历日程页 (严格当月统计 · 消除超额溢出版)
// ==========================================
import QtQuick
import "../calendar"

Rectangle {
    id: calRoot
    anchors.fill: parent
    color: "#14141a"
    radius: (typeof Theme !== "undefined") ? Theme.radiusCard : 16

    property string chosenFont: ""
    readonly property string effectiveFont: (chosenFont !== "") ? chosenFont : ((typeof Theme !== "undefined") ? Theme.activeFont : "")
    readonly property string effectiveMonoFont: (typeof Theme !== "undefined") ? Theme.displayMonoFont : "Monospace"

    readonly property var todayDate: new Date()
    property int calYear: todayDate.getFullYear()
    property int calMonth: todayDate.getMonth()
    property int selYear: todayDate.getFullYear()
    property int selMonth: todayDate.getMonth()
    property int selDay: todayDate.getDate()

    readonly property bool isAlreadyToday: (selYear === todayDate.getFullYear() &&
                                           selMonth === todayDate.getMonth() &&
                                           selDay === todayDate.getDate() &&
                                           calYear === todayDate.getFullYear() &&
                                           calMonth === todayDate.getMonth())

    property var habitsList: []
    property int currentHabitIndex: 0
    property bool isManagingHabits: false
    readonly property var currentHabit: (habitsList && habitsList.length > 0 && currentHabitIndex < habitsList.length) ? habitsList[currentHabitIndex] : null
    
    property var calGridModel: []
    property var checkRecords: ({})

    function formatDateStr(y, m, d) {
        var mStr = (m + 1 < 10 ? "0" : "") + (m + 1);
        var dStr = (d < 10 ? "0" : "") + d;
        return y + "-" + mStr + "-" + dStr;
    }

    readonly property string selectedDateStr: formatDateStr(selYear, selMonth, selDay)
    readonly property bool isSelectedDayDone: checkRecords[selectedDateStr] === true

    readonly property string selWeekdayStr: {
        var days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
        return days[new Date(selYear, selMonth, selDay).getDay()];
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null

        function onHabitsLoaded(data) {
            calRoot.habitsList = data || [];
            if (calRoot.currentHabitIndex >= calRoot.habitsList.length) {
                calRoot.currentHabitIndex = Math.max(0, calRoot.habitsList.length - 1);
            }
            calRoot.requestGridFromBackend();
        }

        function onCalendarGridLoaded(y, m, grid) {
            if (calRoot.calYear === y && calRoot.calMonth === m) {
                calRoot.calGridModel = grid || [];
                var rec = {};
                for (var i = 0; i < calRoot.calGridModel.length; i++) {
                    var cell = calRoot.calGridModel[i];
                    if (cell.isChecked) {
                        rec[cell.dateStr] = true;
                    }
                }
                calRoot.checkRecords = rec;
            }
        }

        function onHabitRecordToggled(habitId, dateStr, isChecked) {
            if (calRoot.currentHabit && calRoot.currentHabit.id === habitId) {
                var copy = Object.assign({}, calRoot.checkRecords);
                if (isChecked) {
                    copy[dateStr] = true;
                } else {
                    delete copy[dateStr];
                }
                calRoot.checkRecords = copy;
            }
        }
    }

    function requestGridFromBackend() {
        if (typeof Bridge === "undefined" || !Bridge.requestCalendarGrid) return;
        var hId = currentHabit ? currentHabit.id : "";
        Bridge.requestCalendarGrid(calYear, calMonth, hId);
    }

    function reloadHabits() {
        if (typeof Bridge !== "undefined" && Bridge.requestHabits) {
            Bridge.requestHabits();
        }
    }

    function toggleSelectedDay() {
        if (!currentHabit || typeof Bridge === "undefined" || !Bridge.requestToggleRecord) {
            isManagingHabits = true;
            return;
        }
        Bridge.requestToggleRecord(currentHabit.id, selectedDateStr);
    }

    function selectDay(item) {
        if (!item) return;
        selYear = item.year;
        selMonth = item.month;
        selDay = item.day;
        if (item.month !== calMonth || item.year !== calYear) {
            calYear = item.year;
            calMonth = item.month;
            requestGridFromBackend();
        }
    }

    function quickToggleDay(item) {
        selectDay(item);
        toggleSelectedDay();
    }

    function gotoToday() {
        selYear = todayDate.getFullYear();
        selMonth = todayDate.getMonth();
        selDay = todayDate.getDate();
        calYear = todayDate.getFullYear();
        calMonth = todayDate.getMonth();
        requestGridFromBackend();
    }

    function gotoPrevMonth() {
        if (calMonth === 0) { calMonth = 11; calYear--; }
        else { calMonth--; }
        requestGridFromBackend();
    }

    function gotoNextMonth() {
        if (calMonth === 11) { calMonth = 0; calYear++; }
        else { calMonth++; }
        requestGridFromBackend();
    }

    property real wheelAccum: 0
    Timer { id: wheelResetTimer; interval: 260; onTriggered: calRoot.wheelAccum = 0 }

    function handleWheelStep(deltaY) {
        wheelResetTimer.restart();
        calRoot.wheelAccum += deltaY;
        if (Math.abs(calRoot.wheelAccum) >= 80) {
            if (calRoot.wheelAccum > 0) gotoPrevMonth();
            else gotoNextMonth();
            calRoot.wheelAccum = 0;
        }
    }

    // 🚀【核心修复】：只统计当月 (isCurrentMonth == true) 的打卡记录，彻底杜绝 33/31 天溢出
    readonly property int completedCount: {
        var cnt = 0;
        if (calGridModel && calGridModel.length > 0) {
            for (var i = 0; i < calGridModel.length; i++) {
                var cell = calGridModel[i];
                if (cell && cell.isCurrentMonth && checkRecords[cell.dateStr]) {
                    cnt++;
                }
            }
        }
        return cnt;
    }
    readonly property int daysInMonth: new Date(calYear, calMonth + 1, 0).getDate()

    Component.onCompleted: {
        reloadHabits();
        requestGridFromBackend();
    }

    Row {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            width: 128
            height: parent.height
            radius: (typeof Theme !== "undefined") ? Theme.radiusCard : 16
            color: "#181820"
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            clip: true

            CalendarDashboard {
                anchors.fill: parent
                currentHabit: calRoot.currentHabit
                effectiveFont: calRoot.effectiveFont
                effectiveMonoFont: calRoot.effectiveMonoFont
                completedCount: calRoot.completedCount
                daysInMonth: calRoot.daysInMonth
                selMonth: calRoot.selMonth
                selDay: calRoot.selDay
                selWeekdayStr: calRoot.selWeekdayStr
                isSelectedDayDone: calRoot.isSelectedDayDone
                isAlreadyToday: calRoot.isAlreadyToday
                visible: !calRoot.isManagingHabits
                onOpenHabitManager: {
                    calRoot.isManagingHabits = true;
                    drawer.focusInput();
                }
                onToggleSelectedDayCheck: calRoot.toggleSelectedDay()
                onResetTodayRequested: calRoot.gotoToday()
            }

            CalendarManagerDrawer {
                id: drawer
                visible: calRoot.isManagingHabits
                effectiveFont: calRoot.effectiveFont
                habitsList: calRoot.habitsList
                currentHabitIndex: calRoot.currentHabitIndex
                onCloseRequested: calRoot.isManagingHabits = false
                onHabitCreated: (name) => {
                    if (typeof Bridge !== "undefined" && Bridge.requestAddHabit) {
                        Bridge.requestAddHabit(name, "📌");
                    }
                }
                onHabitDeleted: (id) => {
                    if (typeof Bridge !== "undefined" && Bridge.requestDeleteHabit) {
                        Bridge.requestDeleteHabit(id);
                    }
                }
                onHabitSelected: (idx) => {
                    calRoot.currentHabitIndex = idx;
                    calRoot.requestGridFromBackend();
                    calRoot.isManagingHabits = false;
                }
            }
        }

        CalendarMonthView {
            width: parent.width - 138
            height: parent.height
            calYear: calRoot.calYear
            calMonth: calRoot.calMonth
            currentHabit: calRoot.currentHabit
            calGridModel: calRoot.calGridModel
            checkRecords: calRoot.checkRecords
            effectiveFont: calRoot.effectiveFont
            effectiveMonoFont: calRoot.effectiveMonoFont
            selYear: calRoot.selYear
            selMonth: calRoot.selMonth
            selDay: calRoot.selDay
            isAlreadyToday: calRoot.isAlreadyToday

            onPrevMonthRequested: calRoot.gotoPrevMonth()
            onNextMonthRequested: calRoot.gotoNextMonth()
            onTodayRequested: calRoot.gotoToday()
            onDaySelected: (item) => calRoot.selectDay(item)
            onDayToggled: (item) => calRoot.quickToggleDay(item)
            onWheelFlipped: (deltaY) => calRoot.handleWheelStep(deltaY)
        }
    }
}