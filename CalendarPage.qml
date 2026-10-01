import QtQuick 2.15

Item {
    id: calRoot

    property string chosenFont: ""
    property int calYear: new Date().getFullYear()
    property int calMonth: new Date().getMonth()
    property var calGridModel: []

    function updateCalGrid() {
        var firstDayIndex = new Date(calYear, calMonth, 1).getDay()
        var offset = (firstDayIndex === 0) ? 6 : (firstDayIndex - 1)
        var daysInCurrentMonth = new Date(calYear, calMonth + 1, 0).getDate()
        var daysInPrevMonth = new Date(calYear, calMonth, 0).getDate()

        var today = new Date()
        var isCurrentYearMonth = (today.getFullYear() === calYear && today.getMonth() === calMonth)
        var todayDate = today.getDate()

        var grid = []
        for (var p = offset - 1; p >= 0; p--) {
            grid.push({ day: daysInPrevMonth - p, isCurrentMonth: false, isToday: false })
        }
        for (var d = 1; d <= daysInCurrentMonth; d++) {
            grid.push({ day: d, isCurrentMonth: true, isToday: (isCurrentYearMonth && d === todayDate) })
        }
        var totalCells = grid.length > 35 ? 42 : 35
        var remaining = totalCells - grid.length
        for (var n = 1; n <= remaining; n++) {
            grid.push({ day: n, isCurrentMonth: false, isToday: false })
        }
        calRoot.calGridModel = grid
    }

    function prevCalMonth() {
        if (calMonth === 0) { calMonth = 11; calYear-- } else { calMonth-- }
        updateCalGrid()
    }
    function nextCalMonth() {
        if (calMonth === 11) { calMonth = 0; calYear++ } else { calMonth++ }
        updateCalGrid()
    }
    function resetToToday() {
        var now = new Date()
        calYear = now.getFullYear(); calMonth = now.getMonth()
        updateCalGrid()
    }

    Component.onCompleted: updateCalGrid()

    Row {
        anchors.fill: parent
        spacing: 16

        // 左侧 Bento "TODAY" 卡片
        Rectangle {
            width: 126; height: parent.height; radius: 16
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(1, 1, 1, 0.08)

            Column {
                anchors.centerIn: parent; spacing: 4

                Row {
                    spacing: 5; anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle { width: 6; height: 6; radius: 3; color: "#10b981"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "TODAY"; font.pixelSize: 9; font.weight: Font.Black; color: "#10b981"; font.family: calRoot.chosenFont; font.letterSpacing: 0.8 }
                }

                Text {
                    text: new Date().getDate()
                    color: "white"; font.pixelSize: 52; font.weight: Font.Black
                    font.family: (calRoot.chosenFont !== "") ? calRoot.chosenFont : "Monospace"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: {
                        var days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
                        var d = new Date()
                        return days[d.getDay()] + " · " + (d.getMonth() + 1) + "月"
                    }
                    color: Qt.rgba(1, 1, 1, 0.75); font.pixelSize: 12; font.weight: Font.Bold
                    font.family: calRoot.chosenFont
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Item { height: 4 }

                Rectangle {
                    width: 82; height: 22; radius: 11
                    color: resetBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                    scale: resetBtnArea.pressed ? 0.94 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text { anchors.centerIn: parent; text: "回到今天"; color: Qt.rgba(1, 1, 1, 0.9); font.pixelSize: 10; font.family: calRoot.chosenFont; font.weight: Font.Bold }
                    MouseArea {
                        id: resetBtnArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: calRoot.resetToToday()
                    }
                }
            }
        }

        // 右侧日历网格
        Column {
            width: parent.width - 142; height: parent.height
            spacing: 6

            Item {
                width: parent.width; height: 22
                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: calRoot.calYear + "年 " + (calRoot.calMonth + 1) + "月"
                    color: "white"; font.pixelSize: 14; font.weight: Font.Black; font.family: calRoot.chosenFont
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: prevMonthArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                        scale: prevMonthArea.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 16; font.weight: Font.Bold; color: prevMonthArea.containsMouse ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.7) }
                        MouseArea { id: prevMonthArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calRoot.prevCalMonth() }
                    }
                    Rectangle {
                        width: 22; height: 22; radius: 11
                        color: nextMonthArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                        scale: nextMonthArea.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 16; font.weight: Font.Bold; color: nextMonthArea.containsMouse ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.7) }
                        MouseArea { id: nextMonthArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calRoot.nextCalMonth() }
                    }
                }
            }

            Row {
                width: parent.width
                Repeater {
                    model: ["一", "二", "三", "四", "五", "六", "日"]
                    Item {
                        width: parent.width / 7; height: 16
                        Text {
                            anchors.centerIn: parent
                            text: modelData; font.pixelSize: 11; font.weight: Font.Bold
                            color: (index >= 5) ? Qt.rgba(244, 114, 182, 0.85) : Qt.rgba(1, 1, 1, 0.45)
                            font.family: calRoot.chosenFont
                        }
                    }
                }
            }

            Grid {
                columns: 7; width: parent.width; spacing: 0
                Repeater {
                    model: calRoot.calGridModel
                    Item {
                        width: Math.floor(parent.width / 7); height: 22

                        Rectangle {
                            anchors.centerIn: parent
                            width: 22; height: 22; radius: 11
                            color: modelData.isToday ? "#10b981" : (cellArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day; font.pixelSize: 12
                            font.weight: modelData.isToday ? Font.Black : Font.DemiBold
                            color: modelData.isToday ? "white" : (modelData.isCurrentMonth ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.25))
                            font.family: (calRoot.chosenFont !== "") ? calRoot.chosenFont : "Monospace"
                        }

                        MouseArea { id: cellArea; anchors.fill: parent; hoverEnabled: true }
                    }
                }
            }
        }
    }
}