// ==========================================
// 📄 File: ui/components/calendar/CalendarDayCell.qml
// 🌟 纯粹绿点单元格 (单双击零冲突 · 纯正 Handlers 加固版)
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

    // 1. 底卡：仅在选中或悬停时提供极浅白色/天蓝色交互反馈
    Rectangle {
        id: bgCard
        anchors.centerIn: parent
        width: Math.min(parent.width - 2, 34)
        height: Math.min(parent.height - 2, 24)
        radius: 6

        color: cellRoot.isSelected ?
               Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.22) :
               (cellHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

        border.color: cellRoot.isSelected ?
                      "#38bdf8" :
                      (cellHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent")
        border.width: cellRoot.isSelected ? 1.5 : 1

        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }

        // 2. 公历日号
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: cellRoot.isChecked ? -2.5 : -0.5

            text: cellRoot.cellData ? cellRoot.cellData.day : ""
            font.pixelSize: 13
            font.weight: (cellRoot.isToday || cellRoot.isSelected) ? Font.Black : Font.Bold

            color: {
                if (cellRoot.isSelected) {
                    return "#ffffff";
                }
                if (cellRoot.isToday) {
                    return "#34d399";
                }
                return cellRoot.isCurrentMonth ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.22);
            }

            font.family: cellRoot.effectiveMonoFont
            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 100 } }
        }

        // 3. 纯粹实心绿点
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

    // 4. 原生 Pointer Handlers 交互（单击与双击无竞争）
    HoverHandler {
        id: cellHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: singleTap
        onTapped: {
            if (cellRoot.cellData) {
                cellRoot.cellClicked(cellRoot.cellData);
            }
        }
        onDoubleTapped: {
            if (cellRoot.cellData) {
                cellRoot.cellDoubleClicked(cellRoot.cellData);
            }
        }
    }
}