import QtQuick

Rectangle {
    id: notifBubbleRoot

    property bool active: false
    property int unreadCount: 0
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

    readonly property bool shouldShow: active && (unreadCount > 0)
    opacity: shouldShow ? 1.0 : 0.0
    scale: shouldShow ? 1.0 : 0.2
    visible: opacity > 0.01

    Behavior on border.color { ColorAnimation { duration: 180 } }
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }

    Rectangle {
        anchors.centerIn: parent
        width: 30; height: 22; radius: 11
        color: Qt.rgba(129, 140, 248, 0.18)
        SequentialAnimation on opacity {
            running: notifBubbleRoot.shouldShow
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 1200; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.9; duration: 1200; easing.type: Easing.InOutSine }
        }
    }

    // 🚀 头像裁切优化：内嵌圆形双层裁切，彻底消除头像图片是矩形时的尖角溢出
    Item {
        id: avatarWrapper
        anchors.centerIn: parent
        width: 22; height: 22

        Rectangle {
            id: avatarContainer
            anchors.fill: parent
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

        // 边缘圆弧修饰环，遮盖硬质锯齿
        Rectangle {
            anchors.fill: parent
            radius: 11
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
        }
    }

    // 未读消息数角标
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