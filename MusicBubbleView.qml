// ==========================================
// 📄 File: MusicBubbleView.qml (去除彩色色调背景·纯净黑曜石版)
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

    width: 48 + (barsCount - 5) * 4
    height: 34
    radius: 17
    clip: true
    transformOrigin: Item.Right

    // 中央动效平滑接管
    Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveDecel } }

    antialiasing: true
    smooth: true
    
    // 🚀 核心修复 1：纯净黑曜石底色，绝不再泛任何彩色底调
    color: Theme.bgCapsule

    // 🚀 核心修复 2：彻底移除刺眼的彩色外框，回归纯正微光极细边
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

    // （已彻底删除原本中间那个发青蓝色的彩色背景光块 Rectangle）

    // 4 通道自然展开为 5~10 通道
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
    // 纯粹声学跳动柱（高光通透、背景纯净）
    // =========================================================================
    Row {
        id: waveRow
        anchors.centerIn: parent
        spacing: musicBubbleRoot.barsCount >= 9 ? 1.8 : 2.0
        height: 16

        Repeater {
            model: musicBubbleRoot.barsCount

            Item {
                id: barItem
                width: 2.8
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                readonly property real barVal: musicBubbleRoot.getBarScale(index, musicBubbleRoot.barsCount)
                readonly property real centerRatio: 1.0 - Math.abs((index / (musicBubbleRoot.barsCount - 1)) - 0.5) * 2.0

                Rectangle {
                    anchors.fill: parent
                    radius: 99
                    // 声波柱颜色：中心稍亮、两端沉稳，悬停时自然提亮
                    color: centerRatio > 0.6 ? 
                           (musicBubbleRoot.isHovered ? "#ffffff" : Qt.lighter(musicBubbleRoot.dominantColor, 1.25)) : 
                           (musicBubbleRoot.isHovered ? Qt.rgba(255, 255, 255, 0.85) : musicBubbleRoot.dominantColor)

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

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