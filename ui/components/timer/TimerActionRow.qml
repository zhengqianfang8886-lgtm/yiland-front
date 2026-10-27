// ==========================================
// 📄 File: ui/components/timer/TimerActionRow.qml
// 🌟 强触感主控操作底栏 (字号强化 · 核心 CTA 醒目版)
// ==========================================
import QtQuick

Row {
    id: actionRowRoot
    width: parent.width
    height: 38
    spacing: 8

    property bool isRunning: false
    property bool isPaused: false
    property bool isCompleted: false
    property bool isCountUp: false
    property color accentColor: "#f97316"
    property string textFont: ""

    signal togglePauseRequested()
    signal recordLapRequested()
    signal resetRequested()

    readonly property bool hasAuxiliary: actionRowRoot.isRunning || actionRowRoot.isPaused || actionRowRoot.isCompleted

    // =========================================================================
    // 1. 主行动呼出按钮 (CTA Button - 占据大部分宽度)
    // =========================================================================
    Rectangle {
        width: actionRowRoot.hasAuxiliary ? (actionRowRoot.isCountUp && actionRowRoot.isRunning ? parent.width - 96 : parent.width - 52) : parent.width
        height: parent.height
        radius: height / 2

        color: mainTap.pressed ? Qt.darker(actionRowRoot.accentColor, 1.25) : 
               (mainHover.hovered ? Qt.lighter(actionRowRoot.accentColor, 1.15) : actionRowRoot.accentColor)

        border.color: Qt.rgba(255, 255, 255, 0.25)
        border.width: 1

        scale: mainTap.pressed ? 0.96 : (mainHover.hovered ? 1.01 : 1.0)
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 150 } }

        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: actionRowRoot.isCompleted ? "↺" : 
                      (actionRowRoot.isRunning ? "❚❚" : 
                      (actionRowRoot.isPaused ? "▶" : "▶"))
                color: "white"
                font.pixelSize: 13
                font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: actionRowRoot.isCompleted ? "完成并重置" : 
                      (actionRowRoot.isRunning ? "暂停" : 
                      (actionRowRoot.isPaused ? "继续专注" : 
                      (actionRowRoot.isCountUp ? "开启秒表" : "开启专注")))
                color: "white"
                font.family: actionRowRoot.textFont
                font.pixelSize: 13
                font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        HoverHandler { id: mainHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: mainTap; onTapped: actionRowRoot.togglePauseRequested() }
    }

    // =========================================================================
    // 2. 计次按键 (秒表运行时显现)
    // =========================================================================
    Rectangle {
        width: 40
        height: parent.height
        radius: height / 2
        visible: actionRowRoot.isCountUp && actionRowRoot.isRunning

        color: lapTap.pressed ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.4) : 
               (lapHover.hovered ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.25) : Qt.rgba(1, 1, 1, 0.08))
        border.color: lapHover.hovered ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.15)
        border.width: 1

        scale: lapTap.pressed ? 0.92 : 1.0

        Text {
            anchors.centerIn: parent
            text: "计次"
            font.pixelSize: 11
            font.weight: Font.Bold
            font.family: actionRowRoot.textFont
            color: "white"
        }

        HoverHandler { id: lapHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: lapTap; onTapped: actionRowRoot.recordLapRequested() }
    }

    // =========================================================================
    // 3. 重置圆角按键
    // =========================================================================
    Rectangle {
        width: 44
        height: parent.height
        radius: height / 2
        visible: actionRowRoot.hasAuxiliary

        color: resetTap.pressed ? Qt.rgba(1, 1, 1, 0.25) : 
               (resetHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
        border.color: resetHover.hovered ? Qt.rgba(255, 255, 255, 0.3) : Qt.rgba(1, 1, 1, 0.15)
        border.width: 1

        scale: resetTap.pressed ? 0.92 : 1.0

        Text {
            anchors.centerIn: parent
            text: "重置"
            font.pixelSize: 11
            font.weight: Font.Bold
            font.family: actionRowRoot.textFont
            color: "white"
        }

        HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: resetTap; onTapped: actionRowRoot.resetRequested() }
    }
}