import QtQuick 2.15

Rectangle {
    id: timerBubbleRoot

    property string chosenFont: ""
    property bool active: false
    property string timerText: "25:00"
    property bool hasHours: false

    property bool isCountUp: false
    property real progress: 1.0
    property int remainingSeconds: 0
    property int totalSeconds: 0

    signal clicked()
    signal wheelAdjust(int deltaSec)

    readonly property color urgencyColor: {
        if (isCountUp) return "#38bdf8"
        if (!active) return "#f97316"
        if (remainingSeconds <= 60) return "#ef4444"
        if (remainingSeconds <= 300) return "#f43f5e"
        return "#f97316"
    }

    // 宽度适度舒展（84px / 104px），完美容纳放大后的数字
    width: hasHours ? 104 : 84
    height: 36
    radius: height / 2
    clip: true

    color: Qt.rgba(0.08, 0.08, 0.1, 0.96)
    border.width: 1
    border.color: timerBubbleHover.hovered ? Qt.lighter(urgencyColor, 1.2) : Qt.rgba(urgencyColor.r, urgencyColor.g, urgencyColor.b, 0.45)
    Behavior on border.color { ColorAnimation { duration: 200 } }

    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.2
    visible: opacity > 0.01

    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }

    Row {
        anchors.centerIn: parent
        spacing: 5.5

        // 等比放大的微型环形进度刻度（14x14）
        Canvas {
            id: ringCanvas
            width: 14
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            renderTarget: Canvas.Image

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var centerX = width / 2
                var centerY = height / 2
                var radius = width / 2 - 1.2

                // 底层刻度导轨
                ctx.beginPath()
                ctx.arc(centerX, centerY, radius, 0, 2 * Math.PI, false)
                ctx.lineWidth = 1.8
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.18)
                ctx.stroke()

                // 表层进度弧线
                if (timerBubbleRoot.progress > 0) {
                    ctx.beginPath()
                    var startAngle = -Math.PI / 2
                    var endAngle = startAngle + (2 * Math.PI * timerBubbleRoot.progress)
                    ctx.arc(centerX, centerY, radius, startAngle, endAngle, false)
                    ctx.lineWidth = 1.8
                    ctx.lineCap = "round"
                    ctx.strokeStyle = timerBubbleRoot.urgencyColor
                    ctx.stroke()
                }
            }

            Connections {
                target: timerBubbleRoot
                function onProgressChanged() { ringCanvas.requestPaint() }
                function onUrgencyColorChanged() { ringCanvas.requestPaint() }
            }
        }

        // 大字饱满的时间展示（16px / 14.5px）
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: timerBubbleRoot.timerText
            color: "white"
            font.family: (timerBubbleRoot.chosenFont !== "") ? timerBubbleRoot.chosenFont : "Monospace"
            font.pixelSize: timerBubbleRoot.hasHours ? 14.5 : 16
            font.weight: Font.Black
            font.letterSpacing: 0.3
        }
    }

    HoverHandler { id: timerBubbleHover; cursorShape: Qt.PointingHandCursor }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: timerBubbleRoot.clicked()

        onWheel: (wheel) => {
            if (timerBubbleRoot.active && !timerBubbleRoot.isCountUp) {
                timerBubbleRoot.wheelAdjust(wheel.angleDelta.y > 0 ? 60 : -60)
            }
        }
    }
}