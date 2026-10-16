// ==========================================
// 📄 File: timer/TimerSegmentedBar.qml
// 🌟 鼠标悬停意图识别（即停即切）分段器
// ==========================================
import QtQuick

Rectangle {
    id: segBarRoot
    width: parent.width
    height: 28
    radius: 14
    color: Qt.rgba(1, 1, 1, 0.06)
    border.color: Qt.rgba(1, 1, 1, 0.12)
    border.width: 1

    property bool isCountUp: false
    property bool isRunning: false
    property string textFont: ""

    signal switchRequested(string targetType)

    // 🚀【意图识别时间窗口】：120ms 为人体工程学黄金悬停阈值（既灵敏又防误掠过）
    readonly property int intentDwellInterval: 120

    // 倒计时意图识别定时器
    Timer {
        id: cdIntentTimer
        interval: segBarRoot.intentDwellInterval
        repeat: false
        onTriggered: {
            if (!segBarRoot.isRunning && segBarRoot.isCountUp && cdHover.hovered) {
                segBarRoot.switchRequested("countdown")
            }
        }
    }

    // 正向计时意图识别定时器
    Timer {
        id: swIntentTimer
        interval: segBarRoot.intentDwellInterval
        repeat: false
        onTriggered: {
            if (!segBarRoot.isRunning && !segBarRoot.isCountUp && swHover.hovered) {
                segBarRoot.switchRequested("stopwatch")
            }
        }
    }

    // 滑动弹性高亮底块
    Rectangle {
        x: segBarRoot.isCountUp ? Math.round(parent.width / 2 + 2) : 2
        y: 2
        width: Math.round(parent.width / 2 - 4)
        height: parent.height - 4
        radius: 12
        color: segBarRoot.isCountUp ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.28) : Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.28)
        border.color: segBarRoot.isCountUp ? "#38bdf8" : "#f97316"
        border.width: 1

        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    Row {
        anchors.fill: parent

        // ---------------------------------------------------------------------
        // 【左标签】：倒计时 (支持悬停意图识别)
        // ---------------------------------------------------------------------
        Item {
            width: parent.width / 2
            height: parent.height

            Text {
                anchors.centerIn: parent
                text: "倒计时"
                color: !segBarRoot.isCountUp ? "white" : (cdHover.hovered ? "#fdba74" : Qt.rgba(1, 1, 1, 0.5))
                font.pixelSize: 11
                font.weight: !segBarRoot.isCountUp ? Font.Black : Font.Bold
                font.family: segBarRoot.textFont
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            HoverHandler {
                id: cdHover
                cursorShape: segBarRoot.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered) {
                        // 🚀 指针移入且当前处于正向计时状态，开启 120ms 意图识别
                        if (!segBarRoot.isRunning && segBarRoot.isCountUp) {
                            cdIntentTimer.restart()
                        }
                    } else {
                        // 指针滑出，立即取消切换意图
                        cdIntentTimer.stop()
                    }
                }
            }

            // 支持即时点击保底（无需等待 120ms）
            TapHandler {
                enabled: !segBarRoot.isRunning
                onTapped: {
                    cdIntentTimer.stop()
                    segBarRoot.switchRequested("countdown")
                }
            }
        }

        // ---------------------------------------------------------------------
        // 【右标签】：正向计时 (支持悬停意图识别)
        // ---------------------------------------------------------------------
        Item {
            width: parent.width / 2
            height: parent.height

            Text {
                anchors.centerIn: parent
                text: "正向计时"
                color: segBarRoot.isCountUp ? "white" : (swHover.hovered ? "#7dd3fc" : Qt.rgba(1, 1, 1, 0.5))
                font.pixelSize: 11
                font.weight: segBarRoot.isCountUp ? Font.Black : Font.Bold
                font.family: segBarRoot.textFont
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            HoverHandler {
                id: swHover
                cursorShape: segBarRoot.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered) {
                        // 🚀 指针移入且当前处于倒计时状态，开启 120ms 意图识别
                        if (!segBarRoot.isRunning && !segBarRoot.isCountUp) {
                            swIntentTimer.restart()
                        }
                    } else {
                        // 指针滑出，立即取消切换意图
                        swIntentTimer.stop()
                    }
                }
            }

            // 支持即时点击保底（无需等待 120ms）
            TapHandler {
                enabled: !segBarRoot.isRunning
                onTapped: {
                    swIntentTimer.stop()
                    segBarRoot.switchRequested("stopwatch")
                }
            }
        }
    }
}