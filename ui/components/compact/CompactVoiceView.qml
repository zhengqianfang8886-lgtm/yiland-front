// ==========================================
// 📄 File: ui/components/compact/CompactVoiceView.qml
// 🌟 极光流体语音输入组件 (高敏液态波形 · 物理一键切断)
// ==========================================
import QtQuick

Item {
    id: voiceRoot
    anchors.fill: parent

    property string chosenFont: ""
    property real voiceLevel: 0.2
    property string streamText: ""
    property bool isListening: false

    signal stopRequested()

    clip: true
    visible: opacity > 0.001
    opacity: isListening ? 1.0 : 0.0
    scale: isListening ? 1.0 : 0.92

    Behavior on opacity { NumberAnimation { duration: 160 } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

    // 1. 左侧呼吸拾音环
    Item {
        id: micArea
        width: 32; height: 32
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            id: auraGlow
            anchors.centerIn: parent
            width: parent.width + 6
            height: parent.height + 6
            radius: width / 2
            color: "transparent"
            border.color: "#38bdf8"
            border.width: 1.5
            opacity: 0.3 + voiceRoot.voiceLevel * 0.7
            scale: 0.9 + voiceRoot.voiceLevel * 0.4

            Behavior on scale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
            Behavior on opacity { NumberAnimation { duration: 60 } }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.25)
            border.color: "#10b981"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "🎙️"
                font.pixelSize: 13
                scale: 1.0 + voiceRoot.voiceLevel * 0.25
                Behavior on scale { NumberAnimation { duration: 70 } }
            }
        }
    }

    // 2. 右侧物理一键切断按钮
    Rectangle {
        id: killBtn
        width: 24; height: 24; radius: 12
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        color: killTap.pressed ? "#b91c1c" : (killHover.hovered ? "#dc2626" : Qt.rgba(1, 1, 1, 0.12))
        border.color: killHover.hovered ? "#ef4444" : Qt.rgba(1, 1, 1, 0.2)
        border.width: 1
        scale: killTap.pressed ? 0.90 : 1.0

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: "white"
            font.pixelSize: 9
            font.weight: Font.Black
        }

        HoverHandler { id: killHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: killTap
            onTapped: voiceRoot.stopRequested()
        }
    }

    // 3. 中间 Siri 多频律动条 + 实时文字跑马灯
    Row {
        id: centerContentRow
        anchors.left: micArea.right
        anchors.leftMargin: 8
        anchors.right: killBtn.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        clip: true

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Repeater {
                model: [0.8, 1.2, 1.6, 1.1, 0.7]
                Rectangle {
                    width: 3
                    height: 16
                    radius: 1.5
                    color: index % 2 === 0 ? "#38bdf8" : "#a855f7"
                    anchors.verticalCenter: parent.verticalCenter

                    transform: Scale {
                        origin.y: 8
                        yScale: Math.max(0.2, Math.min(1.0, voiceRoot.voiceLevel * modelData))
                        Behavior on yScale { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                    }
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 32
            spacing: 1

            Text {
                text: voiceRoot.streamText ? voiceRoot.streamText : "正在聆听并转录..."
                color: voiceRoot.streamText ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                font.family: voiceRoot.chosenFont
                font.pixelSize: 11
                font.weight: Font.Bold
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: "端侧安全离线引擎 · 15s 静音自动切断"
                color: Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.75)
                font.family: voiceRoot.chosenFont
                font.pixelSize: 8
                font.weight: Font.DemiBold
            }
        }
    }
}