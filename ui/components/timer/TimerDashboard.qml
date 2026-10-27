// ==========================================
// 📄 File: ui/components/timer/TimerDashboard.qml
// 🌟 沉浸式计时大仪表盘 (支持超时追溯视觉联动版)
// ==========================================
import QtQuick

Rectangle {
    id: dashRoot
    width: 172
    height: parent.height
    radius: (typeof Theme !== "undefined") ? Theme.radiusCard : 16

    color: Qt.rgba(14 / 255, 16 / 255, 24 / 255, 0.95)
    border.color: Qt.rgba(dashRoot.accentColor.r, dashRoot.accentColor.g, dashRoot.accentColor.b, dashRoot.isRunning ? 0.45 : 0.20)
    border.width: 1.5

    Behavior on border.color { ColorAnimation { duration: 250 } }

    property color accentColor: "#f97316"
    property string textFont: ""
    property string displayFont: "Monospace"
    property bool isRunning: false
    property bool isPaused: false
    property bool isCompleted: false
    property bool isOvertime: false  // 🚀
    property bool isCountUp: false
    property string currentMode: "focus"
    property real progress: 0.0

    property int hoursPart: 0
    property int minutesPart: 0
    property int secondsPart: 0

    signal adjustRequested(int deltaSec)

    readonly property bool hasHours: hoursPart > 0
    readonly property bool canAdjust: !dashRoot.isRunning && !dashRoot.isCountUp && !dashRoot.isOvertime

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        // 顶栏徽标
        Item {
            width: parent.width
            height: 18

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                width: statusRow.implicitWidth + 12
                radius: 9
                color: Qt.rgba(dashRoot.accentColor.r, dashRoot.accentColor.g, dashRoot.accentColor.b, 0.16)
                border.color: Qt.rgba(dashRoot.accentColor.r, dashRoot.accentColor.g, dashRoot.accentColor.b, 0.35)
                border.width: 1

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 4

                    Rectangle {
                        width: 5; height: 5; radius: 2.5
                        color: dashRoot.accentColor
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            running: dashRoot.isRunning || dashRoot.isCompleted || dashRoot.isOvertime
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 500; easing.type: Easing.OutQuad }
                            NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InQuad }
                        }
                    }

                    Text {
                        text: {
                            if (dashRoot.isOvertime) return "已超时 · 追溯中";
                            if (dashRoot.isCompleted) return "已完成";
                            if (dashRoot.isCountUp) return dashRoot.isRunning ? "秒表计时中" : (dashRoot.isPaused ? "已暂停" : "秒表就绪");
                            if (dashRoot.currentMode === "break") return dashRoot.isRunning ? "休息放松中" : "小憩暂停";
                            return dashRoot.isRunning ? "深度专注中" : (dashRoot.isPaused ? "专注已暂停" : "专注倒计时");
                        }
                        font.pixelSize: 9
                        font.weight: Font.Black
                        color: dashRoot.accentColor
                        font.family: dashRoot.textFont
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: dashRoot.canAdjust ? "滚轮微调" : ""
                font.pixelSize: 8
                font.weight: Font.Bold
                color: Qt.rgba(1, 1, 1, 0.35)
                font.family: dashRoot.textFont
                visible: dashRoot.canAdjust
            }
        }

        // 核心大字
        Item {
            width: parent.width
            height: parent.height - 18 - 6 - 8 - 14

            Row {
                anchors.centerIn: parent
                spacing: 1

                // 🚀 超时前置 "+"
                Text {
                    visible: dashRoot.isOvertime
                    text: "+"
                    font.pixelSize: dashRoot.hasHours ? 22 : 32
                    font.weight: Font.Black
                    color: dashRoot.accentColor
                    font.family: dashRoot.displayFont
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                }

                // 时
                Item {
                    visible: dashRoot.hasHours
                    width: 32
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: (dashRoot.hoursPart < 10 ? "0" : "") + dashRoot.hoursPart
                        font.pixelSize: 26
                        font.weight: Font.Black
                        font.family: dashRoot.displayFont
                        color: dashRoot.accentColor
                        renderType: Text.QtRendering
                    }
                }

                Text {
                    text: ":"
                    font.pixelSize: dashRoot.hasHours ? 22 : 32
                    font.weight: Font.Black
                    color: Qt.rgba(1, 1, 1, 0.25)
                    font.family: dashRoot.displayFont
                    visible: dashRoot.hasHours
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                }

                // 分
                Item {
                    width: dashRoot.hasHours ? 34 : 58
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: (dashRoot.minutesPart < 10 ? "0" : "") + dashRoot.minutesPart
                        font.pixelSize: dashRoot.hasHours ? 28 : 42
                        font.weight: Font.Black
                        font.family: dashRoot.displayFont
                        color: dashRoot.isOvertime ? dashRoot.accentColor : (mArea.containsMouse && dashRoot.canAdjust ? dashRoot.accentColor : "#ffffff")
                        renderType: Text.QtRendering
                    }

                    MouseArea {
                        id: mArea
                        anchors.fill: parent
                        hoverEnabled: dashRoot.canAdjust
                        cursorShape: dashRoot.canAdjust ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onWheel: (wheel) => {
                            if (!dashRoot.canAdjust) return;
                            wheel.accepted = true;
                            dashRoot.adjustRequested(wheel.angleDelta.y > 0 ? 60 : -60);
                        }
                    }
                }

                Text {
                    text: ":"
                    font.pixelSize: dashRoot.hasHours ? 22 : 36
                    font.weight: Font.Black
                    color: Qt.rgba(1, 1, 1, 0.25)
                    font.family: dashRoot.displayFont
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                }

                // 秒
                Item {
                    width: dashRoot.hasHours ? 34 : 58
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: (dashRoot.secondsPart < 10 ? "0" : "") + dashRoot.secondsPart
                        font.pixelSize: dashRoot.hasHours ? 28 : 42
                        font.weight: Font.Black
                        font.family: dashRoot.displayFont
                        color: dashRoot.isOvertime ? dashRoot.accentColor : (sArea.containsMouse && dashRoot.canAdjust ? dashRoot.accentColor : "#ffffff")
                        renderType: Text.QtRendering
                    }

                    MouseArea {
                        id: sArea
                        anchors.fill: parent
                        hoverEnabled: dashRoot.canAdjust
                        cursorShape: dashRoot.canAdjust ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onWheel: (wheel) => {
                            if (!dashRoot.canAdjust) return;
                            wheel.accepted = true;
                            dashRoot.adjustRequested(wheel.angleDelta.y > 0 ? 5 : -5);
                        }
                    }
                }
            }
        }

        // 底部加粗流体进度条
        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(1, 1, 1, 0.10)
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: 3
                width: dashRoot.isOvertime ? parent.width : Math.max(height, Math.round(parent.width * Math.min(1.0, Math.max(0.0, dashRoot.progress))))
                color: dashRoot.accentColor

                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }
            }
        }
    }
}