// ==========================================
// 📄 File: capsule/CapsuleSpecularGlint.qml
// ==========================================
import QtQuick

Item {
    id: glintCanvas
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 14
    clip: true
    z: 3

    property bool isPureIdle: false
    property real capsuleWidth: parent.width

    visible: isPureIdle && opacity > 0.01
    opacity: isPureIdle ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }

    Rectangle {
        id: glintBar
        width: Math.max(55, Math.min(glintCanvas.capsuleWidth * 0.45, 90))
        height: 2.0
        radius: 1.0
        
        // 🌟 核心修复：彻底消灭 0.3 这样的小数偏移！设为 0，严格对齐顶层边框像素栅格
        y: 0

        property real travelProgress: 0.0
        // 两端各向内收缩 24px，确保天光永远只在平直顶线上滑行，绝对不踩进两端的圆角区！
        x: 24 + travelProgress * (glintCanvas.capsuleWidth - width - 48)

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1.0, 1.0, 1.0, glintBar.breathAlpha) }
            GradientStop { position: 1.0; color: "transparent" }
        }

        SequentialAnimation on travelProgress {
            running: glintCanvas.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0.0; to: 1.0; duration: 4200; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 600 }
            NumberAnimation { from: 1.0; to: 0.0; duration: 4200; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 600 }
        }

        property real breathAlpha: 0.45
        SequentialAnimation on breathAlpha {
            running: glintCanvas.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.65; duration: 2600; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 600 }
            NumberAnimation { to: 0.35; duration: 3800; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 1400 }
        }
    }
}