import QtQuick
import "../timer"

Item {
    id: timerRoot
    anchors.fill: parent

    property string chosenFont: ""
    readonly property string textFont: (typeof Config !== "undefined" && Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) ? Config.fontFamily : ""
    readonly property string displayFont: (textFont !== "") ? textFont : "Monospace"

    // 🚀【核心重构】：所有属性均为只读代理，单一事实源位于 Bridge
    readonly property string timerType: (typeof Bridge !== "undefined") ? Bridge.timerType : "countdown"
    readonly property bool isCountUp: timerType === "stopwatch"
    readonly property bool isRunning: (typeof Bridge !== "undefined") ? Bridge.timerIsRunning : false
    readonly property bool isPaused: (typeof Bridge !== "undefined") ? Bridge.timerIsPaused : false
    readonly property bool isCompleted: (typeof Bridge !== "undefined") ? Bridge.timerIsCompleted : false
    readonly property string currentMode: (typeof Bridge !== "undefined") ? Bridge.timerMode : "focus"

    readonly property int displaySec: isCountUp ? 
                                      ((typeof Bridge !== "undefined") ? Bridge.timerElapsedSec : 0) : 
                                      ((typeof Bridge !== "undefined") ? Bridge.timerRemainingSec : 1500)
    readonly property int hoursPart: Math.floor(displaySec / 3600)
    readonly property int minutesPart: Math.floor((displaySec % 3600) / 60)
    readonly property int secondsPart: displaySec % 60

    readonly property real progress: {
        if (typeof Bridge === "undefined") return 0
        if (isCountUp) return (displaySec % 60) / 60.0
        return Bridge.timerTotalSec > 0 ? (Bridge.timerRemainingSec / Bridge.timerTotalSec) : 0
    }

    readonly property color accentColor: isCountUp ? "#38bdf8" : (isCompleted ? "#10b981" : (currentMode === "break" ? "#10b981" : "#f97316"))

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
            onAdjustRequested: (delta) => {
                if (typeof Bridge !== "undefined") Bridge.adjustTimerTime(delta)
            }
        }

        // 2. 右侧操作区
        Column {
            width: parent.width - 166
            height: parent.height
            spacing: 8

            TimerSegmentedBar {
                isCountUp: timerRoot.isCountUp
                isRunning: timerRoot.isRunning
                textFont: timerRoot.textFont
                onSwitchRequested: (type) => {
                    if (typeof Bridge !== "undefined") Bridge.switchTimerType(type)
                }
            }

            TimerPresetGrid {
                visible: !timerRoot.isCountUp
                isRunning: timerRoot.isRunning
                currentMode: timerRoot.currentMode
                totalSeconds: (typeof Bridge !== "undefined") ? Bridge.timerTotalSec : 1500
                textFont: timerRoot.textFont
                onPresetTriggered: (sec, mode) => {
                    if (typeof Bridge !== "undefined") Bridge.startTimerPreset(sec, mode)
                }
            }

            TimerLapList {
                visible: timerRoot.isCountUp
                laps: (typeof Bridge !== "undefined") ? Bridge.timerLaps : []
                textFont: timerRoot.textFont
                displayFont: timerRoot.displayFont
            }

            TimerActionRow {
                isRunning: timerRoot.isRunning
                isPaused: timerRoot.isPaused
                isCompleted: timerRoot.isCompleted
                isCountUp: timerRoot.isCountUp
                accentColor: timerRoot.accentColor
                textFont: timerRoot.textFont
                onTogglePauseRequested: if (typeof Bridge !== "undefined") Bridge.toggleTimerPause()
                onRecordLapRequested: if (typeof Bridge !== "undefined") Bridge.recordTimerLap()
                onResetRequested: if (typeof Bridge !== "undefined") Bridge.resetTimer()
            }
        }
    }
}