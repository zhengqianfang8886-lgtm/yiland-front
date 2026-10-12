// ==========================================
// 📄 File: IslandCapsule.qml
// 🌟 终极修复：逻辑统一收拢 · 离开准时收回
// ==========================================
import QtQuick
import QtQuick.Controls
import "capsule"

Item {
    id: capsuleRoot

    property string chosenFont: ""
    readonly property string effectiveFont: chosenFont !== "" ? chosenFont : Theme.activeFont

    property bool isExpanded: false
    property bool isCollapsing: false
    property var enabledTabs: []
    property bool isIslandHidden: false

    property alias expandedTab: expandedCardView.expandedTab

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
    property int wsCurrent: 0
    property int wsTotal: 4
    property string wsName: ""
    property var wsList: []

    property var lockedTargetId: 0

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
    readonly property bool isMouseOver: sensorArea.isPointerHovered

    signal requestExpand(string tabName)
    signal requestSettings()
    signal maskCommitRequested()
    signal timerAlert(string title, string msg)
    signal requestHideIsland()

    function lockBriefMorph() { sensorArea.lockBriefMorph() }
    function cancelCollapse() { sensorArea.cancelCollapse() }
    function requestCollapse() { sensorArea.triggerRequestCollapse() }
    function startCollapse() { sensorArea.triggerImmediateCollapse() }
    function triggerClipGlow() { capsuleBackground.triggerClipGlow() }

    readonly property bool isLongAlert: (activeTransient === "ALERT") && (((alertTitle || "").length + (alertSubtitle || "").length) > 24 || (alertSubtitle || "").indexOf("\n") !== -1)
    readonly property int currentNormalWidth: Math.max(80, Math.ceil((compactCapsuleView.textRowImplicitWidth + 24) / 2) * 2)

    readonly property int targetWidth: {
        if (isExpanded) return 430
        if (isCalling) return 320
        if (activeTransient === "SEDENTARY") return 520
        if (sensorArea.isScrubbing) return 300
        if (activeTransient === "ALERT") return Math.round(Math.min(420, Math.max(160, compactCapsuleView.alertContentImplicitWidth + 28)))
        if (activeTransient === "OSD") return currentNormalWidth
        if (activeTransient === "WORKSPACE") return Math.max(168, Math.max(compactCapsuleView.wsContentImplicitWidth + 20, currentNormalWidth))
        return currentNormalWidth
    }

    readonly property int targetHeight: {
        if (isExpanded) return 240
        if (activeTransient === "SEDENTARY") return 108
        if (activeTransient === "ALERT") return isLongAlert ? 64 : 48
        return isCalling ? 44 : 34
    }

    readonly property int radius: isExpanded ? 28 : (activeTransient === "SEDENTARY" ? 26 : (isCalling ? 22 : (activeTransient === "ALERT" ? 24 : 17)))
    readonly property bool isNoticeActive: (activeTransient === "ALERT") || (activeTransient === "SEDENTARY") || isCalling
    readonly property bool isMorphGrowing: isExpanded || isNoticeActive || (activeTransient === "WORKSPACE") || sensorArea.isScrubbing
    readonly property bool isMorphing: (widthNumAnim && widthNumAnim.running) || (heightNumAnim && heightNumAnim.running)

    readonly property color currentEffectiveAccent: {
        if (isCalling) return Theme.media
        if (activeTransient === "SEDENTARY") return Qt.rgba(52 / 255, 211 / 255, 153 / 255, 1.0)
        if (activeTransient === "ALERT") return compactCapsuleView.alertThemeColor
        if (activeTransient === "OSD" && compactCapsuleView.isHardwareMuted) return Theme.danger
        if (sensorArea.isScrubbing) return sensorArea.isScrubCanceling ? Theme.danger : Theme.workspace
        if (status === "Playing" && !isExpanded) return dominantColor
        return Qt.rgba(0, 0, 0, 0)
    }

    z: 2
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: Math.round(Config.offsetX)
    Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveDecel } }

    anchors.topMargin: isIslandHidden ? (-height - 20) : ((typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined) ? Config.capsuleTopMargin : 8)
    Behavior on anchors.topMargin {
        NumberAnimation {
            duration: capsuleRoot.isIslandHidden ? 100 : Theme.animSlow
            easing.type: capsuleRoot.isIslandHidden ? Easing.InQuad : Theme.curveSpring
            easing.overshoot: Theme.springOvershootNormal
        }
    }

    width: targetWidth
    height: targetHeight

    opacity: isIslandHidden ? 0.0 : 1.0
    visible: opacity > 0.001
    Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveFluid } }

    onIsExpandedChanged: {
        if (isExpanded) {
            maskCommitRequested()
        }
    }

    Behavior on width {
        enabled: !capsuleRoot.isIslandHidden
        NumberAnimation {
            id: widthNumAnim
            // 收缩时（isCollapsing 或卡片变小）使用 130ms 迅速收合
            duration: capsuleRoot.isExpanded ? Theme.animNormal : 130
            easing.type: capsuleRoot.isExpanded ? Theme.curveSpring : Easing.OutCubic
            easing.overshoot: 1.0
            onRunningChanged: {
                if (!running && !heightNumAnim.running && !capsuleRoot.isExpanded) {
                    capsuleRoot.isCollapsing = false
                    capsuleRoot.maskCommitRequested()
                }
            }
        }
    }

    Behavior on height {
        NumberAnimation {
            id: heightNumAnim
            // 收缩时使用 130ms 迅速收合
            duration: capsuleRoot.isExpanded ? Theme.animNormal : 130
            easing.type: capsuleRoot.isExpanded ? Theme.curveSpring : Easing.OutCubic
            easing.overshoot: 1.0
            onRunningChanged: {
                if (!running && !widthNumAnim.running && !capsuleRoot.isExpanded) {
                    capsuleRoot.isCollapsing = false
                    capsuleRoot.maskCommitRequested()
                }
            }
        }
    }

    // 1. 材质与高光底板
    CapsuleBackground {
        id: capsuleBackground
        capsuleRadius: capsuleRoot.radius
        accentColor: capsuleRoot.currentEffectiveAccent
        isHovered: sensorArea.isPointerHovered
    }

    // 2. 常态胶囊内构
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
        wsList: capsuleRoot.wsList

        isScrubbing: sensorArea.isScrubbing
        isScrubCanceling: sensorArea.isScrubCanceling

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

    // 3. 展开卡片内构 (z: 10)
    Item {
        anchors.fill: parent
        clip: false
        z: 10

        ExpandedCardView {
            id: expandedCardView
            width: 398; height: 208
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

    // 4. 🚀【核心设计】：交互感知层置于最顶层 (z: 20)
    // 展开时它的点击层已通过 enabled: false 完全穿透，绝不阻碍卡片内的按钮点击；
    // 它的 HoverHandler 处于最高优先级，能够完整覆盖整个 430x240 范围，进出状态绝对准确！
    CapsuleSensorArea {
        id: sensorArea
        z: 20
        isExpanded: capsuleRoot.isExpanded
        isCollapsing: capsuleRoot.isCollapsing
        isCalling: capsuleRoot.isCalling
        isNoticeActive: capsuleRoot.isNoticeActive
        activeTransient: capsuleRoot.activeTransient
        subBubbleInteracting: capsuleRoot.subBubbleInteracting

        onRequestExpand: (tab) => capsuleRoot.requestExpand(tab)
        onRequestHideIsland: () => capsuleRoot.requestHideIsland()

        onStartCollapse: {
            capsuleRoot.isCollapsing = true
            capsuleRoot.isExpanded = false
            if (capsuleRoot.activeTransient === "ALERT") capsuleRoot.activeTransient = ""
        }

        onWheelScrolled: (deltaY) => {
            if (typeof Bridge !== "undefined" && (!capsuleRoot.isExpanded || capsuleRoot.expandedTab === "workspace")) {
                if (deltaY > 0) Bridge.switchWorkspacePrev()
                else if (deltaY < 0) Bridge.switchWorkspaceNext()
            }
        }

        onScrubStarted: compactCapsuleView.updateCursorByMouseX(sensorArea.pressStartX)

        onScrubMoved: (mx, my) => {
            compactCapsuleView.updateCursorByMouseX(mx)
            var targetIdx = compactCapsuleView.scrubHoverIndex
            var items = compactCapsuleView.workspaceItems
            var tId = targetIdx
            if (items && items.length > targetIdx && targetIdx >= 0) {
                var it = items[targetIdx]
                if (it && it.id !== undefined) tId = it.id
            }
            capsuleRoot.lockedTargetId = tId
        }

        onScrubCommitted: {
            compactCapsuleView.snapToNearest()
            var finalTarget = capsuleRoot.lockedTargetId
            if (typeof Bridge !== "undefined" && Bridge.switchWorkspace) Bridge.switchWorkspace(finalTarget)
            capsuleRoot.maskCommitRequested()
        }

        onScrubCanceled: capsuleRoot.maskCommitRequested()
    }
}