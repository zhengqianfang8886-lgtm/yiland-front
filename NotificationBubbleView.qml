import QtQuick

Rectangle {
    id: notifBubbleRoot

    property bool active: false
    property string chosenFont: ""
    readonly property bool isHovered: bubbleHover.hovered

    readonly property var notifModel: (typeof Bridge !== "undefined") ? Bridge.notificationModel : null
    property int unreadCount: notifModel ? notifModel.unreadCount : 0
    property string avatarUrl: notifModel ? notifModel.latestAvatar : ""

    signal clicked()
    signal rightClicked()

    transformOrigin: (typeof Config !== "undefined" && Config.multiIslandExpandDirection === "left") ? Item.Right : Item.Left

    width: 48
    height: 36
    radius: height / 2
    clip: false

    color: Theme.bgCapsule
    border.color: notifBubbleRoot.isHovered ? Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.9) :
                  Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.35)
    border.width: 1

    readonly property bool shouldShow: active && (unreadCount > 0)

    // 🚀 核心：一旦不应显示，瞬间直接 visible = false，立刻彻底隐藏，0ms 无缩小动画
    visible: shouldShow
    opacity: shouldShow ? 1.0 : 0.0
    scale: shouldShow ? 1.0 : 0.0

    Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

    Behavior on opacity {
        NumberAnimation {
            duration: notifBubbleRoot.shouldShow ? 160 : 0
            easing.type: Easing.OutQuad
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: notifBubbleRoot.shouldShow ? 220 : 0
            easing.type: Easing.OutBack
            easing.overshoot: Theme.springOvershoot
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 30; height: 22; radius: 11
        color: Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.18)

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
                sourceSize.width: 44; sourceSize.height: 44
                asynchronous: true; cache: true
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

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: notifBubbleRoot.clicked()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: notifBubbleRoot.rightClicked()
    }
}