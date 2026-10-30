// =========================================================================
// 📄 File: ui/components/capsule/CapsuleBackground.qml
// 🌟 纯正黑曜石材质 (彻底拔除顶部白线伪影 · 极简无暇 · 系统动力学边框版)
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

    property real pullY: 0.0
    property real pullRatio: 0.0
    property bool isTriggerPrimed: false

    readonly property bool hasAccent: accentColor.a > 0.001
    readonly property bool isStealth: (typeof Config !== "undefined" && Config.stealthTuckEnabled)

    property real modePulseOpacity: 0.0
    property color modePulseColor: "#ffffff"
    property real tuckFlashOpacity: 0.0

    SequentialAnimation {
        id: modePulseAnim
        ParallelAnimation {
            NumberAnimation { target: bgRoot; property: "modePulseOpacity"; to: 0.85; duration: Theme.animFast; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: bgRoot; property: "modePulseOpacity"; to: 0.0; duration: Theme.animNormal; easing.type: Easing.InOutQuad }
        }
    }

    SequentialAnimation {
        id: tuckFlashAnim
        NumberAnimation { target: bgRoot; property: "tuckFlashOpacity"; to: 1.0; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: bgRoot; property: "tuckFlashOpacity"; to: 0.0; duration: Theme.animSlow; easing.type: Easing.InQuad }
    }

    function triggerModeHaptic(isAnchored) {
        modePulseColor = isAnchored ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.6)
        modePulseAnim.restart()
    }

    function triggerTuckFlash() {
        if (!bgRoot.isStealth) {
            tuckFlashAnim.restart()
        }
    }

    // 1. 实体纯黑曜石底壳 (与屏幕顶沿完美咬合，零杂线)
    Rectangle {
        id: mainBody
        anchors.fill: parent
        radius: bgRoot.capsuleRadius
        color: "#08090d"
        antialiasing: true
        smooth: true

        border.color: {
            if (bgRoot.isTriggerPrimed) return "#c084fc"; // 落锁：清澈紫罗兰
            if (bgRoot.pullRatio > 0.05) {
                // 随着下拉拉力平滑柔和泛起微光
                return Qt.rgba(
                    (255 + (192 - 255) * bgRoot.pullRatio) / 255,
                    (255 + (132 - 255) * bgRoot.pullRatio) / 255,
                    (255 + (252 - 255) * bgRoot.pullRatio) / 255,
                    0.14 + 0.35 * Math.min(1.0, bgRoot.pullRatio)
                );
            }
            if (bgRoot.hasAccent) return Qt.rgba(bgRoot.accentColor.r, bgRoot.accentColor.g, bgRoot.accentColor.b, 0.45);
            return Qt.rgba(255, 255, 255, 0.14);
        }
        border.width: bgRoot.isTriggerPrimed ? 1.5 : 1

        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.width { NumberAnimation { duration: Theme.animInstant } }
    }

    // 2. 内部微倒角微光
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, bgRoot.capsuleRadius - 1)
        color: "transparent"
        border.color: bgRoot.isTriggerPrimed ? Qt.rgba(192 / 255, 132 / 255, 252 / 255, 0.35) : Qt.rgba(255, 255, 255, 0.05)
        border.width: 1
        antialiasing: true

        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    }

    // 3. 常态触感脉冲环
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

    // 4. 入眠锁定闪光环
    Rectangle {
        anchors.fill: parent
        radius: bgRoot.capsuleRadius
        color: "transparent"
        border.color: "#a855f7"
        border.width: 1.5
        opacity: (!bgRoot.isStealth) ? bgRoot.tuckFlashOpacity : 0.0
        visible: opacity > 0.01
        antialiasing: true
    }

    // 5. 深潜微缝呼吸带 (隐形模式下关闭)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        anchors.horizontalCenter: parent.horizontalCenter
        height: 2
        radius: 1
        color: "#818cf8"
        visible: bgRoot.isTucked && !bgRoot.isStealth
        width: visible ? Math.min(42, parent.width * 0.35) : 0
        Behavior on width { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

        SequentialAnimation on opacity {
            running: bgRoot.visible && bgRoot.isTucked && !bgRoot.isStealth
            loops: Animation.Infinite
            NumberAnimation { to: 0.85; duration: 1600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.15; duration: 1600; easing.type: Easing.InOutSine }
        }
    }
}