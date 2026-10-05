// ==========================================
// 📄 File: calendar/CalendarCell.qml
// ==========================================
import QtQuick

Item {
    id: cellRoot

    property var cellData: null
    property bool isChecked: false
    property bool isSelected: false
    property string effectiveMonoFont: ""

    signal toggleCheck(var item)

    readonly property bool isToday: cellData ? cellData.isToday : false
    readonly property bool isCurrentMonth: cellData ? cellData.isCurrentMonth : false

    // 单元格底板
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2, 34)
        height: Math.min(parent.height - 2, 23)
        radius: 6

        color: cellRoot.isChecked ?
               Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.22) :
               (cellRoot.isToday ? Qt.rgba(255, 255, 255, 0.08) :
               (cellHover.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent"))

        border.color: cellRoot.isChecked ?
                      "#10b981" :
                      (cellRoot.isSelected ? "#38bdf8" : (cellRoot.isToday ? Qt.rgba(255, 255, 255, 0.3) : "transparent"))
        border.width: 1

        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on border.color { ColorAnimation { duration: 100 } }
    }

    Column {
        anchors.centerIn: parent
        spacing: 1

        // 纯净公历数字 (字号严格使用整型 int 12)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: cellRoot.cellData ? cellRoot.cellData.day : ""
            font.pixelSize: 12
            font.weight: (cellRoot.isToday || cellRoot.isChecked) ? Font.Black : Font.DemiBold
            color: cellRoot.isChecked ? "#34d399" :
                   (cellRoot.isToday ? "#ffffff" :
                   (cellRoot.isCurrentMonth ? Qt.rgba(1, 1, 1, 0.90) : Qt.rgba(1, 1, 1, 0.22)))
            font.family: cellRoot.effectiveMonoFont
        }

        // 绿点：仅该事项在这一天打卡时点亮
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 4; height: 4; radius: 2
            color: cellRoot.isChecked ? "#10b981" : "transparent"
            visible: cellRoot.isChecked

            Rectangle {
                anchors.centerIn: parent
                width: 8; height: 8; radius: 4
                color: "transparent"
                border.color: Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.45)
                border.width: 1
                visible: cellRoot.isChecked
            }
        }
    }

    HoverHandler { id: cellHover }
    TapHandler {
        onTapped: cellRoot.toggleCheck(cellRoot.cellData)
    }
}