// ==========================================
// 📄 File: ui/components/calendar/CalendarMonthView.qml
// 🌟 纯粹月历组件 (纯展示 · 剔除一切打卡项)
// ==========================================
import QtQuick

Item {
    id: monthViewRoot

    property int calYear: 2026
    property int calMonth: 0
    property var calGridModel: []
    property string effectiveFont: ""
    property string effectiveMonoFont: ""
    property int selYear: 2026
    property int selMonth: 0
    property int selDay: 1
    property bool isAlreadyToday: false

    signal prevMonthRequested()
    signal nextMonthRequested()
    signal todayRequested()
    signal daySelected(var item)
    signal wheelFlipped(real deltaY)

    Column {
        anchors.fill: parent
        spacing: 4

        // 1. 顶栏：年月与切月控制器
        Item {
            width: parent.width
            height: 24

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: monthViewRoot.calYear + "年 " + (monthViewRoot.calMonth + 1) + "月"
                color: "white"
                font.pixelSize: 13
                font.weight: Font.Black
                font.family: monthViewRoot.effectiveFont
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                // 今天胶囊
                Rectangle {
                    height: 20
                    width: todayRow.implicitWidth + 12
                    radius: 10
                    visible: !monthViewRoot.isAlreadyToday
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    color: todayTap.pressed ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35) :
                           (todayHover.hovered ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.20) : Qt.rgba(1, 1, 1, 0.08))
                    border.color: todayHover.hovered ? "#38bdf8" : Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.4)
                    border.width: 1

                    Row {
                        id: todayRow
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: "↺"; color: "#38bdf8"; font.pixelSize: 10; font.weight: Font.Bold }
                        Text { text: "今天"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: monthViewRoot.effectiveFont }
                    }

                    HoverHandler { id: todayHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: todayTap; onTapped: monthViewRoot.todayRequested() }
                }

                // ‹ 翻月
                Rectangle {
                    width: 22; height: 20; radius: 10
                    color: prevHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 15; font.weight: Font.Bold; color: "white" }
                    HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: monthViewRoot.prevMonthRequested() }
                }

                // › 翻月
                Rectangle {
                    width: 22; height: 20; radius: 10
                    color: nextHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 15; font.weight: Font.Bold; color: "white" }
                    HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: monthViewRoot.nextMonthRequested() }
                }
            }
        }

        // 2. 星期表头
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
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: (index >= 5) ? Qt.rgba(244 / 255, 114 / 255, 182 / 255, 0.85) : Qt.rgba(1, 1, 1, 0.45)
                        font.family: monthViewRoot.effectiveFont
                    }
                }
            }
        }

        // 3. 单元格网格
        Item {
            id: gridArea
            width: parent.width
            height: parent.height - 44
            clip: true

            readonly property real cellHeight: height / (monthViewRoot.calGridModel.length > 35 ? 6.0 : 5.0)

            Grid {
                id: grid
                columns: 7
                width: parent.width
                spacing: 0

                Repeater {
                    model: monthViewRoot.calGridModel

                    CalendarDayCell {
                        width: grid.width / 7
                        height: gridArea.cellHeight
                        cellData: modelData
                        effectiveMonoFont: monthViewRoot.effectiveMonoFont
                        isSelected: (modelData.year === monthViewRoot.selYear && modelData.month === monthViewRoot.selMonth && modelData.day === monthViewRoot.selDay)
                        onCellClicked: (item) => monthViewRoot.daySelected(item)
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => monthViewRoot.wheelFlipped(event.angleDelta.y)
            }
        }
    }
}