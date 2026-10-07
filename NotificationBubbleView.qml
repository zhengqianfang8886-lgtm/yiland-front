// ==========================================
// 📄 File: NotificationBubbleView.qml (中央动效驱动版)
// ==========================================
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

    visible: opacity > 0.001
    opacity: shouldShow ? 1.0 : 0.0
    scale: shouldShow ? 1.0 : 0.0

    // 中央动效接管
    Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveDecel } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    Behavior on opacity {
        NumberAnimation {
            duration: notifBubbleRoot.shouldShow ? Theme.animNormal : Theme.animFast
            easing.type: Theme.curveFluid
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: notifBubbleRoot.shouldShow ? Theme.animSpring : Theme.animFast
            easing.type: notifBubbleRoot.shouldShow ? Theme.curveSpring : Theme.curveDecel
            easing.overshoot: Theme.springOvershootNormal
        }
    }

    // 呼吸柔光底托
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 6
        height: parent.height - 6
        radius: height / 2
        color: Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.12)

        SequentialAnimation on opacity {
            running: notifBubbleRoot.shouldShow && notifBubbleRoot.opacity > 0.1
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: Theme.animSlow * 4; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.90; duration: Theme.animSlow * 4; easing.type: Easing.InOutSine }
        }
    }

    Row {
        id: notifContentRow
        anchors.centerIn: parent
        spacing: 6

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
                    text: avatarImg.visible ? "" : "💬"
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

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 18
            radius: 9
            width: Math.max(18, countText.implicitWidth + 8)
            color: notifBubbleRoot.isHovered ? "#4f46e5" : "#6366f1"
            border.color: Qt.rgba(255, 255, 255, 0.3)
            border.width: 1

            Behavior on color { ColorAnimation { duration: Theme.animInstant } }

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

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: notifBubbleRoot.clicked()
    }

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