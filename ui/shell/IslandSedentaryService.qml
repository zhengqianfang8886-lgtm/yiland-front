// ==========================================
// 📄 File: ui/shell/IslandSedentaryService.qml
// 🌟 统一久坐伏案健康守护服务 (FSM 优先级直通闭环版)
// ==========================================
import QtQuick

Item {
    id: sedentaryService

    property var fsm: null

    readonly property bool isEnabled: (typeof Config !== "undefined" && Config.sedentaryReminderEnabled !== undefined) ? Config.sedentaryReminderEnabled : true
    readonly property int intervalMinutes: (typeof Config !== "undefined" && Config.sedentaryIntervalMinutes !== undefined) ? Config.sedentaryIntervalMinutes : 45
    readonly property int snoozeMinutes: (typeof Config !== "undefined" && Config.sedentarySnoozeMinutes !== undefined) ? Config.sedentarySnoozeMinutes : 5

    property int elapsedSeconds: 0
    property bool isAlertActive: false
    property int currentTargetSeconds: intervalMinutes * 60

    signal requestAlert(int continuousMinutes)
    signal dismissAlert()

    Timer {
        id: workTickTimer
        interval: 1000
        repeat: true
        running: sedentaryService.isEnabled && !sedentaryService.isAlertActive
        onTriggered: {
            sedentaryService.elapsedSeconds += 1;
            if (sedentaryService.elapsedSeconds >= sedentaryService.currentTargetSeconds) {
                sedentaryService.triggerAlertPopup();
            }
        }
    }

    function triggerAlertPopup() {
        isAlertActive = true;
        var mins = Math.max(1, Math.round(elapsedSeconds / 60));

        // 🚀 直通 FSM 暂态优先级队列 (Priority: 60)
        if (fsm) {
            fsm.postTransient("SEDENTARY", {
                continuousMinutes: mins,
                title: "久坐提醒",
                subtitle: "已连续伏案 " + mins + " 分钟，建议起身放松"
            }, 0); // 0 维持手动干预
        }

        if (typeof Bridge !== "undefined" && Bridge.forceRaise) {
            Bridge.forceRaise();
        }
        sedentaryService.requestAlert(mins);
    }

    // 用户响应：我已起身
    function markRested() {
        isAlertActive = false;
        elapsedSeconds = 0;
        currentTargetSeconds = intervalMinutes * 60;
        if (fsm) {
            fsm.dismissTransient("SEDENTARY");
        }
        sedentaryService.dismissAlert();
    }

    // 用户响应：延后 5 分钟
    function snooze() {
        isAlertActive = false;
        currentTargetSeconds = elapsedSeconds + (snoozeMinutes * 60);
        if (fsm) {
            fsm.dismissTransient("SEDENTARY");
        }
        sedentaryService.dismissAlert();
    }

    onIntervalMinutesChanged: {
        if (!isAlertActive) {
            currentTargetSeconds = intervalMinutes * 60;
        }
    }
}