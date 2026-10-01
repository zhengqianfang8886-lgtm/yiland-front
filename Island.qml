import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Item {
    id: root
    width: 720
    height: 270

    property bool isExpanded: false
    property bool animationReady: false
    property bool isCollapsing: false
    property bool isMorphing: false

    readonly property bool isMouseOverCapsule: (typeof capsuleHover !== "undefined" && capsuleHover.hovered) || (typeof capsuleMouseArea !== "undefined" && capsuleMouseArea.containsMouse)

    function handleCapsuleHoverEnter() {
        root.cancelCollapse()
        if (!root.isExpanded && !root.isCollapsing) hoverDwellTimer.restart()
    }
    function handleCapsuleHoverLeave() {
        hoverDwellTimer.stop(); root.requestCollapse()
    }

    readonly property string chosenFont: (!Config.fontFamily || Config.fontFamily.indexOf("系统默认") !== -1) ? "" : Config.fontFamily

    // 数据状态
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

    // 多岛激活状态
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

    // 气泡消失缓冲保护定时器
    Timer {
        id: maskRetractTimer
        interval: 260
        onTriggered: root.safeCommitMask()
    }

    onHasMusicIslandChanged: {
        if (hasMusicIsland) safeCommitMask()
        else maskRetractTimer.restart()
    }
    onHasTimerIslandChanged: {
        if (hasTimerIsland) safeCommitMask()
        else maskRetractTimer.restart()
    }
    onHasNotifIslandChanged: {
        if (hasNotifIsland) safeCommitMask()
        else maskRetractTimer.restart()
    }

    onIsCollapsingChanged: {
        if (!root.isCollapsing && !root.isExpanded) safeCommitMask()
    }

    // 穿透遮罩计算
    function safeCommitMask() {
        if (!root.animationReady) return

        if (root.isExpanded || root.isCollapsing || root.isMorphing || root.targetWidth > 300 || root.targetHeight > 100) {
            var fullW = 430 + 80, fullH = 240 + 32
            var pX = Math.max(0, Math.round((root.width - fullW) / 2) + Config.offsetX)
            Bridge.updateMask(pX, Math.max(0, Math.round(Config.topMargin)), Math.min(root.width, Math.round(fullW)), Math.round(fullH))
            return
        }

        var cx = Math.round(root.width / 2) + Config.offsetX
        var halfCapW = Math.round(root.targetWidth / 2)

        var leftBubbleActive = root.hasMusicIsland || maskRetractTimer.running
        var leftExtra = (leftBubbleActive ? (48 + root.splitGap) : 0) + ((root.notifExpandsToLeft && (root.hasNotifIsland || maskRetractTimer.running)) ? (48 + root.splitGap) : 0)
        
        var rightBubbleActive = root.hasTimerIsland || maskRetractTimer.running
        var rightExtra = (rightBubbleActive ? (rightTimerBubble ? rightTimerBubble.width : 84) + root.splitGap : 0) + ((!root.notifExpandsToLeft && (root.hasNotifIsland || maskRetractTimer.running)) ? (48 + root.splitGap) : 0)

        var minX = Math.max(0, (cx - halfCapW - leftExtra) - 20)
        var maxX = Math.min(root.width, (cx + halfCapW + rightExtra) + 20)
        Bridge.updateMask(minX, Math.max(0, Math.round(Config.topMargin)), Math.round(maxX - minX), Math.round(root.targetHeight + 16))
    }

    property string displayDate: ""
    property string displayTime: "04:53"
    property string displayPeriod: "pm"
    property string displaySeconds: ""

    readonly property var enabledTabs: {
        var list = []
        if (Config.showMediaTab) list.push({ key: "media", name: "媒体", color: "#ffffff", activeColor: Qt.rgba(1, 1, 1, 0.18) })
        if (Config.showCalendarTab) list.push({ key: "calendar", name: "日历", color: "#38bdf8", activeColor: Qt.rgba(56, 189, 248, 0.22) })
        if (typeof Config !== "undefined" && Config.showWorkspaceTab) list.push({ key: "workspace", name: "桌面", color: "#a855f7", activeColor: Qt.rgba(168, 85, 247, 0.22) })
        list.push({ key: "timer", name: "计时", color: "#f97316", activeColor: Qt.rgba(249, 115, 22, 0.22) })
        list.push({ key: "notification", name: "消息", color: "#818cf8", activeColor: Qt.rgba(129, 140, 248, 0.22) })
        if (typeof Config !== "undefined" && Config.showBluetoothTab) list.push({ key: "bluetooth", name: "蓝牙", color: "#60a5fa", activeColor: Qt.rgba(96, 165, 250, 0.22) })
        if (Config.showNetworkTab) list.push({ key: "network", name: "网络", color: "#34d399", activeColor: Qt.rgba(52, 211, 153, 0.22) })
        if (Config.showClockTab) list.push({ key: "clock", name: "时钟", color: "#f59e0b", activeColor: Qt.rgba(245, 158, 11, 0.22) })
        return list
    }

    property string expandedTab: "calendar"
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

    onIsExpandedChanged: {
        if (isExpanded && activeTransient === "ALERT") transientTimer.stop()
        safeCommitMask()
    }

    Connections {
        target: Bridge
        function onMediaUpdated(t, a, s, u, pos, dur) {
            var wasPlaying = (root.status === "Playing")
            root.title = t; root.artist = a; root.status = s; root.artUrl = u
            root.duration = (dur !== undefined && !isNaN(dur)) ? Number(dur) : 0
            root.position = (pos !== undefined && !isNaN(pos)) ? Number(pos) : 0
            if (!wasPlaying && s === "Playing" && Config.showMediaTab) root.expandedTab = "media"
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

    Timer { id: hoverDwellTimer; interval: 180; onTriggered: { if (!root.isCollapsing && root.isMouseOverCapsule && !root.isExpanded) root.isExpanded = true } }
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

    readonly property int targetWidth: {
        if (root.isExpanded) return 430
        if (root.isCalling) return 250
        if (root.activeTransient === "ALERT") {
            var rawLen = (root.alertTitle || "").length + (root.alertSubtitle || "").length
            return rawLen > 30 ? 430 : (rawLen > 16 ? 400 : 360)
        }
        if (root.activeTransient === "WORKSPACE") return Math.max(130, compactCapsuleView.wsRowImplicitWidth + 32)
        if (root.activeTransient === "OSD") return 175
        return compactCapsuleView.textRowImplicitWidth + 36
    }

    readonly property int targetHeight: {
        if (root.isExpanded) return 240
        if (root.activeTransient === "ALERT") return root.isLongAlert ? 68 : 52
        return root.isCalling ? 38 : 36
    }

    // ========================================================
    // 胶囊主舞台
    // ========================================================
    Rectangle {
        id: capsule
        z: 2
        anchors.top: parent.top; anchors.topMargin: Config.topMargin
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Config.offsetX
        Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        width: root.targetWidth; height: root.targetHeight
        radius: root.isExpanded ? 28 : (root.activeTransient === "ALERT" ? 26 : Math.min(height / 2, 27))
        clip: true; color: Qt.rgba(0.08, 0.08, 0.1, 0.96)
        border.color: (root.activeTransient === "ALERT") ? Qt.rgba(129, 140, 248, 0.6) : ((capsuleMouseArea.containsMouse || root.isExpanded) ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.14))
        border.width: root.activeTransient === "ALERT" ? 1.5 : 1

        Behavior on width {
            NumberAnimation {
                id: widthNumAnim; duration: root.isExpanded ? 300 : 220
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                onRunningChanged: { root.isMorphing = running || heightNumAnim.running; if (!running) { root.safeCommitMask(); if (!root.isExpanded) cooldownTimer.restart() } }
            }
        }
        Behavior on height {
            NumberAnimation {
                id: heightNumAnim; duration: root.isExpanded ? 300 : 220
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                onRunningChanged: { root.isMorphing = running || widthNumAnim.running; if (!running) root.safeCommitMask() }
            }
        }
        Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        HoverHandler { id: capsuleHover; onHoveredChanged: hovered ? root.cancelCollapse() : root.requestCollapse() }

        MouseArea {
            id: capsuleMouseArea; anchors.fill: parent; hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: (root.isCalling || root.activeTransient === "ALERT") ? Qt.PointingHandCursor : Qt.ArrowCursor
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
                hoverDwellTimer.stop(); leaveGraceTimer.stop()
                if (mouse.button === Qt.RightButton) {
                    settingsDialog.show(); settingsDialog.raise(); settingsDialog.requestActivate()
                } else {
                    if (root.isCalling || (root.activeTransient === "ALERT" && !root.isExpanded)) {
                        Bridge.focusTeamsWindow(); if (root.activeTransient === "ALERT") root.activeTransient = ""; return
                    }
                    if (!root.isExpanded) root.isExpanded = true
                }
            }
        }

        // 常态紧凑视图
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
            Behavior on opacity { NumberAnimation { duration: root.isExpanded ? 100 : 180; easing.type: Easing.OutQuad } }
        }

        // 展开态大卡片视图
        ExpandedCardView {
            id: expandedCardView
            width: 398; height: 208
            anchors.top: parent.top; anchors.topMargin: 16; anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.isExpanded ? 1 : 0; scale: root.isExpanded ? 1.0 : 0.96; visible: opacity > 0.01
            chosenFont: root.chosenFont; expandedTab: root.expandedTab; enabledTabs: root.enabledTabs
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
            
            // 🚀 核心修复：使用 Qt 6 标准信号挂钩，消除属性不存在报错
            onTabSelected: (key) => {
                root.expandedTab = key
            }

            Behavior on opacity { NumberAnimation { duration: root.isExpanded ? 240 : 100; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: root.isExpanded ? 280 : 140; easing.type: Easing.OutCubic } }
        }
    }

    // ========================================================
    // 相对锚定多副岛
    // ========================================================
    MusicBubbleView {
        id: leftMusicBubble; z: 1
        anchors.right: capsule.left; anchors.rightMargin: root.splitGap; anchors.verticalCenter: capsule.verticalCenter
        active: !root.isExpanded && !root.isCollapsing && !root.isMorphing && root.hasMusicIsland
        onClicked: { root.isExpanded = true; root.expandedTab = "media" }
    }

    TimerBubbleView {
        id: rightTimerBubble; z: 1
        anchors.left: capsule.right; anchors.leftMargin: root.splitGap; anchors.verticalCenter: capsule.verticalCenter
        active: !root.isExpanded && !root.isCollapsing && !root.isMorphing && root.hasTimerIsland
        timerText: expandedCardView.timerPageRef.formattedTime
        hasHours: expandedCardView.timerPageRef.hasHours
        chosenFont: root.chosenFont
        isCountUp: expandedCardView.timerPageRef.isCountUp
        progress: expandedCardView.timerPageRef.progress
        remainingSeconds: expandedCardView.timerPageRef.remainingSeconds
        totalSeconds: expandedCardView.timerPageRef.totalSeconds
        onClicked: { root.isExpanded = true; root.expandedTab = "timer" }
    }

    NotificationBubbleView {
        id: notifBubble; z: 1
        anchors.verticalCenter: capsule.verticalCenter
        anchors.right: root.notifExpandsToLeft ? (root.hasMusicIsland ? leftMusicBubble.left : capsule.left) : undefined
        anchors.left: !root.notifExpandsToLeft ? (root.hasTimerIsland ? rightTimerBubble.right : capsule.right) : undefined
        anchors.rightMargin: root.notifExpandsToLeft ? root.splitGap : 0
        anchors.leftMargin: !root.notifExpandsToLeft ? root.splitGap : 0
        active: !root.isExpanded && !root.isCollapsing && !root.isMorphing && root.hasNotifIsland
        unreadCount: root.unreadNotificationCount; avatarUrl: root.latestNotifAvatar; chosenFont: root.chosenFont
        onClicked: { Bridge.focusTeamsWindow(); Bridge.markAllNotificationsRead() }
        onRightClicked: { root.isExpanded = true; root.expandedTab = "notification" }
    }

    Component.onCompleted: {
        root.animationReady = true; root.updateDateTime(); root.safeCommitMask()
        if (root.status === "Playing" || root.isCalling) root.expandedTab = "media"
        else root.expandedTab = "calendar"
    }
}