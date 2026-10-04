// ==========================================
// 📄 File: compact/CompactOsdView.qml
// ==========================================
import QtQuick
import QtQuick.Shapes
import "../control"

Item {
    id: osdRoot
    anchors.fill: parent
    // 🚀【核心对齐】：与常态时钟左右两端视觉起始线完全重合，消除两端元素位移突跳
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
    // 1. 左侧：纯矢量硬件图标
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
            iconColor: osdRoot.isHardwareMuted ?
                       Theme.danger :
                       (osdRoot.resolvedIconType === "brightness" ?
                        "#facc15" :
                        Qt.rgba(1, 1, 1, 0.95))
        }
    }

    // =========================================================================
    // 2. 右侧：饱满数字指示 (提升字号，与时钟大数字视觉密度一致)
    // =========================================================================
    Item {
        id: valueWrapper
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(32, valText.implicitWidth)
        height: parent.height

        Text {
            id: valText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: osdRoot.isHardwareMuted ? "静音" : (Math.min(100, Math.max(0, osdRoot.osdValue)) + "%")
            color: osdRoot.isHardwareMuted ? Theme.danger : "white"
            font.family: osdRoot.isHardwareMuted ? osdRoot.effectiveFont : osdRoot.displayFont
            font.pixelSize: osdRoot.isHardwareMuted ? 10 : 12
            font.weight: Font.Black
            font.letterSpacing: 0.3
            renderType: Text.QtRendering
        }
    }

    // =========================================================================
    // 3. 🚀【核心重塑】：12px 饱满灵动岛高光流体滑槽 (彻底消除空旷塌陷感)
    // =========================================================================
    Rectangle {
        id: sliderTrack
        anchors.left: iconWrapper.right
        anchors.leftMargin: 10
        anchors.right: valueWrapper.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 12  // 🚀 从 7px 提升至 12px，大幅提升视觉占空比
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.12)
        clip: true

        // 饱满液面填充
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 6

            width: osdRoot.isHardwareMuted ? 0 : Math.round(parent.width * Math.min(1.0, Math.max(0.0, osdRoot.osdValue / 100.0)))

            color: osdRoot.isHardwareMuted ?
                   Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.6) :
                   (osdRoot.resolvedIconType === "brightness" ?
                    "#fbbf24" :
                    "#38bdf8")

            Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            // 滑轨内部微光高光条 (增加立体感)
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1.5
                radius: 0.75
                color: Qt.rgba(1, 1, 1, 0.35)
            }
        }
    }
}