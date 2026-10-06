// ==========================================
// 📄 File: IslandCapsule.qml
// 🌟 消除通知残留水位污染 · 丝滑微交互防抖退火版
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: capsuleRoot

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont

    property bool isExpanded: false
    property bool isCollapsing: false
    property var enabledTabs: []
    property bool isIslandHidden: false

    property alias expandedTab: expandedCardView.expandedTab
    property alias drillDownPage: expandedCardView.drillDownPage

    property string activeTransient: ""
    property string status: "Paused"
    property bool isCalling: false
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""
    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property real position: 0
    property real duration: 0

    property color dominantColor: "#22c55e"
    property int wsCurrent: 1
    property int wsTotal: 4
    property string wsName: ""
    property var wsList: []

    property string osdIcon: "🔊"
    property int osdValue: 50
    property string alertTitle: ""
    property string alertSubtitle: ""
    property string alertAvatar: ""
    property string alertIcon: "🔔"

    property string displayDate: ""
    property string displayTime: ""
    property string displaySeconds: ""
    property string displayPeriod: ""

    property string downCompact: "0K"
    property string upCompact: "0K"
    property string downSpeedStr: ""
    property string upSpeedStr: ""
    property string localIp: ""

    property int continuousSitMinutes: 45
    signal sedentaryRested()
    signal sedentarySnooze()

    property real clipGlowOpacity: 0.0

    SequentialAnimation {
        id: clipGlowAnim
        NumberAnimation { target: capsuleRoot; property: "clipGlowOpacity"; to: 0.95; duration: Theme.animInstant; easing.type: Easing.OutQuad }
        NumberAnimation { target: capsuleRoot; property: "clipGlowOpacity"; to: 0.0; duration: Theme.animSlow; easing.type: Easing.InOutQuad }
    }
    function triggerClipGlow() { clipGlowAnim.restart() }

    readonly property bool timerRunning: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.isRunning : false
    readonly property bool timerIsPaused: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.isPaused : false
    readonly property bool timerIsCompleted: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.isCompleted : false
    readonly property bool timerActive: timerRunning || timerIsPaused || timerIsCompleted
    readonly property string timerFormattedText: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.formattedTime : "25:00"
    readonly property bool timerHasHours: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.hasHours : false
    readonly property bool timerIsCountUp: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.isCountUp : false
    readonly property real timerProgress: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.progress : 0.0
    readonly property int timerRemaining: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.remainingSeconds : 0
    readonly property int timerTotal: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.totalSeconds : 0

    function toggleTimerPause() { if (expandedCardView.timerPageRef) expandedCardView.timerPageRef.togglePause() }
    function dismissTimer() { if (expandedCardView.timerPageRef) expandedCardView.timerPageRef.dismissTimer() }
    function resetTimer() { if (expandedCardView.timerPageRef) expandedCardView.timerPageRef.resetTimer() }

    property bool anySubBubbleHovered: false
    property bool subBubbleInteracting: false

    readonly property bool isCapsuleDirectHovered: capsuleRootHover.hovered || (typeof hitSensorArea !== "undefined" && hitSensorArea.containsMouse)
    readonly property bool isMouseOver: isCapsuleDirectHovered || (isExpanded && anySubBubbleHovered)

    signal requestExpand(string tabName)
    signal requestSettings()
    signal maskCommitRequested()
    signal timerAlert(string title, string msg)
    signal requestHideIsland()

    readonly property bool isLongAlert: {
        if (capsuleRoot.activeTransient !== "ALERT") return false
        var totalLen = (capsuleRoot.alertTitle || "").length + (capsuleRoot.alertSubtitle || "").length
        return totalLen > 24 || (capsuleRoot.alertSubtitle || "").indexOf("\n") !== -1
    }

    function printTraceLog(tag, oldVal, newVal, reason) {
        var now = new Date()
        var timeStr = now.toLocaleTimeString() + "." + ("00" + now.getMilliseconds()).slice(-3)
        console.log("\x1b[36m[" + timeStr + "] [Capsule 尺寸追踪]\x1b[0m " + tag + ": " + oldVal + " -> \x1b[32m" + newVal + "\x1b[0m | 模式: " + (capsuleRoot.activeTransient || "常态") + " | 交互中: " + capsuleRoot.isUserInteracting + " | 原因: " + reason)
    }

    // =========================================================================
    // 🚀【核心机制 1】：生命周期严格对齐的高水位引擎 (仅限工作区/OSD等微交互防抖)
    // =========================================================================
    property bool isUserInteracting: false
    property int peakInteractionWidth: 0

    // 计算当前工作区/OSD等微交互所允许的合理物理最大宽度上限
    readonly property int maxMicroInteractionWidth: {
        var wsW = (compactCapsuleView.wsContentImplicitWidth || 0) + 20
        return Math.max(184, Math.max(wsW, currentNormalWidth))
    }

    Timer {
        id: interactionCooldownTimer
        interval: 850 // 略长于瞬态 800ms，确保瞬态完全交接完毕后才允许收缩
        repeat: false
        onTriggered: {
            capsuleRoot.printTraceLog("交互锁解除", capsuleRoot.peakInteractionWidth, 0, "冷却期满，平稳归位")
            capsuleRoot.isUserInteracting = false
            capsuleRoot.peakInteractionWidth = 0
        }
    }

    function notifyInteraction(callerReason) {
        // 如果当前是 ALERT 或 SEDENTARY，或者正处于收拢/展开，绝不能把这些外部大宽度当成水位的基准！
        if (capsuleRoot.activeTransient === "ALERT" || capsuleRoot.activeTransient === "SEDENTARY" || capsuleRoot.isExpanded) {
            capsuleRoot.peakInteractionWidth = 0
        }

        capsuleRoot.isUserInteracting = true

        // 仅在微交互安全范围内采纳宽度，杜绝被通知弹窗等外部大尺寸残留所污染
        var demand = (capsuleRoot.activeTransient === "WORKSPACE" || capsuleRoot.activeTransient === "OSD") ?
                     capsuleRoot.rawTargetWidth : capsuleRoot.currentNormalWidth
        var curW = Math.round(capsuleRoot.width)
        var clampedCurW = Math.min(curW, capsuleRoot.maxMicroInteractionWidth)
        var clampedDemand = Math.min(demand, capsuleRoot.maxMicroInteractionWidth)

        var oldPeak = capsuleRoot.peakInteractionWidth
        capsuleRoot.peakInteractionWidth = Math.max(capsuleRoot.peakInteractionWidth, clampedCurW, clampedDemand)

        if (capsuleRoot.peakInteractionWidth !== oldPeak) {
            capsuleRoot.printTraceLog("水位线爬升", oldPeak, capsuleRoot.peakInteractionWidth, callerReason)
        }
        interactionCooldownTimer.restart()
    }

    onRawTargetWidthChanged: {
        // 🚀【彻底修复】：仅在工作区或音量 OSD 交互期间才允许水位上升，通知(ALERT)等绝对禁止污染水位线！
        if ((capsuleRoot.activeTransient === "WORKSPACE" || capsuleRoot.activeTransient === "OSD")
            && capsuleRoot.isUserInteracting
            && capsuleRoot.rawTargetWidth > capsuleRoot.peakInteractionWidth) {
            var clampedDemand = Math.min(capsuleRoot.rawTargetWidth, capsuleRoot.maxMicroInteractionWidth)
            if (clampedDemand > capsuleRoot.peakInteractionWidth) {
                capsuleRoot.printTraceLog("内容扩大", capsuleRoot.peakInteractionWidth, clampedDemand, "工作区/OSD内容宽度超过历史水位")
                capsuleRoot.peakInteractionWidth = clampedDemand
            }
        }
    }

    onActiveTransientChanged: {
        capsuleRoot.printTraceLog("瞬态切换", "-", capsuleRoot.activeTransient || "常态", "activeTransient 属性变动")
        if (activeTransient === "OSD" || activeTransient === "WORKSPACE") {
            // 如果存在残留的不合理高水位，立即裁剪至安全微交互上限
            if (capsuleRoot.peakInteractionWidth > capsuleRoot.maxMicroInteractionWidth) {
                capsuleRoot.peakInteractionWidth = 0
            }
            capsuleRoot.notifyInteraction("进入 " + activeTransient + " 模式")
        } else {
            // 退出工作区/OSD，或进入 ALERT / SEDENTARY 时，立即重置微交互水位线，严防下一次交互读到脏数据
            capsuleRoot.isUserInteracting = false
            capsuleRoot.peakInteractionWidth = 0
            interactionCooldownTimer.stop()
        }
    }

    onWsCurrentChanged: if (activeTransient === "WORKSPACE") capsuleRoot.notifyInteraction("切换桌面: " + wsCurrent)
    onWsNameChanged: if (activeTransient === "WORKSPACE") capsuleRoot.notifyInteraction("桌面名称变更: " + wsName)
    onOsdValueChanged: if (activeTransient === "OSD") capsuleRoot.notifyInteraction("OSD 值变更: " + osdValue)

    // =========================================================================
    // 🚀【核心机制 2】：基准物理宽度常驻保障 (绝对杜绝 5ms 塌陷)
    // =========================================================================
    readonly property int currentNormalWidth: {
        var baseW = compactCapsuleView.textRowImplicitWidth + 24
        return Math.max(80, Math.ceil(baseW / 2) * 2)
    }

    readonly property int rawTargetWidth: {
        if (capsuleRoot.isExpanded) return 430
        if (capsuleRoot.isCalling) return 320
        if (capsuleRoot.activeTransient === "SEDENTARY") return 520
        if (capsuleRoot.activeTransient === "ALERT") {
            var dynamicW = compactCapsuleView.alertContentImplicitWidth + 28
            return Math.round(Math.min(420, Math.max(160, dynamicW)))
        }

        if (capsuleRoot.activeTransient === "WORKSPACE") {
            var wsDynamic = (compactCapsuleView.wsContentImplicitWidth || 0) + 20
            return Math.max(168, Math.max(wsDynamic, currentNormalWidth))
        }

        if (capsuleRoot.activeTransient === "OSD") return Math.max(184, currentNormalWidth)

        return currentNormalWidth
    }

    // =========================================================================
    // 🚀【核心机制 3】：决胜裁决宽度（瞬态进行中或操作中，严格隔离安全区间）
    // =========================================================================
    readonly property int targetWidth: {
        // 1. 展开大卡片
        if (capsuleRoot.isExpanded) return 430

        // 2. 🚀【紧急置顶】：来电专属宽度，绝不允许被常态时钟 186px 挤扁！
        if (capsuleRoot.isCalling) return 320

        // 3. 久坐与通知弹窗
        if (capsuleRoot.activeTransient === "SEDENTARY") return 520
        if (capsuleRoot.activeTransient === "ALERT") {
            var dynamicW = compactCapsuleView.alertContentImplicitWidth + 28
            return Math.round(Math.min(420, Math.max(160, dynamicW)))
        }

        // 4. 处于用户交互保护期中（切桌面/调音量），严格受到安全上限保护
        if (capsuleRoot.activeTransient === "WORKSPACE" || capsuleRoot.activeTransient === "OSD" || capsuleRoot.isUserInteracting) {
            var safePeak = Math.min(capsuleRoot.peakInteractionWidth, capsuleRoot.maxMicroInteractionWidth)
            return Math.max(safePeak, capsuleRoot.rawTargetWidth)
        }

        // 5. 常态时钟
        return capsuleRoot.currentNormalWidth
    }

    onTargetWidthChanged: {
        capsuleRoot.printTraceLog("目标宽度 targetWidth", "-", targetWidth, "布局引擎重定尺寸")
    }

    readonly property int targetHeight: {
        if (capsuleRoot.isExpanded) return 240
        if (capsuleRoot.activeTransient === "SEDENTARY") return 108
        if (capsuleRoot.activeTransient === "ALERT") return capsuleRoot.isLongAlert ? 64 : 48
        return capsuleRoot.isCalling ? 44 : 34
    }

    readonly property int radius: isExpanded ? 28 : (activeTransient === "SEDENTARY" ? 26 : (isCalling ? 22 : (activeTransient === "ALERT" ? 24 : 17)))

    readonly property bool isJellyStyle: (typeof Config !== "undefined" && Config.animStyle === "jelly")
    readonly property bool isNoticeActive: (activeTransient === "ALERT") || (activeTransient === "SEDENTARY") || isCalling
    readonly property bool isMorphGrowing: isExpanded || isNoticeActive || (activeTransient === "WORKSPACE") || (activeTransient === "OSD")
    readonly property bool isMorphing: (widthNumAnim && widthNumAnim.running) || (heightNumAnim && heightNumAnim.running)
    readonly property bool isPureIdle: !isExpanded && !isCalling && (status !== "Playing") && (activeTransient === "") && !isMouseOver

    readonly property color currentEffectiveAccent: {
        if (isCalling) return Theme.media
        if (activeTransient === "SEDENTARY") return Qt.rgba(52 / 255, 211 / 255, 153 / 255, 1.0)
        if (activeTransient === "ALERT") return compactCapsuleView.alertThemeColor
        if (activeTransient === "OSD" && compactCapsuleView.isHardwareMuted) return Theme.danger
        if (status === "Playing" && !isExpanded) return dominantColor
        return Qt.rgba(0, 0, 0, 0)
    }

    readonly property bool hasDynamicAccent: currentEffectiveAccent.a > 0.001

    z: 2
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: Math.round(Config.offsetX)
    Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

    anchors.topMargin: capsuleRoot.isIslandHidden ? (-height - 20) : ((typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined) ? Config.capsuleTopMargin : 8)
    Behavior on anchors.topMargin {
        NumberAnimation {
            duration: 350
            easing.type: capsuleRoot.isIslandHidden ? Easing.InBack : Easing.OutBack
            easing.overshoot: capsuleRoot.isIslandHidden ? 0.8 : 1.05
        }
    }

    width: targetWidth
    height: targetHeight

    opacity: capsuleRoot.isIslandHidden ? 0.0 : 1.0
    visible: opacity > 0.001
    Behavior on opacity { NumberAnimation { duration: capsuleRoot.isIslandHidden ? 200 : 300; easing.type: Easing.InOutQuad } }

    // =========================================================================
    // 🚀 唯一的物理缓动：膨胀 140ms 迅速迎合，退火 220ms 沉稳平滑，零反弹
    // =========================================================================
    Behavior on width {
        enabled: !capsuleRoot.isIslandHidden
        NumberAnimation {
            id: widthNumAnim
            duration: capsuleRoot.width < capsuleRoot.targetWidth ? 140 : 220
            easing.type: Easing.OutCubic
            easing.overshoot: 1.0
            onRunningChanged: {
                capsuleRoot.maskCommitRequested()
                if (!running && !heightNumAnim.running) capsuleRoot.onMorphFinished()
            }
        }
    }

    Behavior on height {
        NumberAnimation {
            id: heightNumAnim
            duration: capsuleRoot.isMorphGrowing ? (capsuleRoot.isJellyStyle ? 220 : 190) : 190
            easing.type: capsuleRoot.isMorphGrowing ? (capsuleRoot.isJellyStyle ? Easing.OutBack : Easing.OutCubic) : Easing.OutCubic
            easing.overshoot: capsuleRoot.isMorphGrowing ? (capsuleRoot.isJellyStyle ? 1.15 : 1.0) : 1.0
            onRunningChanged: {
                capsuleRoot.maskCommitRequested()
                if (!running && !widthNumAnim.running) capsuleRoot.onMorphFinished()
            }
        }
    }

    function onMorphFinished() {
        if (!isExpanded) {
            isCollapsing = false
            maskCommitRequested()
            if (typeof Bridge !== "undefined" && Bridge.forceClearWindow) Bridge.forceClearWindow()
        } else {
            if (!capsuleRoot.isMouseOver) capsuleRoot.startCollapse()
        }
    }

    ShaderEffect {
        id: liquidGlassEffect
        anchors.fill: parent
        z: 0

        property vector2d u_size: Qt.vector2d(capsuleRoot.width, capsuleRoot.height)
        property real u_radius: capsuleRoot.radius
        property color u_accent: capsuleRoot.currentEffectiveAccent
        property real u_hasAccent: capsuleRoot.hasDynamicAccent ? 1.0 : 0.0
        property real u_isHovered: capsuleRoot.isMouseOver ? 1.0 : 0.0

        fragmentShader: "liquid_glass.frag.qsb"
    }

    property bool scrollSessionLocked: false

    HoverHandler {
        id: capsuleRootHover
        onHoveredChanged: {
            if (hovered) {
                capsuleRoot.cancelCollapse()
                if (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing && !capsuleRoot.subBubbleInteracting) {
                    if (typeof Config === "undefined" || Config.hoverExpandEnabled !== false) {
                        hoverDwellTimer.restart()
                    }
                }
            } else {
                hoverDwellTimer.stop()
                capsuleRoot.scrollSessionLocked = false
                capsuleRoot.requestCollapse()
            }
        }
    }

    Timer {
        id: hoverDwellTimer
        interval: (typeof Config !== "undefined" && Config.hoverDwellTime !== undefined) ? Config.hoverDwellTime : 240
        onTriggered: {
            if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return
            if (!capsuleRoot.scrollSessionLocked && !capsuleRoot.subBubbleInteracting && !capsuleRoot.isCollapsing && capsuleRoot.isCapsuleDirectHovered && !capsuleRoot.isExpanded) {
                if (capsuleRoot.isCalling) capsuleRoot.requestExpand("media")
                else if (capsuleRoot.activeTransient === "ALERT") capsuleRoot.requestExpand("notification")
                else if (capsuleRoot.activeTransient === "SEDENTARY") return
                else capsuleRoot.requestExpand("workspace")
            }
        }
    }

    Timer {
        id: leaveGraceTimer
        interval: 180
        onTriggered: {
            if (!capsuleRoot.isMouseOver && capsuleRoot.isExpanded) capsuleRoot.startCollapse()
        }
    }

    function cancelCollapse() { leaveGraceTimer.stop() }
    function requestCollapse() { if (isExpanded) leaveGraceTimer.restart() }

    function startCollapse() {
        if (!isExpanded) return
        hoverDwellTimer.stop()
        leaveGraceTimer.stop()
        isCollapsing = true
        isExpanded = false
        if (activeTransient === "ALERT") activeTransient = ""
        capsuleRoot.maskCommitRequested()
    }

    function handleWheelAction(deltaY) {
        if (capsuleRoot.isCalling || capsuleRoot.activeTransient === "SEDENTARY") return
        if (capsuleRoot.isExpanded && capsuleRoot.expandedTab !== "workspace") return

        // 🚀【核心修复】：如果滚轮滚动切换桌面时正处于通知状态，立即重置通知与水位，杜绝污染
        if (capsuleRoot.activeTransient === "ALERT") {
            capsuleRoot.activeTransient = ""
            capsuleRoot.peakInteractionWidth = 0
            capsuleRoot.isUserInteracting = false
        }

        capsuleRoot.notifyInteraction("滚轮滚动切换桌面")

        if (!capsuleRoot.isExpanded) {
            hoverDwellTimer.stop()
            capsuleRoot.scrollSessionLocked = true
            capsuleRoot.activeTransient = "WORKSPACE"
        }

        if (typeof Bridge !== "undefined") {
            if (deltaY > 0) Bridge.switchWorkspacePrev()
            else if (deltaY < 0) Bridge.switchWorkspaceNext()
        }
    }

    MouseArea {
        id: hitSensorArea
        anchors.fill: parent
        z: (capsuleRoot.isExpanded || capsuleRoot.isNoticeActive) ? -1 : 1
        hoverEnabled: true

        acceptedButtons: capsuleRoot.isExpanded ? Qt.NoButton : (Qt.LeftButton | Qt.RightButton)
        cursorShape: capsuleRoot.isExpanded ? Qt.ArrowCursor : Qt.PointingHandCursor

        onEntered: {
            capsuleRoot.cancelCollapse()
            capsuleRoot.scrollSessionLocked = false
            if (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing && !capsuleRoot.subBubbleInteracting) {
                if (typeof Config === "undefined" || Config.hoverExpandEnabled !== false) {
                    hoverDwellTimer.restart()
                }
            }
        }
        onExited: {
            hoverDwellTimer.stop()
            capsuleRoot.scrollSessionLocked = false
            capsuleRoot.requestCollapse()
        }
        onWheel: (wheel) => {
            wheel.accepted = true
            capsuleRoot.notifyInteraction("MouseArea 滚轮事件")
            if (!capsuleRoot.isExpanded || capsuleRoot.expandedTab === "workspace") capsuleRoot.handleWheelAction(wheel.angleDelta.y)
        }
        onClicked: (mouse) => {
            if (capsuleRoot.isExpanded || capsuleRoot.activeTransient === "SEDENTARY") return

            hoverDwellTimer.stop()
            leaveGraceTimer.stop()
            capsuleRoot.scrollSessionLocked = false

            if (mouse.button === Qt.RightButton) {
                capsuleRoot.requestHideIsland()
                return
            }

            if (capsuleRoot.isCalling) { capsuleRoot.requestExpand("media"); return }
            if (capsuleRoot.activeTransient === "ALERT") { capsuleRoot.requestExpand("notification"); return }
            capsuleRoot.requestExpand("time")
        }
    }

    CompactCapsuleView {
        id: compactCapsuleView
        anchors.fill: parent
        anchors.leftMargin: 2; anchors.rightMargin: 2
        height: capsuleRoot.isExpanded ? 34 : parent.height
        clip: false
        z: 5

        visible: !capsuleRoot.isExpanded && (opacity > 0.01)
        opacity: !capsuleRoot.isExpanded ? 1.0 : 0.0

        showNetSpeed: Config.showNetSpeed
        chosenFont: capsuleRoot.effectiveFont
        activeTransient: capsuleRoot.activeTransient
        status: capsuleRoot.status
        isCalling: capsuleRoot.isCalling
        isExpanded: capsuleRoot.isExpanded
        isCollapsing: capsuleRoot.isCollapsing
        isCapsLock: (typeof Bridge !== "undefined" && Bridge.isCapsLock !== undefined) ? Bridge.isCapsLock : false
        isNumLock: (typeof Bridge !== "undefined" && Bridge.isNumLock !== undefined) ? Bridge.isNumLock : false

        wsName: capsuleRoot.wsName
        wsCurrent: capsuleRoot.wsCurrent
        wsTotal: capsuleRoot.wsTotal
        osdIcon: capsuleRoot.osdIcon
        osdValue: capsuleRoot.osdValue
        alertTitle: capsuleRoot.alertTitle
        alertSubtitle: capsuleRoot.alertSubtitle
        alertAvatar: capsuleRoot.alertAvatar
        alertIcon: capsuleRoot.alertIcon
        callTitle: capsuleRoot.callTitle
        callSubtitle: capsuleRoot.callSubtitle
        callAvatar: capsuleRoot.callAvatar
        displayDate: capsuleRoot.displayDate
        displayTime: capsuleRoot.displayTime
        displaySeconds: capsuleRoot.displaySeconds
        displayPeriod: capsuleRoot.displayPeriod
        downCompact: capsuleRoot.downCompact
        upCompact: capsuleRoot.upCompact

        continuousSitMinutes: capsuleRoot.continuousSitMinutes
        onSedentaryRested: capsuleRoot.sedentaryRested()
        onSedentarySnooze: capsuleRoot.sedentarySnooze()

        Behavior on opacity { NumberAnimation { duration: capsuleRoot.isExpanded ? 0 : Theme.animInstant; easing.type: Easing.OutQuad } }
    }

    Item {
        anchors.fill: parent
        clip: false
        z: 10

        ExpandedCardView {
            id: expandedCardView
            width: 398
            height: 208
            anchors.top: parent.top
            anchors.topMargin: (typeof Config !== "undefined" && Config.expandedTopMargin !== undefined) ? Config.expandedTopMargin : 16
            anchors.horizontalCenter: parent.horizontalCenter

            visible: opacity > 0.01
            opacity: capsuleRoot.isExpanded ? 1.0 : 0.0
            scale: capsuleRoot.isExpanded ? 1.0 : 0.94
            chosenFont: capsuleRoot.effectiveFont

            enabledTabs: capsuleRoot.enabledTabs
            dominantColor: capsuleRoot.dominantColor

            isCalling: capsuleRoot.isCalling
            callTitle: capsuleRoot.callTitle
            callSubtitle: capsuleRoot.callSubtitle
            callAvatar: capsuleRoot.callAvatar
            title: capsuleRoot.title
            artist: capsuleRoot.artist
            status: capsuleRoot.status
            artUrl: capsuleRoot.artUrl
            position: capsuleRoot.position
            duration: capsuleRoot.duration
            wsCurrent: capsuleRoot.wsCurrent
            wsTotal: capsuleRoot.wsTotal
            wsName: capsuleRoot.wsName
            wsList: capsuleRoot.wsList
            downSpeedStr: capsuleRoot.downSpeedStr
            upSpeedStr: capsuleRoot.upSpeedStr
            localIp: capsuleRoot.localIp
            activeTransient: capsuleRoot.activeTransient

            onCancelCollapse: capsuleRoot.cancelCollapse()
            onRequestCollapse: capsuleRoot.requestCollapse()
            onStartCollapse: capsuleRoot.startCollapse()
            onTimerCompleted: (t, msg) => capsuleRoot.timerAlert(t, msg)
            onRequestSettings: capsuleRoot.requestSettings()

            Behavior on opacity { NumberAnimation { duration: capsuleRoot.isExpanded ? Theme.animFast : 65; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: capsuleRoot.isExpanded ? Theme.animNormal : 65; easing.type: Easing.OutQuad } }
        }
    }
}