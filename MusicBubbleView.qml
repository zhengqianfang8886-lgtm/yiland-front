import QtQuick

Rectangle {
    id: musicBubbleRoot

    property bool active: false
    signal clicked()

    width: 48
    height: 36
    radius: height / 2
    clip: true

    transformOrigin: Item.Right

    color: Qt.rgba(0.08, 0.08, 0.1, 0.96)
    border.color: bubbleHover.hovered ? Qt.rgba(34, 197, 94, 0.6) : Qt.rgba(1, 1, 1, 0.15)
    border.width: 1

    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation {
            duration: musicBubbleRoot.active ? 180 : 140
            easing.type: Easing.OutQuad
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: musicBubbleRoot.active ? 240 : 160
            easing.type: musicBubbleRoot.active ? Easing.OutBack : Easing.InQuad
            easing.overshoot: musicBubbleRoot.active ? 1.18 : 1.0
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 26; height: 18; radius: 9
        color: musicBubbleRoot.active ? Qt.rgba(34, 197, 94, 0.12) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Row {
        id: waveRow
        anchors.centerIn: parent
        spacing: 2.8
        height: 18
        opacity: musicBubbleRoot.active ? 1.0 : 0.0

        Item {
            width: 2.6; height: parent.height
            Rectangle {
                anchors.centerIn: parent; width: parent.width; radius: 99; color: "#22c55e"; height: 3
                SequentialAnimation on height {
                    running: musicBubbleRoot.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 13; duration: 260; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 6;  duration: 210; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 11; duration: 240; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 3;  duration: 280; easing.type: Easing.InOutSine }
                }
            }
        }

        Item {
            width: 2.6; height: parent.height
            Rectangle {
                anchors.centerIn: parent; width: parent.width; radius: 99; color: "#34d399"; height: 3
                SequentialAnimation on height {
                    running: musicBubbleRoot.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 6;  duration: 200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 15; duration: 270; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 4;  duration: 220; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 12; duration: 250; easing.type: Easing.InOutQuad }
                }
            }
        }

        Item {
            width: 2.6; height: parent.height
            Rectangle {
                anchors.centerIn: parent; width: parent.width; radius: 99; color: "#22c55e"; height: 3
                SequentialAnimation on height {
                    running: musicBubbleRoot.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 16; duration: 280; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 8;  duration: 220; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 14; duration: 260; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 4;  duration: 230; easing.type: Easing.InOutSine }
                }
            }
        }

        Item {
            width: 2.6; height: parent.height
            Rectangle {
                anchors.centerIn: parent; width: parent.width; radius: 99; color: "#34d399"; height: 3
                SequentialAnimation on height {
                    running: musicBubbleRoot.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 5;  duration: 190; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 12; duration: 240; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 4;  duration: 200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 10; duration: 250; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }

    MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onClicked: musicBubbleRoot.clicked()
    }
}