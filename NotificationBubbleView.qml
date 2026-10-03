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

    // 🚀 1. 严格统一全岛 34px 标准高度，彻底消除 2px 错位；宽度随数字智能舒展
    height: 34
    radius: 17
    width: notifContentRow.implicitWidth + 18
    clip: true

    color: Theme.bgCapsule
    border.width: 1
    border.color: notifBubbleRoot.isHovered ?
                  Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.85) :
                  Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.35)

    readonly property bool shouldShow: active && (unreadCount > 0)

    visible: shouldShow
    opacity: shouldShow ? 1.0 : 0.0
    scale: shouldShow ? 1.0 : 0.0

    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
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

    // 背景柔光呼吸
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 6
        height: parent.height - 6
        radius: (height) / 2
        color: Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.12)

        SequentialAnimation on opacity {
            running: notifBubbleRoot.shouldShow && notifBubbleRoot.opacity > 0.05
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 1200; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.9; duration: 1200; easing.type: Easing.InOutSine }
        }
    }

    // 🚀 2. 内嵌自包含排列：正圆头像 + 数字微药丸，完全收拢在岛体内
    Row {
        id: notifContentRow
        anchors.centerIn: parent
        spacing: 6

        // 正圆头像容器（开启硬件级多重采样裁剪，坚决杜绝平底直角漏出）
        Item {
            id: avatarWrapper
            width: 22; height: 22
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: avatarContainer
                anchors.fill: parent
                radius: 11
                color: avatarImg.visible ? "transparent" : "#4F46E5"
                layer.enabled: true
                layer.samples: 4
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
                    text: {
                        if (avatarImg.visible) return ""
                        return "💬"
                    }
                    color: "white"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    visible: !avatarImg.visible
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 11
                color: "transparent"
                border.color: Qt.rgba(255, 255, 255, 0.25)
                border.width: 1
            }
        }

        // 🚀 3. 发光数字微药丸（纯岛内布局，再也不会被窗口遮罩削去一半）
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 18
            radius: 9
            width: Math.max(18, countText.implicitWidth + 8)
            color: notifBubbleRoot.isHovered ? "#4f46e5" : "#6366f1"
            border.color: Qt.rgba(255, 255, 255, 0.3)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                id: countText
                anchors.centerIn: parent
                text: notifBubbleRoot.unreadCount > 99 ? "99+" : notifBubbleRoot.unreadCount
                color: "white"
                font.pixelSize: 11
                font.weight: Font.Black
                font.family: (notifBubbleRoot.chosenFont !== "") ? notifBubbleRoot.chosenFont : "Monospace"
            }
        }
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }

    // 左键点击：展开通知大卡片
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: notifBubbleRoot.clicked()
    }

    // 🚀 4. 右键点击：一键标为全部已读，小岛平滑隐去
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            if (notifBubbleRoot.notifModel && notifBubbleRoot.notifModel.markAllRead) {
                notifBubbleRoot.notifModel.markAllRead()
            }
            notifBubbleRoot.rightClicked()
        }
    }
}