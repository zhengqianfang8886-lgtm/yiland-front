// ==========================================
// 📄 File: MusicBubbleView.qml
// 🌟 饱满实体声波柱 (3.6px 加粗质感版) · 纯正通透发光
// ==========================================
import QtQuick

Rectangle {
    id: musicBubbleRoot

    property bool active: false
    property color dominantColor: Theme.media
    readonly property bool isHovered: bubbleHover.hovered

    property real spec1: 0.2
    property real spec2: 0.2
    property real spec3: 0.2
    property real spec4: 0.2

    readonly property int barsCount: {
        if (typeof Config !== "undefined" && Config.musicVisualizerBars !== undefined) {
            return Math.max(5, Math.min(10, Config.musicVisualizerBars))
        }
        return 5
    }

    signal clicked()
    signal wheelInteracted()

    // 🚀 适应加粗后的条宽与间距，基底宽度提升至 52px
    width: 52 + (barsCount - 5) * 6
    height: 34
    radius: 17
    clip: true
    transformOrigin: Item.Right

    Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveDecel } }

    antialiasing: true
    smooth: true
    color: Theme.bgCapsule

    border.width: 1
    border.color: musicBubbleRoot.isHovered ? Qt.rgba(255, 255, 255, 0.35) : Theme.borderSubtle
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    visible: opacity > 0.001
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveFluid } }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animSpring
            easing.type: Theme.curveSpring
            easing.overshoot: Theme.springOvershootNormal
        }
    }

    function getBarScale(index, total) {
        if (total <= 1) return Math.max(0.20, Math.min(1.0, spec1))
        var t = index / (total - 1)
        var pos = t * 3.0
        var i0 = Math.floor(pos)
        var i1 = Math.min(3, i0 + 1)
        var frac = pos - i0

        var sArr = [spec1, spec2, spec3, spec4]
        var baseVal = sArr[i0] * (1.0 - frac) + sArr[i1] * frac
        var resonance = 1.0 + 0.16 * Math.sin(t * Math.PI)
        return Math.max(0.20, Math.min(1.0, baseVal * resonance))
    }

    // =========================================================================
    // 纯粹声学跳动柱（3.6px 加粗高光质感）
    // =========================================================================
    Row {
        id: waveRow
        anchors.centerIn: parent
        // 🚀 调整条间距：根据条数动态紧凑排布，确保呼吸感
        spacing: musicBubbleRoot.barsCount >= 8 ? 2.2 : 2.5
        height: 16

        Repeater {
            model: musicBubbleRoot.barsCount

            Item {
                id: barItem
                // 🚀【核心加粗】：从 2.8px 提升到 3.6px，饱满且圆润
                width: 3.6
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                readonly property real barVal: musicBubbleRoot.getBarScale(index, musicBubbleRoot.barsCount)
                readonly property real centerRatio: 1.0 - Math.abs((index / (musicBubbleRoot.barsCount - 1)) - 0.5) * 2.0

                // 1. 底层纯正发光色柱 (高饱和)
                Rectangle {
                    anchors.fill: parent
                    radius: 99
                    color: musicBubbleRoot.dominantColor

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    // 2. 自发光中心高光叠层
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "#ffffff"
                        opacity: {
                            if (musicBubbleRoot.isHovered) {
                                return barItem.centerRatio > 0.6 ? 0.70 : 0.35
                            }
                            return barItem.centerRatio > 0.6 ? 0.28 : 0.0
                        }
                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    }

                    transform: Scale {
                        origin.y: 8
                        yScale: barItem.barVal
                        Behavior on yScale { NumberAnimation { duration: Theme.animInstant; easing.type: Theme.curveFluid } }
                    }
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
            musicBubbleRoot.wheelInteracted()
            var step = (typeof Config !== "undefined" && Config.volumeStep !== undefined) ? Config.volumeStep : 5
            var delta = event.angleDelta.y > 0 ? step : -step
            if (typeof Bridge !== "undefined" && Bridge.adjustVolume) {
                Bridge.adjustVolume(delta)
            }
        }
    }
}