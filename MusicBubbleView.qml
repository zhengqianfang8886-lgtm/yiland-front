// ==========================================
// 📄 File: MusicBubbleView.qml (5-10条动态自适应声波岛)
// ==========================================
import QtQuick

Rectangle {
    id: musicBubbleRoot

    property bool active: false
    property color dominantColor: Theme.media
    readonly property bool isHovered: bubbleHover.hovered

    // 4 通道底层音频输入源
    property real spec1: 0.2
    property real spec2: 0.2
    property real spec3: 0.2
    property real spec4: 0.2

    // 🚀【条数动态绑定】：直连配置，范围限制在 5 ~ 10 条
    readonly property int barsCount: {
        if (typeof Config !== "undefined" && Config.musicVisualizerBars !== undefined) {
            return Math.max(5, Math.min(10, Config.musicVisualizerBars))
        }
        return 5
    }

    signal clicked()
    signal wheelInteracted()

    // 🚀 宽度根据条数从 48px 平滑自适应拓展至 68px (每增加 1 条宽 +4px)
    width: 48 + (barsCount - 5) * 4
    height: 34
    radius: 17
    clip: false
    transformOrigin: Item.Right

    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    antialiasing: true
    smooth: true
    color: Theme.bgCapsule

    border.width: 1.8
    border.color: musicBubbleRoot.isHovered ? 
                  Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, 0.95) :
                  Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, 0.75)
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    visible: active
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: Theme.animSpring; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershootNormal } }

    // 中心微光底托 (尺寸随条数自适应拓展)
    Rectangle {
        anchors.centerIn: parent
        width: 28 + (musicBubbleRoot.barsCount - 5) * 4
        height: 20
        radius: 10
        color: Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, 0.16)
        Behavior on width { NumberAnimation { duration: 180 } }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // 🚀 核心频谱插值计算函数：将 4 频段自然展开为 N 个频段 (5~10)
    function getBarScale(index, total) {
        if (total <= 1) return Math.max(0.20, Math.min(1.0, spec1))
        var t = index / (total - 1)  // 0.0 ~ 1.0
        var pos = t * 3.0
        var i0 = Math.floor(pos)
        var i1 = Math.min(3, i0 + 1)
        var frac = pos - i0

        var sArr = [spec1, spec2, spec3, spec4]
        var baseVal = sArr[i0] * (1.0 - frac) + sArr[i1] * frac

        // 加入自然音频拱形共振包络 (中间声学增益略高，两端沉稳)
        var resonance = 1.0 + 0.16 * Math.sin(t * Math.PI)
        return Math.max(0.20, Math.min(1.0, baseVal * resonance))
    }

    // =========================================================================
    // 动态 N 频段纯音频声波柱阵列 (5 - 10 根)
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
                // 距离中心的距离比率 (0: 中心, 1: 两端)，用于呈现高光渐进
                readonly property real centerRatio: 1.0 - Math.abs((index / (musicBubbleRoot.barsCount - 1)) - 0.5) * 2.0

                Rectangle {
                    anchors.fill: parent
                    radius: 99
                    // 中心频段亮度更高，两端沉稳
                    color: centerRatio > 0.6 ? 
                           Qt.lighter(musicBubbleRoot.dominantColor, 1.25) : 
                           musicBubbleRoot.dominantColor

                    transform: Scale {
                        origin.y: 8
                        yScale: barItem.barVal
                        Behavior on yScale { NumberAnimation { duration: 85; easing.type: Easing.OutQuad } }
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