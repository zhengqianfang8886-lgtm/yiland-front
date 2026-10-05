// ==========================================
// 📄 File: MusicBubbleView.qml (相位错位·冷却余烬版)
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

    // 5 频段声学与打字心流响应
    readonly property real rawBar1: Math.max(0.20, Math.min(1.0, spec1))
    readonly property real rawBar2: Math.max(0.20, Math.min(1.0, spec2))
    readonly property real rawBar3: Math.max(0.20, Math.min(1.0, (spec5 > 0.2) ? spec3 : Math.max(spec2, spec3) * 1.15))
    readonly property real rawBar4: Math.max(0.20, Math.min(1.0, (spec5 > 0.2) ? spec4 : spec3))
    readonly property real rawBar5: Math.max(0.20, Math.min(1.0, (spec5 > 0.2) ? spec5 : spec4))

    // =========================================================================
    // 🌟 建议 3 核心机制：物理冷却余烬（Thermal Ember Decay）
    // 当按键停止或声学能量减退时，余热以指数阻尼（2.4 秒）缓缓消退，绝不骤然熄火
    // =========================================================================
    property real emberHeat: 0.0

    // 能量上升迅速汲热，能量跌落时由定时器以长阻尼释放
    onRawBar3Changed: {
        if (rawBar3 > 0.38) {
            emberHeat = Math.min(1.0, emberHeat + 0.35)
            emberCoolingTimer.stop()
        } else {
            emberCoolingTimer.restart()
        }
    }

    Timer {
        id: emberCoolingTimer
        interval: 180
        repeat: false
        onTriggered: emberDecayAnim.restart()
    }

    NumberAnimation {
        id: emberDecayAnim
        target: musicBubbleRoot
        property: "emberHeat"
        to: 0.0
        duration: 2400
        easing.type: Easing.OutCubic
    }

    // 带有余温阻尼的最终高度：即使 rawBar 掉回 0.20，仍保留淡淡的温润浮动
    readonly property real barVal1: Math.max(rawBar1, 0.20 + emberHeat * 0.10)
    readonly property real barVal2: Math.max(rawBar2, 0.20 + emberHeat * 0.14)
    readonly property real barVal3: Math.max(rawBar3, 0.20 + emberHeat * 0.18)
    readonly property real barVal4: Math.max(rawBar4, 0.20 + emberHeat * 0.14)
    readonly property real barVal5: Math.max(rawBar5, 0.20 + emberHeat * 0.10)

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
    // 🌟 建议 2 核心机制：副岛专属 6.2 秒微呼吸（带 0.8s 相位差，绝不与主岛机械同步）
    // =========================================================================
    property real dynamicBreathAlpha: 0.82

    SequentialAnimation on dynamicBreathAlpha {
        running: musicBubbleRoot.active
        loops: Animation.Infinite

        // 初始相位错位：启动时静默沉浸 800ms，避开主岛节拍点
        PauseAnimation { duration: 800 }
        // 缓慢舒展提升 (2.6 秒)
        NumberAnimation { to: 0.94; duration: 2600; easing.type: Easing.InOutQuad }
        // 微停顿 (0.4 秒)
        PauseAnimation { duration: 400 }
        // 缓和回落 (2.4 秒)
        NumberAnimation { to: 0.76; duration: 2400; easing.type: Easing.InOutSine }
    }

    border.width: 1.8
    border.color: isWheelActive ? dominantColor :
                  (musicBubbleRoot.isHovered ? Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, 0.95) :
                  Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, dynamicBreathAlpha))
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    visible: active
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: Theme.animSpring; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershootNormal } }

    property bool isWheelActive: false
    Timer {
        id: wheelActiveTimer
        interval: 650
        onTriggered: musicBubbleRoot.isWheelActive = false
    }

    // 建议 3：中心微光底托带“余烬渐褪”能力（emberHeat 延长温馨光照感）
    Rectangle {
        anchors.centerIn: parent
        width: 30; height: 20; radius: 10
        color: (musicBubbleRoot.active || isWheelActive) ?
               Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, isWheelActive ? 0.32 : (0.16 + emberHeat * 0.12)) :
               "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // 5 频段加粗音波柱（上升迅捷，回落平顺）
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
                    Behavior on yScale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
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
                    Behavior on yScale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
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
                    Behavior on yScale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
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
                    Behavior on yScale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
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
                    Behavior on yScale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
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