import QtQuick

Rectangle {
    id: musicBubbleRoot

    property bool active: false
    readonly property bool isHovered: bubbleHover.hovered

    signal clicked()

    width: 48
    height: 36
    radius: height / 2
    clip: true

    transformOrigin: Item.Right

    color: Theme.bgCapsule
    border.color: musicBubbleRoot.isHovered ? Qt.rgba(Theme.media.r, Theme.media.g, Theme.media.b, 0.8) : Theme.borderSubtle
    border.width: 1

    // 🚀 核心：非 active 瞬间直接 visible = false，立刻彻底隐藏，0ms 无缩小动画
    visible: active
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    // 进场保留萌出动效；退场 duration 为 0，绝对不播放缩小动画
    Behavior on opacity {
        NumberAnimation {
            duration: musicBubbleRoot.active ? 160 : 0
            easing.type: Easing.OutQuad
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: musicBubbleRoot.active ? 220 : 0
            easing.type: Easing.OutBack
            easing.overshoot: Theme.springOvershoot
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 26; height: 18; radius: 9
        color: musicBubbleRoot.active ? Qt.rgba(Theme.media.r, Theme.media.g, Theme.media.b, 0.12) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    readonly property bool isActuallyRendering: musicBubbleRoot.active && musicBubbleRoot.visible

    Row {
        id: waveRow
        anchors.centerIn: parent
        spacing: 2.8
        height: 18
        opacity: musicBubbleRoot.active ? 1.0 : 0.0

        Item {
            width: 2.6; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: Theme.media
                transform: Scale { id: s1; origin.y: 8; yScale: 0.2 }
                SequentialAnimation {
                    running: musicBubbleRoot.isActuallyRendering
                    loops: Animation.Infinite
                    NumberAnimation { target: s1; property: "yScale"; to: 0.85; duration: 260; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: s1; property: "yScale"; to: 0.38; duration: 210; easing.type: Easing.InOutSine }
                    NumberAnimation { target: s1; property: "yScale"; to: 0.70; duration: 240; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: s1; property: "yScale"; to: 0.20; duration: 280; easing.type: Easing.InOutSine }
                }
            }
        }

        Item {
            width: 2.6; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: Theme.network
                transform: Scale { id: s2; origin.y: 8; yScale: 0.2 }
                SequentialAnimation {
                    running: musicBubbleRoot.isActuallyRendering
                    loops: Animation.Infinite
                    NumberAnimation { target: s2; property: "yScale"; to: 0.40; duration: 200; easing.type: Easing.InOutSine }
                    NumberAnimation { target: s2; property: "yScale"; to: 0.95; duration: 270; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: s2; property: "yScale"; to: 0.25; duration: 220; easing.type: Easing.InOutSine }
                    NumberAnimation { target: s2; property: "yScale"; to: 0.75; duration: 250; easing.type: Easing.InOutQuad }
                }
            }
        }

        Item {
            width: 2.6; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: Theme.media
                transform: Scale { id: s3; origin.y: 8; yScale: 0.2 }
                SequentialAnimation {
                    running: musicBubbleRoot.isActuallyRendering
                    loops: Animation.Infinite
                    NumberAnimation { target: s3; property: "yScale"; to: 1.00; duration: 280; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: s3; property: "yScale"; to: 0.50; duration: 220; easing.type: Easing.InOutSine }
                    NumberAnimation { target: s3; property: "yScale"; to: 0.88; duration: 260; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: s3; property: "yScale"; to: 0.25; duration: 230; easing.type: Easing.InOutSine }
                }
            }
        }

        Item {
            width: 2.6; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: Theme.network
                transform: Scale { id: s4; origin.y: 8; yScale: 0.2 }
                SequentialAnimation {
                    running: musicBubbleRoot.isActuallyRendering
                    loops: Animation.Infinite
                    NumberAnimation { target: s4; property: "yScale"; to: 0.30; duration: 190; easing.type: Easing.InOutSine }
                    NumberAnimation { target: s4; property: "yScale"; to: 0.78; duration: 240; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: s4; property: "yScale"; to: 0.25; duration: 200; easing.type: Easing.InOutSine }
                    NumberAnimation { target: s4; property: "yScale"; to: 0.65; duration: 250; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        onTapped: musicBubbleRoot.clicked()
    }
}