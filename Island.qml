// ==========================================
// 📄 File: Island.qml
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 860
    height: 270

    readonly property string chosenFont: Theme.activeFont
    readonly property int splitGap: (typeof Config !== "undefined" && Config.splitGap !== undefined) ? Config.splitGap : 8

    property bool isIslandHidden: false

    readonly property int effectiveHideDurationMs: {
        var sec = 5
        if (typeof Config !== "undefined" && Config.autoHideDurationSeconds !== undefined) {
            sec = Number(Config.autoHideDurationSeconds)
        }
        return Math.max(1000, sec * 1000)
    }

    Timer {
        id: autoRestoreTimer
        interval: root.effectiveHideDurationMs
        repeat: false
        onTriggered: {
            root.wakeIsland()
        }
    }

    function triggerHideIsland() {
        if (capsule.isExpanded) {
            capsule.isExpanded = false
            capsule.isCollapsing = false
        }
        autoRestoreTimer.stop()
        root.isIslandHidden = true

        if (typeof Bridge !== "undefined" && Bridge.setPassthrough) {
            Bridge.setPassthrough()
        }

        autoRestoreTimer.interval = root.effectiveHideDurationMs
        autoRestoreTimer.restart()
        maskController.commit()
    }

    function wakeIsland() {
        autoRestoreTimer.stop()
        root.isIslandHidden = false
        maskController.commit()
    }

    readonly property bool isBlockingTransient: (capsule.isCalling || capsule.activeTransient === "ALERT" || capsule.activeTransient === "SEDENTARY" || capsule.isExpanded || capsule.isCollapsing || root.isIslandHidden)

    readonly property real effectiveCapsuleX: capsule.isExpanded ? 
        Math.round((root.width - capsule.currentNormalWidth) / 2 + (typeof Config !== "undefined" ? Config.offsetX : 0)) : 
        capsule.x

    readonly property real effectiveCapsuleWidth: capsule.isExpanded ? 
        capsule.currentNormalWidth : 
        capsule.width

    property bool musicRetained: relay.status === "Playing"

    Timer {
        id: musicRetainTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (relay.status !== "Playing") {
                root.musicRetained = false
            }
        }
    }

    Connections {
        target: relay
        function onStatusChanged() {
            if (relay.status === "Playing") {
                musicRetainTimer.stop()
                root.musicRetained = true
            } else {
                if (root.musicRetained) {
                    musicRetainTimer.restart()
                }
            }
        }
    }

    readonly property bool hasMusicIsland: (relay.status === "Playing" || musicRetained) && !isBlockingTransient
    readonly property bool hasTypingIsland: !root.isBlockingTransient &&
                                            (typeof Config === "undefined" || Config.showHardwareBubble !== false) &&
                                            (typeof Config === "undefined" || Config.typingVisualizerEnabled !== false)

    readonly property bool hasTimerIsland: capsule.timerActive && !isBlockingTransient
    readonly property bool hasNotifIsland: (relay.unreadCount > 0) && !isBlockingTransient

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
        "notification": { key: "notification", name: "通知", color: Theme.notification, activeColor: Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.22) },
        "process": { key: "process", name: "服务", color: "#a855f7", activeColor: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.22) }
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
        if (key === "process") return Config.showProcessTab !== false
        return true
    }

    readonly property var enabledTabs: {
        var order = (typeof Config !== "undefined" && Config.tabOrder && Config.tabOrder.length > 0) ?
                    Config.tabOrder :
                    ["time", "hardware", "workspace", "media", "calendar", "timer", "clock", "network", "bluetooth", "notification", "process"]
        var list = []
        for (var i = 0; i < order.length; i++) {
            var k = order[i]
            if (isTabEnabled(k) && allTabsMeta[k]) {
                list.push(allTabsMeta[k])
            }
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
            var isDnd = (typeof Config !== "undefined" && Config.dndEnabled)
            var isCall = (icon === "📞" || relay.isCalling)
            var allowCall = (typeof Config !== "undefined" && Config.dndAllowCalls !== false)

            if (isDnd && !isCall) return
            if (isDnd && isCall && !allowCall) return

            capsule.alertIcon = icon
            capsule.alertTitle = t
            capsule.alertSubtitle = sub
            capsule.alertAvatar = avatar || ""
            triggerTransient("ALERT", ms > 0 ? ms : 5000)
        }

        onTriggerClipboard: (icon, t, sub, ms) => {
            if (!(typeof Config !== "undefined" && Config.dndEnabled)) {
                capsule.triggerClipGlow()
            }
        }

        onCallEnded: {
            if (capsule.isExpanded) capsule.startCollapse()
            if (!(typeof Config !== "undefined" && Config.dndEnabled && !Config.dndAllowCalls)) {
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
        onLoaded: { item.show(); item.raise(); item.requestActivate() }
    }

    function openSettingsWindow() {
        if (settingsLoader.status === Loader.Ready && settingsLoader.item) {
            settingsLoader.item.show()
            settingsLoader.item.raise()
            settingsLoader.item.requestActivate()
        } else {
            settingsLoader.active = true
        }
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
        rootItem: root
        capsuleItem: capsule
        lofiBubble: bubbleLofi
        leftMemoryBubble: bubbleMemory
        leftBubble: bubbleMusic
        hwBubble: bubbleHardware
        rightBubble: bubbleTimer
        notifBubble: bubbleNotif
        isExpanded: capsule.isExpanded
        isCollapsing: capsule.isCollapsing
        isMorphing: capsule.isMorphing
        isIslandHidden: root.isIslandHidden
        targetW: capsule.targetWidth
        targetH: capsule.targetHeight
    }

    function expandToTab(tabName) {
        capsule.lockBriefMorph()
        if (capsule.activeTransient === "ALERT") {
            transientTimer.stop()
            capsule.activeTransient = ""
        }
        capsule.expandedTab = tabName
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
        anySubBubbleHovered: bubbleLofi.isHovered || bubbleMemory.isHovered || bubbleMusic.isHovered || bubbleHardware.isHovered || bubbleTimer.isHovered || bubbleNotif.isHovered
        status: relay.status; isCalling: relay.isCalling; callTitle: relay.callTitle; callSubtitle: relay.callSubtitle; callAvatar: relay.callAvatar
        title: relay.title; artist: relay.artist; artUrl: relay.artUrl; position: relay.position; duration: relay.duration
        wsCurrent: relay.wsCurrent; wsTotal: relay.wsTotal; wsName: relay.wsName; wsList: relay.wsList
        osdIcon: relay.osdIcon; osdValue: relay.osdValue
        displayDate: timeService.displayDate; displayTime: timeService.displayTime; displaySeconds: timeService.displaySeconds; displayPeriod: timeService.displayPeriod
        downCompact: relay.downSpeedCompact; upCompact: relay.upSpeedCompact; downSpeedStr: relay.downSpeedStr; upSpeedStr: relay.upSpeedStr; localIp: relay.localIp

        isIslandHidden: root.isIslandHidden
        onRequestHideIsland: root.triggerHideIsland()

        onSedentaryRested: sedentaryService.markRested()
        onSedentarySnooze: sedentaryService.snooze()

        onRequestExpand: (t) => root.expandToTab(t)
        onRequestSettings: root.openSettingsWindow()
        onMaskCommitRequested: maskController.commit()
        onTimerAlert: (t, msg) => {
            capsule.alertIcon = "⏰"; capsule.alertTitle = t; capsule.alertSubtitle = msg; triggerTransient("ALERT", 6000); Bridge.forceRaise()
        }
    }

    readonly property var islandItemMap: ({
        "lofi": bubbleLofi,
        "memory": bubbleMemory,
        "music": bubbleMusic,
        "hardware": bubbleHardware,
        "timer": bubbleTimer,
        "notification": bubbleNotif
    })

    function getIslandSide(key) {
        var left = (typeof Config !== "undefined" && Config.subIslandsLeft) ? Config.subIslandsLeft : ["lofi", "memory", "music"]
        return left.indexOf(key) !== -1 ? "left" : "right"
    }

    function getLeftIslandOffset(key, itemWidth) {
        var list = (typeof Config !== "undefined" && Config.subIslandsLeft) ? Config.subIslandsLeft : ["lofi", "memory", "music"]
        var currentOffset = root.splitGap
        for (var i = 0; i < list.length; i++) {
            var k = list[i]
            var item = islandItemMap[k]
            if (!item) continue
            if (k === key) {
                return currentOffset + itemWidth
            }
            if (item.active) {
                currentOffset += (item.width + root.splitGap)
            }
        }
        return currentOffset + itemWidth
    }

    function getRightIslandOffset(key) {
        var list = (typeof Config !== "undefined" && Config.subIslandsRight) ? Config.subIslandsRight : ["hardware", "timer", "notification"]
        var currentOffset = root.splitGap
        for (var i = 0; i < list.length; i++) {
            var k = list[i]
            var item = islandItemMap[k]
            if (!item) continue
            if (k === key) {
                return currentOffset
            }
            if (item.active) {
                currentOffset += (item.width + root.splitGap)
            }
        }
        return currentOffset
    }

    // 1. Lofi 动画副岛
    LofiBubbleView {
        id: bubbleLofi; z: 1
        readonly property string side: root.getIslandSide("lofi")
        readonly property real targetOffset: side === "left" ? root.getLeftIslandOffset("lofi", width) : root.getRightIslandOffset("lofi")
        property real currentOffset: targetOffset
        Behavior on currentOffset { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        x: side === "left" ? Math.max(8, root.effectiveCapsuleX - currentOffset) : (root.effectiveCapsuleX + root.effectiveCapsuleWidth + currentOffset)
        y: capsule.y + Math.round((capsule.height - height) / 2)
        transformOrigin: side === "left" ? Item.Right : Item.Left

        active: !root.isBlockingTransient &&
                (typeof Config === "undefined" || Config.showLofiBubble !== false)

        onActiveChanged: maskController.commit()
        onXChanged: maskController.commit()
    }

    // 2. 内存监控副岛
    MemoryBubbleView {
        id: bubbleMemory; z: 1
        readonly property string side: root.getIslandSide("memory")
        readonly property real targetOffset: side === "left" ? root.getLeftIslandOffset("memory", width) : root.getRightIslandOffset("memory")
        property real currentOffset: targetOffset
        Behavior on currentOffset { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        x: side === "left" ? Math.max(8, root.effectiveCapsuleX - currentOffset) : (root.effectiveCapsuleX + root.effectiveCapsuleWidth + currentOffset)
        y: capsule.y + Math.round((capsule.height - height) / 2)
        transformOrigin: side === "left" ? Item.Right : Item.Left

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

        onActiveChanged: maskController.commit()
        onXChanged: maskController.commit()
        onClicked: if (typeof Bridge !== "undefined" && Bridge.openSystemMonitor) Bridge.openSystemMonitor()
    }

    // 3. 音乐律动副岛
    MusicBubbleView {
        id: bubbleMusic; z: 1
        readonly property string side: root.getIslandSide("music")
        readonly property real targetOffset: side === "left" ? root.getLeftIslandOffset("music", width) : root.getRightIslandOffset("music")
        property real currentOffset: targetOffset
        Behavior on currentOffset { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        x: side === "left" ? Math.max(8, root.effectiveCapsuleX - currentOffset) : (root.effectiveCapsuleX + root.effectiveCapsuleWidth + currentOffset)
        y: capsule.y + Math.round((capsule.height - height) / 2)
        transformOrigin: side === "left" ? Item.Right : Item.Left

        active: !root.isBlockingTransient && root.hasMusicIsland

        dominantColor: relay.dominantColor
        spec1: relay.spec1
        spec2: relay.spec2
        spec3: relay.spec3
        spec4: relay.spec4

        onActiveChanged: maskController.commit()
        onXChanged: maskController.commit()
        onClicked: root.expandToTab("media")
        onWheelInteracted: root.handleSubBubbleInteracted()
    }

    // 4. 击键心流副岛
    HardwareBubbleView {
        id: bubbleHardware
        z: 5
        readonly property string side: root.getIslandSide("hardware")
        readonly property real targetOffset: side === "left" ? root.getLeftIslandOffset("hardware", width) : root.getRightIslandOffset("hardware")
        property real currentOffset: targetOffset
        Behavior on currentOffset { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        activeMod: relay.typingMod
        activeKey: relay.typingKey
        strokeRevision: relay.strokeRevision

        x: side === "left" ? Math.max(8, root.effectiveCapsuleX - currentOffset) : (root.effectiveCapsuleX + root.effectiveCapsuleWidth + currentOffset)
        y: capsule.y + Math.round((capsule.height - height) / 2)
        transformOrigin: side === "left" ? Item.Right : Item.Left

        active: root.hasTypingIsland

        isTyping: relay.typingActive
        typingThemeColor: relay.typingColor
        spec1: relay.typingSpec1
        spec2: relay.typingSpec2
        spec3: relay.typingSpec3
        spec4: relay.typingSpec4
        kps: relay.typingKps

        onActiveChanged: maskController.commit()
        onXChanged: maskController.commit()
    }

    // 5. 专注计时副岛
    TimerBubbleView {
        id: bubbleTimer; z: 1
        readonly property string side: root.getIslandSide("timer")
        readonly property real targetOffset: side === "left" ? root.getLeftIslandOffset("timer", width) : root.getRightIslandOffset("timer")
        property real currentOffset: targetOffset
        Behavior on currentOffset { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        x: side === "left" ? Math.max(8, root.effectiveCapsuleX - currentOffset) : (root.effectiveCapsuleX + root.effectiveCapsuleWidth + currentOffset)
        y: capsule.y + Math.round((capsule.height - height) / 2)
        transformOrigin: side === "left" ? Item.Right : Item.Left

        active: !root.isBlockingTransient && root.hasTimerIsland
        timerText: capsule.timerFormattedText; hasHours: capsule.timerHasHours; chosenFont: root.chosenFont
        isCountUp: capsule.timerIsCountUp; progress: capsule.timerProgress
        remainingSeconds: capsule.timerRemaining; totalSeconds: capsule.timerTotal

        isRunning: capsule.timerRunning
        isPaused: capsule.timerIsPaused
        isCompleted: capsule.timerIsCompleted

        onActiveChanged: maskController.commit()
        onXChanged: maskController.commit()
        onTogglePause: capsule.toggleTimerPause()
        onDismissTimer: capsule.dismissTimer()
    }

    // 6. 消息通知副岛
    NotificationBubbleView {
        id: bubbleNotif; z: 1
        readonly property string side: root.getIslandSide("notification")
        readonly property real targetOffset: side === "left" ? root.getLeftIslandOffset("notification", width) : root.getRightIslandOffset("notification")
        property real currentOffset: targetOffset
        Behavior on currentOffset { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        x: side === "left" ? Math.max(8, root.effectiveCapsuleX - currentOffset) : (root.effectiveCapsuleX + root.effectiveCapsuleWidth + currentOffset)
        y: capsule.y + Math.round((capsule.height - height) / 2)
        transformOrigin: side === "left" ? Item.Right : Item.Left

        active: !root.isBlockingTransient && root.hasNotifIsland
        unreadCount: relay.unreadCount; avatarUrl: relay.latestNotifAvatar; chosenFont: root.chosenFont

        onActiveChanged: maskController.commit()
        onXChanged: maskController.commit()
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
        startupMaskTimer.start()
    }
}