// ==========================================
// 📄 File: ui/components/timer/TimerPresetGrid.qml
// 🌟 心流专注预设矩阵 (大幅面高触感 · 空间饱满版)
// ==========================================
import QtQuick

Item {
    id: presetGridRoot
    width: parent.width
    height: 82

    property bool isRunning: false
    property string currentMode: "focus"
    property int totalSeconds: 1500
    property string textFont: ""

    signal presetTriggered(int sec, string mode)

    readonly property int colGap: 8
    readonly property int rowGap: 8
    readonly property int cardWidth: Math.floor((width - colGap) / 2)
    readonly property int cardHeight: 37

    Grid {
        anchors.fill: parent
        columns: 2
        columnSpacing: presetGridRoot.colGap
        rowSpacing: presetGridRoot.rowGap
        enabled: !presetGridRoot.isRunning
        opacity: presetGridRoot.isRunning ? 0.35 : 1.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // --- 1. 25m 标准番茄 ---
        Rectangle {
            id: p25Card
            width: presetGridRoot.cardWidth; height: presetGridRoot.cardHeight; radius: 10
            readonly property bool isSel: presetGridRoot.currentMode === "focus" && presetGridRoot.totalSeconds === 1500

            color: isSel ? Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.28) :
                   (p25Area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
            border.color: isSel ? "#f97316" : (p25Area.containsMouse ? Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.45) : Qt.rgba(1, 1, 1, 0.12))
            border.width: isSel ? 1.5 : 1

            scale: p25Area.pressed ? 0.96 : 1.0
            Behavior on scale { NumberAnimation { duration: 80 } }
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text { text: "🍅"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text { text: "25m 番茄"; color: "white"; font.pixelSize: 11; font.weight: Font.Black; font.family: presetGridRoot.textFont }
                    Text { text: "经典高强度专注"; color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 8; font.family: presetGridRoot.textFont }
                }
            }
            MouseArea { id: p25Area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: presetGridRoot.presetTriggered(1500, "focus") }
        }

        // --- 2. 60m 深度心流 ---
        Rectangle {
            id: p60Card
            width: presetGridRoot.cardWidth; height: presetGridRoot.cardHeight; radius: 10
            readonly property bool isSel: presetGridRoot.currentMode === "focus" && presetGridRoot.totalSeconds === 3600

            color: isSel ? Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.28) :
                   (p60Area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
            border.color: isSel ? "#f97316" : (p60Area.containsMouse ? Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.45) : Qt.rgba(1, 1, 1, 0.12))
            border.width: isSel ? 1.5 : 1

            scale: p60Area.pressed ? 0.96 : 1.0
            Behavior on scale { NumberAnimation { duration: 80 } }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text { text: "🚀"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text { text: "1h 深度"; color: "white"; font.pixelSize: 11; font.weight: Font.Black; font.family: presetGridRoot.textFont }
                    Text { text: "沉浸式长篇编码"; color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 8; font.family: presetGridRoot.textFont }
                }
            }
            MouseArea { id: p60Area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: presetGridRoot.presetTriggered(3600, "focus") }
        }

        // --- 3. 5m 间歇小憩 ---
        Rectangle {
            id: p5Card
            width: presetGridRoot.cardWidth; height: presetGridRoot.cardHeight; radius: 10
            readonly property bool isSel: presetGridRoot.currentMode === "break" && presetGridRoot.totalSeconds === 300

            color: isSel ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.28) :
                   (p5Area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
            border.color: isSel ? "#10b981" : (p5Area.containsMouse ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.45) : Qt.rgba(1, 1, 1, 0.12))
            border.width: isSel ? 1.5 : 1

            scale: p5Area.pressed ? 0.96 : 1.0
            Behavior on scale { NumberAnimation { duration: 80 } }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text { text: "☕"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text { text: "5m 小憩"; color: "white"; font.pixelSize: 11; font.weight: Font.Black; font.family: presetGridRoot.textFont }
                    Text { text: "接水/远眺拉伸"; color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 8; font.family: presetGridRoot.textFont }
                }
            }
            MouseArea { id: p5Area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: presetGridRoot.presetTriggered(300, "break") }
        }

        // --- 4. 15m 冲刺 ---
        Rectangle {
            id: p15Card
            width: presetGridRoot.cardWidth; height: presetGridRoot.cardHeight; radius: 10
            readonly property bool isSel: presetGridRoot.currentMode === "focus" && presetGridRoot.totalSeconds === 900

            color: isSel ? Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.28) :
                   (p15Area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
            border.color: isSel ? "#f97316" : (p15Area.containsMouse ? Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.45) : Qt.rgba(1, 1, 1, 0.12))
            border.width: isSel ? 1.5 : 1

            scale: p15Area.pressed ? 0.96 : 1.0
            Behavior on scale { NumberAnimation { duration: 80 } }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text { text: "⚡"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text { text: "15m 冲刺"; color: "white"; font.pixelSize: 11; font.weight: Font.Black; font.family: presetGridRoot.textFont }
                    Text { text: "极速解决短任务"; color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 8; font.family: presetGridRoot.textFont }
                }
            }
            MouseArea { id: p15Area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: presetGridRoot.presetTriggered(900, "focus") }
        }
    }
}