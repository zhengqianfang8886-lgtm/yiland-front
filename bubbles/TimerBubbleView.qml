// ==========================================
// 📄 File: bubbles/TimerBubbleView.qml
// ==========================================
import QtQuick
import QtQuick.Shapes

Rectangle {
    id: timerBubbleRoot

    property string chosenFont: ""
    readonly property string displayFont: (typeof Config !== "undefined") ? Config.numberFont : "Monospace"
    readonly property string textFont: (typeof Config !== "undefined") ? Config.activeFont : ""

    property bool active: false
    readonly property bool isHovered: bubbleHover.hovered

    property string timerText: "25:00"
    property bool hasHours: false
    property bool isCountUp: false
    property bool isRunning: false
    property bool isPaused: false
    property bool isCompleted: false
    property real progress: 1.0
    property int remainingSeconds: 0
    property int totalSeconds: 0

    property bool isConfirmingDismiss: false

    signal togglePause()
    signal dismissTimer()

    transformOrigin: Item.Left

    Timer {
        id: dismissConfirmTimer
        interval: 3500
        repeat: false
        onTriggered: timerBubbleRoot.isConfirmingDismiss = false
    }

    readonly property string currentState: {
        if (isConfirmingDismiss) return "confirming"
        if (isCompleted) return "completed"
        if (isPaused) return "paused"
        if (isRunning) return "running"
        return "idle"
    }

    readonly property color stateAccentColor: {
        if (isConfirmingDismiss) return Theme.danger
        if (currentState === "paused") return "#f59e0b"
        if (currentState === "completed") return "#10b981"
        if (isCountUp) return Theme.stopwatch
        if (remainingSeconds <= 60) return "#ef4444"
        if (remainingSeconds <= 300) return "#f97316"
        return Theme.timer
    }

    width: hasHours ? 104 : 88
    height: 34
    radius: height / 2
    clip: true

    color: Theme.bgCapsule
    border.width: 1
    border.color: isConfirmingDismiss ?
                  Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.85) :
                  (timerBubbleRoot.isHovered ?
                  Qt.lighter(stateAccentColor, 1.2) :
                  (currentState === "paused" ? Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.6) :
                  (currentState === "completed" ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.7) : Qt.rgba(stateAccentColor.r, stateAccentColor.g, stateAccentColor.b, 0.4))))

    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    // 🚀【核心修复】：平滑透明度过滤，杜绝 visible 硬切造成合成器层不可见
    visible: opacity > 0.001
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    Behavior on width { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveDecel } }
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveFluid } }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animSpring
            easing.type: Theme.curveSpring
            easing.overshoot: Theme.springOvershootNormal
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.14)
        visible: timerBubbleRoot.isConfirmingDismiss
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveFluid } }
    }

    readonly property string rawDisplayStr: timerBubbleRoot.currentState === "completed" ? "00:00" : timerBubbleRoot.timerText
    readonly property var charList: rawDisplayStr.split("")

    // 🚀【核心修复】：独立驱动呼吸透明度，彻底解除 SequentialAnimation 与 Behavior 争用冲突
    property real pauseBreatheFactor: 1.0
    SequentialAnimation {
        id: pauseBreatheAnim
        running: timerBubbleRoot.currentState === "paused" && !timerBubbleRoot.isConfirmingDismiss
        loops: Animation.Infinite
        NumberAnimation { target: timerBubbleRoot; property: "pauseBreatheFactor"; to: 0.55; duration: Theme.animSlow * 2.5; easing.type: Easing.InOutSine }
        NumberAnimation { target: timerBubbleRoot; property: "pauseBreatheFactor"; to: 1.0; duration: Theme.animSlow * 2.5; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) timerBubbleRoot.pauseBreatheFactor = 1.0
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 5
        visible: !timerBubbleRoot.isConfirmingDismiss
        opacity: visible ? (timerBubbleRoot.currentState === "paused" ? timerBubbleRoot.pauseBreatheFactor : 1.0) : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveFluid } }

        // 1.1 动态圆环指示器
        Item {
            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter

            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    strokeWidth: 2.2
                    strokeColor: Qt.rgba(1, 1, 1, 0.12)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: 9; centerY: 9
                        radiusX: 7.0; radiusY: 7.0
                        startAngle: -90; sweepAngle: 360
                    }
                }

                ShapePath {
                    strokeWidth: 2.2
                    strokeColor: timerBubbleRoot.stateAccentColor
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: 9; centerY: 9
                        radiusX: 7.0; radiusY: 7.0
                        startAngle: -90
                        sweepAngle: {
                            if (timerBubbleRoot.currentState === "completed") return 360
                            var p = Math.min(1.0, Math.max(0.0, timerBubbleRoot.progress))
                            return p > 0.005 ? 360 * p : 0
                        }
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 2
                visible: timerBubbleRoot.currentState === "paused"
                Rectangle { width: 1.8; height: 6; radius: 0.9; color: "#f59e0b" }
                Rectangle { width: 1.8; height: 6; radius: 0.9; color: "#f59e0b" }
            }

            Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 10
                font.weight: Font.Black
                color: "#10b981"
                visible: timerBubbleRoot.currentState === "completed"
            }
        }

        // 1.2 独立等宽槽位
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Repeater {
                model: timerBubbleRoot.charList

                Item {
                    readonly property bool isColon: (modelData === ":")
                    width: isColon ? 5 : (timerBubbleRoot.hasHours ? 8 : 9)
                    height: 20

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: timerBubbleRoot.currentState === "paused" ? "#fcd34d" :
                               (timerBubbleRoot.currentState === "completed" ? "#6ee7b7" : "white")
                        font.family: timerBubbleRoot.displayFont
                        font.pixelSize: timerBubbleRoot.hasHours ? 12 : 13
                        font.weight: Font.Black
                        renderType: Text.QtRendering
                    }
                }
            }
        }
    }

    MouseArea {
        id: mainTouchArea
        anchors.fill: parent
        enabled: !timerBubbleRoot.isConfirmingDismiss
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                timerBubbleRoot.togglePause()
            } else if (mouse.button === Qt.RightButton) {
                timerBubbleRoot.isConfirmingDismiss = true
                dismissConfirmTimer.restart()
            }
        }
    }

    Row {
        id: confirmRow
        anchors.centerIn: parent
        spacing: 6
        visible: opacity > 0.01
        opacity: timerBubbleRoot.isConfirmingDismiss ? 1.0 : 0.0
        scale: timerBubbleRoot.isConfirmingDismiss ? 1.0 : 0.92
        z: 10

        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveFluid } }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.animFast
                easing.type: Theme.curveSpring
                easing.overshoot: Theme.springOvershootSubtle
            }
        }

        Rectangle {
            width: (timerBubbleRoot.width - 18) / 2
            height: 24
            radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: backMouse.pressed ? Qt.rgba(1, 1, 1, 0.22) : (backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
            border.color: backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Theme.borderSubtle
            border.width: 1
            scale: backMouse.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.animInstant } }

            Shape {
                anchors.centerIn: parent
                width: 12; height: 12
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeColor: backMouse.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.85)
                    strokeWidth: 1.6
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    startX: 5.5; startY: 2.8
                    PathLine { x: 2.2; y: 6.0 }
                    PathLine { x: 5.5; y: 9.2 }
                    PathMove { x: 2.2; y: 6.0 }
                    PathLine { x: 10.0; y: 6.0 }
                }
            }

            MouseArea {
                id: backMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    dismissConfirmTimer.stop()
                    timerBubbleRoot.isConfirmingDismiss = false
                }
            }
        }

        Rectangle {
            width: (timerBubbleRoot.width - 18) / 2
            height: 24
            radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: closeMouse.pressed ? "#991b1b" : (closeMouse.containsMouse ? "#dc2626" : Theme.danger)
            scale: closeMouse.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: Theme.animInstant } }

            Shape {
                anchors.centerIn: parent
                width: 10; height: 10
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeColor: "white"
                    strokeWidth: 1.8
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 1.5; startY: 1.5
                    PathLine { x: 8.5; y: 8.5 }
                    PathMove { x: 8.5; y: 1.5 }
                    PathLine { x: 1.5; y: 8.5 }
                }
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    dismissConfirmTimer.stop()
                    timerBubbleRoot.isConfirmingDismiss = false
                    timerBubbleRoot.dismissTimer()
                }
            }
        }
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }
}