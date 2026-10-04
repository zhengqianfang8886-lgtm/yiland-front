// ==========================================
// 📄 File: compact/CompactOsdView.qml (灵动岛级硬件 HUD)
// ==========================================
import QtQuick
import QtQuick.Shapes
import "../control"

Item {
    id: osdRoot
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 12

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property string osdIcon: "🔊"
    property int osdValue: 50

    // 智能识别当前硬件类型
    readonly property string resolvedIconType: {
        if (osdIcon === "☀️") return "brightness"
        if (osdIcon === "🎙️" || osdIcon === "🚫") return "mic"
        return "volume"
    }

    readonly property bool isHardwareMuted: (osdIcon === "🔇" || osdIcon === "🚫")

    // 入场动效：柔和微光浮现与微弹性形变
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.06 } }

    // =========================================================================
    // 1. 左侧：纯矢量微光硬件图标（告别字符 Emoji 的模糊割裂）
    // =========================================================================
    Item {
        id: iconWrapper
        width: 14
        height: 14
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        ControlCenterIcon {
            anchors.fill: parent
            iconType: osdRoot.resolvedIconType
            isMuted: osdRoot.isHardwareMuted
            iconColor: osdRoot.isHardwareMuted ?
                       Theme.danger :
                       (osdRoot.resolvedIconType === "brightness" ?
                        Qt.rgba(254 / 255, 240 / 255, 138 / 255, 0.95) :
                        Qt.rgba(1, 1, 1, 0.90))
        }
    }

    // =========================================================================
    // 2. 右侧：精密数字或静音指示
    // =========================================================================
    Item {
        id: valueWrapper
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(30, valText.implicitWidth)
        height: parent.height

        Text {
            id: valText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: osdRoot.isHardwareMuted ? "静音" : (Math.min(100, Math.max(0, osdRoot.osdValue)) + "%")
            color: osdRoot.isHardwareMuted ? Theme.danger : "white"
            font.family: osdRoot.isHardwareMuted ? osdRoot.effectiveFont : osdRoot.displayFont
            font.pixelSize: osdRoot.isHardwareMuted ? 10 : 11
            font.weight: Font.Black
            font.letterSpacing: 0.3

            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    // =========================================================================
    // 3. 中间：7px 饱满灵动岛流体滑槽（告别 5px 细线）
    // =========================================================================
    Rectangle {
        id: sliderTrack
        anchors.left: iconWrapper.right
        anchors.leftMargin: 9
        anchors.right: valueWrapper.left
        anchors.rightMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        height: 7
        radius: 3.5

        // 深色半透明微光槽底
        color: Qt.rgba(1, 1, 1, 0.14)
        clip: true

        // 饱满填充进度流
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 3.5

            width: osdRoot.isHardwareMuted ? 0 : Math.round(parent.width * Math.min(1.0, Math.max(0.0, osdRoot.osdValue / 100.0)))

            // 亮度采用月光温润淡金白，音量采用极光透光白，静音为微红警示
            color: osdRoot.isHardwareMuted ?
                   Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.5) :
                   (osdRoot.resolvedIconType === "brightness" ?
                    Qt.rgba(254 / 255, 240 / 255, 138 / 255, 0.95) :
                    Qt.rgba(1, 1, 1, 0.95))

            Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
}