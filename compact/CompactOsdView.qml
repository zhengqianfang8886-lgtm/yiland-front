// ==========================================
// 📄 File: compact/CompactOsdView.qml
// 🌟 纯正苹果美学 · 声学微震脉冲 · 流体开阔音量滑轨
// ==========================================
import QtQuick
import QtQuick.Shapes

Item {
    id: osdRoot
    anchors.fill: parent
    anchors.leftMargin: 14
    anchors.rightMargin: 14

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property string osdIcon: "🔊"
    property int osdValue: 50

    readonly property bool isHardwareMuted: (osdIcon === "🔇" || osdIcon === "🚫")
    readonly property int clampedValue: Math.min(100, Math.max(0, osdValue))

    // 每次音量变动触发声学微脉冲震颤
    onOsdValueChanged: {
        speakerPulseAnim.stop()
        speakerPulseAnim.start()
    }

    // =========================================================================
    // 1. 左侧：原生苹果声学喇叭（随音量弧线动态响应 + 触觉微震）
    // =========================================================================
    Item {
        id: iconArea
        width: 18
        height: 18
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        transformOrigin: Item.Center

        SequentialAnimation {
            id: speakerPulseAnim
            NumberAnimation { target: iconArea; property: "scale"; to: 1.18; duration: 18; easing.type: Easing.OutQuad }
            NumberAnimation { target: iconArea; property: "scale"; to: 1.0; duration: 60; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            // 1.1 喇叭锥体
            ShapePath {
                fillColor: osdRoot.isHardwareMuted ? Theme.danger : "#ffffff"
                strokeColor: "transparent"
                startX: 2.5; startY: 6.2
                PathLine { x: 5.5; y: 6.2 }
                PathLine { x: 9.0; y: 3.2 }
                PathLine { x: 9.0; y: 14.8 }
                PathLine { x: 5.5; y: 11.8 }
                PathLine { x: 2.5; y: 11.8 }
                PathLine { x: 2.5; y: 6.2 }
            }

            // 1.2 低音量弧 (>= 1% 显示)
            ShapePath {
                strokeColor: (!osdRoot.isHardwareMuted && osdRoot.clampedValue > 0) ? "#ffffff" : "transparent"
                strokeWidth: 1.3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 11.2; startY: 6.8
                PathArc { x: 11.2; y: 11.2; radiusX: 3.0; radiusY: 3.0; useLargeArc: false }
            }

            // 1.3 中音量弧 (>= 34% 显示)
            ShapePath {
                strokeColor: (!osdRoot.isHardwareMuted && osdRoot.clampedValue >= 34) ? "#ffffff" : "transparent"
                strokeWidth: 1.3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 13.5; startY: 5.0
                PathArc { x: 13.5; y: 13.0; radiusX: 5.5; radiusY: 5.5; useLargeArc: false }
            }

            // 1.4 高音量弧 (>= 67% 显示)
            ShapePath {
                strokeColor: (!osdRoot.isHardwareMuted && osdRoot.clampedValue >= 67) ? "#ffffff" : "transparent"
                strokeWidth: 1.3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 15.8; startY: 3.2
                PathArc { x: 15.8; y: 14.8; radiusX: 8.0; radiusY: 8.0; useLargeArc: false }
            }

            // 1.5 静音斜杠
            ShapePath {
                strokeColor: osdRoot.isHardwareMuted ? Theme.danger : "transparent"
                strokeWidth: 1.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 11.0; startY: 6.0
                PathLine { x: 15.0; y: 12.0 }
                PathMove { x: 15.0; y: 6.0 }
                PathLine { x: 11.0; y: 12.0 }
            }
        }
    }

    // =========================================================================
    // 2. 右侧：克制定宽百分比（严格整型字号，消除跳宽）
    // =========================================================================
    Item {
        id: valueWrapper
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: parent.height

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: osdRoot.isHardwareMuted ? "静音" : (osdRoot.clampedValue + "%")
            color: osdRoot.isHardwareMuted ? Theme.danger : Qt.rgba(1, 1, 1, 0.85)
            font.family: osdRoot.isHardwareMuted ? osdRoot.effectiveFont : osdRoot.displayFont
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            renderType: Text.QtRendering
        }
    }

    // =========================================================================
    // 3. 中间：110px+ 极开阔苹果流体大胶囊滑轨（Fluid Capsule Track）
    // =========================================================================
    Rectangle {
        id: sliderTrack
        anchors.left: iconArea.right
        anchors.leftMargin: 12
        anchors.right: valueWrapper.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 8
        radius: 4
        color: Qt.rgba(1, 1, 1, 0.16)
        clip: true

        // 纯白高阶微流体填充（苹果原汁原味）
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            radius: 4

            width: osdRoot.isHardwareMuted ? 0 : Math.round(parent.width * (osdRoot.clampedValue / 100.0))
            color: osdRoot.isHardwareMuted ? Theme.danger : "#ffffff"

            Behavior on width {
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 140 }
            }
        }
    }
}