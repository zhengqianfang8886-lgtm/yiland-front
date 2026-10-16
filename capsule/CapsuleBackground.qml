// ==========================================
// 📄 File: capsule/CapsuleBackground.qml
// 🌟 100% 不透光纯黑实体底板 (完整圆弧防裁切版)
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
    property real clipGlowOpacity: 0.0

    SequentialAnimation {
        id: clipGlowAnim
        NumberAnimation { target: bgRoot; property: "clipGlowOpacity"; to: 0.95; duration: Theme.animInstant; easing.type: Easing.OutQuad }
        NumberAnimation { target: bgRoot; property: "clipGlowOpacity"; to: 0.0; duration: Theme.animSlow; easing.type: Easing.InOutQuad }
    }

    function triggerClipGlow() {
        clipGlowAnim.restart()
    }

    // 🚀【核心修复】：留出 1px 安全内缩边距，确保 1px 描边与抗锯齿弧度 100% 完整，永不被边界硬切！
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

    // 剪贴板高光外发光边缘
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, bgRoot.capsuleRadius - 1)
        color: "transparent"
        border.color: "#38bdf8"
        border.width: 1.5
        opacity: bgRoot.clipGlowOpacity
        visible: opacity > 0.01
        antialiasing: true
        smooth: true
    }
}