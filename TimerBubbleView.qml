import QtQuick
import QtQuick.Shapes

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

        // 🚀 核心优化：采用 QtQuick.Shapes GPU 顶点硬件加速管线，取代 Canvas CPU 软绘
        Shape {
            id: ringShape
            width: 14
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            layer.enabled: true
            layer.samples: 4 // 开启硬件 MSAA 多重采样抗锯齿

            // 底层导轨
            ShapePath {
                strokeColor: Qt.rgba(1, 1, 1, 0.18)
                strokeWidth: 1.8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: 7; centerY: 7
                    radiusX: 5.8; radiusY: 5.8
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            // 表层动态进度弧
            ShapePath {
                strokeColor: timerBubbleRoot.urgencyColor
                strokeWidth: 1.8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: 7; centerY: 7
                    radiusX: 5.8; radiusY: 5.8
                    startAngle: -90
                    sweepAngle: Math.max(0.1, 360.0 * Math.min(1.0, Math.max(0.0, timerBubbleRoot.progress)))
                }
            }
        }

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