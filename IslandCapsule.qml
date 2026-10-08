// ==========================================
// 📄 File: IslandCapsule.qml
// 🌟 解决正常离开不消失 · 160ms 极速敏捷收缩 · 260ms 瞬时变形防抖完整版
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: capsuleRoot

    property string chosenFont: ""
    readonly property string effectiveFont: chosenFont !== "" ? chosenFont : Theme.activeFont

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

    // 🚀【双通道敏捷指针感知】：无论是底层还是顶层 Hover，只要有一个在即为在，离开即触发收缩
    readonly property bool isMouseOver: capsuleRootHover.hovered || (typeof hitSensorArea !== "undefined" && hitSensorArea.containsMouse)

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

    property bool isUserInteracting: false
    property int peakInteractionWidth: 0

    readonly property int maxMicroInteractionWidth: {
        var wsW = (compactCapsuleView.wsContentImplicitWidth || 0) + 20
        return Math.max(184, Math.max(wsW, currentNormalWidth))
    }

    Timer {
        id: interactionCooldownTimer
        interval: Theme.animSlow * 3
        repeat: false
        onTriggered: {
            capsuleRoot.isUserInteracting = false
            capsuleRoot.peakInteractionWidth = 0
        }
    }

    function notifyInteraction(callerReason) {
        if (capsuleRoot.activeTransient === "ALERT" || capsuleRoot.activeTransient === "SEDENTARY" || capsuleRoot.isExpanded) {
            capsuleRoot.peakInteractionWidth = 0
        }
        if (capsuleRoot.activeTransient === "OSD") {
            return
        }

        capsuleRoot.isUserInteracting = true
        var demand = (capsuleRoot.activeTransient === "WORKSPACE") ?
                     capsuleRoot.rawTargetWidth : capsuleRoot.currentNormalWidth
        var curW = Math.round(capsuleRoot.width)
        var clampedCurW = Math.min(curW, capsuleRoot.maxMicroInteractionWidth)
        var clampedDemand = Math.min(demand, capsuleRoot.maxMicroInteractionWidth)

        capsuleRoot.peakInteractionWidth = Math.max(capsuleRoot.peakInteractionWidth, clampedCurW, clampedDemand)
        interactionCooldownTimer.restart()
    }

    onRawTargetWidthChanged: {
        if (capsuleRoot.activeTransient === "WORKSPACE"
            && capsuleRoot.isUserInteracting
            && capsuleRoot.rawTargetWidth > capsuleRoot.peakInteractionWidth) {
            var clampedDemand = Math.min(capsuleRoot.rawTargetWidth, capsuleRoot.maxMicroInteractionWidth)
            if (clampedDemand > capsuleRoot.peakInteractionWidth) {
                capsuleRoot.peakInteractionWidth = clampedDemand
            }
        }
    }

    onActiveTransientChanged: {
        if (activeTransient === "WORKSPACE") {
            if (capsuleRoot.peakInteractionWidth > capsuleRoot.maxMicroInteractionWidth) {
                capsuleRoot.peakInteractionWidth = 0
            }
            capsuleRoot.notifyInteraction("进入 WORKSPACE")
        } else {
            capsuleRoot.isUserInteracting = false
            capsuleRoot.peakInteractionWidth = 0
            interactionCooldownTimer.stop()
        }
    }

    onWsCurrentChanged: if (activeTransient === "WORKSPACE") capsuleRoot.notifyInteraction("切换桌面")
    onWsNameChanged: if (activeTransient === "WORKSPACE") capsuleRoot.notifyInteraction("桌面名称变更")

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
        if (capsuleRoot.activeTransient === "OSD") {
            return currentNormalWidth
        }
        return currentNormalWidth
    }

    readonly property int targetWidth: {
        if (capsuleRoot.isExpanded) return 430
        if (capsuleRoot.isCalling) return 320
        if (capsuleRoot.activeTransient === "SEDENTARY") return 520
        if (capsuleRoot.activeTransient === "ALERT") {
            var dynamicW = compactCapsuleView.alertContentImplicitWidth + 28
            return Math.round(Math.min(420, Math.max(160, dynamicW)))
        }
        if (capsuleRoot.activeTransient === "OSD") {
            return capsuleRoot.currentNormalWidth
        }
        if (capsuleRoot.activeTransient === "WORKSPACE" || capsuleRoot.isUserInteracting) {
            var safePeak = Math.min(capsuleRoot.peakInteractionWidth, capsuleRoot.maxMicroInteractionWidth)
            return Math.max(safePeak, capsuleRoot.rawTargetWidth)
        }
        return capsuleRoot.currentNormalWidth
    }

    readonly property int targetHeight: {
        if (capsuleRoot.isExpanded) return 240
        if (capsuleRoot.activeTransient === "SEDENTARY") return 108
        if (capsuleRoot.activeTransient === "ALERT") return capsuleRoot.isLongAlert ? 64 : 48
        return capsuleRoot.isCalling ? 44 : 34
    }

    readonly property int radius: isExpanded ? 28 : (activeTransient === "SEDENTARY" ? 26 : (isCalling ? 22 : (activeTransient === "ALERT" ? 24 : 17)))
    readonly property bool isNoticeActive: (activeTransient === "ALERT") || (activeTransient === "SEDENTARY") || isCalling
    readonly property bool isMorphGrowing: isExpanded || isNoticeActive || (activeTransient === "WORKSPACE")
    readonly property bool isMorphing: (widthNumAnim && widthNumAnim.running) || (heightNumAnim && heightNumAnim.running)

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
    Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveDecel } }

    anchors.topMargin: capsuleRoot.isIslandHidden ? (-height - 20) : ((typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined) ? Config.capsuleTopMargin : 8)
    Behavior on anchors.topMargin {
        NumberAnimation {
            duration: capsuleRoot.isIslandHidden ? 100 : Theme.animSlow
            easing.type: capsuleRoot.isIslandHidden ? Easing.InQuad : Theme.curveSpring
            easing.overshoot: Theme.springOvershootNormal
        }
    }

    width: targetWidth
    height: targetHeight

    opacity: capsuleRoot.isIslandHidden ? 0.0 : 1.0
    visible: opacity > 0.001
    Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveFluid } }

    onWidthChanged: capsuleRoot.maskCommitRequested()
    onHeightChanged: capsuleRoot.maskCommitRequested()

    Behavior on width {
        enabled: !capsuleRoot.isIslandHidden
        NumberAnimation {
            id: widthNumAnim
            duration: capsuleRoot.width < capsuleRoot.targetWidth ? Theme.animFast : Theme.animNormal
            easing.type: Theme.curveDecel
            onRunningChanged: {
                capsuleRoot.maskCommitRequested()
                if (!running && !heightNumAnim.running) capsuleRoot.onMorphFinished()
            }
        }
    }

    Behavior on height {
        NumberAnimation {
            id: heightNumAnim
            duration: capsuleRoot.isMorphGrowing ? Theme.animNormal : Theme.animFast
            easing.type: capsuleRoot.isMorphGrowing ? Theme.curveSpring : Theme.curveDecel
            easing.overshoot: capsuleRoot.isMorphGrowing ? Theme.springOvershootNormal : 1.0
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

    // 🚀【核心优化 1】：瞬态变形防抖锁 (仅在动画舒展的 260ms 内保护，动画结束立刻回归灵敏状态)
    property bool morphBriefLocked: false
    Timer {
        id: morphBriefTimer
        interval: 260
        repeat: false
        onTriggered: {
            capsuleRoot.morphBriefLocked = false
            // 查岗：展开动画完成后若鼠标不在卡片上，立刻开始收缩
            if (capsuleRoot.isExpanded && !capsuleRoot.isMouseOver) {
                capsuleRoot.requestCollapse()
            }
        }
    }

    function lockBriefMorph() {
        capsuleRoot.cancelCollapse()
        capsuleRoot.morphBriefLocked = true
        morphBriefTimer.restart()
    }

    HoverHandler {
        id: capsuleRootHover
        onHoveredChanged: {
            if (hovered) {
                capsuleRoot.morphBriefLocked = false
                morphBriefTimer.stop()
                capsuleRoot.cancelCollapse()
                if (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing && !capsuleRoot.subBubbleInteracting) {
                    if (typeof Config === "undefined" || Config.hoverExpandEnabled !== false) {
                        hoverDwellTimer.restart()
                    }
                }
            } else {
                hoverDwellTimer.stop()
                capsuleRoot.scrollSessionLocked = false
                if (capsuleRoot.isExpanded) {
                    capsuleRoot.requestCollapse()
                }
            }
        }
    }

    Timer {
        id: hoverDwellTimer
        interval: (typeof Config !== "undefined" && Config.hoverDwellTime !== undefined) ? Config.hoverDwellTime : 240
        onTriggered: {
            if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return
            if (!capsuleRoot.scrollSessionLocked && !capsuleRoot.subBubbleInteracting && !capsuleRoot.isCollapsing && capsuleRoot.isMouseOver && !capsuleRoot.isExpanded) {
                if (capsuleRoot.isCalling) capsuleRoot.requestExpand("media")
                else if (capsuleRoot.activeTransient === "ALERT") capsuleRoot.requestExpand("notification")
                else if (capsuleRoot.activeTransient === "SEDENTARY") return
                else capsuleRoot.requestExpand("workspace")
            }
        }
    }

    // 🚀【核心优化 2】：极速敏捷离开收缩 (160ms 黄金跟手收拢)
    Timer {
        id: leaveGraceTimer
        interval: 160
        repeat: false
        onTriggered: {
            if (capsuleRoot.isExpanded && !capsuleRoot.morphBriefLocked && !capsuleRoot.isMouseOver) {
                capsuleRoot.startCollapse()
            }
        }
    }

    function cancelCollapse() { leaveGraceTimer.stop() }
    function requestCollapse() {
        if (isExpanded && !morphBriefLocked) {
            leaveGraceTimer.restart()
        }
    }

    function startCollapse() {
        if (!isExpanded) return
        morphBriefLocked = false
        morphBriefTimer.stop()
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

        if (capsuleRoot.activeTransient === "ALERT") {
            capsuleRoot.activeTransient = ""
            capsuleRoot.peakInteractionWidth = 0
            capsuleRoot.isUserInteracting = false
        }

        capsuleRoot.notifyInteraction("滚轮切换桌面")

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
        // 🚀【核心优化 3】：解除错误拦截，无论何种状态只要光标滑出立刻请求收拢！
        onExited: {
            hoverDwellTimer.stop()
            capsuleRoot.scrollSessionLocked = false
            capsuleRoot.requestCollapse()
        }
        onWheel: (wheel) => {
            wheel.accepted = true
            capsuleRoot.notifyInteraction("MouseArea 滚轮")
            if (!capsuleRoot.isExpanded || capsuleRoot.expandedTab === "workspace") capsuleRoot.handleWheelAction(wheel.angleDelta.y)
        }
        onClicked: (mouse) => {
            if (capsuleRoot.activeTransient === "SEDENTARY") return

            if (mouse.button === Qt.RightButton) {
                hoverDwellTimer.stop()
                leaveGraceTimer.stop()
                capsuleRoot.requestHideIsland()
                return
            }

            if (capsuleRoot.isExpanded) return

            hoverDwellTimer.stop()
            leaveGraceTimer.stop()
            capsuleRoot.scrollSessionLocked = false

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

        Behavior on opacity { NumberAnimation { duration: capsuleRoot.isExpanded ? 0 : Theme.animInstant; easing.type: Theme.curveFluid } }
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

            Behavior on opacity { NumberAnimation { duration: capsuleRoot.isExpanded ? Theme.animFast : Theme.animInstant; easing.type: Theme.curveFluid } }
            Behavior on scale { NumberAnimation { duration: capsuleRoot.isExpanded ? Theme.animNormal : Theme.animInstant; easing.type: Theme.curveDecel } }
        }
    }
}