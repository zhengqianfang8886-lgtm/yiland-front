// ==========================================
// 📄 File: calendar/CalendarMonthView.qml (集成右上角智能返回今天)
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: monthViewRoot

    property int calYear: 2026
    property int calMonth: 0
    property var currentHabit: null
    property var calGridModel: []
    property var checkRecords: ({})
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
    signal dayToggled(var item)
    signal wheelFlipped(real deltaY)

    Column {
        anchors.fill: parent
        spacing: 3

        // 1. 顶栏：年月与切月控制器
        Item {
            width: parent.width
            height: 22

            // 左侧：年月与当前事项
            Row {
                anchors.left: parent.left
                anchors.right: rightControlsRow.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                clip: true

                Text {
                    text: monthViewRoot.calYear + "年 " + (monthViewRoot.calMonth + 1) + "月"
                    color: "white"
                    font.pixelSize: 13
                    font.weight: Font.Black
                    font.family: monthViewRoot.effectiveFont
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: monthViewRoot.currentHabit ? ("· " + monthViewRoot.currentHabit.name) : "· 未选择事项"
                    color: "#34d399"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.family: monthViewRoot.effectiveFont
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 🚀 右侧控制区：[ ↺ 今天 ] [ ‹ ] [ › ] 紧密排列，极度顺手
            Row {
                id: rightControlsRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                // 核心按钮：非今天时平滑显现
                Rectangle {
                    id: todayBtn
                    height: 20
                    width: todayRow.implicitWidth + 12
                    radius: 10
                    visible: !monthViewRoot.isAlreadyToday
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    color: todayTap.pressed ?
                           Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.35) :
                           (todayHover.hovered ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.22) : Qt.rgba(1, 1, 1, 0.08))
                    border.color: todayHover.hovered ? "#10b981" : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.5)
                    border.width: 1
                    scale: todayTap.pressed ? 0.94 : 1.0

                    Row {
                        id: todayRow
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: "↺"
                            color: "#34d399"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "今天"
                            color: "white"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.family: monthViewRoot.effectiveFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: todayHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: todayTap
                        onTapped: monthViewRoot.todayRequested()
                    }
                }

                // ‹ 翻月
                Rectangle {
                    width: 20; height: 20; radius: 10
                    color: prevHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                    Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 15; font.weight: Font.Bold; color: "white" }
                    HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: monthViewRoot.prevMonthRequested() }
                }

                // › 翻月
                Rectangle {
                    width: 20; height: 20; radius: 10
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
            height: 14

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
                        color: (index >= 5) ? Qt.rgba(244 / 255, 114 / 255, 182 / 255, 0.85) : Qt.rgba(1, 1, 1, 0.4)
                        font.family: monthViewRoot.effectiveFont
                    }
                }
            }
        }

        // 3. 单元格网格
        Item {
            id: gridArea
            width: parent.width
            height: parent.height - 40
            clip: true

            readonly property real cellHeight: (monthViewRoot.calGridModel.length > 35) ? (height / 6.0) : (height / 5.0)

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
                        isChecked: {
                            if (!monthViewRoot.currentHabit) return false;
                            var mStr = (modelData.month + 1 < 10 ? "0" : "") + (modelData.month + 1);
                            var dStr = (modelData.day < 10 ? "0" : "") + modelData.day;
                            var k = modelData.year + "-" + mStr + "-" + dStr;
                            return monthViewRoot.checkRecords[k] === true;
                        }
                        onCellClicked: (item) => monthViewRoot.daySelected(item)
                        onCellDoubleClicked: (item) => monthViewRoot.dayToggled(item)
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