// ==========================================
// 📄 File: capsule/CapsuleSpecularGlint.qml (彻底根除毛边·安全平直区流光版)
// ==========================================
import QtQuick

Item {
    id: glintCanvas
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 10
    clip: true
    z: 3

    property bool isPureIdle: false
    property real capsuleWidth: parent.width
    property real capsuleRadius: 17

    // 🚀【核心机制 1】：严格计算胶囊顶部的安全平直区间，绝不触碰两端圆角
    readonly property real flatStart: capsuleRadius + 8
    readonly property real flatEnd: capsuleWidth - capsuleRadius - 8
    readonly property real flatLength: Math.max(0, flatEnd - flatStart)

    // 当平直长度低于 60px（即单时间微胶囊紧凑态）时，完全静默关闭，杜绝任何切角毛边
    readonly property bool canShowGlint: isPureIdle && (flatLength >= 60)

    // 光斑宽度严格按平直区比例缩放，杜绝死锁 55px
    readonly property real barWidth: Math.max(24, Math.min(flatLength * 0.35, 60))
    readonly property real travelSpan: Math.max(0, flatLength - barWidth)

    visible: opacity > 0.001
    opacity: canShowGlint ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

    Rectangle {
        id: glintBar
        width: Math.round(glintCanvas.barWidth)
        height: 1.2
        radius: 0.6

        // 🚀【核心机制 2】：垂直坐标内嵌在边框内壁（1.5px），绝不直接骑在最外层 y:0 制造毛边
        y: 1.5

        property real travelProgress: 0.0

        // 严格在平直安全区内往返，两端留足缓冲，物理上绝对无法滑到圆弧处
        x: Math.round(glintCanvas.flatStart + travelProgress * glintCanvas.travelSpan)

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1.0, 1.0, 1.0, glintBar.breathAlpha) }
            GradientStop { position: 1.0; color: "transparent" }
        }

        SequentialAnimation on travelProgress {
            running: glintCanvas.canShowGlint
            loops: Animation.Infinite
            NumberAnimation { from: 0.0; to: 1.0; duration: 3800; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 500 }
            NumberAnimation { from: 1.0; to: 0.0; duration: 3800; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 500 }
        }

        property real breathAlpha: 0.35
        SequentialAnimation on breathAlpha {
            running: glintCanvas.canShowGlint
            loops: Animation.Infinite
            NumberAnimation { to: 0.55; duration: 2200; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 400 }
            NumberAnimation { to: 0.20; duration: 3200; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 1000 }
        }
    }
}