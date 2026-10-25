// ==========================================
// 📄 File: ui/components/calendar/CalendarDashboard.qml
// 🌟 日历左侧看板 (微型快速归位 · 纯正轻量级 Handlers 版)
// ==========================================
import QtQuick

Item {
    id: dashRoot

    property var currentHabit: null
    property string effectiveFont: ""
    property string effectiveMonoFont: ""
    property int completedCount: 0
    property int daysInMonth: 31
    property int selMonth: 0
    property int selDay: 1
    property string selWeekdayStr: ""
    property bool isSelectedDayDone: false
    property bool isAlreadyToday: false

    signal openHabitManager()
    signal toggleSelectedDayCheck()
    signal resetTodayRequested()

    Column {
        anchors.fill: parent
        anchors.margins: 9
        spacing: 6

        // 1. 事项切换药丸
        Rectangle {
            width: parent.width
            height: 24
            radius: 6
            color: habitHover.hovered ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.22) : Qt.rgba(1, 1, 1, 0.08)
            border.color: dashRoot.currentHabit ? "#10b981" : Qt.rgba(1, 1, 1, 0.2)
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 4
                width: parent.width - 12

                Text { text: dashRoot.currentHabit ? dashRoot.currentHabit.icon : "➕"; font.pixelSize: 10 }
                Text {
                    text: dashRoot.currentHabit ? dashRoot.currentHabit.name : "添加事项"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: dashRoot.currentHabit ? "white" : "#34d399"
                    font.family: dashRoot.effectiveFont
                    elide: Text.ElideRight
                    width: parent.width - 28
                }
                Text { text: "▾"; font.pixelSize: 8; color: Qt.rgba(1, 1, 1, 0.5) }
            }

            HoverHandler { id: habitHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: dashRoot.openHabitManager() }
        }

        // 2. 选中日期与状态指示
        Column {
            width: parent.width
            spacing: 2

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Text {
                    text: (dashRoot.selMonth + 1) + "月" + dashRoot.selDay + "日"
                    font.pixelSize: 18
                    font.weight: Font.Black
                    color: "white"
                    font.family: dashRoot.effectiveMonoFont
                    anchors.verticalCenter: parent.verticalCenter
                }

                // 非今天时，附带极简快速回弹微标
                Rectangle {
                    width: 16; height: 16; radius: 8
                    visible: !dashRoot.isAlreadyToday
                    color: snapHover.hovered ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.25) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "↺"
                        color: "#34d399"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }

                    HoverHandler { id: snapHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: dashRoot.resetTodayRequested() }
                }
            }

            Text {
                text: dashRoot.selWeekdayStr + " · " + (dashRoot.isSelectedDayDone ? "已记录" : "未记录")
                font.pixelSize: 9
                font.weight: Font.Bold
                color: dashRoot.isSelectedDayDone ? "#34d399" : ((typeof Theme !== "undefined") ? Theme.textMuted : Qt.rgba(1, 1, 1, 0.45))
                font.family: dashRoot.effectiveFont
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // 3. 本月完成统计进度条
        Column {
            width: parent.width
            spacing: 3

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2
                Text {
                    text: dashRoot.completedCount
                    font.pixelSize: 18
                    font.weight: Font.Black
                    color: "#34d399"
                    font.family: dashRoot.effectiveMonoFont
                }
                Text {
                    text: "/" + dashRoot.daysInMonth + " 天"
                    font.pixelSize: 9
                    color: (typeof Theme !== "undefined") ? Theme.textMuted : Qt.rgba(1, 1, 1, 0.45)
                    font.family: dashRoot.effectiveFont
                    anchors.baseline: parent.children[0].baseline
                }
            }

            Rectangle {
                width: parent.width - 8
                height: 3
                radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.1)
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    height: parent.height
                    radius: 1.5
                    color: "#10b981"
                    width: Math.min(parent.width, parent.width * (dashRoot.completedCount / Math.max(1, dashRoot.daysInMonth)))
                    Behavior on width { NumberAnimation { duration: 180 } }
                }
            }
        }

        Item { height: 1 }

        // 4. 打卡操作核心大按钮
        Rectangle {
            width: parent.width
            height: 24
            radius: 12
            anchors.horizontalCenter: parent.horizontalCenter
            color: dashRoot.isSelectedDayDone ?
                   (actTap.pressed ? "#059669" : "#10b981") :
                   (actTap.pressed ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.3) : Qt.rgba(1, 1, 1, 0.08))
            border.color: "#10b981"
            border.width: 1
            scale: actTap.pressed ? 0.94 : 1.0

            Row {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: dashRoot.isSelectedDayDone ? "✓" : "＋"
                    color: dashRoot.isSelectedDayDone ? "white" : "#34d399"
                    font.pixelSize: 10
                    font.weight: Font.Black
                }
                Text {
                    text: dashRoot.isSelectedDayDone ? "取消记录" : "标记已做"
                    color: "white"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.family: dashRoot.effectiveFont
                }
            }

            HoverHandler { id: actHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: actTap
                onTapped: dashRoot.toggleSelectedDayCheck()
            }
        }
    }
}