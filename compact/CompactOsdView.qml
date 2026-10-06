// ==========================================
// 📄 File: compact/CompactOsdView.qml
// 🌟 纯正苹果美学 · 纯白精密微流体 OSD 滑轨
// ==========================================
import QtQuick
import QtQuick.Shapes
import "../control"

Item {
    id: osdRoot
    anchors.fill: parent
    // 左右留白严格对齐灵动岛光学安全边距
    anchors.leftMargin: 16
    anchors.rightMargin: 16

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property string osdIcon: "🔊"
    property int osdValue: 50

    readonly property string resolvedIconType: {
        if (osdIcon === "☀️") return "brightness"
        if (osdIcon === "🎙️" || osdIcon === "🚫") return "mic"
        return "volume"
    }

    readonly property bool isHardwareMuted: (osdIcon === "🔇" || osdIcon === "🚫")

    // =========================================================================
    // 1. 左侧：纯矢量硬件图标（苹果白 / 静音红）
    // =========================================================================
    Item {
        id: iconWrapper
        width: 16
        height: 16
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        ControlCenterIcon {
            anchors.fill: parent
            iconType: osdRoot.resolvedIconType
            isMuted: osdRoot.isHardwareMuted
            // 🚀 彻底剔除刺眼杂色，常态纯白，静音优雅警示红
            iconColor: osdRoot.isHardwareMuted ?
                       Theme.danger :
                       Qt.rgba(1, 1, 1, 0.90)
        }
    }

    // =========================================================================
    // 2. 右侧：定宽等宽百分比（消除跳宽，层级细腻克制）
    // =========================================================================
    Item {
        id: valueWrapper
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: parent.height

        Text {
            id: valText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: osdRoot.isHardwareMuted ? "静音" : (Math.min(100, Math.max(0, osdRoot.osdValue)) + "%")
            color: osdRoot.isHardwareMuted ? Theme.danger : Qt.rgba(1, 1, 1, 0.85)
            font.family: osdRoot.isHardwareMuted ? osdRoot.effectiveFont : osdRoot.displayFont
            // 🚀 严格整型字号，中等字重，极简不笨重
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            renderType: Text.QtRendering
        }
    }

    // =========================================================================
    // 3. 🚀【核心重塑】：7px 苹果精密纤细微流体滑轨（Pure White Sleek Track）
    // =========================================================================
    Rectangle {
        id: sliderTrack
        anchors.left: iconWrapper.right
        anchors.leftMargin: 12
        anchors.right: valueWrapper.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 7
        radius: 3.5
        // 苹果标准半透明黑曜磨砂底槽
        color: Qt.rgba(1, 1, 1, 0.16)
        clip: true

        // 纯白高阶微流体填充（彻底消除怪异平顶白线）
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 3.5

            width: osdRoot.isHardwareMuted ? 0 : Math.round(parent.width * Math.min(1.0, Math.max(0.0, osdRoot.osdValue / 100.0)))

            // 🚀 核心色彩重塑：苹果经典纯白（Muted 时切为优雅浅红）
            color: osdRoot.isHardwareMuted ?
                   Theme.danger :
                   "#ffffff"

            Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
}