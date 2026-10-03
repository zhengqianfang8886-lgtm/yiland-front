import QtQuick
import QtQuick.Shapes

Rectangle {
    id: timerBubbleRoot

    // 🚀 补回供 Island.qml 绑定的接口属性，彻底消除编译报错
    property string chosenFont: ""

    // 🚀 全局字体响应：时间与数字直连 Config.numberFont，普通文本直连 Config.activeFont
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

    Behavior on width { NumberAnimation { duration: Theme.animSpring; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershootSubtle } }
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: Theme.animSpring; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershootNormal } }

    onProgressChanged: progressCanvas.requestPaint()
    onStateAccentColorChanged: progressCanvas.requestPaint()
    onCurrentStateChanged: {
        progressCanvas.requestPaint()
        if (currentState !== "paused") contentRow.opacity = 1.0
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.14)
        visible: timerBubbleRoot.isConfirmingDismiss
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    }

    // =========================================================================
    // 1. 常态时间显示
    // =========================================================================
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6
        visible: !timerBubbleRoot.isConfirmingDismiss
        opacity: visible ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }

        SequentialAnimation {
            id: pauseBreatheAnim
            running: timerBubbleRoot.currentState === "paused" && !timerBubbleRoot.isConfirmingDismiss
            loops: Animation.Infinite
            NumberAnimation { target: contentRow; property: "opacity"; to: 0.55; duration: 750; easing.type: Easing.InOutSine }
            NumberAnimation { target: contentRow; property: "opacity"; to: 1.0; duration: 750; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) contentRow.opacity = 1.0
        }

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
                spacing: 2.2
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

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: timerBubbleRoot.currentState === "completed" ? "00:00" : timerBubbleRoot.timerText
            color: timerBubbleRoot.currentState === "paused" ? "#fcd34d" :
                   (timerBubbleRoot.currentState === "completed" ? "#6ee7b7" : "white")
            font.family: timerBubbleRoot.displayFont
            font.pixelSize: timerBubbleRoot.hasHours ? 12 : 14
            font.weight: Font.Black
            font.letterSpacing: 0.3
        }
    }

    // 🚀【核心手势控制器】：完全隔离左键与右键，进入确认状态时立即禁用，绝无事件穿透！
    MouseArea {
        id: mainTouchArea
        anchors.fill: parent
        enabled: !timerBubbleRoot.isConfirmingDismiss
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                // 🚀 规则 1：左键点击是【唯一】合法的暂停/继续开关！
                timerBubbleRoot.togglePause()
            } else if (mouse.button === Qt.RightButton) {
                // 🚀 规则 2：右键点击【绝对禁止触发暂停】！时间继续走，只呼出关闭确认
                timerBubbleRoot.isConfirmingDismiss = true
                dismissConfirmTimer.restart()
            }
        }
    }

    // =========================================================================
    // 2. 右键呼出的关闭层 (左返回 ← / 右直接消失 ✕)
    // =========================================================================
    Row {
        id: confirmRow
        anchors.centerIn: parent
        spacing: 6
        visible: timerBubbleRoot.isConfirmingDismiss
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.92
        z: 10

        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershootSubtle } }

        // 返回箭头
        Rectangle {
            width: (timerBubbleRoot.width - 18) / 2
            height: 24
            radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: backMouse.pressed ? Qt.rgba(1, 1, 1, 0.22) : (backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
            border.color: backMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Theme.borderSubtle
            border.width: 1
            scale: backMouse.pressed ? 0.92 : 1.0

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

        // 🚀 红色按钮：点击后时间小岛像灵动岛一样【直接消失】！绝不重置重新开始！
        Rectangle {
            width: (timerBubbleRoot.width - 18) / 2
            height: 24
            radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: closeMouse.pressed ? "#991b1b" : (closeMouse.containsMouse ? "#dc2626" : Theme.danger)
            scale: closeMouse.pressed ? 0.92 : 1.0

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
                    // 🚀 发射 dismissTimer 让小岛静默缩回消失
                    timerBubbleRoot.dismissTimer()
                }
            }
        }
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }
}