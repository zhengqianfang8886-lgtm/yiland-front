// ==========================================
// 📄 File: calendar/CalendarHeader.qml
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: headerRoot
    width: parent.width
    height: 24

    property string effectiveFont: ""
    property int selMonth: 0
    property int selDay: 1
    property string selWeekdayStr: ""
    property string selLunarFullStr: ""
    property bool isSpecialDay: false
    property int daysDelta: 0
    property bool isViewingToday: true
    property bool isViewingCurrentMonth: true

    property int calYear: 2026
    property int calMonth: 0

    signal prevMonthRequested()
    signal nextMonthRequested()
    signal resetTodayRequested()

    // 1. 左侧：高密联动日期面板
    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // 状态徽章 (TODAY / +8天)
        Rectangle {
            height: 18
            width: badgeRow.implicitWidth + 10
            radius: 9
            color: headerRoot.isViewingToday ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.18) : Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.18)
            border.color: headerRoot.isViewingToday ? "#10b981" : "#38bdf8"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            Row {
                id: badgeRow
                anchors.centerIn: parent
                spacing: 4
                Rectangle {
                    width: 5; height: 5; radius: 2.5
                    color: headerRoot.isViewingToday ? "#10b981" : "#38bdf8"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: headerRoot.isViewingToday ? "TODAY" : (headerRoot.daysDelta > 0 ? ("+" + headerRoot.daysDelta + "天") : (headerRoot.daysDelta + "天"))
                    color: headerRoot.isViewingToday ? "#34d399" : "#38bdf8"
                    font.pixelSize: 9
                    font.weight: Font.Black
                    font.family: headerRoot.effectiveFont
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // 公历月日星期
        Text {
            text: (headerRoot.selMonth + 1) + "月" + headerRoot.selDay + "日 · " + headerRoot.selWeekdayStr
            color: "white"
            font.pixelSize: 13
            font.weight: Font.Black
            font.family: headerRoot.effectiveFont
            anchors.verticalCenter: parent.verticalCenter
        }

        // 农历节气全称
        Text {
            text: "· " + headerRoot.selLunarFullStr
            color: headerRoot.isSpecialDay ? "#fbbf24" : Theme.textSecondary
            font.pixelSize: 11
            font.weight: Font.Bold
            font.family: headerRoot.effectiveFont
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // 2. 右侧：翻月与归位控制区
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // 一键回到今天按钮
        Rectangle {
            height: 20
            width: resetRow.implicitWidth + 12
            radius: 10
            visible: !headerRoot.isViewingToday || !headerRoot.isViewingCurrentMonth
            color: resetTap.pressed ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.3) : (resetHover.hovered ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.2) : Qt.rgba(1, 1, 1, 0.08))
            border.color: "#10b981"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            scale: resetTap.pressed ? 0.94 : 1.0

            Row {
                id: resetRow
                anchors.centerIn: parent
                spacing: 3
                Text { text: "↺"; color: "#10b981"; font.pixelSize: 11; font.weight: Font.Bold }
                Text { text: "今天"; color: "white"; font.pixelSize: 9; font.weight: Font.Bold; font.family: headerRoot.effectiveFont }
            }

            HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { id: resetTap; onTapped: headerRoot.resetTodayRequested() }
        }

        // 当前月历年月
        Text {
            text: headerRoot.calYear + "年 " + (headerRoot.calMonth + 1) + "月"
            color: "white"
            font.pixelSize: 13
            font.weight: Font.Black
            font.family: headerRoot.effectiveFont
            anchors.verticalCenter: parent.verticalCenter
        }

        // 翻月切页键
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: 20; height: 20; radius: 10
                color: prevHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                scale: prevTap.pressed ? 0.9 : 1.0
                Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 15; font.weight: Font.Bold; color: prevHover.hovered ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.6) }
                HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: prevTap; onTapped: headerRoot.prevMonthRequested() }
            }

            Rectangle {
                width: 20; height: 20; radius: 10
                color: nextHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                scale: nextTap.pressed ? 0.9 : 1.0
                Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 15; font.weight: Font.Bold; color: nextHover.hovered ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.6) }
                HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: nextTap; onTapped: headerRoot.nextMonthRequested() }
            }
        }
    }
}