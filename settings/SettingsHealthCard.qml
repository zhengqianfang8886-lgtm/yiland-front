// ==========================================
// 📄 File: settings/SettingsHealthCard.qml
// ==========================================
import QtQuick
import QtQuick.Controls

Rectangle {
    id: cardRoot
    height: healthSettingsCol.implicitHeight + 24
    radius: 12
    color: Qt.rgba(1, 1, 1, 0.05)
    border.color: Qt.rgba(52, 211, 153, 0.3)
    border.width: 1

    Column {
        id: healthSettingsCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text { text: "🌿 健康关怀与系统监控"; color: "#34d399"; font.pixelSize: 12; font.bold: true }

        // 1. 内存监控小岛
        Item {
            width: parent.width; height: 30
            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Text { text: "💾"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "内存监控小岛 (RAM %)"; color: "white"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            Switch {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                checked: (typeof Config !== "undefined" && Config.showMemoryBubble !== undefined) ? Config.showMemoryBubble : true
                onToggled: if (typeof Config !== "undefined") Config.showMemoryBubble = checked
            }
        }

        Row {
            width: parent.width; height: 26; spacing: 6
            visible: (typeof Config !== "undefined" && Config.showMemoryBubble !== false)

            Text { text: "弹出阈值:"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter }

            Repeater {
                model: [
                    { label: "常驻", val: 0 },
                    { label: "60%", val: 60 },
                    { label: "70%", val: 70 },
                    { label: "75%", val: 75 },
                    { label: "80%", val: 80 },
                    { label: "85%", val: 85 }
                ]
                Rectangle {
                    width: 44; height: 22; radius: 11
                    readonly property bool isSel: (typeof Config !== "undefined" && Config.memoryThreshold === modelData.val)
                    color: isSel ? Qt.rgba(52, 211, 153, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: isSel ? "#34d399" : "transparent"; border.width: 1

                    Text {
                        anchors.centerIn: parent; text: modelData.label
                        color: parent.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (typeof Config !== "undefined") Config.memoryThreshold = modelData.val
                    }
                }
            }
        }

        Item { height: 2 }

        // 2. 久坐提醒
        Item {
            width: parent.width; height: 30
            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Text { text: "🧘"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "久坐伏案提醒 (特大打断弹窗)"; color: "white"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            Switch {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                checked: (typeof Config !== "undefined" && Config.sedentaryReminderEnabled !== undefined) ? Config.sedentaryReminderEnabled : true
                onToggled: if (typeof Config !== "undefined") Config.sedentaryReminderEnabled = checked
            }
        }

        Row {
            width: parent.width; height: 26; spacing: 8
            visible: (typeof Config !== "undefined" && Config.sedentaryReminderEnabled !== false)

            Text { text: "提醒周期:"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter }

            Repeater {
                model: [30, 45, 60]
                Rectangle {
                    width: 54; height: 24; radius: 12
                    readonly property bool isSel: (typeof Config !== "undefined" && Config.sedentaryIntervalMinutes === modelData)
                    color: isSel ? Qt.rgba(52, 211, 153, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: isSel ? "#34d399" : "transparent"; border.width: 1

                    Text {
                        anchors.centerIn: parent; text: modelData + "m"
                        color: parent.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (typeof Config !== "undefined") Config.sedentaryIntervalMinutes = modelData
                    }
                }
            }
        }

        Item { height: 4 }

        // 3. 音量调节步长
        Column {
            width: parent.width; spacing: 6

            Item {
                width: parent.width; height: 16
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                    Text { text: "🔊"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "滚轮音量调节步长"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                }
                Text {
                    text: ((typeof Config !== "undefined" && Config.volumeStep !== undefined) ? Config.volumeStep : 5) + " %"
                    color: "#34d399"; font.pixelSize: 11; font.weight: Font.Black; font.family: "Monospace"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                }
            }

            Slider {
                id: volumeStepSlider
                width: parent.width; height: 22; from: 1; to: 20; stepSize: 1
                value: (typeof Config !== "undefined" && Config.volumeStep !== undefined) ? Config.volumeStep : 5
                onMoved: if (typeof Config !== "undefined") Config.volumeStep = Math.round(value)

                background: Rectangle {
                    x: volumeStepSlider.leftPadding; y: volumeStepSlider.topPadding + volumeStepSlider.availableHeight / 2 - height / 2
                    width: volumeStepSlider.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12)
                    Rectangle { width: volumeStepSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#34d399" }
                }
                handle: Rectangle {
                    x: volumeStepSlider.leftPadding + volumeStepSlider.visualPosition * (volumeStepSlider.availableWidth - width)
                    y: volumeStepSlider.topPadding + volumeStepSlider.availableHeight / 2 - height / 2
                    width: 14; height: 14; radius: 7; color: volumeStepSlider.pressed ? "#6ee7b7" : "#34d399"; border.color: "#ffffff"; border.width: 1.5
                }
            }

            Row {
                spacing: 6
                Repeater {
                    model: [1, 2, 5, 10]
                    Rectangle {
                        width: 44; height: 20; radius: 10
                        readonly property bool isSel: (typeof Config !== "undefined" && Config.volumeStep === modelData)
                        color: isSel ? Qt.rgba(52, 211, 153, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: isSel ? "#34d399" : "transparent"; border.width: 1

                        Text {
                            anchors.centerIn: parent; text: modelData + "%"
                            color: parent.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.weight: Font.Bold
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: if (typeof Config !== "undefined") Config.volumeStep = modelData
                        }
                    }
                }
            }
        }
    }
}