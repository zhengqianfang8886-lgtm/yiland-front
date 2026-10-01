import QtQuick 2.15

Rectangle {
    id: notifBubbleRoot

    property bool active: false
    property int unreadCount: 1
    property string avatarUrl: ""
    property string chosenFont: ""

    signal clicked()
    signal rightClicked()

    width: 48
    height: 36
    radius: height / 2
    clip: false

    color: Qt.rgba(0.08, 0.08, 0.1, 0.96)
    border.color: bubbleHover.hovered ? Qt.rgba(129, 140, 248, 0.8) : Qt.rgba(129, 140, 248, 0.35)
    border.width: 1

    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.2
    visible: opacity > 0.01

    Behavior on border.color { ColorAnimation { duration: 180 } }
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }

    Rectangle {
        anchors.centerIn: parent
        width: 30; height: 22; radius: 11
        color: Qt.rgba(129, 140, 248, 0.18)
        SequentialAnimation on opacity {
            running: notifBubbleRoot.active
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 1200; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.9; duration: 1200; easing.type: Easing.InOutSine }
        }
    }

    Rectangle {
        id: avatarContainer
        anchors.centerIn: parent
        width: 22; height: 22
        radius: 11
        color: avatarImg.visible ? "transparent" : "#4F46E5"
        clip: true

        Image {
            id: avatarImg
            anchors.fill: parent
            source: (notifBubbleRoot.avatarUrl && notifBubbleRoot.avatarUrl.length > 5) ? notifBubbleRoot.avatarUrl : ""
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            cache: false
            onStatusChanged: if (status === Image.Error) source = ""
        }

        Text {
            anchors.centerIn: parent
            text: "💬"
            font.pixelSize: 13
            visible: !avatarImg.visible
        }
    }

    Rectangle {
        anchors.top: parent.top; anchors.topMargin: -2
        anchors.right: parent.right; anchors.rightMargin: -2
        width: Math.max(16, countText.implicitWidth + 8)
        height: 16; radius: 8
        color: "#6366f1"
        border.color: "#18181b"
        border.width: 1.5
        visible: notifBubbleRoot.unreadCount > 0

        Text {
            id: countText
            anchors.centerIn: parent
            text: notifBubbleRoot.unreadCount > 99 ? "99+" : notifBubbleRoot.unreadCount
            color: "white"
            font.pixelSize: 9
            font.weight: Font.Black
            font.family: "Monospace"
        }
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                notifBubbleRoot.rightClicked()
            } else {
                notifBubbleRoot.clicked()
            }
        }
    }
}