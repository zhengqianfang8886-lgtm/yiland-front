import QtQuick
import QtQuick.Controls
import QtQuick.Window

Item {
    id: root
    width: 720
    height: 270

    property bool isExpanded: false
    property bool animationReady: false
    property bool isCollapsing: false
    property bool isMorphing: false

    readonly property bool isMouseOverCapsule: (typeof capsuleHover !== "undefined" && capsuleHover.hovered) || (typeof capsuleMouseArea !== "undefined" && capsuleMouseArea.containsMouse)

    function expandToTab(tabName) {
        root.cancelCollapse()
        hoverDwellTimer.stop()
        leaveGraceTimer.stop()
        
        if (tabName !== "notification" && root.activeTransient === "ALERT") {
            transientTimer.stop()
            root.activeTransient = ""
        }

        root.expandedTab = tabName
        root.isExpanded = true
        root.safeCommitMask()
    }

    readonly property string chosenFont: (!Config.fontFamily || Config.fontFamily.indexOf("系统默认") !== -1) ? "" : Config.fontFamily

    property string title: "等待播放..."
    property string artist: "未知歌手"
    property string status: "Paused"
    property string artUrl: ""
    property real position: 0
    property real duration: 0

    property bool isCalling: false
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""

    property string activeTransient: ""
    property string osdIcon: "🔊"
    property int osdValue: 50
    property int wsCurrent: 1
    property int wsTotal: 4
    property string wsName: "Desktop 1"
    property var wsList: []

    property string alertIcon: "🔔"
    property string alertTitle: ""
    property string alertSubtitle: ""
    property string alertAvatar: ""

    property int unreadNotificationCount: 0
    property string latestNotifAvatar: ""

    property string downSpeedStr: "0.0 B/s"
    property string upSpeedStr: "0.0 B/s"
    property string downSpeedCompact: "0K"
    property string upSpeedCompact: "0K"
    property string localIp: "127.0.0.1"

    readonly property int splitGap: (typeof Config !== "undefined" && Config.splitGap !== undefined) ? Config.splitGap : 8

    readonly property bool hasMusicIsland: (root.status === "Playing") && (root.activeTransient === "")
    readonly property bool hasTimerIsland: expandedCardView.timerPageRef.isRunning && (root.activeTransient === "")
    readonly property bool hasNotifIsland: (root.unreadNotificationCount > 0) && (root.activeTransient === "")

    readonly property string expandDirection: (typeof Config !== "undefined" && Config.multiIslandExpandDirection) ? Config.multiIslandExpandDirection : "right"
    readonly property bool notifExpandsToLeft: (expandDirection === "left")
    readonly property bool isSplit: (root.hasMusicIsland || root.hasTimerIsland || root.hasNotifIsland) && !root.isExpanded

    onIsSplitChanged: safeCommitMask()
    onTargetWidthChanged: safeCommitMask()
    onTargetHeightChanged: safeCommitMask()
    onSplitGapChanged: safeCommitMask()
    onIsMorphingChanged: safeCommitMask()

    Timer {
        id: maskRetractTimer
        interval: 260
        onTriggered: root.safeCommitMask()
    }

    onHasMusicIslandChanged: if (hasMusicIsland) safeCommitMask(); else maskRetractTimer.restart()
    onHasTimerIslandChanged: if (hasTimerIsland) safeCommitMask(); else maskRetractTimer.restart()
    onHasNotifIslandChanged: if (hasNotifIsland) safeCommitMask(); else maskRetractTimer.restart()

    onIsCollapsingChanged: {
        if (!root.isCollapsing && !root.isExpanded) {
            root.safeCommitMask()
            Bridge.onIslandCollapsed()
        }
    }

    function safeCommitMask() {
        if (!root.animationReady) return

        // 🚀 核心优化：展开、变形、弹性过渡阶段使用全覆盖安全遮罩，杜绝动效期间切片
        if (root.isExpanded || root.isCollapsing || root.isMorphing || root.targetWidth > 300 || root.targetHeight > 100) {
            var fullW = 430 + 100, fullH = 240 + 40
            var pX = Math.max(0, Math.round((root.width - fullW) / 2) + Config.offsetX)
            Bridge.updateMask(pX, 0, Math.min(root.width, Math.round(fullW)), Math.round(fullH))
            return
        }

        var rectList = []
        // 🚀 预留 16px 缓冲区，从容包容 Easing.OutBack 的 1.15 倍弹性 overshoot
        var padX = 16
        var padY = 6

        var effectiveW = Math.max(capsule.width, root.targetWidth)
        var effectiveH = Math.max(capsule.height, root.targetHeight)
        var effectiveX = Math.round((root.width - effectiveW) / 2) + Config.offsetX

        rectList.push({
            x: Math.max(0, effectiveX - padX),
            y: Math.max(0, Math.round(capsule.y) - padY),
            w: Math.round(effectiveW) + padX * 2,
            h: Math.round(effectiveH) + padY * 2
        })

        if (leftMusicBubble.active) {
            rectList.push({
                x: Math.max(0, Math.round(leftMusicBubble.x) - padX),
                y: Math.max(0, Math.round(leftMusicBubble.y) - padY),
                w: Math.round(leftMusicBubble.width) + padX * 2,
                h: Math.round(leftMusicBubble.height) + padY * 2
            })
        }

        if (rightTimerBubble.active) {
            rectList.push({
                x: Math.max(0, Math.round(rightTimerBubble.x) - padX),
                y: Math.max(0, Math.round(rightTimerBubble.y) - padY),
                w: Math.round(rightTimerBubble.width) + padX * 2,
                h: Math.round(rightTimerBubble.height) + padY * 2
            })
        }

        if (notifBubble.active) {
            rectList.push({
                x: Math.max(0, Math.round(notifBubble.x) - padX),
                y: Math.max(0, Math.round(notifBubble.y) - padY),
                w: Math.round(notifBubble.width) + padX * 2,
                h: Math.round(notifBubble.height) + padY * 2
            })
        }

        Bridge.updateCompositeMask(rectList)
    }

    property string displayDate: ""
    property string displayTime: "04:53"
    property string displayPeriod: "pm"
    property string displaySeconds: ""

    readonly property var enabledTabs: {
        var list = []
        if (typeof Config !== "undefined" && Config.showWorkspaceTab) list.push({ key: "workspace", name: "桌面", color: Theme.workspace, activeColor: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.22) })
        if (Config.showMediaTab) list.push({ key: "media", name: "媒体", color: Theme.textPrimary, activeColor: Qt.rgba(1, 1, 1, 0.18) })
        if (Config.showCalendarTab) list.push({ key: "calendar", name: "日历", color: Theme.calendar, activeColor: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.22) })
        list.push({ key: "timer", name: "计时", color: Theme.timer, activeColor: Qt.rgba(Theme.timer.r, Theme.timer.g, Theme.timer.b, 0.22) })
        list.push({ key: "notification", name: "消息", color: Theme.notification, activeColor: Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.22) })
        if (typeof Config !== "undefined" && Config.showBluetoothTab) list.push({ key: "bluetooth", name: "蓝牙", color: Theme.bluetooth, activeColor: Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.22) })
        if (Config.showNetworkTab) list.push({ key: "network", name: "网络", color: Theme.network, activeColor: Qt.rgba(Theme.network.r, Theme.network.g, Theme.network.b, 0.22) })
        if (Config.showClockTab) list.push({ key: "clock", name: "时钟", color: Theme.clock, activeColor: Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.22) })
        return list
    }

    property string expandedTab: "workspace"
    SettingsWindow { id: settingsDialog }

    Timer { id: raiseTimer; interval: 160; onTriggered: Bridge.forceRaise() }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: updateDateTime() }

    function updateDateTime() {
        var d = new Date(), h = d.getHours(), m = d.getMinutes(), s = d.getSeconds()
        if (Config.showDate) {
            var days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            root.displayDate = (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1) + "/" + (d.getDate() < 10 ? "0" : "") + d.getDate() + " " + days[d.getDay()]
        } else { root.displayDate = "" }
        root.displaySeconds = Config.showSeconds ? (":" + (s < 10 ? "0" : "") + s) : ""
        if (Config.timeFormat === "24h") {
            root.displayTime = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
            root.displayPeriod = ""
        } else {
            root.displayPeriod = h >= 12 ? "pm" : "am"
            h = h % 12; h = h ? h : 12
            root.displayTime = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
        }
    }

    Timer { id: transientTimer; onTriggered: root.activeTransient = "" }
    function triggerTransient(mode, ms) {
        if (root.isExpanded) return
        root.activeTransient = mode
        transientTimer.interval = ms; transientTimer.restart()
    }

    onIsExpandedChanged: safeCommitMask()

    Connections {
        target: Bridge
        function onMediaUpdated(t, a, s, u, pos, dur) {
            root.title = t; root.artist = a; root.status = s; root.artUrl = u
            
            // 🚀 核心防护：只有在传入有效合法数值时才更新，防止暂停事件导致进度被 0 冲刷
            var newDur = (dur !== undefined && !isNaN(dur)) ? Number(dur) : 0
            if (newDur > 0) root.duration = newDur

            var newPos = (pos !== undefined && !isNaN(pos)) ? Number(pos) : -1
            if (newPos >= 0) {
                root.position = newPos
            }
        }
        function onProgressUpdated(pos, dur) {
            var d = (dur !== undefined && !isNaN(dur)) ? Number(dur) : root.duration
            if (d > 0) root.duration = d
            root.position = (pos !== undefined && !isNaN(pos)) ? Number(pos) : 0
        }
        function onOsdTriggered(icon, label, val) { root.osdIcon = icon; root.osdValue = val; root.triggerTransient("OSD", 1500) }
        function onWorkspaceTriggered(curr, tot, name) {
            root.wsCurrent = curr; root.wsTotal = tot; root.wsName = name
            root.triggerTransient("WORKSPACE", 800); Bridge.forceRaise(); raiseTimer.restart()
        }
        function onWorkspaceListUpdated(list) { root.wsList = list }
        function onAlertTriggered(icon, t, sub, ms, avatar) {
            if (icon === "📞" || ms <= 0) {
                root.isCalling = true; root.expandedTab = "media"; root.callTitle = t; root.callSubtitle = sub || "正在通话..."
                root.callAvatar = avatar || ""
            } else {
                root.alertIcon = icon; root.alertTitle = t; root.alertSubtitle = sub; root.alertAvatar = avatar || ""
                root.triggerTransient("ALERT", ms > 0 ? ms : 5000)
            }
        }
        function onCallEndedTriggered() {
            root.isCalling = false
            if (root.isExpanded) root.startCollapse()
            root.alertIcon = "📞"; root.alertTitle = root.callTitle || "Teams 通话"; root.alertSubtitle = "呼叫已完成"
            root.alertAvatar = ""; root.triggerTransient("ALERT", 1500)
        }
        function onNetSpeedUpdated(down, up, downComp, upComp, ip) {
            root.downSpeedStr = down; root.upSpeedStr = up; root.downSpeedCompact = downComp; root.upSpeedCompact = upComp
            if (ip) root.localIp = ip
        }
        function onUnreadCountChanged(cnt) {
            root.unreadNotificationCount = cnt
            if (typeof Bridge !== "undefined" && Bridge.getLatestNotificationAvatar) {
                root.latestNotifAvatar = Bridge.getLatestNotificationAvatar()
            }
        }
    }

    Timer {
        id: hoverDwellTimer
        interval: 180
        onTriggered: {
            if (!root.isCollapsing && root.isMouseOverCapsule && !root.isExpanded) {
                if (root.activeTransient === "ALERT") root.expandToTab("notification")
                else root.expandToTab("workspace")
            }
        }
    }

    Timer { id: leaveGraceTimer; interval: 280; onTriggered: { if (!root.isCalling && !root.isMouseOverCapsule) root.startCollapse() } }
    Timer {
        id: cooldownTimer; interval: 140
        onTriggered: {
            root.isCollapsing = false; root.safeCommitMask()
            if (root.isMouseOverCapsule && !root.isExpanded) hoverDwellTimer.restart()
        }
    }

    function cancelCollapse() { leaveGraceTimer.stop() }
    function requestCollapse() { if (!root.isCalling && root.isExpanded) leaveGraceTimer.restart() }
    function startCollapse() {
        if (!root.isExpanded) return
        root.isCollapsing = true; hoverDwellTimer.stop(); leaveGraceTimer.stop(); root.isExpanded = false
        if (root.activeTransient === "ALERT") root.activeTransient = ""
    }

    readonly property bool isLongAlert: {
        if (root.activeTransient !== "ALERT") return false
        var totalLen = (root.alertTitle || "").length + (root.alertSubtitle || "").length
        return totalLen > 18 || (root.alertSubtitle || "").indexOf("\n") !== -1
    }

    // 🚀 核心改进：加宽冗余度，保障字体较宽、秒数开启、工作区多桌面点显示完整无裁切
    readonly property int targetWidth: {
        if (root.isExpanded) return 430
        if (root.isCalling) return 250
        if (root.activeTransient === "ALERT") {
            var rawLen = (root.alertTitle || "").length + (root.alertSubtitle || "").length
            return rawLen > 30 ? 430 : (rawLen > 16 ? 400 : 360)
        }
        if (root.activeTransient === "WORKSPACE") return Math.max(148, compactCapsuleView.wsRowImplicitWidth + 48)
        if (root.activeTransient === "OSD") return 175
        return Math.max(124, compactCapsuleView.textRowImplicitWidth + 46)
    }

    readonly property int targetHeight: {
        if (root.isExpanded) return 240
        if (root.activeTransient === "ALERT") return root.isLongAlert ? 68 : 52
        return root.isCalling ? 38 : 36
    }

    Rectangle {
        id: capsule
        z: 2
        // 🚀 核心修复：固定留出 6px 上呼吸空隙，绝不贴死 y=0，保证顶部圆角与边框 100% 完整显示
        anchors.top: parent.top; anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Config.offsetX
        Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

        width: root.targetWidth; height: root.targetHeight
        radius: root.isExpanded ? 28 : (root.activeTransient === "ALERT" ? 26 : Math.min(height / 2, 27))
        clip: true; color: Theme.bgCapsule
        border.color: (root.activeTransient === "ALERT") ? Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.6) :
                      ((capsuleMouseArea.containsMouse || root.isExpanded) ? Theme.borderFocus : Theme.borderSubtle)
        border.width: root.activeTransient === "ALERT" ? 1.5 : 1

        Behavior on width {
            NumberAnimation {
                id: widthNumAnim; duration: root.isExpanded ? Theme.animSlow : Theme.animNormal
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                onRunningChanged: { root.isMorphing = running || heightNumAnim.running; if (!running) { root.safeCommitMask(); if (!root.isExpanded) cooldownTimer.restart() } }
            }
        }
        Behavior on height {
            NumberAnimation {
                id: heightNumAnim; duration: root.isExpanded ? Theme.animSlow : Theme.animNormal
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                onRunningChanged: { root.isMorphing = running || widthNumAnim.running; if (!running) root.safeCommitMask() }
            }
        }
        Behavior on radius { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: capsuleHover
            onHoveredChanged: {
                if (hovered) {
                    root.cancelCollapse()
                    if (!root.isExpanded && !root.isCollapsing) hoverDwellTimer.restart()
                } else {
                    hoverDwellTimer.stop()
                    root.requestCollapse()
                }
            }
        }

        MouseArea {
            id: capsuleMouseArea
            anchors.fill: parent; hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onEntered: { root.cancelCollapse(); if (!root.isExpanded && !root.isCollapsing) hoverDwellTimer.restart() }
            onExited: { hoverDwellTimer.stop(); root.requestCollapse() }
            onWheel: (wheel) => {
                if (!root.isExpanded || root.expandedTab === "workspace") {
                    if (typeof Bridge !== "undefined") {
                        if (wheel.angleDelta.y > 0) Bridge.switchWorkspacePrev()
                        else if (wheel.angleDelta.y < 0) Bridge.switchWorkspaceNext()
                    }
                }
            }
            onClicked: (mouse) => {
                hoverDwellTimer.stop()
                leaveGraceTimer.stop()

                if (mouse.button === Qt.RightButton) {
                    settingsDialog.show(); settingsDialog.raise(); settingsDialog.requestActivate()
                    return
                }
                if (root.isCalling) {
                    Bridge.focusTeamsWindow()
                    return
                }
                if (root.activeTransient === "ALERT") {
                    root.expandToTab("notification")
                    return
                }
                root.expandToTab("workspace")
            }
        }

        CompactCapsuleView {
            id: compactCapsuleView
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            opacity: root.isExpanded ? 0 : 1; visible: opacity > 0.01
            showNetSpeed: Config.showNetSpeed; chosenFont: root.chosenFont; activeTransient: root.activeTransient
            status: root.status; isCalling: root.isCalling; isExpanded: root.isExpanded; isCollapsing: root.isCollapsing
            wsName: root.wsName; wsCurrent: root.wsCurrent; wsTotal: root.wsTotal
            osdIcon: root.osdIcon; osdValue: root.osdValue
            alertTitle: root.alertTitle; alertSubtitle: root.alertSubtitle; alertAvatar: root.alertAvatar; alertIcon: root.alertIcon
            callTitle: root.callTitle; callSubtitle: root.callSubtitle; callAvatar: root.callAvatar
            displayDate: root.displayDate; displayTime: root.displayTime; displaySeconds: root.displaySeconds; displayPeriod: root.displayPeriod
            downCompact: root.downSpeedCompact; upCompact: root.upSpeedCompact
            Behavior on opacity { NumberAnimation { duration: root.isExpanded ? Theme.animInstant : Theme.animNormal; easing.type: Easing.OutQuad } }
        }

        ExpandedCardView {
            id: expandedCardView
            width: 398; height: 208
            anchors.top: parent.top; anchors.topMargin: 16; anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.isExpanded ? 1 : 0; scale: root.isExpanded ? 1.0 : 0.96; visible: opacity > 0.01
            chosenFont: root.chosenFont
            
            expandedTab: root.expandedTab
            enabledTabs: root.enabledTabs
            
            isCalling: root.isCalling; callTitle: root.callTitle; callSubtitle: root.callSubtitle; callAvatar: root.callAvatar
            title: root.title; artist: root.artist; status: root.status; artUrl: root.artUrl; position: root.position; duration: root.duration
            wsCurrent: root.wsCurrent; wsTotal: root.wsTotal; wsName: root.wsName; wsList: root.wsList
            downSpeedStr: root.downSpeedStr; upSpeedStr: root.upSpeedStr; localIp: root.localIp; activeTransient: root.activeTransient

            onCancelCollapse: root.cancelCollapse()
            onRequestCollapse: root.requestCollapse()
            onStartCollapse: root.startCollapse()
            onTimerCompleted: (t, msg) => {
                root.alertIcon = "⏰"; root.alertTitle = t; root.alertSubtitle = msg; root.triggerTransient("ALERT", 6000); Bridge.forceRaise()
            }
            onTabSelected: (key) => {
                root.expandedTab = key
            }

            Behavior on opacity { NumberAnimation { duration: root.isExpanded ? Theme.animSlow : Theme.animInstant; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: root.isExpanded ? Theme.animSlow : Theme.animFast; easing.type: Easing.OutCubic } }
        }
    }

    // ==========================================
    // 相对锚定多副岛
    // ==========================================

    MusicBubbleView {
        id: leftMusicBubble; z: 1
        anchors.right: capsule.left; anchors.rightMargin: root.splitGap; anchors.verticalCenter: capsule.verticalCenter
        active: !root.isExpanded && !root.isCollapsing && root.hasMusicIsland
        onActiveChanged: root.safeCommitMask()
        onClicked: root.expandToTab("media")
    }

    TimerBubbleView {
        id: rightTimerBubble; z: 1
        anchors.left: capsule.right; anchors.leftMargin: root.splitGap; anchors.verticalCenter: capsule.verticalCenter
        active: !root.isExpanded && !root.isCollapsing && root.hasTimerIsland
        onActiveChanged: root.safeCommitMask()
        timerText: expandedCardView.timerPageRef.formattedTime
        hasHours: expandedCardView.timerPageRef.hasHours
        chosenFont: root.chosenFont
        isCountUp: expandedCardView.timerPageRef.isCountUp
        progress: expandedCardView.timerPageRef.progress
        remainingSeconds: expandedCardView.timerPageRef.remainingSeconds
        totalSeconds: expandedCardView.timerPageRef.totalSeconds
        onClicked: root.expandToTab("timer")
    }

    NotificationBubbleView {
        id: notifBubble; z: 1
        anchors.verticalCenter: capsule.verticalCenter
        anchors.right: root.notifExpandsToLeft ? (root.hasMusicIsland ? leftMusicBubble.left : capsule.left) : undefined
        anchors.left: !root.notifExpandsToLeft ? (root.hasTimerIsland ? rightTimerBubble.right : capsule.right) : undefined
        anchors.rightMargin: root.notifExpandsToLeft ? root.splitGap : 0
        anchors.leftMargin: !root.notifExpandsToLeft ? root.splitGap : 0
        active: !root.isExpanded && !root.isCollapsing && root.hasNotifIsland
        onActiveChanged: root.safeCommitMask()
        unreadCount: root.unreadNotificationCount; avatarUrl: root.latestNotifAvatar; chosenFont: root.chosenFont

        onClicked: root.expandToTab("notification")
        onRightClicked: root.expandToTab("notification")
    }

    Component.onCompleted: {
        root.animationReady = true; root.updateDateTime(); root.safeCommitMask()
        if (root.isCalling) root.expandedTab = "media"
        else root.expandedTab = "workspace"
    }
}