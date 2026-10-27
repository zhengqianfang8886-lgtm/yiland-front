// ==========================================
// 📄 File: ui/components/pages/TimerPage.qml
// 🌟 专注时钟主页 (超时追溯联动版)
// ==========================================
import QtQuick
import "../timer"

Item {
    id: timerRoot
    anchors.fill: parent

    property string chosenFont: ""
    readonly property string textFont: (typeof Config !== "undefined" && Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) ? Config.fontFamily : ""
    readonly property string displayFont: (textFont !== "") ? textFont : "Monospace"

    readonly property string timerType: (typeof Bridge !== "undefined") ? Bridge.timerType : "countdown"
    readonly property bool isCountUp: timerType === "stopwatch"
    readonly property bool isRunning: (typeof Bridge !== "undefined") ? Bridge.timerIsRunning : false
    readonly property bool isPaused: (typeof Bridge !== "undefined") ? Bridge.timerIsPaused : false
    readonly property bool isCompleted: (typeof Bridge !== "undefined") ? Bridge.timerIsCompleted : false
    readonly property bool isOvertime: (typeof Bridge !== "undefined") ? Bridge.timerIsOvertime : false
    readonly property string currentMode: (typeof Bridge !== "undefined") ? Bridge.timerMode : "focus"

    // 🚀【当前展示秒数】：超时阶段展示已超时秒数，倒计时展示剩余秒数
    readonly property int displaySec: {
        if (typeof Bridge === "undefined") return 1500;
        if (isCountUp) return Bridge.timerElapsedSec;
        if (isOvertime) return Bridge.timerOvertimeSec;
        return Bridge.timerRemainingSec;
    }

    readonly property int hoursPart: Math.floor(displaySec / 3600)
    readonly property int minutesPart: Math.floor((displaySec % 3600) / 60)
    readonly property int secondsPart: displaySec % 60

    readonly property real progress: {
        if (typeof Bridge === "undefined") return 0;
        if (isCountUp) return (displaySec % 60) / 60.0;
        return Bridge.timerTotalSec > 0 ? (Bridge.timerRemainingSec / Bridge.timerTotalSec) : 0;
    }

    // 🚀【强调色】：超时时强制变为经典警示红 #FF453A
    readonly property color accentColor: isOvertime ? "#FF453A" : 
                                         (isCountUp ? "#38bdf8" : 
                                         (isCompleted ? "#10b981" : 
                                         (currentMode === "break" ? "#10b981" : "#f97316")))

    Row {
        anchors.fill: parent
        spacing: 12

        // 1. 左侧大看板
        TimerDashboard {
            accentColor: timerRoot.accentColor
            textFont: timerRoot.textFont
            displayFont: timerRoot.displayFont
            isRunning: timerRoot.isRunning
            isPaused: timerRoot.isPaused
            isCompleted: timerRoot.isCompleted
            isOvertime: timerRoot.isOvertime
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

        // 2. 右侧操作与预设区
        Item {
            width: parent.width - 172 - 12
            height: parent.height

            TimerSegmentedBar {
                id: segBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                isCountUp: timerRoot.isCountUp
                isRunning: timerRoot.isRunning || timerRoot.isOvertime
                textFont: timerRoot.textFont
                onSwitchRequested: (type) => {
                    if (typeof Bridge !== "undefined") Bridge.switchTimerType(type)
                }
            }

            TimerPresetGrid {
                id: presetGrid
                anchors.top: segBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                visible: !timerRoot.isCountUp
                isRunning: timerRoot.isRunning || timerRoot.isOvertime
                currentMode: timerRoot.currentMode
                totalSeconds: (typeof Bridge !== "undefined") ? Bridge.timerTotalSec : 1500
                textFont: timerRoot.textFont
                onPresetTriggered: (sec, mode) => {
                    if (typeof Bridge !== "undefined") Bridge.startTimerPreset(sec, mode)
                }
            }

            TimerLapList {
                id: lapList
                anchors.top: segBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: actionRow.top
                anchors.bottomMargin: 8
                visible: timerRoot.isCountUp
                laps: (typeof Bridge !== "undefined") ? Bridge.timerLaps : []
                textFont: timerRoot.textFont
                displayFont: timerRoot.displayFont
            }

            TimerActionRow {
                id: actionRow
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                isRunning: timerRoot.isRunning
                isPaused: timerRoot.isPaused
                isCompleted: timerRoot.isCompleted || timerRoot.isOvertime
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