// ==========================================
// 📄 File: Island.qml (全面防切终极版)
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 720; height: 270

    readonly property string chosenFont: (!Config.fontFamily || Config.fontFamily.indexOf("系统默认") !== -1) ? "" : Config.fontFamily
    readonly property int splitGap: (typeof Config !== "undefined" && Config.splitGap !== undefined) ? Config.splitGap : 8

    // 只有在全屏大卡片展开/收缩、来电打断、久坐打断时才隐藏副岛
    readonly property bool isBlockingTransient: (capsule.isCalling || capsule.activeTransient === "ALERT" || capsule.activeTransient === "SEDENTARY" || capsule.isExpanded || capsule.isCollapsing)
    readonly property bool hasMusicIsland: (relay.status === "Playing") && !isBlockingTransient
    readonly property bool hasTimerIsland: capsule.timerActive && !isBlockingTransient
    readonly property bool hasNotifIsland: (relay.unreadCount > 0) && !isBlockingTransient

    readonly property var enabledTabs: {
        var list = []
        list.push({ key: "time", name: "时间", color: Theme.calendar, activeColor: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.22) })

        if (typeof Config === "undefined" || Config.showWorkspaceTab !== false) {
            list.push({ key: "workspace", name: "桌面", color: Theme.workspace, activeColor: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.22) })
        }
        if (typeof Config === "undefined" || Config.showMediaTab !== false) {
            list.push({ key: "media", name: "媒体", color: Theme.textPrimary, activeColor: Qt.rgba(1, 1, 1, 0.18) })
        }
        if (typeof Config === "undefined" || Config.showCalendarTab !== false) {
            list.push({ key: "calendar", name: "日历", color: Theme.calendar, activeColor: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.22) })
        }
        if (typeof Config === "undefined" || Config.showTimerTab !== false) {
            list.push({ key: "timer", name: "计时", color: Theme.timer, activeColor: Qt.rgba(Theme.timer.r, Theme.timer.g, Theme.timer.b, 0.22) })
        }
        if (typeof Config === "undefined" || Config.showClockTab !== false) {
            list.push({ key: "clock", name: "时钟", color: Theme.clock, activeColor: Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.22) })
        }
        if (typeof Config === "undefined" || Config.showNetworkTab !== false) {
            list.push({ key: "network", name: "网络", color: Theme.network, activeColor: Qt.rgba(Theme.network.r, Theme.network.g, Theme.network.b, 0.22) })
        }
        if (typeof Config === "undefined" || Config.showBluetoothTab !== false) {
            list.push({ key: "bluetooth", name: "蓝牙", color: Theme.bluetooth, activeColor: Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.22) })
        }
        if (typeof Config === "undefined" || Config.showNotificationTab !== false) {
            list.push({ key: "notification", name: "通知", color: Theme.notification, activeColor: Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.22) })
        }
        return list
    }

    IslandTimeService { id: timeService }

    IslandSedentaryService {
        id: sedentaryService
        onRequestAlert: (continuousMinutes) => {
            capsule.continuousSitMinutes = continuousMinutes
            triggerTransient("SEDENTARY", 0)
        }
        onDismissAlert: {
            if (capsule.activeTransient === "SEDENTARY") {
                capsule.activeTransient = ""
            }
        }
    }

    IslandBridgeRelay {
        id: relay
        onTriggerOsd: (icon, label, val) => triggerTransient("OSD", 1500)
        onTriggerWorkspace: (c, t, n) => { triggerTransient("WORKSPACE", 800); Bridge.forceRaise() }
        onTriggerAlert: (icon, t, sub, ms, avatar) => {
            capsule.alertIcon = icon
            capsule.alertTitle = t
            capsule.alertSubtitle = sub
            capsule.alertAvatar = avatar || ""
            triggerTransient("ALERT", ms > 0 ? ms : 5000)
        }
        onTriggerClipboard: (icon, t, sub, ms) => {
            capsule.triggerClipGlow()
        }
        onCallEnded: {
            if (capsule.isExpanded) capsule.startCollapse()
            capsule.alertIcon = "📞"
            capsule.alertTitle = relay.callTitle || "Teams 通话"
            capsule.alertSubtitle = "呼叫已完成"
            capsule.alertAvatar = ""
            triggerTransient("ALERT", 1500)
        }
    }

    Loader {
        id: settingsLoader
        active: false; source: "SettingsWindow.qml"
        onLoaded: { item.show(); item.raise(); item.requestActivate() }
    }

    Timer { id: transientTimer; onTriggered: capsule.activeTransient = "" }
    function triggerTransient(mode, ms) {
        if (capsule.isExpanded) return
        capsule.activeTransient = mode
        if (ms > 0) {
            transientTimer.interval = ms; transientTimer.restart()
        } else {
            transientTimer.stop()
        }
    }

    IslandMaskController {
        id: maskController
        rootItem: root; capsuleItem: capsule
        leftMemoryBubble: bubbleMemory
        leftBubble: bubbleMusic
        hwBubble: bubbleHardware
        rightBubble: bubbleTimer
        notifBubble: bubbleNotif
        isExpanded: capsule.isExpanded; isCollapsing: capsule.isCollapsing; isMorphing: capsule.isMorphing
        targetW: capsule.targetWidth; targetH: capsule.targetHeight
    }

    function expandToTab(tabName) {
        capsule.cancelCollapse()
        if (tabName !== "notification" && capsule.activeTransient === "ALERT") {
            transientTimer.stop()
            capsule.activeTransient = ""
        }

        capsule.expandedTab = tabName
        capsule.drillDownPage = ""
        capsule.isExpanded = true
        maskController.commit()
    }

    Timer {
        id: subInteractingTimer
        interval: 700
        onTriggered: capsule.subBubbleInteracting = false
    }

    function handleSubBubbleInteracted() {
        capsule.subBubbleInteracting = true
        subInteractingTimer.restart()
    }

    IslandCapsule {
        id: capsule
        chosenFont: root.chosenFont
        enabledTabs: root.enabledTabs
        dominantColor: relay.dominantColor
        anySubBubbleHovered: bubbleMemory.isHovered || bubbleMusic.isHovered || bubbleHardware.isHovered || bubbleTimer.isHovered || bubbleNotif.isHovered
        status: relay.status; isCalling: relay.isCalling; callTitle: relay.callTitle; callSubtitle: relay.callSubtitle; callAvatar: relay.callAvatar
        title: relay.title; artist: relay.artist; artUrl: relay.artUrl; position: relay.position; duration: relay.duration
        wsCurrent: relay.wsCurrent; wsTotal: relay.wsTotal; wsName: relay.wsName; wsList: relay.wsList
        osdIcon: relay.osdIcon; osdValue: relay.osdValue
        displayDate: timeService.displayDate; displayTime: timeService.displayTime; displaySeconds: timeService.displaySeconds; displayPeriod: timeService.displayPeriod
        downCompact: relay.downSpeedCompact; upCompact: relay.upSpeedCompact; downSpeedStr: relay.downSpeedStr; upSpeedStr: relay.upSpeedStr; localIp: relay.localIp

        onSedentaryRested: sedentaryService.markRested()
        onSedentarySnooze: sedentaryService.snooze()

        onRequestExpand: (t) => root.expandToTab(t)
        onRequestSettings: {
            if (settingsLoader.status === Loader.Ready && settingsLoader.item) {
                settingsLoader.item.show(); settingsLoader.item.raise(); settingsLoader.item.requestActivate()
            } else { settingsLoader.active = true }
        }
        onMaskCommitRequested: maskController.commit()
        onTimerAlert: (t, msg) => {
            capsule.alertIcon = "⏰"; capsule.alertTitle = t; capsule.alertSubtitle = msg; triggerTransient("ALERT", 6000); Bridge.forceRaise()
        }
    }

    readonly property var islandItemMap: ({
        "memory": bubbleMemory,
        "music": bubbleMusic,
        "hardware": bubbleHardware,
        "timer": bubbleTimer,
        "notification": bubbleNotif
    })

    function getIslandSide(key) {
        var left = (typeof Config !== "undefined" && Config.subIslandsLeft) ? Config.subIslandsLeft : ["memory", "music"]
        return left.indexOf(key) !== -1 ? "left" : "right"
    }

    function getLeftIslandX(key, itemWidth) {
        var list = (typeof Config !== "undefined" && Config.subIslandsLeft) ? Config.subIslandsLeft : ["memory", "music"]
        var currentEdge = capsule.x - root.splitGap
        for (var i = 0; i < list.length; i++) {
            var k = list[i]
            var item = islandItemMap[k]
            if (!item) continue
            if (k === key) {
                return Math.max(8, currentEdge - itemWidth)
            }
            if (item.active) {
                currentEdge -= (item.width + root.splitGap)
            }
        }
        return Math.max(8, capsule.x - root.splitGap - itemWidth)
    }

    function getRightIslandX(key) {
        var list = (typeof Config !== "undefined" && Config.subIslandsRight) ? Config.subIslandsRight : ["hardware", "timer", "notification"]
        var currentEdge = capsule.x + capsule.width + root.splitGap
        for (var i = 0; i < list.length; i++) {
            var k = list[i]
            var item = islandItemMap[k]
            if (!item) continue
            if (k === key) {
                return currentEdge
            }
            if (item.active) {
                currentEdge += (item.width + root.splitGap)
            }
        }
        return capsule.x + capsule.width + root.splitGap
    }

    function getIslandX(key, itemWidth) {
        if (getIslandSide(key) === "left") {
            return getLeftIslandX(key, itemWidth)
        } else {
            return getRightIslandX(key)
        }
    }

    // =========================================================================
    // 5 大副岛组件（位移或隐现均向 maskController 报备，彻底告别切断残影）
    // =========================================================================

    MemoryBubbleView {
        id: bubbleMemory; z: 1
        x: root.getIslandX("memory", width)
        y: capsule.y + Math.round((capsule.height - height) / 2)
        transformOrigin: root.getIslandSide("memory") === "left" ? Item.Right : Item.Left

        readonly property bool meetsThreshold: {
            if (typeof Config === "undefined" || Config.memoryThreshold === undefined || Config.memoryThreshold <= 0) return true
            return relay.memoryPercent >= Config.memoryThreshold
        }

        active: !root.isBlockingTransient &&
                (typeof Config === "undefined" || Config.showMemoryBubble !== false) &&
                meetsThreshold

        memoryPercent: relay.memoryPercent
        memoryUsedGb: relay.memoryUsedGb
        memoryTotalGb: relay.memoryTotalGb

        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        // 🚀 核心联动：位移或显隐立即放开遮罩
        onActiveChanged: maskController.notifyIslandMoving()
        onXChanged: maskController.notifyIslandMoving()
        onClicked: if (typeof Bridge !== "undefined" && Bridge.openSystemMonitor) Bridge.openSystemMonitor()
    }

    MusicBubbleView {
        id: bubbleMusic; z: 1
        x: root.getIslandX("music", width)
        y: capsule.y + Math.round((capsule.height - height) / 2)
        transformOrigin: root.getIslandSide("music") === "left" ? Item.Right : Item.Left

        active: !root.isBlockingTransient && root.hasMusicIsland

        dominantColor: relay.dominantColor
        spec1: relay.spec1
        spec2: relay.spec2
        spec3: relay.spec3
        spec4: relay.spec4

        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        onActiveChanged: maskController.notifyIslandMoving()
        onXChanged: maskController.notifyIslandMoving()
        onClicked: root.expandToTab("media")
        onWheelInteracted: root.handleSubBubbleInteracted()
    }

    HardwareBubbleView {
        id: bubbleHardware; z: 1
        x: root.getIslandX("hardware", width)
        y: capsule.y + Math.round((capsule.height - height) / 2)
        transformOrigin: root.getIslandSide("hardware") === "left" ? Item.Right : Item.Left

        active: !root.isBlockingTransient &&
                (typeof Config === "undefined" || Config.showHardwareBubble !== false)

        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        onActiveChanged: maskController.notifyIslandMoving()
        onXChanged: maskController.notifyIslandMoving()

        onWheelAdjusted: (mode, delta) => {
            root.handleSubBubbleInteracted()
            if (typeof Bridge !== "undefined") {
                Bridge.adjustHardware(mode, delta)
            }
        }

        onToggleMuteTriggered: (mode) => {
            root.handleSubBubbleInteracted()
            if (typeof Bridge !== "undefined") {
                Bridge.toggleHardwareMute(mode)
            }
        }

        onModeChanged: (mode) => {
            root.handleSubBubbleInteracted()
        }
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onHardwareMuteStateChanged(volMuted, micMuted) {
            bubbleHardware.isVolMuted = volMuted
            bubbleHardware.isMicMuted = micMuted
        }
    }

    TimerBubbleView {
        id: bubbleTimer; z: 1
        x: root.getIslandX("timer", width)
        y: capsule.y + Math.round((capsule.height - height) / 2)
        transformOrigin: root.getIslandSide("timer") === "left" ? Item.Right : Item.Left

        active: !root.isBlockingTransient && root.hasTimerIsland
        timerText: capsule.timerFormattedText; hasHours: capsule.timerHasHours; chosenFont: root.chosenFont
        isCountUp: capsule.timerIsCountUp; progress: capsule.timerProgress
        remainingSeconds: capsule.timerRemaining; totalSeconds: capsule.timerTotal

        isRunning: capsule.timerRunning
        isPaused: capsule.timerIsPaused
        isCompleted: capsule.timerIsCompleted

        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        onActiveChanged: maskController.notifyIslandMoving()
        onXChanged: maskController.notifyIslandMoving()

        onTogglePause: capsule.toggleTimerPause()
        onDismissTimer: capsule.resetTimer()
    }

    NotificationBubbleView {
        id: bubbleNotif; z: 1
        x: root.getIslandX("notification", width)
        y: capsule.y + Math.round((capsule.height - height) / 2)
        transformOrigin: root.getIslandSide("notification") === "left" ? Item.Right : Item.Left

        active: !root.isBlockingTransient && root.hasNotifIsland
        unreadCount: relay.unreadCount; avatarUrl: relay.latestNotifAvatar; chosenFont: root.chosenFont

        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        onActiveChanged: maskController.notifyIslandMoving()
        onXChanged: maskController.notifyIslandMoving()
        onClicked: root.expandToTab("notification")
        onRightClicked: root.expandToTab("notification")
    }

    Timer {
        id: startupMaskTimer
        interval: 60; running: false; repeat: false
        onTriggered: {
            maskController.maskActive = true
            maskController.commit()
        }
    }

    Component.onCompleted: {
        capsule.expandedTab = relay.isCalling ? "media" : "time"
        capsule.drillDownPage = ""
        startupMaskTimer.start()
    }
}