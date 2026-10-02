import QtQuick

Item {
    id: timerRoot

    property string chosenFont: ""
    property string timerType: "countdown"
    readonly property bool isCountUp: timerType === "stopwatch"

    property bool isRunning: false
    property bool isPaused: false

    property int remainingSeconds: 1500
    property int totalSeconds: 1500
    property string currentMode: "focus"

    property int elapsedSeconds: 0
    property var laps: []

    readonly property int displaySec: isCountUp ? elapsedSeconds : remainingSeconds
    readonly property int hoursPart: Math.floor(displaySec / 3600)
    readonly property int minutesPart: Math.floor((displaySec % 3600) / 60)
    readonly property int secondsPart: displaySec % 60
    readonly property bool hasHours: displaySec >= 3600

    readonly property string formattedTime: formatTime(displaySec)
    readonly property real progress: isCountUp ? ((elapsedSeconds % 60) / 60.0) : (totalSeconds > 0 ? (remainingSeconds / totalSeconds) : 0)
    readonly property color accentColor: isCountUp ? "#38bdf8" : (currentMode === "break" ? "#10b981" : "#f97316")

    signal timerCompleted(string title, string message)

    function formatTime(sec) {
        var s = Math.max(0, sec)
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var remS = s % 60
        var hStr = (h < 10 ? "0" : "") + h
        var mStr = (m < 10 ? "0" : "") + m
        var sStr = (remS < 10 ? "0" : "") + remS
        if (h > 0) return hStr + ":" + mStr + ":" + sStr
        return mStr + ":" + sStr
    }

    function switchType(type) {
        if (isRunning) return
        resetTimer()
        timerType = type
    }

    function adjustTime(deltaSec) {
        if (isRunning || isCountUp) return
        var target = Math.max(0, remainingSeconds + deltaSec)
        remainingSeconds = target
        totalSeconds = Math.max(target, 1)
        currentMode = "custom"
    }

    function startPreset(sec, mode) {
        if (isRunning) return
        timerType = "countdown"
        totalSeconds = sec
        remainingSeconds = sec
        currentMode = mode
        isPaused = false
        isRunning = true
        tickTimer.restart()
    }

    function recordLap() {
        if (!isRunning || !isCountUp) return
        var list = laps.slice()
        list.unshift({ id: list.length + 1, time: formatTime(elapsedSeconds) })
        if (list.length > 3) list.pop()
        laps = list
    }

    function togglePause() {
        if (!isRunning && !isPaused) {
            isRunning = true
            tickTimer.restart()
        } else if (isRunning) {
            isRunning = false
            isPaused = true
            tickTimer.stop()
        } else if (isPaused) {
            isPaused = false
            isRunning = true
            tickTimer.restart()
        }
    }

    function resetTimer() {
        isRunning = false
        isPaused = false
        tickTimer.stop()
        if (isCountUp) {
            elapsedSeconds = 0
            laps = []
        } else {
            remainingSeconds = totalSeconds
        }
    }

    Timer {
        id: tickTimer
        interval: 1000
        repeat: true
        running: timerRoot.isRunning
        onTriggered: {
            if (timerRoot.isCountUp) {
                timerRoot.elapsedSeconds += 1
            } else {
                if (timerRoot.remainingSeconds > 1) {
                    timerRoot.remainingSeconds -= 1
                } else {
                    timerRoot.remainingSeconds = 0
                    timerRoot.isRunning = false
                    timerRoot.isPaused = false
                    tickTimer.stop()

                    if (timerRoot.currentMode === "break") {
                        timerRoot.timerCompleted("休息结束", "精力充沛，准备开启下一次专注吧 🚀")
                    } else {
                        timerRoot.timerCompleted("专注完成", "倒计时已结束，站起来活动一下身体")
                    }
                }
            }
        }
    }

    Row {
        anchors.fill: parent
        spacing: 14

        // 1. 左侧看板
        Rectangle {
            width: 195
            height: parent.height
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(timerRoot.accentColor.r, timerRoot.accentColor.g, timerRoot.accentColor.b, 0.28)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 6

                Row {
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: timerRoot.accentColor
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on opacity {
                            running: timerRoot.isRunning
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 600 }
                            NumberAnimation { to: 1.0; duration: 600 }
                        }
                    }
                    Text {
                        text: timerRoot.isCountUp ?
                              (timerRoot.isRunning ? "STOPWATCH RUNNING" : (timerRoot.isPaused ? "STOPWATCH PAUSED" : "STOPWATCH READY")) :
                              (timerRoot.isRunning ? (timerRoot.currentMode === "break" ? "TAKING A BREAK" : "FOCUSING (LOCKED)") : (timerRoot.isPaused ? "PAUSED" : "SCROLL TO EDIT"))
                        font.pixelSize: 9
                        font.weight: Font.Black
                        color: timerRoot.accentColor
                        font.family: timerRoot.chosenFont
                        font.letterSpacing: 0.8
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2

                    Column {
                        spacing: 2
                        Rectangle {
                            width: 44; height: 42; radius: 8
                            color: (hMouse.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? Qt.rgba(249, 115, 22, 0.2) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: (timerRoot.hoursPart < 10 ? "0" : "") + timerRoot.hoursPart
                                color: (hMouse.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? timerRoot.accentColor : "white"
                                font.pixelSize: 28; font.weight: Font.Black; font.family: "Monospace"
                            }
                            HoverHandler { id: hMouse; enabled: !timerRoot.isRunning && !timerRoot.isCountUp }
                            WheelHandler {
                                enabled: !timerRoot.isRunning && !timerRoot.isCountUp
                                onWheel: (e) => timerRoot.adjustTime(e.angleDelta.y > 0 ? 3600 : -3600)
                            }
                        }
                        Text { text: "时"; font.pixelSize: 9; color: Qt.rgba(1, 1, 1, 0.4); font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                    }

                    Text { text: ":"; font.pixelSize: 22; font.weight: Font.Black; color: Qt.rgba(1, 1, 1, 0.3); y: 6 }

                    Column {
                        spacing: 2
                        Rectangle {
                            width: 44; height: 42; radius: 8
                            color: (mMouse.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? Qt.rgba(249, 115, 22, 0.2) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: (timerRoot.minutesPart < 10 ? "0" : "") + timerRoot.minutesPart
                                color: (mMouse.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? timerRoot.accentColor : "white"
                                font.pixelSize: 28; font.weight: Font.Black; font.family: "Monospace"
                            }
                            HoverHandler { id: mMouse; enabled: !timerRoot.isRunning && !timerRoot.isCountUp }
                            WheelHandler {
                                enabled: !timerRoot.isRunning && !timerRoot.isCountUp
                                onWheel: (e) => timerRoot.adjustTime(e.angleDelta.y > 0 ? 60 : -60)
                            }
                        }
                        Text { text: "分"; font.pixelSize: 9; color: Qt.rgba(1, 1, 1, 0.4); font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                    }

                    Text { text: ":"; font.pixelSize: 22; font.weight: Font.Black; color: Qt.rgba(1, 1, 1, 0.3); y: 6 }

                    Column {
                        spacing: 2
                        Rectangle {
                            width: 44; height: 42; radius: 8
                            color: (sMouse.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? Qt.rgba(249, 115, 22, 0.2) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: (timerRoot.secondsPart < 10 ? "0" : "") + timerRoot.secondsPart
                                color: (sMouse.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? timerRoot.accentColor : "white"
                                font.pixelSize: 28; font.weight: Font.Black; font.family: "Monospace"
                            }
                            HoverHandler { id: sMouse; enabled: !timerRoot.isRunning && !timerRoot.isCountUp }
                            WheelHandler {
                                enabled: !timerRoot.isRunning && !timerRoot.isCountUp
                                onWheel: (e) => timerRoot.adjustTime(e.angleDelta.y > 0 ? 5 : -5)
                            }
                        }
                        Text { text: "秒"; font.pixelSize: 9; color: Qt.rgba(1, 1, 1, 0.4); font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                Rectangle {
                    width: 140
                    height: 4.5
                    radius: 99
                    color: Qt.rgba(1, 1, 1, 0.12)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: parent.width * Math.min(1.0, Math.max(0.0, timerRoot.progress))
                        height: parent.height
                        radius: 99
                        color: timerRoot.accentColor
                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }

        // 2. 右侧操作区
        Column {
            width: parent.width - 209
            height: parent.height
            spacing: 8

            // 🚀 带 180ms 悬停意图识别引擎的高级分段选择器
            Rectangle {
                id: segContainer
                width: parent.width
                height: 28
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(1, 1, 1, 0.1)

                // 悬停驻留意图识别定时器 (180ms)
                Timer {
                    id: segDwellTimer
                    property string pendingType: ""
                    interval: 180
                    onTriggered: {
                        if (!timerRoot.isRunning && pendingType !== "" && pendingType !== timerRoot.timerType) {
                            timerRoot.switchType(pendingType)
                        }
                    }
                }

                // 物理动态滑动胶囊
                Rectangle {
                    x: timerRoot.isCountUp ? parent.width / 2 + 2 : 2
                    y: 2
                    width: parent.width / 2 - 4
                    height: parent.height - 4
                    radius: 12
                    color: timerRoot.isCountUp ? Qt.rgba(56, 189, 248, 0.24) : Qt.rgba(249, 115, 22, 0.24)
                    border.color: timerRoot.isCountUp ? "#38bdf8" : "#f97316"
                    border.width: 1

                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                Row {
                    anchors.fill: parent

                    // 倒计时 Tab
                    Item {
                        width: parent.width / 2; height: parent.height

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 12
                            color: cdHover.hovered && timerRoot.isCountUp ? Qt.rgba(249, 115, 22, 0.12) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "⏳ 倒计时"
                            color: !timerRoot.isCountUp ? "white" : (cdHover.hovered ? "#fdba74" : Qt.rgba(1, 1, 1, 0.5))
                            font.pixelSize: 11
                            font.weight: !timerRoot.isCountUp ? Font.Black : Font.Bold
                            font.family: timerRoot.chosenFont
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        HoverHandler {
                            id: cdHover
                            cursorShape: timerRoot.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered && timerRoot.isCountUp && !timerRoot.isRunning) {
                                    segDwellTimer.pendingType = "countdown"
                                    segDwellTimer.restart()
                                } else if (!hovered && segDwellTimer.pendingType === "countdown") {
                                    segDwellTimer.stop()
                                }
                            }
                        }

                        TapHandler {
                            enabled: !timerRoot.isRunning
                            onTapped: {
                                segDwellTimer.stop()
                                timerRoot.switchType("countdown")
                            }
                        }
                    }

                    // 正向计时 Tab
                    Item {
                        width: parent.width / 2; height: parent.height

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 12
                            color: swHover.hovered && !timerRoot.isCountUp ? Qt.rgba(56, 189, 248, 0.12) : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "⏱ 正向计时"
                            color: timerRoot.isCountUp ? "white" : (swHover.hovered ? "#7dd3fc" : Qt.rgba(1, 1, 1, 0.5))
                            font.pixelSize: 11
                            font.weight: timerRoot.isCountUp ? Font.Black : Font.Bold
                            font.family: timerRoot.chosenFont
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        HoverHandler {
                            id: swHover
                            cursorShape: timerRoot.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered && !timerRoot.isCountUp && !timerRoot.isRunning) {
                                    segDwellTimer.pendingType = "stopwatch"
                                    segDwellTimer.restart()
                                } else if (!hovered && segDwellTimer.pendingType === "stopwatch") {
                                    segDwellTimer.stop()
                                }
                            }
                        }

                        TapHandler {
                            enabled: !timerRoot.isRunning
                            onTapped: {
                                segDwellTimer.stop()
                                timerRoot.switchType("stopwatch")
                            }
                        }
                    }
                }
            }

            // 预设模式选择块
            Item {
                width: parent.width
                height: 80
                visible: !timerRoot.isCountUp

                Grid {
                    anchors.fill: parent
                    columns: 2
                    spacing: 6
                    enabled: !timerRoot.isRunning
                    opacity: timerRoot.isRunning ? 0.35 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Rectangle {
                        width: (parent.width - 6) / 2; height: 36; radius: 9
                        color: p25Tap.pressed ? Qt.rgba(249, 115, 22, 0.35) : (p25Hover.hovered ? Qt.rgba(249, 115, 22, 0.2) : Qt.rgba(1, 1, 1, 0.06))
                        border.color: timerRoot.currentMode === "focus" && timerRoot.totalSeconds === 1500 ? "#f97316" : (p25Hover.hovered ? Qt.rgba(249, 115, 22, 0.4) : "transparent")
                        scale: p25Tap.pressed ? 0.95 : (p25Hover.hovered ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text { anchors.centerIn: parent; text: "25m 专注"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: timerRoot.chosenFont }
                        HoverHandler { id: p25Hover; cursorShape: timerRoot.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor }
                        TapHandler { id: p25Tap; onTapped: timerRoot.startPreset(1500, "focus") }
                    }

                    Rectangle {
                        width: (parent.width - 6) / 2; height: 36; radius: 9
                        color: p1hTap.pressed ? Qt.rgba(249, 115, 22, 0.35) : (p1hHover.hovered ? Qt.rgba(249, 115, 22, 0.2) : Qt.rgba(1, 1, 1, 0.06))
                        border.color: timerRoot.totalSeconds === 3600 ? "#f97316" : (p1hHover.hovered ? Qt.rgba(249, 115, 22, 0.4) : "transparent")
                        scale: p1hTap.pressed ? 0.95 : (p1hHover.hovered ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text { anchors.centerIn: parent; text: "1h 深度"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: timerRoot.chosenFont }
                        HoverHandler { id: p1hHover; cursorShape: timerRoot.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor }
                        TapHandler { id: p1hTap; onTapped: timerRoot.startPreset(3600, "focus") }
                    }

                    Rectangle {
                        width: (parent.width - 6) / 2; height: 36; radius: 9
                        color: p5Tap.pressed ? Qt.rgba(16, 185, 129, 0.35) : (p5Hover.hovered ? Qt.rgba(16, 185, 129, 0.2) : Qt.rgba(1, 1, 1, 0.06))
                        border.color: timerRoot.currentMode === "break" ? "#10b981" : (p5Hover.hovered ? Qt.rgba(16, 185, 129, 0.4) : "transparent")
                        scale: p5Tap.pressed ? 0.95 : (p5Hover.hovered ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text { anchors.centerIn: parent; text: "5m 小憩"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: timerRoot.chosenFont }
                        HoverHandler { id: p5Hover; cursorShape: timerRoot.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor }
                        TapHandler { id: p5Tap; onTapped: timerRoot.startPreset(300, "break") }
                    }

                    Rectangle {
                        width: (parent.width - 6) / 2; height: 36; radius: 9
                        color: p15Tap.pressed ? Qt.rgba(1, 1, 1, 0.2) : (p15Hover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                        scale: p15Tap.pressed ? 0.95 : (p15Hover.hovered ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text { anchors.centerIn: parent; text: "15m 冲刺"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: timerRoot.chosenFont }
                        HoverHandler { id: p15Hover; cursorShape: timerRoot.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor }
                        TapHandler { id: p15Tap; onTapped: timerRoot.startPreset(900, "focus") }
                    }
                }
            }

            // 正向计时打点计次
            Item {
                width: parent.width
                height: 80
                visible: timerRoot.isCountUp

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    visible: timerRoot.laps.length === 0

                    Text { text: "⏱ 正向连续计时"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold; font.family: timerRoot.chosenFont; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "支持随时暂停、重置与打点标记"; color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 10; font.family: timerRoot.chosenFont; anchors.horizontalCenter: parent.horizontalCenter }
                }

                Column {
                    anchors.fill: parent
                    spacing: 4
                    visible: timerRoot.laps.length > 0

                    Repeater {
                        model: timerRoot.laps
                        Rectangle {
                            width: parent.width; height: 22; radius: 6
                            color: Qt.rgba(56, 189, 248, 0.1)

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "计次 " + modelData.id
                                    color: "#38bdf8"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.family: timerRoot.chosenFont
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.time
                                    color: "white"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    font.family: "Monospace"
                                }
                            }
                        }
                    }
                }
            }

            // 底部主按键
            Row {
                width: parent.width
                spacing: 6

                Rectangle {
                    width: (timerRoot.isRunning || timerRoot.isPaused) ? (timerRoot.isCountUp && timerRoot.isRunning ? parent.width - 86 : parent.width - 44) : parent.width
                    height: 36
                    radius: 18
                    color: mainTap.pressed ? Qt.darker(timerRoot.accentColor, 1.25) : (mainHover.hovered ? Qt.lighter(timerRoot.accentColor, 1.12) : timerRoot.accentColor)
                    scale: mainTap.pressed ? 0.95 : (mainHover.hovered ? 1.015 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animInstant; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: timerRoot.isRunning ? "暂停" : (timerRoot.isPaused ? "继续" : (timerRoot.isCountUp ? "开始计时" : "开始专注"))
                        color: "white"
                        font.family: timerRoot.chosenFont
                        font.pixelSize: 12
                        font.weight: Font.Black
                    }

                    HoverHandler { id: mainHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: mainTap; onTapped: timerRoot.togglePause() }
                }

                Rectangle {
                    width: 38; height: 36; radius: 18
                    visible: timerRoot.isCountUp && timerRoot.isRunning
                    color: lapTap.pressed ? Qt.rgba(56, 189, 248, 0.4) : (lapHover.hovered ? Qt.rgba(56, 189, 248, 0.25) : Qt.rgba(1, 1, 1, 0.08))
                    scale: lapTap.pressed ? 0.92 : (lapHover.hovered ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text { anchors.centerIn: parent; text: "计次"; font.pixelSize: 10; font.weight: Font.Bold; color: "white" }
                    HoverHandler { id: lapHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: lapTap; onTapped: timerRoot.recordLap() }
                }

                Rectangle {
                    width: 38; height: 36; radius: 18
                    visible: timerRoot.isRunning || timerRoot.isPaused
                    color: resetTap.pressed ? Qt.rgba(1, 1, 1, 0.25) : (resetHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                    scale: resetTap.pressed ? 0.92 : (resetHover.hovered ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text { anchors.centerIn: parent; text: "重置"; font.pixelSize: 10; font.weight: Font.Bold; color: "white" }
                    HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: resetTap; onTapped: timerRoot.resetTimer() }
                }
            }
        }
    }
}