// ==========================================
// 📄 File: capsule/CapsuleBackground.qml
// 🌟 胶囊流体玻璃材质与光效背景层
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

    // 剪贴板复制微光脉冲
    SequentialAnimation {
        id: clipGlowAnim
        NumberAnimation { target: bgRoot; property: "clipGlowOpacity"; to: 0.95; duration: Theme.animInstant; easing.type: Easing.OutQuad }
        NumberAnimation { target: bgRoot; property: "clipGlowOpacity"; to: 0.0; duration: Theme.animSlow; easing.type: Easing.InOutQuad }
    }

    function triggerClipGlow() {
        clipGlowAnim.restart()
    }

    // 核心流体玻璃着色器
    ShaderEffect {
        id: liquidGlassEffect
        anchors.fill: parent

        property vector2d u_size: Qt.vector2d(bgRoot.width, bgRoot.height)
        property real u_radius: bgRoot.capsuleRadius
        property color u_accent: bgRoot.accentColor
        property real u_hasAccent: bgRoot.hasAccent ? 1.0 : 0.0
        property real u_isHovered: bgRoot.isHovered ? 1.0 : 0.0

        fragmentShader: "liquid_glass.frag.qsb"
    }

    // 剪贴板高光外发光边缘
    Rectangle {
        anchors.fill: parent
        radius: bgRoot.capsuleRadius
        color: "transparent"
        border.color: "#38bdf8"
        border.width: 1.5
        opacity: bgRoot.clipGlowOpacity
        visible: opacity > 0.01
    }
}