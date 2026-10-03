import QtQuick
import QtQuick.Shapes

Rectangle {
    id: timerBubbleRoot

    property string chosenFont: ""
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

    signal togglePause()
    signal dismissTimer()

    transformOrigin: Item.Left

    // =========================================================================
    // 1. 状态机模型定义 (State Machine)
    // =========================================================================
    readonly property string currentState: {
        if (isCompleted) return "completed"
        if (isPaused) return "paused"
        if (isRunning) return "running"
        return "idle"
    }

    readonly property color stateAccentColor: {
        if (currentState === "paused") return "#f59e0b"        // 暂停琥珀金
        if (currentState === "completed") return "#10b981"     // 完成清新绿
        if (isCountUp) return Theme.stopwatch
        if (remainingSeconds <= 60) return "#ef4444"          // 临近结束警示红
        if (remainingSeconds <= 300) return "#f97316"         // 剩余5分钟活力橙
        return Theme.timer
    }

    width: hasHours ? 106 : 90
    height: 34
    radius: height / 2
    clip: true

    color: Theme.bgCapsule
    border.width: 1.2
    border.color: timerBubbleRoot.isHovered ?
                  Qt.lighter(stateAccentColor, 1.2) :
                  (currentState === "paused" ? Qt.rgba(245, 158, 11, 0.6) :
                  (currentState === "completed" ? Qt.rgba(16, 185, 129, 0.7) : Qt.rgba(stateAccentColor.r, stateAccentColor.g, stateAccentColor.b, 0.4)))
    Behavior on border.color { ColorAnimation { duration: 180 } }

    visible: active
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershoot } }

    onProgressChanged: progressCanvas.requestPaint()
    onStateAccentColorChanged: progressCanvas.requestPaint()
    onCurrentStateChanged: {
        progressCanvas.requestPaint()
        // 🚀 核心修复：一旦切出暂停状态，无条件重置内容层透明度为 100%
        if (currentState !== "paused") {
            contentRow.opacity = 1.0
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6
        opacity: 1.0

        Behavior on opacity {
            enabled: timerBubbleRoot.currentState !== "paused"
            NumberAnimation { duration: 120 }
        }

        // 🚀 核心修复：通过独立控制器管理呼吸动效，停止时触发强制复位，绝不定格在灰色
        SequentialAnimation {
            id: pauseBreatheAnim
            running: timerBubbleRoot.currentState === "paused"
            loops: Animation.Infinite
            NumberAnimation { target: contentRow; property: "opacity"; to: 0.55; duration: 750; easing.type: Easing.InOutSine }
            NumberAnimation { target: contentRow; property: "opacity"; to: 1.0; duration: 750; easing.type: Easing.InOutSine }
            onRunningChanged: {
                if (!running) {
                    contentRow.opacity = 1.0
                }
            }
        }

        // =====================================================================
        // 环形进度圈与状态核心标识
        // =====================================================================
        Item {
            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: progressCanvas
                anchors.fill: parent
                renderTarget: Canvas.FramebufferObject
                renderStrategy: Canvas.Threaded

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)

                    var cx = width / 2
                    var cy = height / 2
                    var radius = 7.0
                    var strokeW = 2.2

                    // 底环
                    ctx.beginPath()
                    ctx.arc(cx, cy, radius, 0, 2 * Math.PI, false)
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.12)"
                    ctx.lineWidth = strokeW
                    ctx.stroke()

                    // 进度弧
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

            // 暂停态：圆环正中精致的双竖线微暂停标
            Row {
                anchors.centerIn: parent
                spacing: 2.2
                visible: timerBubbleRoot.currentState === "paused"

                Rectangle { width: 1.8; height: 6; radius: 0.9; color: "#f59e0b" }
                Rectangle { width: 1.8; height: 6; radius: 0.9; color: "#f59e0b" }
            }

            // 完成态：中心打勾徽标
            Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 10
                font.weight: Font.Black
                color: "#10b981"
                visible: timerBubbleRoot.currentState === "completed"
            }
        }

        // =====================================================================
        // 等宽紧凑时间大字 (字号严格使用整型 12/14)
        // =====================================================================
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: timerBubbleRoot.currentState === "completed" ? "00:00" : timerBubbleRoot.timerText
            color: timerBubbleRoot.currentState === "paused" ? "#fcd34d" :
                   (timerBubbleRoot.currentState === "completed" ? "#6ee7b7" : "white")
            font.family: (timerBubbleRoot.chosenFont !== "") ? timerBubbleRoot.chosenFont : "Monospace"
            font.pixelSize: timerBubbleRoot.hasHours ? 12 : 14
            font.weight: Font.Black
            font.letterSpacing: 0.3
        }
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }

    // 左键单击：切换 暂停 / 继续
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: timerBubbleRoot.togglePause()
    }

    // 右键单击：重置并退场
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: timerBubbleRoot.dismissTimer()
    }
}