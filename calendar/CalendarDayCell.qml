// ==========================================
// 📄 File: calendar/CalendarDayCell.qml (无绿底·纯粹绿点版)
// ==========================================
import QtQuick

Item {
    id: cellRoot

    property var cellData: null
    property bool isSelected: false
    property bool isChecked: false
    property string effectiveMonoFont: ""

    signal cellClicked(var item)
    signal cellDoubleClicked(var item)

    readonly property bool isToday: cellData ? cellData.isToday : false
    readonly property bool isCurrentMonth: cellData ? cellData.isCurrentMonth : false

    // 1. 底卡：仅在选中或悬停时提供极浅白色/天蓝色交互反馈，严禁出现任何绿色底色！
    Rectangle {
        id: bgCard
        anchors.centerIn: parent
        width: Math.min(parent.width - 2, 34)
        height: Math.min(parent.height - 2, 24)
        radius: 6

        // 🚀 彻底去除所有绿色背景，平时完全透明
        color: cellRoot.isSelected ?
               Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.22) :
               (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

        border.color: cellRoot.isSelected ?
                      "#38bdf8" :
                      (mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent")
        border.width: cellRoot.isSelected ? 1.5 : 1

        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }

        // 2. 公历日号（仅用文字颜色区分今日，干净清爽）
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: cellRoot.isChecked ? -2.5 : -0.5

            text: cellRoot.cellData ? cellRoot.cellData.day : ""
            font.pixelSize: 13
            font.weight: (cellRoot.isToday || cellRoot.isSelected) ? Font.Black : Font.Bold

            color: {
                if (cellRoot.isSelected) {
                    return "#ffffff"
                }
                if (cellRoot.isToday) {
                    return "#34d399" // 今日仅以翡翠绿文字标出，无背景框打扰
                }
                return cellRoot.isCurrentMonth ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.22)
            }

            font.family: cellRoot.effectiveMonoFont
            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 100 } }
        }

        // 3. 🚀 纯粹、利落的打卡实心绿点（剔除一切发虚晕染）
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            anchors.horizontalCenter: parent.horizontalCenter
            width: 4
            height: 4
            radius: 2
            color: "#10b981"
            antialiasing: true
            visible: cellRoot.isChecked
        }
    }

    // 4. 单双击无冲突热区
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (cellRoot.cellData) {
                cellRoot.cellClicked(cellRoot.cellData)
            }
        }

        onDoubleClicked: {
            if (cellRoot.cellData) {
                cellRoot.cellDoubleClicked(cellRoot.cellData)
            }
        }
    }
}