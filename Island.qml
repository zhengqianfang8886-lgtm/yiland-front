// ==========================================
// 📄 File: Island.qml
// 🌟 动态安全包络线 · 绝不切边总控
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 460
    height: 280

    readonly property string chosenFont: Theme.activeFont

    IslandStateMachine {
        id: fsm
        isBlockedByTransient: (capsule.isCalling || capsule.activeTransient === "ALERT" || capsule.activeTransient === "SEDENTARY")

        onIsSettledChanged: {
            if (!isSettled) {
                // 🚀 动画行进期间：全放开，让 GPU 满血绘制，绝不裁切！
                if (typeof Bridge !== "undefined") Bridge.openFullCorridorForMotion()
            } else {
                // 动画彻底稳定：落定安全遮罩
                root.commitSettledMask()
            }
        }
    }

    // 🚀【核心修复】：带 6px 绝对呼吸空间的智能包络遮罩
    function commitSettledMask() {
        if (typeof Bridge === "undefined") return

        var capW = Math.round(capsule.width)
        var capX = Math.round((root.width - capW) / 2 + capsule.islandOffsetX)
        var safePad = 6  // 6px 呼吸边距，彻底消灭任何边缘撕裂

        if (fsm.stateName === "TUCKED") {
            // 吸顶时：仅保留顶端 8px 捕捉鼠标，左右留足呼吸边距
            Bridge.applySettledMask(Math.max(0, capX - safePad), 0, capW + safePad * 2, 8)
            return
        }

        var capY = Math.max(0, Math.round(capsule.y))
        var capH = Math.round(capsule.height)

        // 常态/大卡片态：向四周外扩 6px，保证抗锯齿与外发光绝不被切
        Bridge.applySettledMask(
            Math.max(0, capX - safePad),
            Math.max(0, capY - safePad),
            capW + safePad * 2,
            capH + safePad * 2
        )
    }

    readonly property var allTabsMeta: ({
        "time": { key: "time", name: "时间", color: Theme.calendar, activeColor: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.22) },
        "hardware": { key: "hardware", name: "控制", color: "#f59e0b", activeColor: Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.22) },
        "workspace": { key: "workspace", name: "桌面", color: Theme.workspace, activeColor: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.22) },
        "media": { key: "media", name: "媒体", color: Theme.textPrimary, activeColor: Qt.rgba(1, 1, 1, 0.18) },
        "calendar": { key: "calendar", name: "日历", color: Theme.calendar, activeColor: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.22) },
        "timer": { key: "timer", name: "计时", color: Theme.timer, activeColor: Qt.rgba(Theme.timer.r, Theme.timer.g, Theme.timer.b, 0.22) },
        "clock": { key: "clock", name: "时钟", color: Theme.clock, activeColor: Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.22) },
        "network": { key: "network", name: "网络", color: Theme.network, activeColor: Qt.rgba(Theme.network.r, Theme.network.g, Theme.network.b, 0.22) },
        "bluetooth": { key: "bluetooth", name: "蓝牙", color: Theme.bluetooth, activeColor: Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.22) },
        "notification": { key: "notification", name: "通知", color: Theme.notification, activeColor: Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.22) }
    })

    function isTabEnabled(key) {
        if (typeof Config === "undefined") return true
        if (key === "time") return true
        if (key === "hardware") return Config.showHardwareTab !== false
        if (key === "workspace") return Config.showWorkspaceTab !== false
        if (key === "media") return Config.showMediaTab !== false
        if (key === "calendar") return Config.showCalendarTab !== false
        if (key === "timer") return Config.showTimerTab !== false
        if (key === "clock") return Config.showClockTab !== false
        if (key === "network") return Config.showNetworkTab !== false
        if (key === "bluetooth") return Config.showBluetoothTab !== false
        if (key === "notification") return Config.showNotificationTab !== false
        return true
    }

    readonly property var enabledTabs: {
        var order = (typeof Config !== "undefined" && Config.tabOrder && Config.tabOrder.length > 0) ?
                    Config.tabOrder :
                    ["time", "hardware", "workspace", "media", "calendar", "timer", "clock", "network", "bluetooth", "notification"]
        var list = []
        for (var i = 0; i < order.length; i++) {
            var k = order[i]
            if (isTabEnabled(k) && allTabsMeta[k]) list.push(allTabsMeta[k])
        }
        return list
    }

    IslandTimeService { id: timeService }

    IslandSedentaryService {
        id: sedentaryService
        onRequestAlert: (continuousMinutes) => {
            // 收到久坐提醒，若吸顶则立即唤醒钉回常态
            fsm.evLeftClickPin()
            capsule.continuousSitMinutes = continuousMinutes
            triggerTransient("SEDENTARY", 0)
        }
        onDismissAlert: {
            if (capsule.activeTransient === "SEDENTARY") capsule.activeTransient = ""
        }
    }

    IslandBridgeRelay {
        id: relay
        onTriggerOsd: (icon, label, val) => triggerTransient("OSD", 1500)
        onTriggerWorkspace: (c, t, n) => {
            if (capsule.isAtMotel) capsule.goHome()
            triggerTransient("WORKSPACE", 800)
            if (typeof Bridge !== "undefined") Bridge.forceRaise()
        }

        // 🚀【核心防护】：新消息/来电到来时，强制从天花板拉回常态，绝不允许遮罩卡在 5px！
        onTriggerAlert: (icon, t, sub, ms, avatar) => {
            var isDnd = (typeof Config !== "undefined" && Config.dndEnabled)
            var isCall = (icon === "📞" || relay.isCalling)
            var allowCall = (typeof Config !== "undefined" && Config.dndAllowCalls !== false)

            if (isDnd && !isCall) return
            if (isDnd && isCall && !allowCall) return

            // 0ms 解脱吸顶状态，防止切边
            fsm.evLeftClickPin()
            if (capsule.isAtMotel) capsule.goHome()

            capsule.alertIcon = icon
            capsule.alertTitle = t
            capsule.alertSubtitle = sub
            capsule.alertAvatar = avatar || ""
            triggerTransient("ALERT", ms > 0 ? ms : 5000)
        }

        onTriggerClipboard: (icon, t, sub, ms) => {
            if (!(typeof Config !== "undefined" && Config.dndEnabled) && fsm.stateName !== "TUCKED") capsule.triggerClipGlow()
        }

        onCallEnded: {
            if (fsm.stateName === "EXPANDED") fsm.evCollapseCard()
            if (!(typeof Config !== "undefined" && Config.dndEnabled && !Config.dndAllowCalls)) {
                fsm.evLeftClickPin()
                capsule.alertIcon = "📞"
                capsule.alertTitle = relay.callTitle || "Teams 通话"
                capsule.alertSubtitle = "呼叫已完成"
                capsule.alertAvatar = ""
                triggerTransient("ALERT", 1500)
            }
        }
    }

    Loader {
        id: settingsLoader
        active: false; source: "SettingsWindow.qml"
        onLoaded: { item.show(); item.raise() }
    }

    function openSettingsWindow() {
        if (settingsLoader.status === Loader.Ready && settingsLoader.item) {
            settingsLoader.item.show(); settingsLoader.item.raise()
        } else {
            settingsLoader.active = true
        }
    }

    Timer { id: transientTimer; onTriggered: capsule.activeTransient = "" }
    function triggerTransient(mode, ms) {
        if (fsm.stateName === "EXPANDED") return
        capsule.activeTransient = mode
        if (ms > 0) {
            transientTimer.interval = ms; transientTimer.restart()
        } else {
            transientTimer.stop()
        }
    }

    function expandToTab(tabName) {
        fsm.evLeftClickPin()
        if (capsule.lockBriefMorph) capsule.lockBriefMorph()
        if (capsule.activeTransient === "ALERT") {
            transientTimer.stop()
            capsule.activeTransient = ""
        }
        capsule.expandedTab = tabName
        fsm.evExpandCard()
    }

    // 核心胶囊
    IslandCapsule {
        id: capsule
        fsm: fsm
        anchors.horizontalCenter: parent.horizontalCenter

        chosenFont: root.chosenFont
        enabledTabs: root.enabledTabs
        dominantColor: relay.dominantColor
        spec1: relay.spec1; spec2: relay.spec2; spec3: relay.spec3; spec4: relay.spec4

        status: relay.status; isCalling: relay.isCalling; callTitle: relay.callTitle; callSubtitle: relay.callSubtitle; callAvatar: relay.callAvatar
        title: relay.title; artist: relay.artist; artUrl: relay.artUrl; position: relay.position; duration: relay.duration
        wsCurrent: relay.wsCurrent; wsTotal: relay.wsTotal; wsName: relay.wsName; wsList: relay.wsList
        osdIcon: relay.osdIcon; osdValue: relay.osdValue
        displayDate: timeService.displayDate; displayTime: timeService.displayTime; displaySeconds: timeService.displaySeconds; displayPeriod: timeService.displayPeriod
        downCompact: relay.downSpeedCompact; upCompact: relay.upSpeedCompact; downSpeedStr: relay.downSpeedStr; upSpeedStr: relay.upSpeedStr; localIp: relay.localIp

        unreadCount: relay.unreadCount
        latestNotifAvatar: relay.latestNotifAvatar
        memoryPercent: relay.memoryPercent

        onSedentaryRested: sedentaryService.markRested()
        onSedentarySnooze: sedentaryService.snooze()

        onRequestExpand: (t) => root.expandToTab(t)
        onRequestSettings: root.openSettingsWindow()

        // 🚀 只要播放状态改变（开始播放音乐），立即确保退出吸顶
        onStatusChanged: {
            if (status === "Playing" && fsm.stateName === "TUCKED") {
                fsm.evLeftClickPin()
            }
        }
    }

    Connections {
        target: capsule
        ignoreUnknownSignals: true
        function onTimerAlert(t, msg) {
            fsm.evLeftClickPin()
            capsule.alertIcon = "⏰"
            capsule.alertTitle = t
            capsule.alertSubtitle = msg
            triggerTransient("ALERT", 6000)
            if (typeof Bridge !== "undefined") Bridge.forceRaise()
        }
    }

    Component.onCompleted: {
        capsule.expandedTab = relay.isCalling ? "media" : "time"
        root.commitSettledMask()
    }
}