// ==========================================
// 📄 File: ui/components/pages/CalendarPage.qml
// 🌟 日历日程打卡主页面 (纯异步数据绑定 · 主线程零卡顿版)
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

    // =========================================================================
    // 🚀【核心改动】：全面接入 Bridge 异步信号通道，绝不阻塞主渲染帧
    // =========================================================================
    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null

        function onHabitsLoaded(data) {
            calRoot.habitsList = data || [];
            if (calRoot.currentHabitIndex >= calRoot.habitsList.length) {
                calRoot.currentHabitIndex = Math.max(0, calRoot.habitsList.length - 1);
            }
            calRoot.reloadMonthRecords();
        }

        function onMonthRecordsLoaded(habitId, year, month, records) {
            if (calRoot.currentHabit && calRoot.currentHabit.id === habitId &&
                calRoot.calYear === year && calRoot.calMonth === month) {
                calRoot.checkRecords = records || ({});
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

    function reloadHabits() {
        if (typeof Bridge !== "undefined" && Bridge.requestHabits) {
            Bridge.requestHabits();
        }
    }

    function reloadMonthRecords() {
        if (!currentHabit || typeof Bridge === "undefined" || !Bridge.requestMonthRecords) {
            checkRecords = ({});
            return;
        }
        Bridge.requestMonthRecords(currentHabit.id, calYear, calMonth);
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
            updateCalGrid();
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
        updateCalGrid();
    }

    function gotoPrevMonth() {
        if (calMonth === 0) { calMonth = 11; calYear--; }
        else { calMonth--; }
        updateCalGrid();
    }

    function gotoNextMonth() {
        if (calMonth === 11) { calMonth = 0; calYear++; }
        else { calMonth++; }
        updateCalGrid();
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

    property var calGridModel: []
    function updateCalGrid() {
        var firstIdx = new Date(calYear, calMonth, 1).getDay();
        var offset = (firstIdx === 0) ? 6 : (firstIdx - 1);
        var daysInCurrent = new Date(calYear, calMonth + 1, 0).getDate();
        var daysInPrev = new Date(calYear, calMonth, 0).getDate();
        var grid = [];

        for (var p = offset - 1; p >= 0; p--) {
            var prevD = daysInPrev - p;
            var prevM = calMonth === 0 ? 11 : calMonth - 1;
            var prevY = calMonth === 0 ? calYear - 1 : calYear;
            grid.push({ year: prevY, month: prevM, day: prevD, isCurrentMonth: false, isToday: false });
        }
        for (var d = 1; d <= daysInCurrent; d++) {
            grid.push({
                year: calYear, month: calMonth, day: d, isCurrentMonth: true,
                isToday: (todayDate.getFullYear() === calYear && todayDate.getMonth() === calMonth && todayDate.getDate() === d)
            });
        }
        var total = grid.length > 35 ? 42 : 35;
        var rem = total - grid.length;
        for (var n = 1; n <= rem; n++) {
            var nextM = calMonth === 11 ? 0 : calMonth + 1;
            var nextY = calMonth === 11 ? calYear + 1 : calYear;
            grid.push({ year: nextY, month: nextM, day: n, isCurrentMonth: false, isToday: false });
        }
        calGridModel = grid;
        reloadMonthRecords();
    }

    readonly property int completedCount: {
        var cnt = 0;
        for (var k in checkRecords) { if (checkRecords[k]) cnt++; }
        return cnt;
    }
    readonly property int daysInMonth: new Date(calYear, calMonth + 1, 0).getDate()

    Component.onCompleted: {
        reloadHabits();
        updateCalGrid();
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
                    calRoot.reloadMonthRecords();
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