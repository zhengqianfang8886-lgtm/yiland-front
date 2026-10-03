import QtQuick

Rectangle {
    id: musicBubbleRoot

    property bool active: false
    property color dominantColor: Theme.media
    readonly property bool isHovered: bubbleHover.hovered

    // 真实 4 频段 FFT 频谱输入
    property real spec1: 0.2
    property real spec2: 0.2
    property real spec3: 0.2
    property real spec4: 0.2

    signal clicked()
    signal wheelInteracted()

    width: 48
    height: 34
    radius: 17
    clip: true
    transformOrigin: Item.Right

    color: Theme.bgCapsule
    border.width: 1
    // 自适应专辑色调
    border.color: isWheelActive ? dominantColor :
                  (musicBubbleRoot.isHovered ? Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, 0.85) :
                  Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, 0.35))
    Behavior on border.color { ColorAnimation { duration: 180 } }

    visible: active
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershoot } }

    property bool isWheelActive: false
    Timer {
        id: wheelActiveTimer
        interval: 650
        onTriggered: musicBubbleRoot.isWheelActive = false
    }

    Rectangle {
        anchors.centerIn: parent
        width: 26; height: 18; radius: 9
        color: (musicBubbleRoot.active || isWheelActive) ? Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, isWheelActive ? 0.28 : 0.14) : "transparent"
        Behavior on color { ColorAnimation { duration: 180 } }
    }

    // 4 频段实时跳动音波柱
    Row {
        id: waveRow
        anchors.centerIn: parent
        spacing: 2.8
        height: 18
        opacity: musicBubbleRoot.active ? 1.0 : 0.0

        Item {
            width: 2.6; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: musicBubbleRoot.dominantColor
                transform: Scale {
                    id: s1; origin.y: 8
                    yScale: Math.max(0.18, Math.min(1.0, musicBubbleRoot.spec1))
                    Behavior on yScale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
            }
        }

        Item {
            width: 2.6; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: Qt.lighter(musicBubbleRoot.dominantColor, 1.15)
                transform: Scale {
                    id: s2; origin.y: 8
                    yScale: Math.max(0.18, Math.min(1.0, musicBubbleRoot.spec2))
                    Behavior on yScale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
            }
        }

        Item {
            width: 2.6; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: musicBubbleRoot.dominantColor
                transform: Scale {
                    id: s3; origin.y: 8
                    yScale: Math.max(0.18, Math.min(1.0, musicBubbleRoot.spec3))
                    Behavior on yScale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
            }
        }

        Item {
            width: 2.6; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: Qt.lighter(musicBubbleRoot.dominantColor, 1.25)
                transform: Scale {
                    id: s4; origin.y: 8
                    yScale: Math.max(0.18, Math.min(1.0, musicBubbleRoot.spec4))
                    Behavior on yScale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
            }
        }
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: musicBubbleRoot.clicked() }

    // 🚀【核心优化】：零延迟滚轮捕获，直接调用 Bridge 的乐观预测
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            event.accepted = true
            musicBubbleRoot.isWheelActive = true
            wheelActiveTimer.restart()
            musicBubbleRoot.wheelInteracted()

            var delta = event.angleDelta.y > 0 ? 5 : -5
            if (typeof Bridge !== "undefined" && Bridge.adjustVolume) {
                Bridge.adjustVolume(delta)
            }
        }
    }
}