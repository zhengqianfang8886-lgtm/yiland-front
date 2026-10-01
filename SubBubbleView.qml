import QtQuick

Rectangle {
    id: subBubbleRoot

    property string chosenFont: ""
    property string displayTime: ""
    property string status: "Paused"
    property bool isSplit: false

    property bool timerRunning: false
    property string timerText: "25:00"

    signal clicked()
    signal wheelAdjust(int deltaSec)

    radius: height / 2
    color: Qt.rgba(0.08, 0.08, 0.1, 0.96)

    border.color: timerRunning ?
                  (subBubbleHover.hovered ? "#fb923c" : Qt.rgba(249, 115, 22, 0.5)) :
                  (subBubbleHover.hovered ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.15))
    border.width: 1

    opacity: isSplit ? 1.0 : 0.0
    scale: isSplit ? 1.0 : 0.4
    visible: opacity > 0.01

    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
    Behavior on border.color { ColorAnimation { duration: 200 } }
    Behavior on scale {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutBack
            easing.overshoot: 1.08
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 4
        visible: subBubbleRoot.timerRunning

        Text {
            text: "⏱"
            font.pixelSize: 12
            color: "#fb923c"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: subBubbleRoot.timerText
            color: "white"
            font.family: (subBubbleRoot.chosenFont !== "") ? subBubbleRoot.chosenFont : "Monospace"
            font.pixelSize: 13
            font.weight: Font.Black
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 3
        visible: !subBubbleRoot.timerRunning

        Text {
            text: subBubbleRoot.displayTime
            color: "white"
            font.family: (subBubbleRoot.chosenFont !== "") ? subBubbleRoot.chosenFont : "Monospace"
            font.pixelSize: 12
            font.weight: Font.Black
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            spacing: 1.8
            anchors.verticalCenter: parent.verticalCenter
            visible: subBubbleRoot.status === "Playing"

            Repeater {
                model: [9, 5, 10]
                Rectangle {
                    width: 1.6; radius: 99; color: "#22c55e"
                    height: 3
                    SequentialAnimation on height {
                        running: subBubbleRoot.isSplit && subBubbleRoot.status === "Playing"
                        loops: Animation.Infinite
                        NumberAnimation { to: modelData; duration: 260 + index * 45; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 3; duration: 300 + index * 40; easing.type: Easing.InOutQuad }
                    }
                }
            }
        }
    }

    HoverHandler {
        id: subBubbleHover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: subBubbleRoot.clicked()

        onWheel: (wheel) => {
            if (subBubbleRoot.timerRunning) {
                subBubbleRoot.wheelAdjust(wheel.angleDelta.y > 0 ? 60 : -60)
            }
        }
    }
}