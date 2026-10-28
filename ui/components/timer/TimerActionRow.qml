// ==========================================
// 📄 File: ui/components/timer/TimerActionRow.qml
// 🌟 强触感主控操作底栏 (自适应等比定宽 · 彻底消灭边缘裁切版)
// ==========================================
import QtQuick

Item {
    id: actionRowRoot
    width: parent.width
    height: 38

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

    // 精准测算：间距 6px，右侧按钮定宽，主按钮自适应填满剩余空间，总宽严格等于 parent.width
    readonly property int buttonGap: 6
    readonly property int resetBtnWidth: 46
    readonly property int lapBtnWidth: 44

    readonly property int mainBtnWidth: {
        if (!hasAuxiliary) return width;
        if (actionRowRoot.isCountUp && actionRowRoot.isRunning) {
            // 三个按钮同时显示：总宽 - 间距(12) - 计次(44) - 重置(46)
            return Math.max(80, width - (buttonGap * 2) - lapBtnWidth - resetBtnWidth);
        }
        // 两个按钮显示：总宽 - 间距(6) - 重置(46)
        return Math.max(100, width - buttonGap - resetBtnWidth);
    }

    Row {
        anchors.fill: parent
        spacing: actionRowRoot.buttonGap

        // 1. 主操作按钮 (CTA 核心焦点)
        Rectangle {
            width: actionRowRoot.mainBtnWidth
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
                          (actionRowRoot.isRunning ? "❚❚" : "▶")
                    color: "white"
                    font.pixelSize: 13
                    font.weight: Font.Black
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: {
                        if (actionRowRoot.isCompleted) return "完成并重置";
                        if (actionRowRoot.isRunning) return "暂停";
                        if (actionRowRoot.isPaused) {
                            return actionRowRoot.isCountUp ? "继续计时" : "继续专注";
                        }
                        return actionRowRoot.isCountUp ? "开启秒表" : "开启专注";
                    }
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

        // 2. 计次按键 (秒表运行中平滑现身)
        Rectangle {
            width: actionRowRoot.lapBtnWidth
            height: parent.height
            radius: height / 2
            visible: actionRowRoot.isCountUp && actionRowRoot.isRunning

            color: lapTap.pressed ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35) : 
                   (lapHover.hovered ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.20) : Qt.rgba(1, 1, 1, 0.08))
            border.color: lapHover.hovered ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.16)
            border.width: 1

            scale: lapTap.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 80 } }

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

        // 3. 重置按键 (只要有计时数据即出现，严格对齐)
        Rectangle {
            width: actionRowRoot.resetBtnWidth
            height: parent.height
            radius: height / 2
            visible: actionRowRoot.hasAuxiliary

            color: resetTap.pressed ? Qt.rgba(1, 1, 1, 0.22) : 
                   (resetHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
            border.color: resetHover.hovered ? Qt.rgba(255, 255, 255, 0.35) : Qt.rgba(1, 1, 1, 0.16)
            border.width: 1

            scale: resetTap.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 80 } }

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
}