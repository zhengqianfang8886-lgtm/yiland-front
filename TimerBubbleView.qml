// ==========================================
// 📄 File: TimerBubbleView.qml
// 🌟 独立等宽数字槽位架构 · 彻底死锁时间长度 · 零抖动完整版
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

    // 🚀【宽度锁定】：小时态固定 104px，分秒态固定 88px
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

    visible: active
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

    onProgressChanged: progressCanvas.requestPaint()
    onStateAccentColorChanged: progressCanvas.requestPaint()
    onCurrentStateChanged: {
        progressCanvas.requestPaint()
        if (currentState !== "paused") contentRow.opacity = 1.0
    }

    // 右键解散警告底色
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.14)
        visible: timerBubbleRoot.isConfirmingDismiss
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveFluid } }
    }

    // 🚀 将当前时间文本拆分为单字符数组，供等宽槽位绑定
    readonly property string rawDisplayStr: timerBubbleRoot.currentState === "completed" ? "00:00" : timerBubbleRoot.timerText
    readonly property var charList: rawDisplayStr.split("")

    // =========================================================================
    // 1. 常态时间展示行 (圆环进度 + 独立等宽槽位时间)
    // =========================================================================
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 5
        visible: !timerBubbleRoot.isConfirmingDismiss
        opacity: visible ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveFluid } }

        SequentialAnimation {
            id: pauseBreatheAnim
            running: timerBubbleRoot.currentState === "paused" && !timerBubbleRoot.isConfirmingDismiss
            loops: Animation.Infinite
            NumberAnimation { target: contentRow; property: "opacity"; to: 0.55; duration: Theme.animSlow * 2.5; easing.type: Easing.InOutSine }
            NumberAnimation { target: contentRow; property: "opacity"; to: 1.0; duration: Theme.animSlow * 2.5; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) contentRow.opacity = 1.0
        }

        // 1.1 左侧动态圆环指示器 (18x18 固定)
        Item {
            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: progressCanvas
                anchors.fill: parent
                renderTarget: Canvas.FramebufferObject
                renderStrategy: Canvas.Immediate

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)

                    var cx = width / 2, cy = height / 2, radius = 7.0, strokeW = 2.2
                    ctx.beginPath()
                    ctx.arc(cx, cy, radius, 0, 2 * Math.PI, false)
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.12)"
                    ctx.lineWidth = strokeW
                    ctx.stroke()

                    var p = Math.min(1.0, Math.max(0.0, timerBubbleRoot.progress))
                    if (timerBubbleRoot.currentState === "completed") p = 1.0
                    if (p > 0.005) {
                        var startAngle = -0.5 * Math.PI
                        var endAngle = startAngle + (2 * Math.PI * p)
                        ctx.beginPath()
                        ctx.arc(cx, cy, radius, startAngle, endAngle, false)
                        ctx.strokeStyle = timerBubbleRoot.stateAccentColor.toString()
                        ctx.lineWidth = strokeW
                        ctx.lineCap = "round"
                        ctx.stroke()
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

        // 1.2 🚀【核心设计：独立等宽槽位】：数字独占 9px，冒号独占 5px，物理长度绝对死锁！
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Repeater {
                model: timerBubbleRoot.charList

                Item {
                    // 数字锁定 9px (含小时字号略小锁定 8px)，冒号锁定 5px
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

    // =========================================================================
    // 2. 右键确认层
    // =========================================================================
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