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

    color: Theme.bgCapsule
    border.color: bubbleHover.hovered ? Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.8) :
                  Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.35)
    border.width: 1

    readonly property bool shouldShow: active && (unreadCount > 0)
    opacity: shouldShow ? 1.0 : 0.0
    scale: shouldShow ? 1.0 : 0.2
    visible: opacity > 0.01

    Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }
    Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.springEasing; easing.overshoot: Theme.springOvershoot } }

    Rectangle {
        anchors.centerIn: parent
        width: 30; height: 22; radius: 11
        color: Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.18)
        
        // 🚀 幽灵渲染消除：折叠时关闭呼吸灯
        SequentialAnimation on opacity {
            running: notifBubbleRoot.shouldShow && notifBubbleRoot.opacity > 0.05
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 1200; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.9; duration: 1200; easing.type: Easing.InOutSine }
        }
    }

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
                
                // 🚀 头像显存约束
                sourceSize.width: 44
                sourceSize.height: 44
                asynchronous: true
                cache: true
                visible: status === Image.Ready
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
            anchors.fill: parent
            radius: 11
            color: "transparent"
            border.color: Theme.borderSubtle
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