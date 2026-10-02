import QtQuick

Rectangle {
    id: timerBubbleRoot

    property string chosenFont: ""
    property bool active: false
    readonly property bool isHovered: timerBubbleHover.hovered

    property string timerText: "25:00"
    property bool hasHours: false
    property bool isCountUp: false
    property real progress: 1.0
    property int remainingSeconds: 0
    property int totalSeconds: 0

    signal clicked()
    signal wheelAdjust(int deltaSec)

    transformOrigin: Item.Left

    readonly property color urgencyColor: {
        if (isCountUp) return Theme.stopwatch
        if (!active) return Theme.timer
        if (remainingSeconds <= 60) return "#ef4444"
        if (remainingSeconds <= 300) return "#f97316"
        return Theme.timer
    }

    width: hasHours ? 104 : 88
    height: 34
    radius: height / 2
    clip: true

    color: Theme.bgCapsule
    border.width: 1
    border.color: timerBubbleRoot.isHovered ? Qt.rgba(urgencyColor.r, urgencyColor.g, urgencyColor.b, 0.5) : Theme.borderSubtle
    Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

    visible: active
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

    Behavior on opacity {
        NumberAnimation {
            duration: timerBubbleRoot.active ? 160 : 0
            easing.type: Easing.OutQuad
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: timerBubbleRoot.active ? 220 : 0
            easing.type: Easing.OutBack
            easing.overshoot: Theme.springOvershoot
        }
    }

    onProgressChanged: progressCanvas.requestPaint()
    onUrgencyColorChanged: progressCanvas.requestPaint()

    Row {
        anchors.centerIn: parent
        spacing: 7

        Canvas {
            id: progressCanvas
            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Threaded

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)

                var centerX = width / 2
                var centerY = height / 2
                var radius = 6.8
                var strokeW = 2.0

                ctx.beginPath()
                ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI, false)
                ctx.strokeStyle = "rgba(255, 255, 255, 0.15)"
                ctx.lineWidth = strokeW
                ctx.lineCap = "round"
                ctx.stroke()

                var p = Math.min(1.0, Math.max(0.0, timerBubbleRoot.progress))
                if (p > 0.005) {
                    var startAngle = -0.5 * Math.PI
                    var endAngle = startAngle + (2 * Math.PI * p)
                    ctx.beginPath()
                    ctx.arc(centerX, centerY, radius, startAngle, endAngle, false)
                    ctx.strokeStyle = timerBubbleRoot.urgencyColor.toString()
                    ctx.lineWidth = strokeW
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
            }
        }

        // 🚀 核心优化：计时器副岛文字全面采用 Font.Black
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: timerBubbleRoot.timerText
            color: "white"
            font.family: (timerBubbleRoot.chosenFont !== "") ? timerBubbleRoot.chosenFont : "Monospace"
            font.pixelSize: timerBubbleRoot.hasHours ? 13 : 15
            font.weight: Font.Black
            font.letterSpacing: 0.5
        }
    }

    HoverHandler { id: timerBubbleHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        onTapped: timerBubbleRoot.clicked()
    }
    WheelHandler {
        onWheel: (event) => {
            if (timerBubbleRoot.active && !timerBubbleRoot.isCountUp) {
                timerBubbleRoot.wheelAdjust(event.angleDelta.y > 0 ? 60 : -60)
            }
        }
    }
}