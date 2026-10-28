// ==========================================
// 📄 File: ui/components/pages/CalendarPage.qml
// 🌟 纯粹极简双栏日历页面 (全新优雅排版 · 零打卡负担版)
// ==========================================
import QtQuick
import "../calendar"

Item {
    id: calRoot
    anchors.fill: parent

    property string chosenFont: ""
    readonly property string effectiveFont: (chosenFont !== "") ? chosenFont : ((typeof Theme !== "undefined") ? Theme.activeFont : "")
    readonly property string effectiveMonoFont: (typeof Theme !== "undefined") ? Theme.displayMonoFont : "Monospace"

    // 原生系统今天
    readonly property var todayDate: new Date()

    // 当前查阅的年月 (支持翻页)
    property int calYear: todayDate.getFullYear()
    property int calMonth: todayDate.getMonth()  // 0-11

    // 当前鼠标点击选中的年月日
    property int selYear: todayDate.getFullYear()
    property int selMonth: todayDate.getMonth()
    property int selDay: todayDate.getDate()

    // 选中状态推导
    readonly property bool isSelectedToday: (selYear === todayDate.getFullYear() &&
                                             selMonth === todayDate.getMonth() &&
                                             selDay === todayDate.getDate())
    readonly property bool isViewingCurrentMonth: (calYear === todayDate.getFullYear() && calMonth === todayDate.getMonth())

    // 选中日的时间对象
    readonly property var selDateObj: new Date(selYear, selMonth, selDay)

    // 格式化信息：星期全称
    readonly property string selWeekdayFull: {
        var days = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"];
        return days[selDateObj.getDay()];
    }

    // 格式化信息：相对今天的时间距离提示
    readonly property string relativeDayText: {
        var d1 = new Date(todayDate.getFullYear(), todayDate.getMonth(), todayDate.getDate());
        var d2 = new Date(selYear, selMonth, selDay);
        var diffTime = d2.getTime() - d1.getTime();
        var diffDays = Math.round(diffTime / (1000 * 3600 * 24));
        if (diffDays === 0) return "今天";
        if (diffDays === 1) return "明天";
        if (diffDays === -1) return "昨天";
        if (diffDays > 0) return diffDays + " 天后";
        return Math.abs(diffDays) + " 天前";
    }

    // 格式化信息：本年度第几周
    readonly property int weekOfYear: {
        var d = new Date(Date.UTC(selYear, selMonth, selDay));
        var dayNum = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - dayNum);
        var yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    }

    // 格式化信息：本年度第几天
    readonly property int dayOfYear: {
        var start = new Date(selYear, 0, 0);
        var diff = selDateObj - start;
        var oneDay = 1000 * 60 * 60 * 24;
        return Math.floor(diff / oneDay);
    }

    // =========================================================================
    // 标准公历网格矩阵计算
    // =========================================================================
    readonly property var calGridModel: {
        var grid = [];
        var firstDayOfWeek = new Date(calYear, calMonth, 1).getDay();
        var startOffset = (firstDayOfWeek === 0) ? 6 : (firstDayOfWeek - 1);

        var daysInCurrentMonth = new Date(calYear, calMonth + 1, 0).getDate();
        var daysInPrevMonth = new Date(calYear, calMonth, 0).getDate();

        // 1. 上月余留格
        for (var p = startOffset - 1; p >= 0; p--) {
            grid.push({
                year: calMonth === 0 ? calYear - 1 : calYear,
                month: calMonth === 0 ? 11 : calMonth - 1,
                day: daysInPrevMonth - p,
                isCurrentMonth: false,
                isToday: false
            });
        }

        // 2. 当月日期格
        for (var d = 1; d <= daysInCurrentMonth; d++) {
            var isTod = (calYear === todayDate.getFullYear() && calMonth === todayDate.getMonth() && d === todayDate.getDate());
            grid.push({
                year: calYear,
                month: calMonth,
                day: d,
                isCurrentMonth: true,
                isToday: isTod
            });
        }

        // 3. 补齐到 35 或 42 格
        var targetTotal = grid.length > 35 ? 42 : 35;
        var nextDay = 1;
        while (grid.length < targetTotal) {
            grid.push({
                year: calMonth === 11 ? calYear + 1 : calYear,
                month: calMonth === 11 ? 0 : calMonth + 1,
                day: nextDay++,
                isCurrentMonth: false,
                isToday: false
            });
        }

        return grid;
    }

    function gotoToday() {
        calYear = todayDate.getFullYear();
        calMonth = todayDate.getMonth();
        selYear = todayDate.getFullYear();
        selMonth = todayDate.getMonth();
        selDay = todayDate.getDate();
    }

    function gotoPrevMonth() {
        if (calMonth === 0) { calMonth = 11; calYear--; }
        else { calMonth--; }
    }

    function gotoNextMonth() {
        if (calMonth === 11) { calMonth = 0; calYear++; }
        else { calMonth++; }
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

    // =========================================================================
    // 纯粹日历主界面：左侧【时光印记牌】 + 右侧【优雅月历网格】
    // =========================================================================
    Row {
        anchors.fill: parent
        spacing: 12

        // =====================================================================
        // 1. 左侧：高质感时光信息看板
        // =====================================================================
        Rectangle {
            width: 132
            height: parent.height
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: calRoot.isSelectedToday ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35) : Qt.rgba(255, 255, 255, 0.10)
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: 200 } }

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                // 顶部：月份与年份胶囊
                Rectangle {
                    height: 20
                    width: parent.width
                    radius: 6
                    color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.16)

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: (calRoot.selMonth + 1) + "月"
                            color: "#38bdf8"
                            font.pixelSize: 11
                            font.weight: Font.Black
                            font.family: calRoot.effectiveFont
                        }
                        Text {
                            text: calRoot.selYear
                            color: Qt.rgba(255, 255, 255, 0.7)
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.family: calRoot.effectiveMonoFont
                        }
                    }
                }

                // 核心：特大公历日号
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: calRoot.selDay
                    color: "#ffffff"
                    font.pixelSize: 42
                    font.weight: Font.Black
                    font.family: calRoot.effectiveMonoFont
                }

                // 星期与相对距离
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: calRoot.selWeekdayFull
                        color: calRoot.isSelectedToday ? "#38bdf8" : "#ffffff"
                        font.pixelSize: 12
                        font.weight: Font.Black
                        font.family: calRoot.effectiveFont
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: calRoot.relativeDayText
                        color: Qt.rgba(255, 255, 255, 0.5)
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: calRoot.effectiveFont
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(255, 255, 255, 0.08) }

                // 纯日历维度数据：第几周 & 第几天
                Column {
                    width: parent.width
                    spacing: 3

                    Row {
                        spacing: 4
                        Text { text: "周次:"; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 9; font.family: calRoot.effectiveFont }
                        Text { text: "第 " + calRoot.weekOfYear + " 周"; color: "white"; font.pixelSize: 9; font.weight: Font.Bold; font.family: calRoot.effectiveMonoFont }
                    }

                    Row {
                        spacing: 4
                        Text { text: "累积:"; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 9; font.family: calRoot.effectiveFont }
                        Text { text: "第 " + calRoot.dayOfYear + " 天"; color: "white"; font.pixelSize: 9; font.weight: Font.Bold; font.family: calRoot.effectiveMonoFont }
                    }
                }

                Item { height: 2 }

                // 快捷“回到今天”按钮 (仅在非今天时显现)
                Rectangle {
                    width: parent.width
                    height: 24
                    radius: 12
                    visible: !calRoot.isSelectedToday || !calRoot.isViewingCurrentMonth
                    color: returnTodayTap.pressed ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35) :
                           (returnTodayHover.hovered ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.22) : Qt.rgba(1, 1, 1, 0.08))
                    border.color: returnTodayHover.hovered ? "#38bdf8" : Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.4)
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "↺"; color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Bold }
                        Text { text: "回到今天"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: calRoot.effectiveFont }
                    }

                    HoverHandler { id: returnTodayHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: returnTodayTap; onTapped: calRoot.gotoToday() }
                }
            }
        }

        // =====================================================================
        // 2. 右侧：全幅无障碍纯日历网格
        // =====================================================================
        Item {
            width: parent.width - 132 - 12
            height: parent.height

            CalendarMonthView {
                anchors.fill: parent
                calYear: calRoot.calYear
                calMonth: calRoot.calMonth
                calGridModel: calRoot.calGridModel
                selYear: calRoot.selYear
                selMonth: calRoot.selMonth
                selDay: calRoot.selDay
                isAlreadyToday: calRoot.isSelectedToday && calRoot.isViewingCurrentMonth
                effectiveFont: calRoot.effectiveFont
                effectiveMonoFont: calRoot.effectiveMonoFont

                onPrevMonthRequested: calRoot.gotoPrevMonth()
                onNextMonthRequested: calRoot.gotoNextMonth()
                onTodayRequested: calRoot.gotoToday()
                onWheelFlipped: (deltaY) => calRoot.handleWheelStep(deltaY)

                onDaySelected: (item) => {
                    calRoot.selYear = item.year;
                    calRoot.selMonth = item.month;
                    calRoot.selDay = item.day;

                    if (item.month !== calRoot.calMonth || item.year !== calRoot.calYear) {
                        calRoot.calYear = item.year;
                        calRoot.calMonth = item.month;
                    }
                }
            }
        }
    }
}