// ==========================================
// 📄 File: compact/CompactOsdView.qml (流体物理滑轨·紧凑自适应版)
// ==========================================
import QtQuick
import QtQuick.Shapes

Item {
    id: osdRoot
    anchors.fill: parent
    // 紧贴胶囊内边距，完全服从胶囊现有物理宽度
    anchors.leftMargin: 8
    anchors.rightMargin: 8

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property string osdIcon: "🔊"
    property int osdValue: 50

    readonly property bool isHardwareMuted: (osdIcon === "🔇" || osdIcon === "🚫")
    readonly property int clampedValue: Math.min(100, Math.max(0, osdValue))

    onOsdValueChanged: {
        speakerPulseScale = 1.15
        pulseCooldownTimer.restart()
    }

    property real speakerPulseScale: 1.0
    Behavior on speakerPulseScale {
        NumberAnimation {
            duration: Theme.animInstant
            easing.type: Theme.curveDecel
        }
    }

    Timer {
        id: pulseCooldownTimer
        interval: 35
        repeat: false
        onTriggered: osdRoot.speakerPulseScale = 1.0
    }

    // 1. 左侧喇叭图标（紧凑 15px）
    Item {
        id: iconArea
        width: 15
        height: 15
        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        transformOrigin: Item.Center
        scale: osdRoot.speakerPulseScale

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            // 喇叭锥体
            ShapePath {
                fillColor: osdRoot.isHardwareMuted ? Theme.danger : "#ffffff"
                strokeColor: "transparent"
                startX: 1.5; startY: 5.0
                PathLine { x: 4.2; y: 5.0 }
                PathLine { x: 7.5; y: 2.2 }
                PathLine { x: 7.5; y: 12.8 }
                PathLine { x: 4.2; y: 10.0 }
                PathLine { x: 1.5; y: 10.0 }
                PathLine { x: 1.5; y: 5.0 }
            }

            // 低音量弧
            ShapePath {
                strokeColor: (!osdRoot.isHardwareMuted && osdRoot.clampedValue > 0) ? "#ffffff" : "transparent"
                strokeWidth: 1.2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 9.5; startY: 5.5
                PathArc { x: 9.5; y: 9.5; radiusX: 2.6; radiusY: 2.6; useLargeArc: false }
            }

            // 高音量弧
            ShapePath {
                strokeColor: (!osdRoot.isHardwareMuted && osdRoot.clampedValue >= 50) ? "#ffffff" : "transparent"
                strokeWidth: 1.2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 12.0; startY: 3.5
                PathArc { x: 12.0; y: 11.5; radiusX: 5.2; radiusY: 5.2; useLargeArc: false }
            }

            // 静音斜杠
            ShapePath {
                strokeColor: osdRoot.isHardwareMuted ? Theme.danger : "transparent"
                strokeWidth: 1.3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 9.0; startY: 4.5
                PathLine { x: 13.5; y: 10.5 }
                PathMove { x: 13.5; y: 4.5 }
                PathLine { x: 9.0; y: 10.5 }
            }
        }
    }

    // 2. 右侧定宽百分比（紧凑 26px）
    Item {
        id: valueWrapper
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: parent.height

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: osdRoot.isHardwareMuted ? "静音" : (osdRoot.clampedValue + "%")
            color: osdRoot.isHardwareMuted ? Theme.danger : Qt.rgba(1, 1, 1, 0.85)
            font.family: osdRoot.isHardwareMuted ? osdRoot.effectiveFont : osdRoot.displayFont
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            renderType: Text.QtRendering
        }
    }

    // 3. 中间流体滑轨（左右锚定填满剩余空间，胶囊多长它就多长，不推挤外壳）
    Rectangle {
        id: sliderTrack
        anchors.left: iconArea.right
        anchors.leftMargin: 6
        anchors.right: valueWrapper.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.16)
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 3

            width: osdRoot.isHardwareMuted ? 0 : Math.round(parent.width * (osdRoot.clampedValue / 100.0))
            color: osdRoot.isHardwareMuted ? Theme.danger : "#ffffff"

            Behavior on width {
                NumberAnimation { duration: Theme.animInstant; easing.type: Theme.curveDecel }
            }
            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }
        }
    }
}