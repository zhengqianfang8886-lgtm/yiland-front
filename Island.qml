// ==========================================
// 📄 File: Island.qml
// 🌟 悬停偷瞄(Peek)自动缩回 · 点击左键固定常驻(Pin)
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 860
    height: 270

    readonly property string chosenFont: Theme.activeFont
    readonly property int splitGap: (typeof Config !== "undefined" && Config.splitGap !== undefined) ? Config.splitGap : 8

    // 阻塞状态：胶囊实际上处于隐藏吸顶状态（非 Peek 偷瞄中）时才阻断副岛
    readonly property bool isBlockingTransient: (capsule.isCalling || capsule.activeTransient === "ALERT" || capsule.activeTransient === "SEDENTARY" || capsule.isExpanded || capsule.isCollapsing || capsule.isActuallyTucked)

    // 副岛展示门控：主岛稳定着陆且非吸顶中（Peek 偷瞄探出时也允许副岛展示）
    readonly property bool subIslandsAllowed: capsule.isCapsuleSettled && !root.isBlockingTransient

    readonly property real effectiveCapsuleX: capsule.isExpanded ? 
        Math.round((root.width - capsule.currentNormalWidth) / 2 + (typeof Config !== "undefined" ? Config.offsetX : 0)) : 
        capsule.x

    readonly property real effectiveCapsuleWidth: capsule.isExpanded ? 
        capsule.currentNormalWidth : 
        capsule.width

    // -------------------------------------------------------------------------
    // 媒体音乐状态管理
    // -------------------------------------------------------------------------
    property bool musicRetained: Boolean(relay && relay.status === "Playing")

    Timer {
        id: musicRetainTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (!relay || relay.status !== "Playing") root.musicRetained = false
        }
    }

    Connections {
        target: relay
        ignoreUnknownSignals: true
        function onStatusChanged() {
            if (relay && relay.status === "Playing") {
                musicRetainTimer.stop()
                root.musicRetained = true
            } else if (root.musicRetained) {
                musicRetainTimer.restart()
            }
        }
    }

    readonly property bool hasMusicIsland: Boolean(relay && (relay.status === "Playing" || root.musicRetained))

    // -------------------------------------------------------------------------
    // 展开卡片与导航标签
    // -------------------------------------------------------------------------
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
            if (capsule.isTucked) { capsule.isTucked = false; capsule.isPeeking = false }
            if (capsule.isAtMotel) capsule.goHome()
            triggerTransient("WORKSPACE", 800)
            Bridge.forceRaise()
        }

        onTriggerAlert: (icon, t, sub, ms, avatar) => {
            var isDnd = (typeof Config !== "undefined" && Config.dndEnabled)
            var isCall = (icon === "📞" || relay.isCalling)
            var allowCall = (typeof Config !== "undefined" && Config.dndAllowCalls !== false)

            if (isDnd && !isCall) return
            if (isDnd && isCall && !allowCall) return

            if (capsule.isTucked) { capsule.isTucked = false; capsule.isPeeking = false }
            if (capsule.isAtMotel) capsule.goHome()

            capsule.alertIcon = icon
            capsule.alertTitle = t
            capsule.alertSubtitle = sub
            capsule.alertAvatar = avatar || ""
            triggerTransient("ALERT", ms > 0 ? ms : 5000)
        }

        onTriggerClipboard: (icon, t, sub, ms) => {
            if (!(typeof Config !== "undefined" && Config.dndEnabled) && !capsule.isTucked) capsule.triggerClipGlow()
        }

        onCallEnded: {
            if (capsule.isExpanded) capsule.startCollapse()
            if (!(typeof Config !== "undefined" && Config.dndEnabled && !Config.dndAllowCalls)) {
                if (capsule.isTucked) { capsule.isTucked = false; capsule.isPeeking = false }
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

    function expandToTab(tabName) {
        if (capsule.isTucked) { capsule.isTucked = false; capsule.isPeeking = false }
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

    // =========================================================================
    // 挂载槽容器与胶囊
    // =========================================================================

    // 1. 左侧挂载槽 (音乐、内存)
    IslandPluginBay {
        id: leftBay
        z: 1
        side: "left"
        capsuleX: root.effectiveCapsuleX
        capsuleWidth: root.effectiveCapsuleWidth
        capsuleY: capsule.y
        capsuleHeight: capsule.height
        splitGap: root.splitGap
        isBlocked: !root.subIslandsAllowed
        relay: relay
        capsule: capsule
        hasMusicIsland: root.hasMusicIsland
        activeKeys: (typeof Config !== "undefined" && Config.subIslandsLeft) ? Config.subIslandsLeft : ["memory", "music"]
        onRequestExpand: (tab) => root.expandToTab(tab)
        onInteracted: root.handleSubBubbleInteracted()
        onMaskUpdateRequested: maskController.commit()
    }

    // 2. 核心主胶囊
    IslandCapsule {
        id: capsule
        chosenFont: root.chosenFont
        enabledTabs: root.enabledTabs
        dominantColor: relay.dominantColor
        anySubBubbleHovered: leftBay.isAnyHovered || rightBay.isAnyHovered
        status: relay.status; isCalling: relay.isCalling; callTitle: relay.callTitle; callSubtitle: relay.callSubtitle; callAvatar: relay.callAvatar
        title: relay.title; artist: relay.artist; artUrl: relay.artUrl; position: relay.position; duration: relay.duration
        wsCurrent: relay.wsCurrent; wsTotal: relay.wsTotal; wsName: relay.wsName; wsList: relay.wsList
        osdIcon: relay.osdIcon; osdValue: relay.osdValue
        displayDate: timeService.displayDate; displayTime: timeService.displayTime; displaySeconds: timeService.displaySeconds; displayPeriod: timeService.displayPeriod
        downCompact: relay.downSpeedCompact; upCompact: relay.upSpeedCompact; downSpeedStr: relay.downSpeedStr; upSpeedStr: relay.upSpeedStr; localIp: relay.localIp

        onSedentaryRested: sedentaryService.markRested()
        onSedentarySnooze: sedentaryService.snooze()

        onRequestExpand: (t) => root.expandToTab(t)
        onRequestSettings: root.openSettingsWindow()
        onMaskCommitRequested: maskController.commit()
        onXChanged: maskController.commit()
    }

    // 3. 右侧挂载槽 (计时、通知)
    IslandPluginBay {
        id: rightBay
        z: 1
        side: "right"
        capsuleX: root.effectiveCapsuleX
        capsuleWidth: root.effectiveCapsuleWidth
        capsuleY: capsule.y
        capsuleHeight: capsule.height
        splitGap: root.splitGap
        isBlocked: !root.subIslandsAllowed
        relay: relay
        capsule: capsule
        hasMusicIsland: root.hasMusicIsland
        activeKeys: (typeof Config !== "undefined" && Config.subIslandsRight) ? Config.subIslandsRight : ["timer", "notification"]
        onRequestExpand: (tab) => root.expandToTab(tab)
        onInteracted: root.handleSubBubbleInteracted()
        onMaskUpdateRequested: maskController.commit()
    }

    Connections {
        target: capsule
        ignoreUnknownSignals: true
        function onTimerAlert(t, msg) {
            if (capsule.isTucked) { capsule.isTucked = false; capsule.isPeeking = false }
            capsule.alertIcon = "⏰"
            capsule.alertTitle = t
            capsule.alertSubtitle = msg
            triggerTransient("ALERT", 6000)
            if (typeof Bridge !== "undefined") Bridge.forceRaise()
        }
    }

    // 4. 自省式遮罩控制器
    IslandMaskController {
        id: maskController
        rootItem: root
        capsuleItem: capsule
        leftBay: leftBay
        rightBay: rightBay
        isExpanded: capsule.isExpanded
        isCollapsing: capsule.isCollapsing
        isMorphing: capsule.isMorphing
        targetW: capsule.targetWidth
        targetH: capsule.targetHeight
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