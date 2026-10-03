import QtQuick

Row {
    id: clockRoot
    spacing: 6

    property string chosenFont: ""
    property bool isCapsLock: false
    property bool showNetSpeed: true
    property string downCompact: "0K"
    property string upCompact: "0K"
    property string displayDate: ""
    property string displayTime: "04:53"
    property string displaySeconds: ""
    property string displayPeriod: "pm"
    property bool isExpanded: false

    visible: !isExpanded && (opacity > 0.001)

    // 大写锁定微胶囊
    Rectangle {
        id: capsLockBadge
        height: 22; radius: 6
        anchors.verticalCenter: parent.verticalCenter
        width: clockRoot.isCapsLock ? (capsInnerRow.implicitWidth + 12) : 0
        visible: width > 0
        clip: true
        color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.18)
        border.color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.50)
        border.width: 1

        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

        Row {
            id: capsInnerRow
            anchors.centerIn: parent
            spacing: 3
            Text { text: "⇪"; color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "大写"; color: "white"; font.pixelSize: 9; font.weight: Font.Bold; font.family: clockRoot.chosenFont; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // 实时网速小卡片
    Rectangle {
        id: netSpeedItem
        visible: clockRoot.showNetSpeed
        width: clockRoot.showNetSpeed ? (speedCol.implicitWidth + 10) : 0
        height: 22; radius: 5
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(1, 1, 1, 0.06); border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1

        Column {
            id: speedCol
            anchors.centerIn: parent; spacing: 1
            Row {
                spacing: 3; anchors.left: parent.left
                Text { text: "↓"; font.pixelSize: 8; font.weight: Font.Black; color: Theme.network; anchors.verticalCenter: parent.verticalCenter }
                Text { text: clockRoot.downCompact; color: "white"; font.pixelSize: 9; font.weight: Font.Black; font.family: "Monospace"; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 3; anchors.left: parent.left
                Text { text: "↑"; font.pixelSize: 8; font.weight: Font.Black; color: Theme.calendar; anchors.verticalCenter: parent.verticalCenter }
                Text { text: clockRoot.upCompact; color: "white"; font.pixelSize: 9; font.weight: Font.Black; font.family: "Monospace"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // 日期文本
    Text {
        text: clockRoot.displayDate
        color: Qt.rgba(1, 1, 1, 0.70)
        font.family: clockRoot.chosenFont; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.2
        visible: (typeof Config !== "undefined" && Config.showDate) && clockRoot.displayDate !== ""
        anchors.verticalCenter: parent.verticalCenter
    }

    Rectangle {
        width: 1; height: 11; radius: 0.5; color: Qt.rgba(1, 1, 1, 0.14)
        anchors.verticalCenter: parent.verticalCenter
        visible: (typeof Config !== "undefined" && Config.showDate) && clockRoot.displayDate !== ""
    }

    // 时间显示区
    Row {
        spacing: 1
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: clockRoot.displayTime
            color: "white"
            font.family: (clockRoot.chosenFont !== "") ? clockRoot.chosenFont : "Monospace"
            font.pixelSize: 18; font.weight: Font.Black
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter
            visible: (typeof Config !== "undefined" && Config.showSeconds) && clockRoot.displaySeconds !== ""
            Text { text: ":"; color: Qt.rgba(1, 1, 1, 0.35); font.family: "Monospace"; font.pixelSize: 11; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
            Text { text: clockRoot.displaySeconds.replace(/^:/, ""); color: Theme.network; font.family: "Monospace"; font.pixelSize: 11; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
        }

        Text {
            text: clockRoot.displayPeriod
            color: Qt.rgba(1, 1, 1, 0.55)
            font.family: clockRoot.chosenFont; font.pixelSize: 9; font.weight: Font.Black; font.capitalization: Font.AllUppercase
            visible: (typeof Config !== "undefined" && Config.timeFormat === "12h") && clockRoot.displayPeriod !== ""
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 2
        }
    }
}