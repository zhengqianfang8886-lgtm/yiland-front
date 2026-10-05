// ==========================================
// 📄 File: timer/TimerPresetGrid.qml (开阔无切边快捷预设矩阵)
// ==========================================
import QtQuick

Item {
    id: presetGridRoot
    width: parent.width
    height: 78

    property bool isRunning: false
    property string currentMode: "focus"
    property int totalSeconds: 1500
    property string textFont: ""

    signal presetTriggered(int sec, string mode)

    // 🚀 充裕宽度整型计算：精确消除浮点裁切与挤压
    readonly property int colGap: 8
    readonly property int rowGap: 6
    readonly property int cardWidth: Math.floor((width - colGap) / 2)
    readonly property int cardHeight: 36

    Grid {
        anchors.fill: parent
        columns: 2
        columnSpacing: presetGridRoot.colGap
        rowSpacing: presetGridRoot.rowGap
        enabled: !presetGridRoot.isRunning
        opacity: presetGridRoot.isRunning ? 0.35 : 1.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // 1. 25m 专注
        Rectangle {
            width: presetGridRoot.cardWidth; height: presetGridRoot.cardHeight; radius: 9
            color: p25Area.pressed ? Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.35) : (p25Area.containsMouse ? Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.2) : Qt.rgba(1, 1, 1, 0.06))
            border.color: (presetGridRoot.currentMode === "focus" && presetGridRoot.totalSeconds === 1500) ? "#f97316" : (p25Area.containsMouse ? Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.5) : Theme.borderSubtle)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "25m 专注"
                color: "white"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.family: presetGridRoot.textFont
            }
            MouseArea { id: p25Area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: presetGridRoot.presetTriggered(1500, "focus") }
        }

        // 2. 1h 深度
        Rectangle {
            width: presetGridRoot.cardWidth; height: presetGridRoot.cardHeight; radius: 9
            color: p1hArea.pressed ? Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.35) : (p1hArea.containsMouse ? Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.2) : Qt.rgba(1, 1, 1, 0.06))
            border.color: presetGridRoot.totalSeconds === 3600 ? "#f97316" : (p1hArea.containsMouse ? Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.5) : Theme.borderSubtle)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "1h 深度"
                color: "white"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.family: presetGridRoot.textFont
            }
            MouseArea { id: p1hArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: presetGridRoot.presetTriggered(3600, "focus") }
        }

        // 3. 5m 小憩
        Rectangle {
            width: presetGridRoot.cardWidth; height: presetGridRoot.cardHeight; radius: 9
            color: p5Area.pressed ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.35) : (p5Area.containsMouse ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.2) : Qt.rgba(1, 1, 1, 0.06))
            border.color: presetGridRoot.currentMode === "break" ? "#10b981" : (p5Area.containsMouse ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.5) : Theme.borderSubtle)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "5m 小憩"
                color: "white"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.family: presetGridRoot.textFont
            }
            MouseArea { id: p5Area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: presetGridRoot.presetTriggered(300, "break") }
        }

        // 4. 15m 冲刺
        Rectangle {
            width: presetGridRoot.cardWidth; height: presetGridRoot.cardHeight; radius: 9
            color: p15Area.pressed ? Qt.rgba(1, 1, 1, 0.22) : (p15Area.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06))
            border.color: p15Area.containsMouse ? Qt.rgba(255, 255, 255, 0.3) : Theme.borderSubtle
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "15m 冲刺"
                color: "white"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.family: presetGridRoot.textFont
            }
            MouseArea { id: p15Area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: presetGridRoot.presetTriggered(900, "focus") }
        }
    }
}