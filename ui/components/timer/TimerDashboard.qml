// ==========================================
// 📄 File: ui/components/timer/TimerDashboard.qml
// 🌟 左侧计时大看板 (物理滚轮穿透阻断 · 平滑动量累加 · 强触感反馈版)
// ==========================================
import QtQuick

Rectangle {
    id: dashRoot
    width: 152
    height: parent.height
    radius: (typeof Theme !== "undefined") ? Theme.radiusCard : 16
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

    // 是否允许手动拨动时间调节
    readonly property bool canAdjust: !dashRoot.isRunning && !dashRoot.isCountUp

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

        // 2. 核心时间大字与独立物理滚轮槽位 (时 / 分 / 秒)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 1

            // =================================================================
            // 【时】滚轮槽位
            // =================================================================
            Column {
                spacing: 1

                Rectangle {
                    id: hBox
                    width: 36; height: 38; radius: 6
                    color: (hMouse.containsMouse && dashRoot.canAdjust) ? Qt.rgba(dashRoot.accentColor.r, dashRoot.accentColor.g, dashRoot.accentColor.b, 0.22) : "transparent"
                    border.color: (hMouse.containsMouse && dashRoot.canAdjust) ? dashRoot.accentColor : "transparent"
                    border.width: 1

                    property real visualBump: 1.0
                    scale: visualBump
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        text: (dashRoot.hoursPart < 10 ? "0" : "") + dashRoot.hoursPart
                        color: (hMouse.containsMouse && dashRoot.canAdjust) ? dashRoot.accentColor : "white"
                        font.pixelSize: 24; font.weight: Font.Black; font.family: dashRoot.displayFont
                    }

                    MouseArea {
                        id: hMouse
                        anchors.fill: parent
                        hoverEnabled: dashRoot.canAdjust
                        cursorShape: dashRoot.canAdjust ? Qt.PointingHandCursor : Qt.ArrowCursor
                        acceptedButtons: Qt.LeftButton

                        property real wheelAccum: 0
                        Timer { id: hResetTimer; interval: 250; onTriggered: hMouse.wheelAccum = 0 }

                        onWheel: (wheel) => {
                            if (!dashRoot.canAdjust) return;
                            wheel.accepted = true; // 🚀 关键：彻底吃掉事件，严禁父级抢占！
                            hResetTimer.restart();

                            hMouse.wheelAccum += wheel.angleDelta.y;
                            if (Math.abs(hMouse.wheelAccum) >= 30) {
                                var delta = hMouse.wheelAccum > 0 ? 3600 : -3600;
                                dashRoot.adjustRequested(delta);
                                hMouse.wheelAccum = 0;

                                // 微动效反馈
                                hBox.visualBump = 1.08;
                                hBumpTimer.restart();
                            }
                        }

                        Timer {
                            id: hBumpTimer; interval: 70
                            onTriggered: hBox.visualBump = 1.0
                        }
                    }
                }

                Text {
                    text: "时"
                    font.pixelSize: 8
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.weight: Font.Bold
                    font.family: dashRoot.textFont
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                text: ":"
                font.pixelSize: 18
                font.weight: Font.Black
                color: Qt.rgba(1, 1, 1, 0.3)
                font.family: dashRoot.displayFont
                y: 6
            }

            // =================================================================
            // 【分】滚轮槽位 (最常用，重点加固)
            // =================================================================
            Column {
                spacing: 1

                Rectangle {
                    id: mBox
                    width: 36; height: 38; radius: 6
                    color: (mMouse.containsMouse && dashRoot.canAdjust) ? Qt.rgba(dashRoot.accentColor.r, dashRoot.accentColor.g, dashRoot.accentColor.b, 0.22) : "transparent"
                    border.color: (mMouse.containsMouse && dashRoot.canAdjust) ? dashRoot.accentColor : "transparent"
                    border.width: 1

                    property real visualBump: 1.0
                    scale: visualBump
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        text: (dashRoot.minutesPart < 10 ? "0" : "") + dashRoot.minutesPart
                        color: (mMouse.containsMouse && dashRoot.canAdjust) ? dashRoot.accentColor : "white"
                        font.pixelSize: 24; font.weight: Font.Black; font.family: dashRoot.displayFont
                    }

                    MouseArea {
                        id: mMouse
                        anchors.fill: parent
                        hoverEnabled: dashRoot.canAdjust
                        cursorShape: dashRoot.canAdjust ? Qt.PointingHandCursor : Qt.ArrowCursor
                        acceptedButtons: Qt.LeftButton

                        property real wheelAccum: 0
                        Timer { id: mResetTimer; interval: 250; onTriggered: mMouse.wheelAccum = 0 }

                        onWheel: (wheel) => {
                            if (!dashRoot.canAdjust) return;
                            wheel.accepted = true; // 🚀 关键：彻底吃掉事件，严禁父级抢占！
                            mResetTimer.restart();

                            mMouse.wheelAccum += wheel.angleDelta.y;
                            if (Math.abs(mMouse.wheelAccum) >= 30) {
                                var delta = mMouse.wheelAccum > 0 ? 60 : -60;
                                dashRoot.adjustRequested(delta);
                                mMouse.wheelAccum = 0;

                                // 微动效反馈
                                mBox.visualBump = 1.08;
                                mBumpTimer.restart();
                            }
                        }

                        Timer {
                            id: mBumpTimer; interval: 70
                            onTriggered: mBox.visualBump = 1.0
                        }
                    }
                }

                Text {
                    text: "分"
                    font.pixelSize: 8
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.weight: Font.Bold
                    font.family: dashRoot.textFont
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Text {
                text: ":"
                font.pixelSize: 18
                font.weight: Font.Black
                color: Qt.rgba(1, 1, 1, 0.3)
                font.family: dashRoot.displayFont
                y: 6
            }

            // =================================================================
            // 【秒】滚轮槽位
            // =================================================================
            Column {
                spacing: 1

                Rectangle {
                    id: sBox
                    width: 36; height: 38; radius: 6
                    color: (sMouse.containsMouse && dashRoot.canAdjust) ? Qt.rgba(dashRoot.accentColor.r, dashRoot.accentColor.g, dashRoot.accentColor.b, 0.22) : "transparent"
                    border.color: (sMouse.containsMouse && dashRoot.canAdjust) ? dashRoot.accentColor : "transparent"
                    border.width: 1

                    property real visualBump: 1.0
                    scale: visualBump
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        text: (dashRoot.secondsPart < 10 ? "0" : "") + dashRoot.secondsPart
                        color: (sMouse.containsMouse && dashRoot.canAdjust) ? dashRoot.accentColor : "white"
                        font.pixelSize: 24; font.weight: Font.Black; font.family: dashRoot.displayFont
                    }

                    MouseArea {
                        id: sMouse
                        anchors.fill: parent
                        hoverEnabled: dashRoot.canAdjust
                        cursorShape: dashRoot.canAdjust ? Qt.PointingHandCursor : Qt.ArrowCursor
                        acceptedButtons: Qt.LeftButton

                        property real wheelAccum: 0
                        Timer { id: sResetTimer; interval: 250; onTriggered: sMouse.wheelAccum = 0 }

                        onWheel: (wheel) => {
                            if (!dashRoot.canAdjust) return;
                            wheel.accepted = true; // 🚀 关键：彻底吃掉事件，严禁父级抢占！
                            sResetTimer.restart();

                            sMouse.wheelAccum += wheel.angleDelta.y;
                            if (Math.abs(sMouse.wheelAccum) >= 30) {
                                var delta = sMouse.wheelAccum > 0 ? 5 : -5;
                                dashRoot.adjustRequested(delta);
                                sMouse.wheelAccum = 0;

                                // 微动效反馈
                                sBox.visualBump = 1.08;
                                sBumpTimer.restart();
                            }
                        }

                        Timer {
                            id: sBumpTimer; interval: 70
                            onTriggered: sBox.visualBump = 1.0
                        }
                    }
                }

                Text {
                    text: "秒"
                    font.pixelSize: 8
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.weight: Font.Bold
                    font.family: dashRoot.textFont
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // 3. 底部进度条
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