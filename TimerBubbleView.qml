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

    // 二次确认状态机变量
    property bool isConfirmingDismiss: false

    signal togglePause()
    signal dismissTimer()

    transformOrigin: Item.Left

    // 二次确认超时自动复位（4秒未操作自动还原）
    Timer {
        id: dismissConfirmTimer
        interval: 4000
        repeat: false
        onTriggered: timerBubbleRoot.isConfirmingDismiss = false
    }

    // =========================================================================
    // 1. 状态机模型定义
    // =========================================================================
    readonly property string currentState: {
        if (isConfirmingDismiss) return "confirming"
        if (isCompleted) return "completed"
        if (isPaused) return "paused"
        if (isRunning) return "running"
        return "idle"
    }

    readonly property color stateAccentColor: {
        if (isConfirmingDismiss) return Theme.danger
        if (currentState === "paused") return "#f59e0b"        // 暂停琥珀金
        if (currentState === "completed") return "#10b981"     // 完成清新绿
        if (isCountUp) return Theme.stopwatch
        if (remainingSeconds <= 60) return "#ef4444"          // 临近结束警示红
        if (remainingSeconds <= 300) return "#f97316"         // 剩余5分钟活力橙
        return Theme.timer
    }

    // 🚀【核心修复】：宽度严格固定，原位切换，绝不延长胶囊，彻底消灭穿模
    width: hasHours ? 106 : 90
    height: 34
    radius: height / 2
    clip: true

    color: Theme.bgCapsule
    border.width: 1.2
    border.color: isConfirmingDismiss ?
                  Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.85) :
                  (timerBubbleRoot.isHovered ?
                  Qt.lighter(stateAccentColor, 1.2) :
                  (currentState === "paused" ? Qt.rgba(245, 158, 11, 0.6) :
                  (currentState === "completed" ? Qt.rgba(16, 185, 129, 0.7) : Qt.rgba(stateAccentColor.r, stateAccentColor.g, stateAccentColor.b, 0.4))))

    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    visible: active
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    Behavior on width {
        NumberAnimation {
            duration: Theme.animSpring
            easing.type: Easing.OutBack
            easing.overshoot: Theme.springOvershootSubtle
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutQuad
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animSpring
            easing.type: Easing.OutBack
            easing.overshoot: Theme.springOvershootNormal
        }
    }

    onProgressChanged: progressCanvas.requestPaint()
    onStateAccentColorChanged: progressCanvas.requestPaint()
    onCurrentStateChanged: {
        progressCanvas.requestPaint()
        if (currentState !== "paused") {
            contentRow.opacity = 1.0
        }
    }

    // 二次确认时的背景微红警示光圈
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.14)
        visible: timerBubbleRoot.isConfirmingDismiss
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    // =========================================================================
    // 常态时间与状态圈内容行
    // =========================================================================
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6
        visible: !timerBubbleRoot.isConfirmingDismiss
        opacity: visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad }
        }

        // 暂停态独立呼吸动效
        SequentialAnimation {
            id: pauseBreatheAnim
            running: timerBubbleRoot.currentState === "paused" && !timerBubbleRoot.isConfirmingDismiss
            loops: Animation.Infinite
            NumberAnimation { target: contentRow; property: "opacity"; to: 0.55; duration: 750; easing.type: Easing.InOutSine }
            NumberAnimation { target: contentRow; property: "opacity"; to: 1.0; duration: 750; easing.type: Easing.InOutSine }
            onRunningChanged: {
                if (!running) {
                    contentRow.opacity = 1.0
                }
            }
        }

        // 环形进度圈与状态核心标识
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

            // 暂停态双竖线微暂停标
            Row {
                anchors.centerIn: parent
                spacing: 2.2
                visible: timerBubbleRoot.currentState === "paused"

                Rectangle { width: 1.8; height: 6; radius: 0.9; color: "#f59e0b" }
                Rectangle { width: 1.8; height: 6; radius: 0.9; color: "#f59e0b" }
            }

            // 完成态中心打勾徽标
            Text {
                anchors.centerIn: parent
                text: "✓"
                font.pixelSize: 10
                font.weight: Font.Black
                color: "#10b981"
                visible: timerBubbleRoot.currentState === "completed"
            }
        }

        // 等宽紧凑时间大字
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

    // =========================================================================
    // 🚀 2. 原位内嵌二次确认操作层 (总宽 80px，完美收拢在 90px 岛体内)
    // =========================================================================
    Row {
        id: confirmRow
        anchors.centerIn: parent
        spacing: 5
        visible: timerBubbleRoot.isConfirmingDismiss
        opacity: visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad }
        }

        Text {
            text: "结束?"
            color: Theme.danger
            font.pixelSize: 10
            font.weight: Font.Black
            font.family: (timerBubbleRoot.chosenFont !== "") ? timerBubbleRoot.chosenFont : "Monospace"
            anchors.verticalCenter: parent.verticalCenter
        }

        // 确认结束按钮 (✓)
        Rectangle {
            width: 22; height: 22; radius: 11
            anchors.verticalCenter: parent.verticalCenter
            color: confirmYesTap.pressed ? "#991b1b" : (confirmYesHover.hovered ? "#dc2626" : Theme.danger)
            scale: confirmYesTap.pressed ? 0.9 : (confirmYesHover.hovered ? 1.06 : 1.0)
            Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }

            Text {
                anchors.centerIn: parent
                text: "✓"
                color: "white"
                font.pixelSize: 11
                font.weight: Font.Black
            }

            HoverHandler { id: confirmYesHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: confirmYesTap
                onTapped: {
                    dismissConfirmTimer.stop()
                    timerBubbleRoot.isConfirmingDismiss = false
                    timerBubbleRoot.dismissTimer()
                }
            }
        }

        // 取消返回按钮 (✕)
        Rectangle {
            width: 22; height: 22; radius: 11
            anchors.verticalCenter: parent.verticalCenter
            color: confirmNoTap.pressed ? Qt.rgba(1, 1, 1, 0.25) : (confirmNoHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
            border.color: Theme.borderSubtle
            border.width: 1
            scale: confirmNoTap.pressed ? 0.9 : (confirmNoHover.hovered ? 1.06 : 1.0)
            Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: Qt.rgba(1, 1, 1, 0.8)
                font.pixelSize: 10
                font.weight: Font.Bold
            }

            HoverHandler { id: confirmNoHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: confirmNoTap
                onTapped: {
                    dismissConfirmTimer.stop()
                    timerBubbleRoot.isConfirmingDismiss = false
                }
            }
        }
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }

    // 左键单击：常态下切换 暂停/继续；确认态下点击外部区域取消确认
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            if (timerBubbleRoot.isConfirmingDismiss) {
                dismissConfirmTimer.stop()
                timerBubbleRoot.isConfirmingDismiss = false
            } else {
                timerBubbleRoot.togglePause()
            }
        }
    }

    // 右键单击：激活二次确认；再次右键则取消确认
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            if (timerBubbleRoot.isConfirmingDismiss) {
                dismissConfirmTimer.stop()
                timerBubbleRoot.isConfirmingDismiss = false
            } else {
                timerBubbleRoot.isConfirmingDismiss = true
                dismissConfirmTimer.restart()
            }
        }
    }
}