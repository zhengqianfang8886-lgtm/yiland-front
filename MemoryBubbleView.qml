// ==========================================
// 📄 File: MemoryBubbleView.qml (阻尼平滑监控岛·中央动效版)
// ==========================================
import QtQuick

Rectangle {
    id: memoryBubbleRoot

    property bool active: true
    property int memoryPercent: 0
    property string memoryUsedGb: "0G"
    property string memoryTotalGb: "0G"

    readonly property bool isHovered: bubbleHover.hovered
    signal clicked()

    readonly property color loadColor: {
        if (memoryPercent >= 85) return Theme.danger
        if (memoryPercent >= 65) return Theme.clock
        return Theme.media
    }

    width: 78
    height: 34
    radius: 17
    clip: true

    color: Theme.bgCapsule
    border.width: 1
    border.color: memoryBubbleRoot.isHovered ? Qt.rgba(loadColor.r, loadColor.g, loadColor.b, 0.85) : Theme.borderSubtle
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

    onMemoryPercentChanged: gaugeCanvas.requestPaint()
    onLoadColorChanged: gaugeCanvas.requestPaint()

    Row {
        anchors.centerIn: parent
        spacing: 6

        Canvas {
            id: gaugeCanvas
            width: 20; height: 20
            anchors.verticalCenter: parent.verticalCenter
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Threaded

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)

                var centerX = width / 2
                var centerY = height / 2
                var radius = 7.0
                var strokeW = 3.0

                ctx.beginPath()
                ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI, false)
                ctx.strokeStyle = "rgba(255, 255, 255, 0.18)"
                ctx.lineWidth = strokeW
                ctx.lineCap = "round"
                ctx.stroke()

                var p = Math.min(1.0, Math.max(0.0, memoryBubbleRoot.memoryPercent / 100.0))
                if (p > 0.01) {
                    var startAngle = -0.5 * Math.PI
                    var endAngle = startAngle + (2 * Math.PI * p)
                    ctx.beginPath()
                    ctx.arc(centerX, centerY, radius, startAngle, endAngle, false)
                    ctx.strokeStyle = memoryBubbleRoot.loadColor.toString()
                    ctx.lineWidth = strokeW
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: memoryBubbleRoot.isHovered ? memoryBubbleRoot.memoryUsedGb : (memoryBubbleRoot.memoryPercent + "%")
            color: "white"
            font.family: "Monospace"
            font.pixelSize: 13
            font.weight: Font.Black
            font.letterSpacing: 0.5
        }
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: memoryBubbleRoot.clicked() }
}