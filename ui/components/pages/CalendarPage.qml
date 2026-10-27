// ==========================================
// 📄 File: ui/components/pages/CalendarPage.qml
// 🌟 纯粹极简日历主页 (修复点击日期顶栏不联动 Bug 版)
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

    // 🚀 当前鼠标点击选中的年月日 (默认初始化为今天)
    property int selYear: todayDate.getFullYear()
    property int selMonth: todayDate.getMonth()
    property int selDay: todayDate.getDate()

    // 判断选中的是不是今天
    readonly property bool isSelectedToday: (selYear === todayDate.getFullYear() &&
                                             selMonth === todayDate.getMonth() &&
                                             selDay === todayDate.getDate())

    // 判断是否在看当月
    readonly property bool isViewingCurrentMonth: (calYear === todayDate.getFullYear() && calMonth === todayDate.getMonth())

    // 🚀【核心修复】：动态计算当前选中的日期是星期几！
    readonly property string selWeekdayStr: {
        var days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
        var d = new Date(calRoot.selYear, calRoot.selMonth, calRoot.selDay);
        return days[d.getDay()];
    }

    // =========================================================================
    // 纯前端 35 / 42 格日历标准矩阵计算
    // =========================================================================
    readonly property var calGridModel: {
        var grid = [];
        var firstDayOfWeek = new Date(calYear, calMonth, 1).getDay(); // 0(周日) ~ 6(周六)
        // 周一为每周第一列：0(周一) ~ 6(周日)
        var startOffset = (firstDayOfWeek === 0) ? 6 : (firstDayOfWeek - 1);

        var daysInCurrentMonth = new Date(calYear, calMonth + 1, 0).getDate();
        var daysInPrevMonth = new Date(calYear, calMonth, 0).getDate();

        // 1. 上月余留格
        for (var p = startOffset - 1; p >= 0; p--) {
            var dPrev = daysInPrevMonth - p;
            grid.push({
                year: calMonth === 0 ? calYear - 1 : calYear,
                month: calMonth === 0 ? 11 : calMonth - 1,
                day: dPrev,
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

    // 一键回到今天
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

    // 鼠标滚轮翻月
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

    Column {
        anchors.fill: parent
        spacing: 4

        // =====================================================================
        // 1. 顶栏：选中的日期实时同步显示
        // =====================================================================
        Item {
            width: parent.width
            height: 24

            // 左侧：年月与【当前选中日期】
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Text {
                    text: calRoot.calYear + "年 " + (calRoot.calMonth + 1) + "月"
                    color: "white"
                    font.pixelSize: 14
                    font.weight: Font.Black
                    font.family: calRoot.effectiveFont
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 3; height: 3; radius: 1.5
                    color: Qt.rgba(1, 1, 1, 0.3)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // 🚀【核心修复点】：绑定 selMonth / selDay / selWeekdayStr
                Text {
                    text: (calRoot.selMonth + 1) + "月" + calRoot.selDay + "日 " + calRoot.selWeekdayStr + (calRoot.isSelectedToday ? " (今天)" : "")
                    color: calRoot.isSelectedToday ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.75)
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.family: calRoot.effectiveFont
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            // 右侧：[↺ 今天] [‹] [›] 控制器
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                // 🚀 只要翻了月、或者点击了别的非今天日期，立即浮现回今天按钮
                Rectangle {
                    height: 20
                    width: todayBtnRow.implicitWidth + 12
                    radius: 10
                    visible: !calRoot.isViewingCurrentMonth || !calRoot.isSelectedToday
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    color: todayTap.pressed ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35) :
                           (todayHover.hovered ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.20) : Qt.rgba(1, 1, 1, 0.08))
                    border.color: todayHover.hovered ? "#38bdf8" : Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.4)
                    border.width: 1

                    Row {
                        id: todayBtnRow
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: "↺"; color: "#38bdf8"; font.pixelSize: 10; font.weight: Font.Bold }
                        Text { text: "今天"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: calRoot.effectiveFont }
                    }

                    HoverHandler { id: todayHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: todayTap; onTapped: calRoot.gotoToday() }
                }

                // ‹ 翻上月
                Rectangle {
                    width: 22; height: 20; radius: 10
                    color: prevHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 15; font.weight: Font.Bold; color: "white" }
                    HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: calRoot.gotoPrevMonth() }
                }

                // › 翻下月
                Rectangle {
                    width: 22; height: 20; radius: 10
                    color: nextHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 15; font.weight: Font.Bold; color: "white" }
                    HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: calRoot.gotoNextMonth() }
                }
            }
        }

        // =====================================================================
        // 2. 星期表头行
        // =====================================================================
        Row {
            width: parent.width
            height: 16

            Repeater {
                model: ["一", "二", "三", "四", "五", "六", "日"]
                Item {
                    width: parent.width / 7
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: (index >= 5) ? Qt.rgba(244 / 255, 114 / 255, 182 / 255, 0.85) : Qt.rgba(1, 1, 1, 0.45)
                        font.family: calRoot.effectiveFont
                    }
                }
            }
        }

        // =====================================================================
        // 3. 全宽日历网格 (点击更新选中状态)
        // =====================================================================
        Item {
            id: gridContainer
            width: parent.width
            height: parent.height - 24 - 16 - 8
            clip: true

            readonly property real rowHeight: height / (calRoot.calGridModel.length > 35 ? 6.0 : 5.0)

            Grid {
                id: grid
                columns: 7
                width: parent.width
                spacing: 0

                Repeater {
                    model: calRoot.calGridModel

                    CalendarDayCell {
                        width: grid.width / 7
                        height: gridContainer.rowHeight
                        cellData: modelData
                        effectiveMonoFont: calRoot.effectiveMonoFont
                        // 选中的判定规则：与当前选中的年月日完全一致
                        isSelected: (modelData.year === calRoot.selYear && modelData.month === calRoot.selMonth && modelData.day === calRoot.selDay)
                        
                        onCellClicked: (item) => {
                            // 🚀 点击后立即更新选中的年月日
                            calRoot.selYear = item.year;
                            calRoot.selMonth = item.month;
                            calRoot.selDay = item.day;

                            // 如果点击了上个月/下个月的灰色格，自动翻到该月份
                            if (item.month !== calRoot.calMonth || item.year !== calRoot.calYear) {
                                calRoot.calYear = item.year;
                                calRoot.calMonth = item.month;
                            }
                        }
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => calRoot.handleWheelStep(event.angleDelta.y)
            }
        }
    }
}