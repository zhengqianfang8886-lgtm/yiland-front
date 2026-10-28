// ==========================================
// 📄 File: ui/components/calendar/CalendarDayCell.qml
// 🌟 纯净日历单元格 (纯展示 · 大字高透 · 零标记负担版)
// ==========================================
import QtQuick

Item {
    id: cellRoot

    property var cellData: null
    property bool isSelected: false
    property string effectiveMonoFont: ""

    signal cellClicked(var item)

    readonly property bool isToday: cellData ? cellData.isToday : false
    readonly property bool isCurrentMonth: cellData ? cellData.isCurrentMonth : false

    Rectangle {
        id: bgCard
        anchors.centerIn: parent
        width: Math.min(parent.width - 4, 38)
        height: Math.min(parent.height - 4, 28)
        radius: 8

        // 状态底色：今天 > 选中 > 悬停 > 默认透明
        color: {
            if (cellRoot.isToday) {
                return "#38bdf8"; // 今天：经典天蓝高亮
            }
            if (cellRoot.isSelected) {
                return Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.22);
            }
            return cellHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent";
        }

        border.color: {
            if (cellRoot.isToday) return "transparent";
            if (cellRoot.isSelected) return "#38bdf8";
            return cellHover.hovered ? Qt.rgba(1, 1, 1, 0.18) : "transparent";
        }
        border.width: 1

        scale: cellTap.pressed ? 0.92 : 1.0

        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }
        Behavior on scale { NumberAnimation { duration: 80 } }

        // 公历日号
        Text {
            anchors.centerIn: parent
            text: cellRoot.cellData ? cellRoot.cellData.day : ""
            font.pixelSize: cellRoot.isToday ? 13 : 12
            font.weight: (cellRoot.isToday || cellRoot.isSelected) ? Font.Black : Font.DemiBold

            color: {
                if (cellRoot.isToday) {
                    return "#0a0c14"; // 今天天蓝背景配深黑高对比度
                }
                if (cellRoot.isSelected) {
                    return "#ffffff";
                }
                return cellRoot.isCurrentMonth ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(1, 1, 1, 0.22);
            }

            font.family: cellRoot.effectiveMonoFont
        }
    }

    HoverHandler {
        id: cellHover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: cellTap
        onTapped: {
            if (cellRoot.cellData) {
                cellRoot.cellClicked(cellRoot.cellData);
            }
        }
    }
}