// ==========================================
// 📄 File: timer/TimerActionRow.qml (底部主控制按键行)
// ==========================================
import QtQuick

Row {
    id: actionRowRoot
    width: parent.width
    spacing: 6

    property bool isRunning: false
    property bool isPaused: false
    property bool isCompleted: false
    property bool isCountUp: false
    property color accentColor: "#f97316"
    property string textFont: ""

    signal togglePauseRequested()
    signal recordLapRequested()
    signal resetRequested()

    Rectangle {
        width: (actionRowRoot.isRunning || actionRowRoot.isPaused || actionRowRoot.isCompleted) ?
               (actionRowRoot.isCountUp && actionRowRoot.isRunning ? parent.width - 86 : parent.width - 44) : parent.width
        height: 36
        radius: 18
        color: mainArea.pressed ? Qt.darker(actionRowRoot.accentColor, 1.25) : (mainArea.containsMouse ? Qt.lighter(actionRowRoot.accentColor, 1.15) : actionRowRoot.accentColor)
        scale: mainArea.pressed ? 0.95 : (mainArea.containsMouse ? 1.015 : 1.0)
        Behavior on scale { NumberAnimation { duration: Theme.animInstant; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: actionRowRoot.isCompleted ? "重置完成" : (actionRowRoot.isRunning ? "暂停" : (actionRowRoot.isPaused ? "继续" : (actionRowRoot.isCountUp ? "开始计时" : "开始专注")))
            color: "white"
            font.family: actionRowRoot.textFont
            font.pixelSize: 12
            font.weight: Font.Black
        }

        MouseArea {
            id: mainArea
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: actionRowRoot.togglePauseRequested()
        }
    }

    Rectangle {
        width: 38; height: 36; radius: 18
        visible: actionRowRoot.isCountUp && actionRowRoot.isRunning
        color: lapArea.pressed ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.4) : (lapArea.containsMouse ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.25) : Qt.rgba(1, 1, 1, 0.08))
        border.color: lapArea.containsMouse ? "#38bdf8" : Theme.borderSubtle
        border.width: 1
        scale: lapArea.pressed ? 0.92 : (lapArea.containsMouse ? 1.05 : 1.0)

        Text { anchors.centerIn: parent; text: "计次"; font.pixelSize: 10; font.weight: Font.Bold; font.family: actionRowRoot.textFont; color: "white" }
        MouseArea { id: lapArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: actionRowRoot.recordLapRequested() }
    }

    Rectangle {
        width: 38; height: 36; radius: 18
        visible: actionRowRoot.isRunning || actionRowRoot.isPaused || actionRowRoot.isCompleted
        color: resetArea.pressed ? Qt.rgba(1, 1, 1, 0.25) : (resetArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
        border.color: resetArea.containsMouse ? Qt.rgba(255, 255, 255, 0.3) : Theme.borderSubtle
        border.width: 1
        scale: resetArea.pressed ? 0.92 : (resetArea.containsMouse ? 1.05 : 1.0)

        Text { anchors.centerIn: parent; text: "重置"; font.pixelSize: 10; font.weight: Font.Bold; font.family: actionRowRoot.textFont; color: "white" }
        MouseArea { id: resetArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: actionRowRoot.resetRequested() }
    }
}