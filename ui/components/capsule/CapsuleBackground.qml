// =========================================================================
// 📄 File: ui/components/capsule/CapsuleBackground.qml
// 🌟 胶囊背景材质层 (集成沉浸深潜光效与入眠反馈版)
// =========================================================================
import QtQuick

Item {
    id: bgRoot
    anchors.fill: parent
    z: 0

    property int capsuleRadius: 17
    property color accentColor: "transparent"
    property bool isHovered: false
    property bool isTucked: false

    readonly property bool hasAccent: accentColor.a > 0.001

    property real modePulseOpacity: 0.0
    property color modePulseColor: "#ffffff"
    property real tuckFlashOpacity: 0.0

    SequentialAnimation {
        id: modePulseAnim
        ParallelAnimation {
            NumberAnimation { target: bgRoot; property: "modePulseOpacity"; to: 0.85; duration: 120; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: bgRoot; property: "modePulseOpacity"; to: 0.0; duration: 320; easing.type: Easing.InOutQuad }
        }
    }

    // 🚀【入眠闪光反馈】：右键触发锁定时，边框瞬间闪烁紫罗兰色
    SequentialAnimation {
        id: tuckFlashAnim
        NumberAnimation { target: bgRoot; property: "tuckFlashOpacity"; to: 1.0; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: bgRoot; property: "tuckFlashOpacity"; to: 0.0; duration: 400; easing.type: Easing.InQuad }
    }

    function triggerModeHaptic(isAnchored) {
        modePulseColor = isAnchored ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.6)
        modePulseAnim.restart()
    }

    function triggerTuckFlash() {
        tuckFlashAnim.restart()
    }

    // 1. 实体黑底
    Rectangle {
        anchors.fill: parent
        radius: bgRoot.capsuleRadius
        color: "#08090d"
        antialiasing: true
        smooth: true

        border.color: bgRoot.hasAccent ? 
                      Qt.rgba(bgRoot.accentColor.r, bgRoot.accentColor.g, bgRoot.accentColor.b, 0.35) : 
                      Qt.rgba(255, 255, 255, 0.12)
        border.width: 1
    }

    // 2. 内部高光内衬
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, bgRoot.capsuleRadius - 1)
        color: "transparent"
        border.color: Qt.rgba(255, 255, 255, 0.05)
        border.width: 1
        antialiasing: true
    }

    // 3. 常态触感光环
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

    // 4. 入眠锁定闪光环 (紫罗兰色禅模式)
    Rectangle {
        anchors.fill: parent
        radius: bgRoot.capsuleRadius
        color: "transparent"
        border.color: "#a855f7" 
        border.width: 1.5
        opacity: bgRoot.tuckFlashOpacity
        visible: opacity > 0.01
        antialiasing: true
    }

    // 5. 🚀【深潜呼吸灯】：仅在隐藏态下于底部 6px 细缝处浮现的呼吸光带
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        anchors.horizontalCenter: parent.horizontalCenter
        height: 2
        radius: 1
        color: "#818cf8" // 靛蓝色静谧光带
        
        // 宽度动态展开
        width: bgRoot.isTucked ? Math.min(64, parent.width * 0.35) : 0
        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

        // 呼吸动画
        SequentialAnimation on opacity {
            running: bgRoot.isTucked
            loops: Animation.Infinite
            NumberAnimation { to: 0.85; duration: 1600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.15; duration: 1600; easing.type: Easing.InOutSine }
        }
    }
}