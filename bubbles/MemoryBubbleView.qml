// ==========================================
// 📄 File: MemoryBubbleView.qml (硬件加速纯净版)
// ==========================================
import QtQuick
import QtQuick.Shapes

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

    Row {
        anchors.centerIn: parent
        spacing: 6

        // 🚀 核心优化：纯 GPU 硬件光栅化 Shape 节点，完全剥离 Canvas 2D
        Shape {
            id: gaugeShape
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            layer.enabled: true
            layer.samples: 4

            // 1. 底层静止灰色背景环
            ShapePath {
                strokeWidth: 2.6
                strokeColor: Qt.rgba(1, 1, 1, 0.18)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: 10
                    centerY: 10
                    radiusX: 7.0
                    radiusY: 7.0
                    startAngle: -90
                    sweepAngle: 360
                }
            }

            // 2. 动态负载有色刻度环（完全由 QML 属性绑定驱动更新）
            ShapePath {
                strokeWidth: 2.6
                strokeColor: memoryBubbleRoot.loadColor
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: 10
                    centerY: 10
                    radiusX: 7.0
                    radiusY: 7.0
                    startAngle: -90
                    sweepAngle: 360 * Math.min(1.0, Math.max(0.0, memoryBubbleRoot.memoryPercent / 100.0))
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