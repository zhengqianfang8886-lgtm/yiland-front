import QtQuick
import QtQuick.Shapes

Item {
    id: timerRoot

    // 🚀 补齐外部传参接口，消除属性不存在报错
    property string chosenFont: ""

    // 🚀 全局字体响应中枢
    readonly property string textFont: {
        if (typeof Config !== "undefined" && Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) {
            return Config.fontFamily
        }
        if (chosenFont !== "" && chosenFont.indexOf("系统默认") === -1) {
            return chosenFont
        }
        return ""
    }
    readonly property string displayFont: (textFont !== "") ? textFont : "Monospace"

    property string timerType: "countdown"
    readonly property bool isCountUp: timerType === "stopwatch"

    property bool isRunning: false
    property bool isPaused: false
    property bool isCompleted: false

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
    readonly property color accentColor: isCountUp ? "#38bdf8" : (isCompleted ? "#10b981" : (currentMode === "break" ? "#10b981" : "#f97316"))

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
        isCompleted = false
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
        isCompleted = false
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
        if (isCompleted) {
            resetTimer()
            return
        }
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
        isCompleted = false
        tickTimer.stop()
        if (isCountUp) {
            elapsedSeconds = 0
            laps = []
        } else {
            remainingSeconds = totalSeconds
        }
    }

    function dismissTimer() {
        isRunning = false
        isPaused = false
        isCompleted = false
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
                    timerRoot.isCompleted = true
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

        // 1. 左侧大看板
        Rectangle {
            width: 195
            height: parent.height
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(timerRoot.accentColor.r, timerRoot.accentColor.g, timerRoot.accentColor.b, 0.3)
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
                            running: timerRoot.isRunning || timerRoot.isCompleted
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 600 }
                            NumberAnimation { to: 1.0; duration: 600 }
                        }
                    }
                    Text {
                        text: timerRoot.isCompleted ? "COMPLETED" :
                              (timerRoot.isCountUp ?
                              (timerRoot.isRunning ? "STOPWATCH RUNNING" : (timerRoot.isPaused ? "STOPWATCH PAUSED" : "STOPWATCH READY")) :
                              (timerRoot.isRunning ? (timerRoot.currentMode === "break" ? "TAKING A BREAK" : "FOCUSING") : (timerRoot.isPaused ? "PAUSED" : "READY")))
                        font.pixelSize: 9
                        font.weight: Font.Black
                        color: timerRoot.accentColor
                        font.family: timerRoot.textFont
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
                            color: (hHover.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? Qt.rgba(timerRoot.accentColor.r, timerRoot.accentColor.g, timerRoot.accentColor.b, 0.22) : "transparent"
                            border.color: (hHover.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? timerRoot.accentColor : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: (timerRoot.hoursPart < 10 ? "0" : "") + timerRoot.hoursPart
                                color: (hHover.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? timerRoot.accentColor : "white"
                                font.pixelSize: 28; font.weight: Font.Black; font.family: timerRoot.displayFont
                            }
                            HoverHandler { id: hHover; enabled: !timerRoot.isRunning && !timerRoot.isCountUp; cursorShape: Qt.PointingHandCursor }
                            WheelHandler {
                                enabled: !timerRoot.isRunning && !timerRoot.isCountUp
                                onWheel: (e) => timerRoot.adjustTime(e.angleDelta.y > 0 ? 3600 : -3600)
                            }
                        }
                        Text { text: "时"; font.pixelSize: 9; color: Qt.rgba(1, 1, 1, 0.4); font.weight: Font.Bold; font.family: timerRoot.textFont; anchors.horizontalCenter: parent.horizontalCenter }
                    }

                    Text { text: ":"; font.pixelSize: 22; font.weight: Font.Black; color: Qt.rgba(1, 1, 1, 0.3); font.family: timerRoot.displayFont; y: 6 }

                    Column {
                        spacing: 2
                        Rectangle {
                            width: 44; height: 42; radius: 8
                            color: (mHover.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? Qt.rgba(timerRoot.accentColor.r, timerRoot.accentColor.g, timerRoot.accentColor.b, 0.22) : "transparent"
                            border.color: (mHover.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? timerRoot.accentColor : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: (timerRoot.minutesPart < 10 ? "0" : "") + timerRoot.minutesPart
                                color: (mHover.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? timerRoot.accentColor : "white"
                                font.pixelSize: 28; font.weight: Font.Black; font.family: timerRoot.displayFont
                            }
                            HoverHandler { id: mHover; enabled: !timerRoot.isRunning && !timerRoot.isCountUp; cursorShape: Qt.PointingHandCursor }
                            WheelHandler {
                                enabled: !timerRoot.isRunning && !timerRoot.isCountUp
                                onWheel: (e) => timerRoot.adjustTime(e.angleDelta.y > 0 ? 60 : -60)
                            }
                        }
                        Text { text: "分"; font.pixelSize: 9; color: Qt.rgba(1, 1, 1, 0.4); font.weight: Font.Bold; font.family: timerRoot.textFont; anchors.horizontalCenter: parent.horizontalCenter }
                    }

                    Text { text: ":"; font.pixelSize: 22; font.weight: Font.Black; color: Qt.rgba(1, 1, 1, 0.3); font.family: timerRoot.displayFont; y: 6 }

                    Column {
                        spacing: 2
                        Rectangle {
                            width: 44; height: 42; radius: 8
                            color: (sHover.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? Qt.rgba(timerRoot.accentColor.r, timerRoot.accentColor.g, timerRoot.accentColor.b, 0.22) : "transparent"
                            border.color: (sHover.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? timerRoot.accentColor : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: (timerRoot.secondsPart < 10 ? "0" : "") + timerRoot.secondsPart
                                color: (sHover.hovered && !timerRoot.isRunning && !timerRoot.isCountUp) ? timerRoot.accentColor : "white"
                                font.pixelSize: 28; font.weight: Font.Black; font.family: timerRoot.displayFont
                            }
                            HoverHandler { id: sHover; enabled: !timerRoot.isRunning && !timerRoot.isCountUp; cursorShape: Qt.PointingHandCursor }
                            WheelHandler {
                                enabled: !timerRoot.isRunning && !timerRoot.isCountUp
                                onWheel: (e) => timerRoot.adjustTime(e.angleDelta.y > 0 ? 5 : -5)
                            }
                        }
                        Text { text: "秒"; font.pixelSize: 9; color: Qt.rgba(1, 1, 1, 0.4); font.weight: Font.Bold; font.family: timerRoot.textFont; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                Rectangle {
                    width: 140; height: 4.5; radius: 99; color: Qt.rgba(1, 1, 1, 0.12)
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle {
                        width: parent.width * Math.min(1.0, Math.max(0.0, timerRoot.isCompleted ? 1.0 : timerRoot.progress))
                        height: parent.height; radius: 99; color: timerRoot.accentColor
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

            Rectangle {
                id: segContainer
                width: parent.width; height: 28; radius: 14
                color: Qt.rgba(1, 1, 1, 0.06); border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1

                Rectangle {
                    x: timerRoot.isCountUp ? parent.width / 2 + 2 : 2
                    y: 2
                    width: parent.width / 2 - 4
                    height: parent.height - 4
                    radius: 12
                    color: timerRoot.isCountUp ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.28) : Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.28)
                    border.color: timerRoot.isCountUp ? "#38bdf8" : "#f97316"
                    border.width: 1

                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                Row {
                    anchors.fill: parent

                    Item {
                        width: parent.width / 2; height: parent.height
                        Text {
                            anchors.centerIn: parent; text: "倒计时"
                            color: !timerRoot.isCountUp ? "white" : (cdHover.hovered ? "#fdba74" : Qt.rgba(1, 1, 1, 0.5))
                            font.pixelSize: 11; font.weight: !timerRoot.isCountUp ? Font.Black : Font.Bold; font.family: timerRoot.textFont
                        }
                        HoverHandler { id: cdHover; cursorShape: timerRoot.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor }
                        TapHandler {
                            enabled: !timerRoot.isRunning
                            onTapped: timerRoot.switchType("countdown")
                        }
                    }

                    Item {
                        width: parent.width / 2; height: parent.height
                        Text {
                            anchors.centerIn: parent; text: "正向计时"
                            color: timerRoot.isCountUp ? "white" : (swHover.hovered ? "#7dd3fc" : Qt.rgba(1, 1, 1, 0.5))
                            font.pixelSize: 11; font.weight: timerRoot.isCountUp ? Font.Black : Font.Bold; font.family: timerRoot.textFont
                        }
                        HoverHandler { id: swHover; cursorShape: timerRoot.isRunning ? Qt.ArrowCursor : Qt.PointingHandCursor }
                        TapHandler {
                            enabled: !timerRoot.isRunning
                            onTapped: timerRoot.switchType("stopwatch")
                        }
                    }
                }
            }

            Item {
                width: parent.width; height: 80; visible: !timerRoot.isCountUp

                Grid {
                    anchors.fill: parent; columns: 2; spacing: 6
                    enabled: !timerRoot.isRunning
                    opacity: timerRoot.isRunning ? 0.35 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Rectangle {
                        width: (parent.width - 6) / 2; height: 36; radius: 9
                        color: p25Area.pressed ? Qt.rgba(249, 115, 22, 0.35) : (p25Area.containsMouse ? Qt.rgba(249, 115, 22, 0.2) : Qt.rgba(1, 1, 1, 0.06))
                        border.color: (timerRoot.currentMode === "focus" && timerRoot.totalSeconds === 1500) ? "#f97316" : (p25Area.containsMouse ? Qt.rgba(249, 115, 22, 0.5) : Theme.borderSubtle)
                        border.width: 1
                        scale: p25Area.pressed ? 0.95 : (p25Area.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text { anchors.centerIn: parent; text: "25m 专注"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: timerRoot.textFont }
                        MouseArea { id: p25Area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: timerRoot.startPreset(1500, "focus") }
                    }

                    Rectangle {
                        width: (parent.width - 6) / 2; height: 36; radius: 9
                        color: p1hArea.pressed ? Qt.rgba(249, 115, 22, 0.35) : (p1hArea.containsMouse ? Qt.rgba(249, 115, 22, 0.2) : Qt.rgba(1, 1, 1, 0.06))
                        border.color: timerRoot.totalSeconds === 3600 ? "#f97316" : (p1hArea.containsMouse ? Qt.rgba(249, 115, 22, 0.5) : Theme.borderSubtle)
                        border.width: 1
                        scale: p1hArea.pressed ? 0.95 : (p1hArea.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text { anchors.centerIn: parent; text: "1h 深度"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: timerRoot.textFont }
                        MouseArea { id: p1hArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: timerRoot.startPreset(3600, "focus") }
                    }

                    Rectangle {
                        width: (parent.width - 6) / 2; height: 36; radius: 9
                        color: p5Area.pressed ? Qt.rgba(16, 185, 129, 0.35) : (p5Area.containsMouse ? Qt.rgba(16, 185, 129, 0.2) : Qt.rgba(1, 1, 1, 0.06))
                        border.color: timerRoot.currentMode === "break" ? "#10b981" : (p5Area.containsMouse ? Qt.rgba(16, 185, 129, 0.5) : Theme.borderSubtle)
                        border.width: 1
                        scale: p5Area.pressed ? 0.95 : (p5Area.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text { anchors.centerIn: parent; text: "5m 小憩"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: timerRoot.textFont }
                        MouseArea { id: p5Area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: timerRoot.startPreset(300, "break") }
                    }

                    Rectangle {
                        width: (parent.width - 6) / 2; height: 36; radius: 9
                        color: p15Area.pressed ? Qt.rgba(1, 1, 1, 0.22) : (p15Area.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06))
                        border.color: p15Area.containsMouse ? Qt.rgba(255, 255, 255, 0.3) : Theme.borderSubtle
                        border.width: 1
                        scale: p15Area.pressed ? 0.95 : (p15Area.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text { anchors.centerIn: parent; text: "15m 冲刺"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: timerRoot.textFont }
                        MouseArea { id: p15Area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: timerRoot.startPreset(900, "focus") }
                    }
                }
            }

            Item {
                width: parent.width; height: 80; visible: timerRoot.isCountUp

                Column {
                    anchors.centerIn: parent; spacing: 4; visible: timerRoot.laps.length === 0
                    Text { text: "正向连续计时"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold; font.family: timerRoot.textFont; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "支持随时暂停、重置与打点标记"; color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 10; font.family: timerRoot.textFont; anchors.horizontalCenter: parent.horizontalCenter }
                }

                Column {
                    anchors.fill: parent; spacing: 4; visible: timerRoot.laps.length > 0
                    Repeater {
                        model: timerRoot.laps
                        Rectangle {
                            width: parent.width; height: 22; radius: 6; color: Qt.rgba(56, 189, 248, 0.12)
                            Item {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "计次 " + modelData.id; color: "#38bdf8"; font.pixelSize: 10; font.weight: Font.Bold; font.family: timerRoot.textFont }
                                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.time; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: timerRoot.displayFont }
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 6

                Rectangle {
                    width: (timerRoot.isRunning || timerRoot.isPaused || timerRoot.isCompleted) ?
                           (timerRoot.isCountUp && timerRoot.isRunning ? parent.width - 86 : parent.width - 44) : parent.width
                    height: 36
                    radius: 18
                    color: mainArea.pressed ? Qt.darker(timerRoot.accentColor, 1.25) : (mainArea.containsMouse ? Qt.lighter(timerRoot.accentColor, 1.15) : timerRoot.accentColor)
                    scale: mainArea.pressed ? 0.95 : (mainArea.containsMouse ? 1.015 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animInstant; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: timerRoot.isCompleted ? "重置完成" : (timerRoot.isRunning ? "暂停" : (timerRoot.isPaused ? "继续" : (timerRoot.isCountUp ? "开始计时" : "开始专注")))
                        color: "white"
                        font.family: timerRoot.textFont
                        font.pixelSize: 12
                        font.weight: Font.Black
                    }

                    MouseArea {
                        id: mainArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: timerRoot.togglePause()
                    }
                }

                Rectangle {
                    width: 38; height: 36; radius: 18
                    visible: timerRoot.isCountUp && timerRoot.isRunning
                    color: lapArea.pressed ? Qt.rgba(56, 189, 248, 0.4) : (lapArea.containsMouse ? Qt.rgba(56, 189, 248, 0.25) : Qt.rgba(1, 1, 1, 0.08))
                    border.color: lapArea.containsMouse ? "#38bdf8" : Theme.borderSubtle
                    border.width: 1
                    scale: lapArea.pressed ? 0.92 : (lapArea.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text { anchors.centerIn: parent; text: "计次"; font.pixelSize: 10; font.weight: Font.Bold; font.family: timerRoot.textFont; color: "white" }
                    MouseArea { id: lapArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: timerRoot.recordLap() }
                }

                Rectangle {
                    width: 38; height: 36; radius: 18
                    visible: timerRoot.isRunning || timerRoot.isPaused || timerRoot.isCompleted
                    color: resetArea.pressed ? Qt.rgba(1, 1, 1, 0.25) : (resetArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                    border.color: resetArea.containsMouse ? Qt.rgba(255, 255, 255, 0.3) : Theme.borderSubtle
                    border.width: 1
                    scale: resetArea.pressed ? 0.92 : (resetArea.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text { anchors.centerIn: parent; text: "重置"; font.pixelSize: 10; font.weight: Font.Bold; font.family: timerRoot.textFont; color: "white" }
                    MouseArea { id: resetArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: timerRoot.resetTimer() }
                }
            }
        }
    }
}