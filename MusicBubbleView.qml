// ==========================================
// 📄 File: MusicBubbleView.qml (流体水晶内发光版)
// ==========================================
import QtQuick

Rectangle {
    id: musicBubbleRoot

    property bool active: false
    property color dominantColor: Theme.media
    readonly property bool isHovered: bubbleHover.hovered

    // 频谱输入通道
    property real spec1: 0.2
    property real spec2: 0.2
    property real spec3: 0.2
    property real spec4: 0.2
    property real spec5: 0.2

    readonly property real barVal1: Math.max(0.20, Math.min(1.0, spec1))
    readonly property real barVal2: Math.max(0.20, Math.min(1.0, spec2))
    readonly property real barVal3: Math.max(0.20, Math.min(1.0, (spec5 > 0.2) ? spec3 : Math.max(spec2, spec3) * 1.15))
    readonly property real barVal4: Math.max(0.20, Math.min(1.0, (spec5 > 0.2) ? spec4 : spec3))
    readonly property real barVal5: Math.max(0.20, Math.min(1.0, (spec5 > 0.2) ? spec5 : spec4))

    signal clicked()
    signal wheelInteracted()

    width: 48
    height: 34
    radius: 17
    clip: false
    transformOrigin: Item.Right

    antialiasing: true
    smooth: true
    color: Theme.bgCapsule

    // =========================================================================
    // 🌟 外沿极净主光圈（纯粹几何轮廓，剔除一切生硬黑边，边缘极其顺滑）
    // =========================================================================
    border.width: 1.8
    border.color: isWheelActive ? dominantColor :
                  (musicBubbleRoot.isHovered ? Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, 0.95) :
                  Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, 0.85))
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    visible: active
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    // 统一 Spring 物理曲线
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: Theme.animSpring; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershootNormal } }

    property bool isWheelActive: false
    Timer {
        id: wheelActiveTimer
        interval: 650
        onTriggered: musicBubbleRoot.isWheelActive = false
    }

    // =========================================================================
    // 🌟 内嵌次级柔光环（Inset Halo，向内部黑底弥散，产生饱满的流体光泽）
    // =========================================================================
    Rectangle {
        id: innerGlowRim
        anchors.fill: parent
        anchors.margins: 1.8
        radius: Math.max(1, musicBubbleRoot.radius - 1.8)
        color: "transparent"
        border.width: 1.0
        antialiasing: true
        smooth: true
        z: 0
        border.color: Qt.rgba(musicBubbleRoot.dominantColor.r, musicBubbleRoot.dominantColor.g, musicBubbleRoot.dominantColor.b, 0.32)
        visible: musicBubbleRoot.active || isWheelActive
    }

    // 中心微光底托
    Rectangle {
        anchors.centerIn: parent
        width: 30; height: 20; radius: 10
        color: (musicBubbleRoot.active || isWheelActive) ? Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, isWheelActive ? 0.32 : 0.18) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // 5 频段加粗音波柱
    Row {
        id: waveRow
        anchors.centerIn: parent
        spacing: 2.0
        height: 16
        opacity: musicBubbleRoot.active ? 1.0 : 0.0

        Item {
            width: 3.0; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: musicBubbleRoot.dominantColor
                transform: Scale {
                    origin.y: 8
                    yScale: musicBubbleRoot.barVal1
                    Behavior on yScale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
            }
        }

        Item {
            width: 3.0; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: Qt.lighter(musicBubbleRoot.dominantColor, 1.15)
                transform: Scale {
                    origin.y: 8
                    yScale: musicBubbleRoot.barVal2
                    Behavior on yScale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
            }
        }

        Item {
            width: 3.0; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: Qt.lighter(musicBubbleRoot.dominantColor, 1.30)
                transform: Scale {
                    origin.y: 8
                    yScale: musicBubbleRoot.barVal3
                    Behavior on yScale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
            }
        }

        Item {
            width: 3.0; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: Qt.lighter(musicBubbleRoot.dominantColor, 1.15)
                transform: Scale {
                    origin.y: 8
                    yScale: musicBubbleRoot.barVal4
                    Behavior on yScale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
            }
        }

        Item {
            width: 3.0; height: 16; anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: 99; color: musicBubbleRoot.dominantColor
                transform: Scale {
                    origin.y: 8
                    yScale: musicBubbleRoot.barVal5
                    Behavior on yScale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
            }
        }
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: musicBubbleRoot.clicked() }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            event.accepted = true
            musicBubbleRoot.isWheelActive = true
            wheelActiveTimer.restart()
            musicBubbleRoot.wheelInteracted()

            var step = (typeof Config !== "undefined" && Config.volumeStep !== undefined) ? Config.volumeStep : 5
            var delta = event.angleDelta.y > 0 ? step : -step
            if (typeof Bridge !== "undefined" && Bridge.adjustVolume) {
                Bridge.adjustVolume(delta)
            }
        }
    }
}