import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 720; height: 270

    readonly property string chosenFont: (!Config.fontFamily || Config.fontFamily.indexOf("系统默认") !== -1) ? "" : Config.fontFamily
    readonly property int splitGap: (typeof Config !== "undefined" && Config.splitGap !== undefined) ? Config.splitGap : 8
    
    // 🚀 核心修复：只有在长报警通知(ALERT)需要占满胶囊时才避让，切桌面(WORKSPACE)和OSD期间副岛稳稳保留！
    readonly property bool isBlockingTransient: (capsule.activeTransient === "ALERT")
    readonly property bool hasMusicIsland: (relay.status === "Playing") && !isBlockingTransient
    readonly property bool hasTimerIsland: capsule.timerRunning && !isBlockingTransient
    readonly property bool hasNotifIsland: (relay.unreadCount > 0) && !isBlockingTransient
    readonly property bool notifExpandsToLeft: (Config.multiIslandExpandDirection === "left")

    readonly property var enabledTabs: {
        var list = []
        if (Config.showWorkspaceTab) list.push({ key: "workspace", name: "桌面", color: Theme.workspace, activeColor: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.22) })
        if (Config.showMediaTab) list.push({ key: "media", name: "媒体", color: Theme.textPrimary, activeColor: Qt.rgba(1, 1, 1, 0.18) })
        if (Config.showCalendarTab) list.push({ key: "calendar", name: "日历", color: Theme.calendar, activeColor: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.22) })
        list.push({ key: "timer", name: "计时", color: Theme.timer, activeColor: Qt.rgba(Theme.timer.r, Theme.timer.g, Theme.timer.b, 0.22) })
        list.push({ key: "notification", name: "消息", color: Theme.notification, activeColor: Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.22) })
        if (Config.showBluetoothTab) list.push({ key: "bluetooth", name: "蓝牙", color: Theme.bluetooth, activeColor: Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.22) })
        if (Config.showNetworkTab) list.push({ key: "network", name: "网络", color: Theme.network, activeColor: Qt.rgba(Theme.network.r, Theme.network.g, Theme.network.b, 0.22) })
        if (Config.showClockTab) list.push({ key: "clock", name: "时钟", color: Theme.clock, activeColor: Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.22) })
        return list
    }

    IslandTimeService { id: timeService }
    IslandBridgeRelay {
        id: relay
        onTriggerOsd: (icon, label, val) => triggerTransient("OSD", 1500)
        onTriggerWorkspace: (c, t, n) => { triggerTransient("WORKSPACE", 800); Bridge.forceRaise() }
        onTriggerAlert: (icon, t, sub, ms, avatar) => {
            capsule.alertIcon = icon; capsule.alertTitle = t; capsule.alertSubtitle = sub; capsule.alertAvatar = avatar || ""
            triggerTransient("ALERT", ms > 0 ? ms : 5000)
        }
        onCallEnded: {
            if (capsule.isExpanded) capsule.startCollapse()
            capsule.alertIcon = "📞"; capsule.alertTitle = relay.callTitle || "Teams 通话"; capsule.alertSubtitle = "呼叫已完成"
            capsule.alertAvatar = ""; triggerTransient("ALERT", 1500)
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
        transientTimer.interval = ms; transientTimer.restart()
    }

    // 遮罩控制器
    IslandMaskController {
        id: maskController
        rootItem: root; capsuleItem: capsule; leftBubble: leftMusicBubble; rightBubble: rightTimerBubble; notifBubble: notifBubble
        isExpanded: capsule.isExpanded; isCollapsing: capsule.isCollapsing; isMorphing: capsule.isMorphing
        targetW: capsule.targetWidth; targetH: capsule.targetHeight
    }

    onHasMusicIslandChanged: maskController.commit()
    onHasTimerIslandChanged: maskController.commit()
    onHasNotifIslandChanged: maskController.commit()

    function expandToTab(tabName) {
        capsule.cancelCollapse()
        if (tabName !== "notification" && capsule.activeTransient === "ALERT") { transientTimer.stop(); capsule.activeTransient = "" }
        capsule.expandedTab = tabName; capsule.isExpanded = true; maskController.commit()
    }

    IslandCapsule {
        id: capsule
        chosenFont: root.chosenFont; enabledTabs: root.enabledTabs
        anySubBubbleHovered: leftMusicBubble.isHovered || rightTimerBubble.isHovered || notifBubble.isHovered
        status: relay.status; isCalling: relay.isCalling; callTitle: relay.callTitle; callSubtitle: relay.callSubtitle; callAvatar: relay.callAvatar
        title: relay.title; artist: relay.artist; artUrl: relay.artUrl; position: relay.position; duration: relay.duration
        wsCurrent: relay.wsCurrent; wsTotal: relay.wsTotal; wsName: relay.wsName; wsList: relay.wsList
        osdIcon: relay.osdIcon; osdValue: relay.osdValue
        displayDate: timeService.displayDate; displayTime: timeService.displayTime; displaySeconds: timeService.displaySeconds; displayPeriod: timeService.displayPeriod
        downCompact: relay.downSpeedCompact; upCompact: relay.upSpeedCompact; downSpeedStr: relay.downSpeedStr; upSpeedStr: relay.upSpeedStr; localIp: relay.localIp
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

    MusicBubbleView {
        id: leftMusicBubble; z: 1
        anchors.right: capsule.left; anchors.rightMargin: root.splitGap; anchors.verticalCenter: capsule.verticalCenter
        active: !capsule.isExpanded && !capsule.isCollapsing && root.hasMusicIsland
        onActiveChanged: maskController.commit()
        onClicked: root.expandToTab("media")
        onHoverActivated: root.expandToTab("media")
    }

    TimerBubbleView {
        id: rightTimerBubble; z: 1
        anchors.left: capsule.right; anchors.leftMargin: root.splitGap; anchors.verticalCenter: capsule.verticalCenter
        active: !capsule.isExpanded && !capsule.isCollapsing && root.hasTimerIsland
        onActiveChanged: maskController.commit()
        timerText: capsule.timerFormattedText; hasHours: capsule.timerHasHours; chosenFont: root.chosenFont
        isCountUp: capsule.timerIsCountUp; progress: capsule.timerProgress
        remainingSeconds: capsule.timerRemaining; totalSeconds: capsule.timerTotal
        onClicked: root.expandToTab("timer")
        onHoverActivated: root.expandToTab("timer")
    }

    NotificationBubbleView {
        id: notifBubble; z: 1
        anchors.verticalCenter: capsule.verticalCenter
        anchors.right: root.notifExpandsToLeft ? (root.hasMusicIsland ? leftMusicBubble.left : capsule.left) : undefined
        anchors.left: !root.notifExpandsToLeft ? (root.hasTimerIsland ? rightTimerBubble.right : capsule.right) : undefined
        anchors.rightMargin: root.notifExpandsToLeft ? root.splitGap : 0
        anchors.leftMargin: !root.notifExpandsToLeft ? root.splitGap : 0
        active: !capsule.isExpanded && !capsule.isCollapsing && root.hasNotifIsland
        onActiveChanged: maskController.commit()
        unreadCount: relay.unreadCount; avatarUrl: relay.latestNotifAvatar; chosenFont: root.chosenFont
        onClicked: root.expandToTab("notification")
        onRightClicked: root.expandToTab("notification")
        onHoverActivated: root.expandToTab("notification")
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
        capsule.expandedTab = relay.isCalling ? "media" : "workspace"
        startupMaskTimer.start()
    }
}