// ==========================================
// 📄 File: HardwareBubbleView.qml (一气呵成无分批收缩·果冻微震版)
// ==========================================
import QtQuick

Item {
    id: typingBubbleRoot

    property bool isTyping: false
    property color typingThemeColor: "#38bdf8"
    property real spec1: 0.0
    property real spec2: 0.0
    property real spec3: 0.0
    property real spec4: 0.0
    property real kps: 0.0

    property bool active: true
    readonly property bool isHovered: bubbleHover.hovered

    readonly property real intensity: Math.max(0.0, Math.min(1.0, kps / 10.0))
    readonly property bool isIdle: intensity < 0.02 && !isTyping

    property bool inRageState: false
    onIntensityChanged: {
        if (!inRageState && intensity >= 0.85) inRageState = true
        else if (inRageState && intensity < 0.68) inRageState = false
    }

    onInRageStateChanged: {
        if (inRageState) rageSingleBurstAnim.restart()
    }

    // 🚀【核心机制 1：零分批一气呵成尺寸收缩】
    readonly property int baseWidth: 56
    // 当强度进入末尾微小区间 (intensity < 0.12) 时，直接吸附至基准 56px，坚决不分批逐像素跳变
    readonly property int targetWidth: (isIdle || intensity < 0.12) ? baseWidth : Math.round(baseWidth + intensity * 14)
    readonly property int islandHeight: 34
    readonly property int radius: 17
    readonly property bool isExpanded: false

    width: targetWidth
    height: islandHeight
    clip: false
    transformOrigin: Item.Left

    // 🚀 核心动效：膨胀时微弹性，收缩时绝对严禁反弹(overshoot: 1.0)，一顺到底
    Behavior on width {
        NumberAnimation {
            duration: typingBubbleRoot.width < typingBubbleRoot.targetWidth ? 130 : 210
            easing.type: Easing.OutCubic
            easing.overshoot: 1.0
        }
    }

    visible: active
    opacity: active ? 1.0 : 0.0

    // 🚀【核心机制 2：Rage 暴走 0.8px 机械果冻微震颤】
    property real jitterX: 0.0

    SequentialAnimation {
        id: rageJitterAnim
        loops: Animation.Infinite
        running: typingBubbleRoot.inRageState
        NumberAnimation { target: typingBubbleRoot; property: "jitterX"; to: 0.8; duration: 32; easing.type: Easing.InOutQuad }
        NumberAnimation { target: typingBubbleRoot; property: "jitterX"; to: -0.8; duration: 32; easing.type: Easing.InOutQuad }
        NumberAnimation { target: typingBubbleRoot; property: "jitterX"; to: 0.0; duration: 32; easing.type: Easing.InOutQuad }
        onStopped: typingBubbleRoot.jitterX = 0.0
    }

    ShaderEffect {
        id: liquidGlassEffect
        anchors.fill: parent
        anchors.horizontalCenterOffset: typingBubbleRoot.jitterX
        z: 0

        property vector2d u_size: Qt.vector2d(typingBubbleRoot.width, typingBubbleRoot.height)
        property real u_radius: typingBubbleRoot.radius
        property color u_accent: typingBubbleRoot.typingThemeColor
        property real u_hasAccent: typingBubbleRoot.isIdle ? 0.0 : Math.min(1.0, 0.4 + typingBubbleRoot.intensity * 0.6)
        property real u_isHovered: typingBubbleRoot.isHovered ? 1.0 : 0.0

        fragmentShader: "liquid_glass.frag.qsb"
    }

    Rectangle {
        id: rageBurstRing
        anchors.fill: parent
        anchors.horizontalCenterOffset: typingBubbleRoot.jitterX
        radius: typingBubbleRoot.radius
        color: "transparent"
        border.color: typingBubbleRoot.typingThemeColor
        border.width: 1.5
        visible: opacity > 0.001
        opacity: 0.0
        scale: 1.0
        z: 1

        ParallelAnimation {
            id: rageSingleBurstAnim
            NumberAnimation { target: rageBurstRing; property: "scale"; from: 1.0; to: 1.34; duration: 460; easing.type: Easing.OutCubic }
            NumberAnimation { target: rageBurstRing; property: "opacity"; from: 0.85; to: 0.0; duration: 460; easing.type: Easing.OutQuad }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: typingBubbleRoot.jitterX
        width: Math.min(parent.width - 12, 36 + typingBubbleRoot.intensity * 16)
        height: 16 + typingBubbleRoot.intensity * 8
        radius: 11
        z: 1
        color: Qt.rgba(typingThemeColor.r, typingThemeColor.g, typingThemeColor.b, 
                       typingBubbleRoot.isIdle ? 0.0 : (0.08 + typingBubbleRoot.intensity * 0.18))

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on width { NumberAnimation { duration: 160 } }
    }

    Item {
        id: keyboardContainer
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        anchors.horizontalCenterOffset: typingBubbleRoot.jitterX
        width: Math.min(parent.width - 14, 38 + typingBubbleRoot.intensity * 8)
        height: 18
        z: 2

        Behavior on width { NumberAnimation { duration: 160 } }

        Row {
            anchors.centerIn: parent
            spacing: 2.2 + typingBubbleRoot.intensity * 1.2
            Behavior on spacing { NumberAnimation { duration: 160 } }

            component KeyCap: Rectangle {
                id: capRoot
                property real strokeRatio: 0.0
                readonly property real maxStrokePx: 1.8 + typingBubbleRoot.intensity * 1.2
                readonly property real targetY: Math.round(strokeRatio * maxStrokePx)

                width: 8.2; height: 13.5
                radius: 2.5
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: capRoot.targetY

                Behavior on anchors.verticalCenterOffset {
                    NumberAnimation {
                        duration: capRoot.anchors.verticalCenterOffset < capRoot.targetY ? 40 : 180
                        easing.type: capRoot.anchors.verticalCenterOffset < capRoot.targetY ? Easing.OutQuad : Easing.OutCubic
                    }
                }

                color: {
                    if (strokeRatio > 0.06) {
                        return Qt.rgba(typingThemeColor.r, typingThemeColor.g, typingThemeColor.b, 
                                       0.20 + strokeRatio * (0.35 + typingBubbleRoot.intensity * 0.25))
                    }
                    return Qt.rgba(1, 1, 1, 0.08)
                }

                border.color: strokeRatio > 0.06 ? 
                              Qt.rgba(typingThemeColor.r, typingThemeColor.g, typingThemeColor.b, 0.45 + strokeRatio * 0.55) : 
                              Qt.rgba(1, 1, 1, 0.14)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 90 } }
                Behavior on border.color { ColorAnimation { duration: 90 } }

                Rectangle {
                    anchors.top: parent.top; anchors.topMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 2; height: 1; radius: 0.5
                    color: Qt.rgba(1, 1, 1, capRoot.strokeRatio > 0.1 ? (0.4 + typingBubbleRoot.intensity * 0.4) : 0.22)
                }
            }

            KeyCap { strokeRatio: typingBubbleRoot.spec1 }
            KeyCap { strokeRatio: typingBubbleRoot.spec2 }
            KeyCap { strokeRatio: typingBubbleRoot.spec3 }
            KeyCap { strokeRatio: typingBubbleRoot.spec4 }
        }
    }

    Rectangle {
        id: typingCaret
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4.8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: typingBubbleRoot.jitterX
        z: 2

        width: typingBubbleRoot.isIdle ? 10 : (12 + typingBubbleRoot.intensity * 30)
        height: 1.6
        radius: 0.8
        clip: true

        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { 
                position: 0.25; 
                color: Qt.rgba(typingBubbleRoot.typingThemeColor.r, typingBubbleRoot.typingThemeColor.g, typingBubbleRoot.typingThemeColor.b, typingBubbleRoot.isIdle ? 0.25 : 0.65) 
            }
            GradientStop { 
                position: 0.50; 
                color: typingBubbleRoot.inRageState ? "#ffffff" : typingBubbleRoot.typingThemeColor 
            }
            GradientStop { 
                position: 0.75; 
                color: Qt.rgba(typingBubbleRoot.typingThemeColor.r, typingBubbleRoot.typingThemeColor.g, typingBubbleRoot.typingThemeColor.b, typingBubbleRoot.isIdle ? 0.25 : 0.65) 
            }
            GradientStop { position: 1.0; color: "transparent" }
        }

        SequentialAnimation on opacity {
            running: typingBubbleRoot.isIdle
            loops: Animation.Infinite
            NumberAnimation { to: 0.20; duration: 1500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.60; duration: 1500; easing.type: Easing.InOutSine }
        }
    }

    HoverHandler {
        id: bubbleHover
        cursorShape: Qt.ArrowCursor
    }
}