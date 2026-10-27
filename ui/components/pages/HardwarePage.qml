// ==========================================
// 📄 File: ui/components/pages/HardwarePage.qml
// 🌟 硬件控制页 (滑条绝对定位赋值 · 彻底根除暴冲爆音版)
// ==========================================
import QtQuick

Item {
    id: hwPageRoot
    anchors.fill: parent

    property string chosenFont: ""
    readonly property string effectiveFont: chosenFont !== "" ? chosenFont : Theme.activeFont
    readonly property string displayFont: Theme.displayMonoFont

    property int currentVolume: (typeof Bridge !== "undefined" && Bridge.currentVolume !== undefined) ? Bridge.currentVolume : 50
    property int currentBrightness: (typeof Bridge !== "undefined" && Bridge.currentBrightness !== undefined) ? Bridge.currentBrightness : 100
    property bool isVolMuted: false
    property bool isMicMuted: false

    signal requestSettings()

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onHardwareMuteStateChanged(volMuted, micMuted) {
            hwPageRoot.isVolMuted = volMuted
            hwPageRoot.isMicMuted = micMuted
        }
        function onVolumeChanged(val) {
            if (hwPageRoot.currentVolume === val) return;
            hwPageRoot.currentVolume = val
        }
        function onBrightnessChanged(val) { 
            if (hwPageRoot.currentBrightness === val) return;
            hwPageRoot.currentBrightness = val 
        }
        function onOsdTriggered(icon, label, val) {
            if (label === "Volume") {
                if (hwPageRoot.currentVolume === val) return;
                hwPageRoot.currentVolume = val
            } else if (label === "Display") {
                if (hwPageRoot.currentBrightness === val) return;
                hwPageRoot.currentBrightness = val
            }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // 1. 顶部快捷工具条
        Item {
            width: parent.width
            height: 24

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                width: micContentRow.implicitWidth + 14
                radius: 12
                color: micTap.pressed ? Qt.rgba(1, 1, 1, 0.22) :
                       (hwPageRoot.isMicMuted ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.25) :
                       (micHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)))
                border.color: hwPageRoot.isMicMuted ? Theme.danger : (micHover.hovered ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.12))
                border.width: 1

                Row {
                    id: micContentRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text { text: "🎙️"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: hwPageRoot.isMicMuted ? "麦克风已静音" : "麦克风拾音中"
                        color: hwPageRoot.isMicMuted ? Theme.danger : "white"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: hwPageRoot.effectiveFont
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: micHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: micTap
                    onTapped: if (typeof Bridge !== "undefined") Bridge.toggleHardwareMute(2)
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                width: setContentRow.implicitWidth + 14
                radius: 12
                color: setTap.pressed ? Qt.rgba(1, 1, 1, 0.22) : (setHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08))
                border.color: setHover.hovered ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.6) : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                Row {
                    id: setContentRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text { text: "⚙️"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "偏好设置 ↗"
                        color: "white"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: hwPageRoot.effectiveFont
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: setHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: setTap
                    onTapped: hwPageRoot.requestSettings()
                }
            }
        }

        // 2. Display 亮度条
        Column {
            width: parent.width
            spacing: 5

            Item {
                width: parent.width
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Display"
                    color: "white"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.family: hwPageRoot.effectiveFont
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: hwPageRoot.currentBrightness + "%"
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font.pixelSize: 12
                    font.weight: Font.Black
                    font.family: hwPageRoot.displayFont
                }
            }

            Rectangle {
                id: displayTrack
                width: parent.width
                height: 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.12)
                clip: true

                Rectangle {
                    id: displayFill
                    height: parent.height
                    radius: 12
                    color: displayMouse.pressed ? "#e4e4e7" : "#ffffff"
                    width: Math.max(height, Math.round(parent.width * (Math.max(5, Math.min(100, hwPageRoot.currentBrightness)) / 100.0)))

                    Behavior on width {
                        enabled: !displayMouse.pressed
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    id: displayMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    // 🚀【绝对定位赋值】：无论鼠标拖多快，只发送准确比例，杜绝暴冲
                    function updateBrightness(mouseX) {
                        var ratio = Math.max(0.05, Math.min(1.0, mouseX / displayTrack.width))
                        var target = Math.round(ratio * 100)
                        if (typeof Bridge !== "undefined") {
                            if (Bridge.setHardware) {
                                Bridge.setHardware(1, target)
                            } else {
                                Bridge.adjustHardware(1, target - hwPageRoot.currentBrightness)
                            }
                        }
                    }

                    onPressed: (mouse) => updateBrightness(mouse.x)
                    onPositionChanged: (mouse) => { if (pressed) updateBrightness(mouse.x) }
                    onWheel: (wheel) => {
                        wheel.accepted = true
                        var delta = wheel.angleDelta.y > 0 ? 5 : -5
                        if (typeof Bridge !== "undefined") Bridge.adjustHardware(1, delta)
                    }
                }
            }
        }

        // 3. Sound 音量条
        Column {
            width: parent.width
            spacing: 5

            Item {
                width: parent.width
                height: 18

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Sound"
                    color: "white"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.family: hwPageRoot.effectiveFont
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: hwPageRoot.isVolMuted ? "MUTED" : (hwPageRoot.currentVolume + "%")
                    color: hwPageRoot.isVolMuted ? Theme.danger : Qt.rgba(1, 1, 1, 0.75)
                    font.pixelSize: 12
                    font.weight: Font.Black
                    font.family: hwPageRoot.isVolMuted ? hwPageRoot.effectiveFont : hwPageRoot.displayFont
                }
            }

            Rectangle {
                id: soundTrack
                width: parent.width
                height: 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.12)
                clip: true

                Rectangle {
                    id: soundFill
                    height: parent.height
                    radius: 12
                    color: hwPageRoot.isVolMuted ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.45) : (soundMouse.pressed ? "#e4e4e7" : "#ffffff")
                    width: hwPageRoot.isVolMuted ? 0 : Math.max(height, Math.round(parent.width * (Math.max(0, Math.min(100, hwPageRoot.currentVolume)) / 100.0)))

                    Behavior on width {
                        enabled: !soundMouse.pressed
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    id: soundMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    // 🚀【绝对定位赋值】：直接调用 setHardware(0, target)，拖拽手感如丝顺滑，彻底消灭 100% 暴冲
                    function updateVolume(mouseX) {
                        var ratio = Math.max(0.0, Math.min(1.0, mouseX / soundTrack.width))
                        var target = Math.round(ratio * 100)
                        if (typeof Bridge !== "undefined") {
                            if (Bridge.setHardware) {
                                Bridge.setHardware(0, target)
                            } else {
                                Bridge.adjustHardware(0, target - hwPageRoot.currentVolume)
                            }
                        }
                    }

                    onPressed: (mouse) => updateVolume(mouse.x)
                    onPositionChanged: (mouse) => { if (pressed) updateVolume(mouse.x) }
                    onWheel: (wheel) => {
                        wheel.accepted = true
                        var step = (typeof Config !== "undefined" && Config.volumeStep !== undefined) ? Config.volumeStep : 5
                        var delta = wheel.angleDelta.y > 0 ? step : -step
                        if (typeof Bridge !== "undefined") Bridge.adjustHardware(0, delta)
                    }
                }
            }
        }
    }
}