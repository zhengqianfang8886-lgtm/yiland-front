// ui/components/capsule/CapsuleBackground.qml
import QtQuick

Item {
    id: bgRoot
    anchors.fill: parent
    z: 0

    property int capsuleRadius: 17
    property color accentColor: "transparent"
    property bool isHovered: false

    readonly property bool hasAccent: accentColor.a > 0.001

    property real modePulseOpacity: 0.0
    property color modePulseColor: "#ffffff"

    SequentialAnimation {
        id: modePulseAnim
        ParallelAnimation {
            NumberAnimation { target: bgRoot; property: "modePulseOpacity"; to: 0.85; duration: 120; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: bgRoot; property: "modePulseOpacity"; to: 0.0; duration: 320; easing.type: Easing.InOutQuad }
        }
    }

    function triggerModeHaptic(isAnchored) {
        modePulseColor = isAnchored ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.6)
        modePulseAnim.restart()
    }

    // 1. 实体黑底（增加极度微弱的背景漫反射，不与壁纸生硬割裂）
    Rectangle {
        anchors.fill: parent
        radius: bgRoot.capsuleRadius
        color: "#08090d" // 稍带极微弱冷调的深黑
        antialiasing: true
        smooth: true

        // 🚀【核心改进】：去掉刺眼的实色粗线，改用高级半透明高光微边（即使有 accentColor，也只施加 25% 柔和微光）
        border.color: bgRoot.hasAccent ? 
                      Qt.rgba(bgRoot.accentColor.r, bgRoot.accentColor.g, bgRoot.accentColor.b, 0.35) : 
                      Qt.rgba(255, 255, 255, 0.12)
        border.width: 1
    }

    // 2. 内部 0.5px 仿玻璃高光内衬 (Inner Rim)
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, bgRoot.capsuleRadius - 1)
        color: "transparent"
        border.color: Qt.rgba(255, 255, 255, 0.05)
        border.width: 1
        antialiasing: true
    }

    // 3. 触感光环
    Rectangle {
        anchors.fill: parent
        radius: bgRoot.capsuleRadius
        color: "transparent"
        border.color: bgRoot.modePulseColor
        border.width: 1.5
        opacity: bgRoot.modePulseOpacity
        visible: opacity > 0.01
        antialiasing: true
    }
}