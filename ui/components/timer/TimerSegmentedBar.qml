// ==========================================
// 📄 File: ui/components/timer/TimerSegmentedBar.qml
// 🌟 顶部分段切换器 (自由无阻断切换版)
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

    readonly property int intentDwellInterval: 120

    Timer {
        id: cdIntentTimer
        interval: segBarRoot.intentDwellInterval
        repeat: false
        onTriggered: {
            if (segBarRoot.isCountUp && cdHover.hovered) {
                segBarRoot.switchRequested("countdown");
            }
        }
    }

    Timer {
        id: swIntentTimer
        interval: segBarRoot.intentDwellInterval
        repeat: false
        onTriggered: {
            if (!segBarRoot.isCountUp && swHover.hovered) {
                segBarRoot.switchRequested("stopwatch");
            }
        }
    }

    // 弹性滑块指示器
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

        // 倒计时标签
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
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered && segBarRoot.isCountUp) cdIntentTimer.restart();
                    else cdIntentTimer.stop();
                }
            }

            TapHandler {
                onTapped: {
                    cdIntentTimer.stop();
                    segBarRoot.switchRequested("countdown");
                }
            }
        }

        // 正向计时 (秒表) 标签
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
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered && !segBarRoot.isCountUp) swIntentTimer.restart();
                    else swIntentTimer.stop();
                }
            }

            TapHandler {
                onTapped: {
                    swIntentTimer.stop();
                    segBarRoot.switchRequested("stopwatch");
                }
            }
        }
    }
}