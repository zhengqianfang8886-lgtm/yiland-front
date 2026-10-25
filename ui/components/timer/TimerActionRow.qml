// ==========================================
// 📄 File: ui/components/timer/TimerActionRow.qml
// 🌟 计时器底部主控制按键行 (全 Handlers 化 · 零手势冲突版)
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

    // 1. 开始 / 暂停 / 继续 主按键
    Rectangle {
        width: (actionRowRoot.isRunning || actionRowRoot.isPaused || actionRowRoot.isCompleted) ?
               (actionRowRoot.isCountUp && actionRowRoot.isRunning ? parent.width - 86 : parent.width - 44) : parent.width
        height: 36
        radius: 18
        color: mainTap.pressed ? Qt.darker(actionRowRoot.accentColor, 1.25) : 
               (mainHover.hovered ? Qt.lighter(actionRowRoot.accentColor, 1.15) : actionRowRoot.accentColor)
        scale: mainTap.pressed ? 0.95 : (mainHover.hovered ? 1.015 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: actionRowRoot.isCompleted ? "重置完成" : 
                  (actionRowRoot.isRunning ? "暂停" : 
                  (actionRowRoot.isPaused ? "继续" : 
                  (actionRowRoot.isCountUp ? "开始计时" : "开始专注")))
            color: "white"
            font.family: actionRowRoot.textFont
            font.pixelSize: 12
            font.weight: Font.Black
        }

        HoverHandler { id: mainHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: mainTap; onTapped: actionRowRoot.togglePauseRequested() }
    }

    // 2. 计次按键 (仅正向计时运行中显现)
    Rectangle {
        width: 38; height: 36; radius: 18
        visible: actionRowRoot.isCountUp && actionRowRoot.isRunning
        color: lapTap.pressed ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.4) : 
               (lapHover.hovered ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.25) : Qt.rgba(1, 1, 1, 0.08))
        border.color: lapHover.hovered ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        scale: lapTap.pressed ? 0.92 : (lapHover.hovered ? 1.05 : 1.0)

        Text {
            anchors.centerIn: parent
            text: "计次"
            font.pixelSize: 10
            font.weight: Font.Bold
            font.family: actionRowRoot.textFont
            color: "white"
        }

        HoverHandler { id: lapHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: lapTap; onTapped: actionRowRoot.recordLapRequested() }
    }

    // 3. 重置按键 (处于运行、暂停或完成态时显现)
    Rectangle {
        width: 38; height: 36; radius: 18
        visible: actionRowRoot.isRunning || actionRowRoot.isPaused || actionRowRoot.isCompleted
        color: resetTap.pressed ? Qt.rgba(1, 1, 1, 0.25) : 
               (resetHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
        border.color: resetHover.hovered ? Qt.rgba(255, 255, 255, 0.3) : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        scale: resetTap.pressed ? 0.92 : (resetHover.hovered ? 1.05 : 1.0)

        Text {
            anchors.centerIn: parent
            text: "重置"
            font.pixelSize: 10
            font.weight: Font.Bold
            font.family: actionRowRoot.textFont
            color: "white"
        }

        HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: resetTap; onTapped: actionRowRoot.resetRequested() }
    }
}