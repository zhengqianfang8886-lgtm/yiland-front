// ==========================================
// 📄 File: capsule/CapsuleBackground.qml (触感呼吸动效完整版)
// ==========================================
import QtQuick

Item {
    id: bgRoot
    anchors.fill: parent
    z: 0

    property int capsuleRadius: 17
    property color accentColor: "transparent"
    property bool isHovered: false

    readonly property bool hasAccent: accentColor.a > 0.001

    // 🚀【专属触觉微反馈】：切换固定/隐藏时，边框产生一次极其通透自然的微光流动，纯物理材质反馈，无任何杂标
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

    // 对外触发切换动画的接口
    function triggerModeHaptic(isAnchored) {
        modePulseColor = isAnchored ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.6)
        modePulseAnim.restart()
    }

    // 1. 底板实体黑底
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, bgRoot.capsuleRadius - 1)
        color: "#0a0c12"
        border.color: bgRoot.hasAccent ? bgRoot.accentColor : Qt.rgba(255, 255, 255, 0.14)
        border.width: 1
        antialiasing: true
        smooth: true
    }

    // 2. 物理触感外边缘光环（零图标，仅凭光影告知用户状态）
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, bgRoot.capsuleRadius - 1)
        color: "transparent"
        border.color: bgRoot.modePulseColor
        border.width: 1.5
        opacity: bgRoot.modePulseOpacity
        visible: opacity > 0.01
        antialiasing: true
        smooth: true
    }
}