// ==========================================
// 📄 File: pages/TimerPage.qml
// ==========================================
import QtQuick
import "../timer"

Item {
    id: timerRoot
    anchors.fill: parent

    property string chosenFont: ""

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

    // 状态机核心
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

    // 外部胶囊与外部卡片绑定接口
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

    // 🚀【核心修复】：状态原子反转。暂停时必须先置 isPaused = true，严防 timerActive 瞬间产生 false 毛刺
    function togglePause() {
        if (isCompleted) { resetTimer(); return }
        if (!isRunning && !isPaused) {
            isPaused = false
            isRunning = true
            tickTimer.restart()
        } else if (isRunning) {
            isPaused = true
            isRunning = false
            tickTimer.stop()
        } else if (isPaused) {
            isRunning = true
            isPaused = false
            tickTimer.restart()
        }
    }

    function resetTimer() {
        tickTimer.stop()
        isRunning = false
        isPaused = false
        isCompleted = false
        if (isCountUp) { elapsedSeconds = 0; laps = [] }
        else { remainingSeconds = totalSeconds }
    }

    function dismissTimer() { resetTimer() }

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
        TimerDashboard {
            accentColor: timerRoot.accentColor
            textFont: timerRoot.textFont
            displayFont: timerRoot.displayFont
            isRunning: timerRoot.isRunning
            isPaused: timerRoot.isPaused
            isCompleted: timerRoot.isCompleted
            isCountUp: timerRoot.isCountUp
            currentMode: timerRoot.currentMode
            progress: timerRoot.progress
            hoursPart: timerRoot.hoursPart
            minutesPart: timerRoot.minutesPart
            secondsPart: timerRoot.secondsPart
            onAdjustRequested: (delta) => timerRoot.adjustTime(delta)
        }

        // 2. 右侧操作区
        Column {
            width: parent.width - 166
            height: parent.height
            spacing: 8

            // 2.1 顶部意图分段器
            TimerSegmentedBar {
                isCountUp: timerRoot.isCountUp
                isRunning: timerRoot.isRunning
                textFont: timerRoot.textFont
                onSwitchRequested: (type) => timerRoot.switchType(type)
            }

            // 2.2 倒计时快捷预设矩阵
            TimerPresetGrid {
                visible: !timerRoot.isCountUp
                isRunning: timerRoot.isRunning
                currentMode: timerRoot.currentMode
                totalSeconds: timerRoot.totalSeconds
                textFont: timerRoot.textFont
                onPresetTriggered: (sec, mode) => timerRoot.startPreset(sec, mode)
            }

            // 2.3 正向计时打点列表
            TimerLapList {
                visible: timerRoot.isCountUp
                laps: timerRoot.laps
                textFont: timerRoot.textFont
                displayFont: timerRoot.displayFont
            }

            // 2.4 底部主操作条
            TimerActionRow {
                isRunning: timerRoot.isRunning
                isPaused: timerRoot.isPaused
                isCompleted: timerRoot.isCompleted
                isCountUp: timerRoot.isCountUp
                accentColor: timerRoot.accentColor
                textFont: timerRoot.textFont
                onTogglePauseRequested: timerRoot.togglePause()
                onRecordLapRequested: timerRoot.recordLap()
                onResetRequested: timerRoot.resetTimer()
            }
        }
    }
}