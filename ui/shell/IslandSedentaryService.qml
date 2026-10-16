import QtQuick

Item {
    id: sedentaryService

    // 1. 配置注入与动态绑定
    readonly property bool isEnabled: (typeof Config !== "undefined" && Config.sedentaryReminderEnabled !== undefined) ? Config.sedentaryReminderEnabled : true
    readonly property int intervalMinutes: (typeof Config !== "undefined" && Config.sedentaryIntervalMinutes !== undefined) ? Config.sedentaryIntervalMinutes : 45
    readonly property int snoozeMinutes: (typeof Config !== "undefined" && Config.sedentarySnoozeMinutes !== undefined) ? Config.sedentarySnoozeMinutes : 5

    // 2. 状态机变量
    property int elapsedSeconds: 0
    property bool isAlertActive: false
    property int currentTargetSeconds: intervalMinutes * 60

    // 3. 业务信号
    signal requestAlert(int continuousMinutes)
    signal dismissAlert()

    // 4. 秒级心跳主定时器
    Timer {
        id: workTickTimer
        interval: 1000
        repeat: true
        running: sedentaryService.isEnabled && !sedentaryService.isAlertActive
        onTriggered: {
            sedentaryService.elapsedSeconds += 1
            if (sedentaryService.elapsedSeconds >= sedentaryService.currentTargetSeconds) {
                sedentaryService.triggerAlertPopup()
            }
        }
    }

    // 触发久坐打断提醒
    function triggerAlertPopup() {
        isAlertActive = true
        var mins = Math.max(1, Math.round(elapsedSeconds / 60))
        sedentaryService.requestAlert(mins)
        if (typeof Bridge !== "undefined" && Bridge.forceRaise) {
            Bridge.forceRaise()
        }
    }

    // 响应：我已起身活动（重置完整周期）
    function markRested() {
        isAlertActive = false
        elapsedSeconds = 0
        currentTargetSeconds = intervalMinutes * 60
        sedentaryService.dismissAlert()
    }

    // 响应：延后 5 分钟（贪睡模式）
    function snooze() {
        isAlertActive = false
        // 将目标顺延 5 分钟
        currentTargetSeconds = elapsedSeconds + (snoozeMinutes * 60)
        sedentaryService.dismissAlert()
    }

    // =========================================================================
    // 🚀 未来扩展插槽（后续接入 DBus 息屏/空闲感知时直接调用即可）
    // =========================================================================
    function onUserIdleDetected(idleMinutes) {
        // 用户离开工位超过 10 分钟，自动视为已起身休息，清零计时
        if (idleMinutes >= 10) {
            sedentaryService.markRested()
        }
    }

    function onUserActiveDetected() {
        // 用户重新操作电脑，唤醒计时器
        if (!workTickTimer.running && isEnabled && !isAlertActive) {
            workTickTimer.start()
        }
    }

    // 动态监听设置时长变更
    onIntervalMinutesChanged: {
        if (!isAlertActive) {
            currentTargetSeconds = intervalMinutes * 60
        }
    }
}