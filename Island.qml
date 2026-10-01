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
    property string alertIcon: "🔔"
    property string alertTitle: ""
    property string alertSubtitle: ""
    property string alertAvatar: ""

    // 未读消息数据
    property int unreadNotificationCount: 0
    property string latestNotifAvatar: ""

    // 网速状态
    property string downSpeedStr: "0.0 B/s"
    property string upSpeedStr: "0.0 B/s"
    property string downSpeedCompact: "0K"
    property string upSpeedCompact: "0K"
    property string localIp: "127.0.0.1"

    readonly property int splitGap: (typeof Config !== "undefined" && Config.splitGap !== undefined) ? Config.splitGap : 8

    // 多岛激活状态
    readonly property bool hasMusicIsland: (root.status === "Playing") && (root.activeTransient === "")
    readonly property bool hasTimerIsland: timerPage.isRunning && (root.activeTransient === "")
    readonly property bool hasNotifIsland: (root.unreadNotificationCount > 0) && (root.activeTransient === "")

    // 扩展方向：向左还是向右
    readonly property string expandDirection: (typeof Config !== "undefined" && Config.multiIslandExpandDirection) ? Config.multiIslandExpandDirection : "right"
    readonly property bool notifExpandsToLeft: (expandDirection === "left")

    readonly property bool isSplit: (root.hasMusicIsland || root.hasTimerIsland || root.hasNotifIsland) && !root.isExpanded

    onIsSplitChanged: safeCommitMask()
    onTargetWidthChanged: safeCommitMask()
    onTargetHeightChanged: safeCommitMask()
    onHasMusicIslandChanged: safeCommitMask()
    onHasTimerIslandChanged: safeCommitMask()
    onHasNotifIslandChanged: safeCommitMask()
    onSplitGapChanged: safeCommitMask()

    onIsCollapsingChanged: {
        if (!root.isCollapsing && !root.isExpanded) {
            safeCommitMask()
        }
    }

    // ========================================================
    // 确定性安全遮罩（与副岛真实物理尺寸无缝对齐）
    // ========================================================
    function safeCommitMask() {
        if (!root.animationReady) return

        if (root.isExpanded || root.isCollapsing || root.isMorphing || root.targetWidth > 300 || root.targetHeight > 100) {
            var fullW = 430 + 80
            var fullH = 240 + 32
            var pX = Math.max(0, Math.round((root.width - fullW) / 2) + Config.offsetX)
            var pY = Math.max(0, Math.round(Config.topMargin))
            Bridge.updateMask(pX, pY, Math.min(root.width, Math.round(fullW)), Math.round(fullH))
            return
        }

        var cx = Math.round(root.width / 2) + Config.offsetX
        var halfCapW = Math.round(root.targetWidth / 2)

        var leftExtra = 0
        if (root.hasMusicIsland) leftExtra += (48 + root.splitGap)
        if (root.notifExpandsToLeft && root.hasNotifIsland) leftExtra += (48 + root.splitGap)

        var rightExtra = 0
        // 动态读取右侧倒计时副岛的实际宽度，绝不硬编码
        if (root.hasTimerIsland) rightExtra += (rightTimerBubble ? rightTimerBubble.width : 84) + root.splitGap
        if (!root.notifExpandsToLeft && root.hasNotifIsland) rightExtra += (48 + root.splitGap)

        var minX = Math.max(0, (cx - halfCapW - leftExtra) - 20)
        var maxX = Math.min(root.width, (cx + halfCapW + rightExtra) + 20)
        var safeW = Math.round(maxX - minX)
        var safeH = Math.round(root.targetHeight + 16)

        Bridge.updateMask(minX, Math.max(0, Math.round(Config.topMargin)), safeW, safeH)
    }

    property string displayDate: ""
    property string displayTime: "04:53"
    property string displayPeriod: "pm"
    property string displaySeconds: ""

    readonly property var enabledTabs: {
        var list = []
        if (Config.showMediaTab) list.push({ key: "media", name: "媒体", color: "#ffffff", activeColor: Qt.rgba(1, 1, 1, 0.18) })
        if (Config.showCalendarTab) list.push({ key: "calendar", name: "日历", color: "#38bdf8", activeColor: Qt.rgba(56, 189, 248, 0.22) })
        list.push({ key: "timer", name: "计时", color: "#f97316", activeColor: Qt.rgba(249, 115, 22, 0.22) })
        list.push({ key: "notification", name: "消息", color: "#818cf8", activeColor: Qt.rgba(129, 140, 248, 0.22) })
        if (typeof Config !== "undefined" && Config.showBluetoothTab) list.push({ key: "bluetooth", name: "蓝牙", color: "#60a5fa", activeColor: Qt.rgba(96, 165, 250, 0.22) })
        if (Config.showNetworkTab) list.push({ key: "network", name: "网络", color: "#34d399", activeColor: Qt.rgba(52, 211, 153, 0.22) })
        if (Config.showClockTab) list.push({ key: "clock", name: "时钟", color: "#f59e0b", activeColor: Qt.rgba(245, 158, 11, 0.22) })
        return list
    }

    property string expandedTab: "calendar"

    onEnabledTabsChanged: {
        var exists = false
        for (var i = 0; i < enabledTabs.length; i++) {
            if (enabledTabs[i].key === root.expandedTab) { exists = true; break }
        }
        if (!exists && enabledTabs.length > 0) root.expandedTab = enabledTabs[0].key
    }

    SettingsWindow { id: settingsDialog }

    Timer { id: raiseTimer; interval: 160; onTriggered: Bridge.forceRaise() }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: updateDateTime() }

    Connections {
        target: Config
        function onTimeFormatChanged() { root.updateDateTime() }
        function onShowSecondsChanged() { root.updateDateTime() }
        function onShowDateChanged() { root.updateDateTime() }
        function onShowNetSpeedChanged() { root.safeCommitMask() }
        function onTopMarginChanged() { root.safeCommitMask() }
        function onOffsetXChanged() { root.safeCommitMask() }
        function onSplitGapChanged() { root.safeCommitMask() }
    }

    function updateDateTime() {
        var d = new Date()
        var h = d.getHours(), m = d.getMinutes(), s = d.getSeconds()
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
            root.downSpeedStr = down; root.upSpeedStr = up
            root.downSpeedCompact = downComp; root.upSpeedCompact = upComp
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
        id: cooldownTimer
        interval: 140
        onTriggered: {
            root.isCollapsing = false
            root.safeCommitMask()
            if (root.isMouseOverCapsule && !root.isExpanded) hoverDwellTimer.restart()
        }
    }

    function cancelCollapse() { leaveGraceTimer.stop() }
    function requestCollapse() { if (!root.isCalling && root.isExpanded) leaveGraceTimer.restart() }
    function startCollapse() {
        if (!root.isExpanded) return
        root.isCollapsing = true; hoverDwellTimer.stop(); leaveGraceTimer.stop()
        root.isExpanded = false
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
            if (rawLen > 30) return 430
            if (rawLen > 16) return 400
            return 360
        }
        if (root.activeTransient === "WORKSPACE") {
            var wsW = compactCapsuleView.wsRowImplicitWidth
            return Math.max(130, wsW + 32)
        }
        if (root.activeTransient === "OSD") return 175
        return compactCapsuleView.textRowImplicitWidth + 36
    }

    readonly property int targetHeight: {
        if (root.isExpanded) return 240
        if (root.activeTransient === "ALERT") return root.isLongAlert ? 68 : 52
        if (root.isCalling) return 38
        return 36
    }

    // 主胶囊容器
    Rectangle {
        id: capsule
        z: 2
        anchors.top: parent.top; anchors.topMargin: Config.topMargin
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Config.offsetX
        Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        width: root.targetWidth; height: root.targetHeight
        radius: root.isExpanded ? 28 : (root.activeTransient === "ALERT" ? 26 : Math.min(height / 2, 27))
        clip: true
        color: Qt.rgba(0.08, 0.08, 0.1, 0.96)

        border.color: {
            if (root.activeTransient === "ALERT") return Qt.rgba(129, 140, 248, 0.6)
            if (capsuleMouseArea.containsMouse || root.isExpanded) return Qt.rgba(1, 1, 1, 0.24)
            return Qt.rgba(1, 1, 1, 0.14)
        }
        border.width: root.activeTransient === "ALERT" ? 1.5 : 1
        Behavior on border.color { ColorAnimation { duration: 180 } }

        Behavior on width {
            enabled: root.animationReady
            NumberAnimation {
                id: widthNumAnim
                duration: root.isExpanded ? 300 : 220
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: root.isExpanded ? 1.06 : 1.0
                onRunningChanged: {
                    root.isMorphing = running || heightNumAnim.running
                    if (!running) {
                        root.safeCommitMask()
                        if (!root.isExpanded) cooldownTimer.restart()
                    }
                }
            }
        }

        Behavior on height {
            enabled: root.animationReady
            NumberAnimation {
                id: heightNumAnim
                duration: root.isExpanded ? 300 : 220
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: root.isExpanded ? 1.06 : 1.0
                onRunningChanged: {
                    root.isMorphing = running || widthNumAnim.running
                    if (!running) root.safeCommitMask()
                }
            }
        }

        Behavior on radius { enabled: root.animationReady; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        HoverHandler { id: capsuleHover; onHoveredChanged: hovered ? root.cancelCollapse() : root.requestCollapse() }

        MouseArea {
            id: capsuleMouseArea
            anchors.fill: parent; hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: (root.isCalling || root.activeTransient === "ALERT") ? Qt.PointingHandCursor : Qt.ArrowCursor
            onEntered: { root.cancelCollapse(); if (!root.isExpanded && !root.isCollapsing) hoverDwellTimer.restart() }
            onExited: { hoverDwellTimer.stop(); root.requestCollapse() }

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

        CompactCapsuleView {
            id: compactCapsuleView
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            opacity: root.isExpanded ? 0 : 1; visible: opacity > 0.01

            showNetSpeed: Config.showNetSpeed
            chosenFont: root.chosenFont; activeTransient: root.activeTransient
            status: root.status; isCalling: root.isCalling
            isExpanded: root.isExpanded; isCollapsing: root.isCollapsing

            wsName: root.wsName; wsCurrent: root.wsCurrent; wsTotal: root.wsTotal
            osdIcon: root.osdIcon; osdValue: root.osdValue
            alertTitle: root.alertTitle; alertSubtitle: root.alertSubtitle; alertAvatar: root.alertAvatar; alertIcon: root.alertIcon
            callTitle: root.callTitle; callSubtitle: root.callSubtitle; callAvatar: root.callAvatar

            displayDate: root.displayDate; displayTime: root.displayTime
            displaySeconds: root.displaySeconds; displayPeriod: root.displayPeriod
            downCompact: root.downSpeedCompact; upCompact: root.upSpeedCompact

            Behavior on opacity {
                NumberAnimation { duration: root.isExpanded ? 100 : 180; easing.type: Easing.OutQuad }
            }
        }

        Item {
            id: expandedView
            width: 398
            height: 208
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter

            opacity: root.isExpanded ? 1 : 0
            scale: root.isExpanded ? 1.0 : 0.96
            visible: opacity > 0.01

            Behavior on opacity { NumberAnimation { duration: root.isExpanded ? 240 : 100; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: root.isExpanded ? 280 : 140; easing.type: Easing.OutCubic } }

            Column {
                anchors.fill: parent; spacing: 12

                Item {
                    width: parent.width; height: 26

                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: root.isCalling ? "● INCOMING CALL" : 
                              (root.activeTransient === "ALERT" ? "● NOTIFICATION" : 
                              (root.expandedTab === "notification" ? "● NOTIFICATION CENTER" :
                              (root.expandedTab === "calendar" ? "● CALENDAR" : 
                              (root.expandedTab === "timer" ? (timerPage.isCountUp ? "● STOPWATCH" : "● FOCUS TIMER") : 
                              (root.expandedTab === "bluetooth" ? "● BLUETOOTH DEVICES" :
                              (root.expandedTab === "network" ? "● NETWORK TRAFFIC" :
                              (root.expandedTab === "clock" ? "● WORLD CLOCK" : 
                              (root.status === "Playing" ? "● NOW PLAYING" : "⏸ PAUSED"))))))))

                        color: root.isCalling ? "#22c55e" : 
                               (root.activeTransient === "ALERT" ? "#818cf8" : 
                               (root.expandedTab === "notification" ? "#818cf8" :
                               (root.expandedTab === "calendar" ? "#38bdf8" : 
                               (root.expandedTab === "timer" ? timerPage.accentColor : 
                               (root.expandedTab === "bluetooth" ? "#60a5fa" :
                               (root.expandedTab === "network" ? "#34d399" :
                               (root.expandedTab === "clock" ? "#f59e0b" : 
                               (root.status === "Playing" ? Qt.rgba(0.2, 0.85, 0.5, 0.9) : Qt.rgba(1, 1, 1, 0.4)))))))))
                        font.family: root.chosenFont; font.pixelSize: 10; font.weight: Font.Black; font.letterSpacing: 0.8
                    }

                    Rectangle {
                        id: tabSliderContainer
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.enabledTabs.length * 48
                        height: 24; radius: 12; color: Qt.rgba(1, 1, 1, 0.08)
                        visible: !root.isCalling && root.activeTransient !== "ALERT" && root.enabledTabs.length > 1

                        readonly property int activeTabIndex: {
                            for (var i = 0; i < root.enabledTabs.length; i++) {
                                if (root.enabledTabs[i].key === root.expandedTab) return i
                            }
                            return 0
                        }

                        Rectangle {
                            z: 0; y: 2
                            x: tabSliderContainer.activeTabIndex * 48 + 2
                            width: 44; height: 20; radius: 10
                            color: {
                                var curr = root.enabledTabs[tabSliderContainer.activeTabIndex]
                                return curr ? curr.activeColor : Qt.rgba(1, 1, 1, 0.18)
                            }
                            border.color: {
                                var curr = root.enabledTabs[tabSliderContainer.activeTabIndex]
                                return curr ? curr.color : Qt.rgba(1, 1, 1, 0.3)
                            }
                            border.width: 1
                            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }

                        Row {
                            z: 1; anchors.fill: parent
                            Repeater {
                                model: root.enabledTabs
                                Item {
                                    width: 48; height: parent.height
                                    readonly property bool isCurrent: root.expandedTab === modelData.key
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.name
                                        color: isCurrent ? (modelData.key === "media" ? "#ffffff" : modelData.color) : Qt.rgba(1, 1, 1, 0.45)
                                        font.pixelSize: 11; font.family: root.chosenFont; font.weight: isCurrent ? Font.Black : Font.Bold
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.expandedTab = modelData.key
                                            if (modelData.key === "calendar") calendarPage.resetToToday()
                                            if (modelData.key === "bluetooth") bluetoothPage.refresh()
                                            if (modelData.key === "notification") notifCenterPage.refresh()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    width: parent.width; height: parent.height - 38

                    CalendarPage {
                        id: calendarPage; anchors.fill: parent; chosenFont: root.chosenFont
                        opacity: (Config.showCalendarTab && root.expandedTab === "calendar" && !root.isCalling && root.activeTransient !== "ALERT") ? 1.0 : 0.0
                        visible: opacity > 0.01
                    }

                    MediaPage {
                        id: mediaPage; anchors.fill: parent; chosenFont: root.chosenFont
                        isCalling: root.isCalling; callTitle: root.callTitle; callSubtitle: root.callSubtitle; callAvatar: root.callAvatar
                        title: root.title; artist: root.artist; status: root.status; artUrl: root.artUrl
                        position: root.position; duration: root.duration
                        onCancelCollapse: root.cancelCollapse(); onRequestCollapse: root.requestCollapse(); onStartCollapse: root.startCollapse()
                        opacity: (Config.showMediaTab && (root.expandedTab === "media" || root.isCalling) && root.activeTransient !== "ALERT") ? 1.0 : 0.0
                        visible: opacity > 0.01
                    }

                    TimerPage {
                        id: timerPage; anchors.fill: parent; chosenFont: root.chosenFont
                        opacity: (root.expandedTab === "timer" && !root.isCalling && root.activeTransient !== "ALERT") ? 1.0 : 0.0
                        visible: opacity > 0.01

                        onTimerCompleted: (t, msg) => {
                            root.alertIcon = "⏰"
                            root.alertTitle = t
                            root.alertSubtitle = msg
                            root.triggerTransient("ALERT", 6000)
                            Bridge.forceRaise()
                        }
                    }

                    NotificationPage {
                        id: notifCenterPage; anchors.fill: parent; chosenFont: root.chosenFont
                        opacity: (root.expandedTab === "notification" && !root.isCalling && root.activeTransient !== "ALERT") ? 1.0 : 0.0
                        visible: opacity > 0.01
                    }

                    BluetoothPage {
                        id: bluetoothPage; anchors.fill: parent; chosenFont: root.chosenFont
                        opacity: (typeof Config !== "undefined" && Config.showBluetoothTab && root.expandedTab === "bluetooth" && !root.isCalling && root.activeTransient !== "ALERT") ? 1.0 : 0.0
                        visible: opacity > 0.01
                    }

                    NetworkPage {
                        id: networkPage; anchors.fill: parent; chosenFont: root.chosenFont
                        downSpeed: root.downSpeedStr; upSpeed: root.upSpeedStr; localIp: root.localIp
                        opacity: (Config.showNetworkTab && root.expandedTab === "network" && !root.isCalling && root.activeTransient !== "ALERT") ? 1.0 : 0.0
                        visible: opacity > 0.01
                    }

                    WorldClockPage {
                        id: worldClockPage; anchors.fill: parent; chosenFont: root.chosenFont; is24h: Config.timeFormat === "24h"
                        opacity: (Config.showClockTab && root.expandedTab === "clock" && !root.isCalling && root.activeTransient !== "ALERT") ? 1.0 : 0.0
                        visible: opacity > 0.01
                    }
                }
            }
        }
    }

    // ========================================================
    // 相对锚定（响应 splitGap 动态间距）
    // ========================================================

    // 1. 音乐副岛
    MusicBubbleView {
        id: leftMusicBubble
        z: 1
        anchors.right: capsule.left
        anchors.rightMargin: root.splitGap
        anchors.verticalCenter: capsule.verticalCenter

        active: !root.isExpanded && !root.isCollapsing && !root.isMorphing && root.hasMusicIsland
        onClicked: { root.isExpanded = true; root.expandedTab = "media" }
    }

    // 2. 倒计时/秒表副岛（大字舒适版）
    TimerBubbleView {
        id: rightTimerBubble
        z: 1
        anchors.left: capsule.right
        anchors.leftMargin: root.splitGap
        anchors.verticalCenter: capsule.verticalCenter

        active: !root.isExpanded && !root.isCollapsing && !root.isMorphing && root.hasTimerIsland
        timerText: timerPage.formattedTime
        hasHours: timerPage.hasHours
        chosenFont: root.chosenFont
        isCountUp: timerPage.isCountUp
        progress: timerPage.progress
        remainingSeconds: timerPage.remainingSeconds
        totalSeconds: timerPage.totalSeconds

        onClicked: { root.isExpanded = true; root.expandedTab = "timer" }
    }

    // 3. 通知副岛
    NotificationBubbleView {
        id: notifBubble
        z: 1
        anchors.verticalCenter: capsule.verticalCenter

        anchors.right: root.notifExpandsToLeft ? (root.hasMusicIsland ? leftMusicBubble.left : capsule.left) : undefined
        anchors.left: !root.notifExpandsToLeft ? (root.hasTimerIsland ? rightTimerBubble.right : capsule.right) : undefined
        anchors.rightMargin: root.notifExpandsToLeft ? root.splitGap : 0
        anchors.leftMargin: !root.notifExpandsToLeft ? root.splitGap : 0

        active: !root.isExpanded && !root.isCollapsing && !root.isMorphing && root.hasNotifIsland
        unreadCount: root.unreadNotificationCount
        avatarUrl: root.latestNotifAvatar
        chosenFont: root.chosenFont

        onClicked: { Bridge.focusTeamsWindow(); Bridge.markAllNotificationsRead() }
        onRightClicked: { root.isExpanded = true; root.expandedTab = "notification" }
    }

    Component.onCompleted: {
        root.animationReady = true; root.updateDateTime(); root.safeCommitMask()
        if (root.status === "Playing" || root.isCalling) root.expandedTab = "media"
        else root.expandedTab = "calendar"
    }
}