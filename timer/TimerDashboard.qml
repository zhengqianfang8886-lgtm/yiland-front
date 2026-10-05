// ==========================================
// 📄 File: timer/TimerDashboard.qml (左侧计时大看板)
// ==========================================
import QtQuick

Rectangle {
    id: dashRoot
    width: 152
    height: parent.height
    radius: Theme.radiusCard
    color: Qt.rgba(1, 1, 1, 0.04)
    border.color: Qt.rgba(dashRoot.accentColor.r, dashRoot.accentColor.g, dashRoot.accentColor.b, 0.3)
    border.width: 1

    property color accentColor: "#f97316"
    property string textFont: ""
    property string displayFont: "Monospace"
    property bool isRunning: false
    property bool isPaused: false
    property bool isCompleted: false
    property bool isCountUp: false
    property string currentMode: "focus"
    property real progress: 0.0

    property int hoursPart: 0
    property int minutesPart: 0
    property int secondsPart: 0

    signal adjustRequested(int deltaSec)

    Column {
        anchors.centerIn: parent
        spacing: 6
        width: parent.width - 16

        // 1. 顶部状态提示行
        Row {
            spacing: 5
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: 6; height: 6; radius: 3
                color: dashRoot.accentColor
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: dashRoot.isRunning || dashRoot.isCompleted
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 600 }
                    NumberAnimation { to: 1.0; duration: 600 }
                }
            }

            Text {
                text: dashRoot.isCompleted ? "COMPLETED" :
                      (dashRoot.isCountUp ?
                      (dashRoot.isRunning ? "STOPWATCH RUNNING" : (dashRoot.isPaused ? "STOPWATCH PAUSED" : "STOPWATCH READY")) :
                      (dashRoot.isRunning ? (dashRoot.currentMode === "break" ? "TAKING A BREAK" : "FOCUSING") : (dashRoot.isPaused ? "PAUSED" : "READY")))
                font.pixelSize: 8
                font.weight: Font.Black
                color: dashRoot.accentColor
                font.family: dashRoot.textFont
                font.letterSpacing: 0.8
                elide: Text.ElideRight
                width: parent.parent.width - 18
            }
        }

        // 2. 核心时间大字与独立滚轮热区
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 1

            // 时
            Column {
                spacing: 1
                Rectangle {
                    width: 36; height: 38; radius: 6
                    color: (hHover.hovered && !dashRoot.isRunning && !dashRoot.isCountUp) ? Qt.rgba(dashRoot.accentColor.r, dashRoot.accentColor.g, dashRoot.accentColor.b, 0.22) : "transparent"
                    border.color: (hHover.hovered && !dashRoot.isRunning && !dashRoot.isCountUp) ? dashRoot.accentColor : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: (dashRoot.hoursPart < 10 ? "0" : "") + dashRoot.hoursPart
                        color: (hHover.hovered && !dashRoot.isRunning && !dashRoot.isCountUp) ? dashRoot.accentColor : "white"
                        font.pixelSize: 24; font.weight: Font.Black; font.family: dashRoot.displayFont
                    }
                    HoverHandler { id: hHover; enabled: !dashRoot.isRunning && !dashRoot.isCountUp; cursorShape: Qt.PointingHandCursor }
                    WheelHandler {
                        enabled: !dashRoot.isRunning && !dashRoot.isCountUp
                        onWheel: (e) => dashRoot.adjustRequested(e.angleDelta.y > 0 ? 3600 : -3600)
                    }
                }
                Text { text: "时"; font.pixelSize: 8; color: Qt.rgba(1, 1, 1, 0.4); font.weight: Font.Bold; font.family: dashRoot.textFont; anchors.horizontalCenter: parent.horizontalCenter }
            }

            Text { text: ":"; font.pixelSize: 18; font.weight: Font.Black; color: Qt.rgba(1, 1, 1, 0.3); font.family: dashRoot.displayFont; y: 6 }

            // 分
            Column {
                spacing: 1
                Rectangle {
                    width: 36; height: 38; radius: 6
                    color: (mHover.hovered && !dashRoot.isRunning && !dashRoot.isCountUp) ? Qt.rgba(dashRoot.accentColor.r, dashRoot.accentColor.g, dashRoot.accentColor.b, 0.22) : "transparent"
                    border.color: (mHover.hovered && !dashRoot.isRunning && !dashRoot.isCountUp) ? dashRoot.accentColor : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: (dashRoot.minutesPart < 10 ? "0" : "") + dashRoot.minutesPart
                        color: (mHover.hovered && !dashRoot.isRunning && !dashRoot.isCountUp) ? dashRoot.accentColor : "white"
                        font.pixelSize: 24; font.weight: Font.Black; font.family: dashRoot.displayFont
                    }
                    HoverHandler { id: mHover; enabled: !dashRoot.isRunning && !dashRoot.isCountUp; cursorShape: Qt.PointingHandCursor }
                    WheelHandler {
                        enabled: !dashRoot.isRunning && !dashRoot.isCountUp
                        onWheel: (e) => dashRoot.adjustRequested(e.angleDelta.y > 0 ? 60 : -60)
                    }
                }
                Text { text: "分"; font.pixelSize: 8; color: Qt.rgba(1, 1, 1, 0.4); font.weight: Font.Bold; font.family: dashRoot.textFont; anchors.horizontalCenter: parent.horizontalCenter }
            }

            Text { text: ":"; font.pixelSize: 18; font.weight: Font.Black; color: Qt.rgba(1, 1, 1, 0.3); font.family: dashRoot.displayFont; y: 6 }

            // 秒
            Column {
                spacing: 1
                Rectangle {
                    width: 36; height: 38; radius: 6
                    color: (sHover.hovered && !dashRoot.isRunning && !dashRoot.isCountUp) ? Qt.rgba(dashRoot.accentColor.r, dashRoot.accentColor.g, dashRoot.accentColor.b, 0.22) : "transparent"
                    border.color: (sHover.hovered && !dashRoot.isRunning && !dashRoot.isCountUp) ? dashRoot.accentColor : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: (dashRoot.secondsPart < 10 ? "0" : "") + dashRoot.secondsPart
                        color: (sHover.hovered && !dashRoot.isRunning && !dashRoot.isCountUp) ? dashRoot.accentColor : "white"
                        font.pixelSize: 24; font.weight: Font.Black; font.family: dashRoot.displayFont
                    }
                    HoverHandler { id: sHover; enabled: !dashRoot.isRunning && !dashRoot.isCountUp; cursorShape: Qt.PointingHandCursor }
                    WheelHandler {
                        enabled: !dashRoot.isRunning && !dashRoot.isCountUp
                        onWheel: (e) => dashRoot.adjustRequested(e.angleDelta.y > 0 ? 5 : -5)
                    }
                }
                Text { text: "秒"; font.pixelSize: 8; color: Qt.rgba(1, 1, 1, 0.4); font.weight: Font.Bold; font.family: dashRoot.textFont; anchors.horizontalCenter: parent.horizontalCenter }
            }
        }

        // 3. 进度指示底条
        Rectangle {
            width: parent.width - 20; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12)
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle {
                width: Math.round(parent.width * Math.min(1.0, Math.max(0.0, dashRoot.isCompleted ? 1.0 : dashRoot.progress)))
                height: parent.height; radius: 2; color: dashRoot.accentColor
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }
        }
    }
}