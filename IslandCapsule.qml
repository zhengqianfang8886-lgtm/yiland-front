// ==========================================
// 📄 File: IslandCapsule.qml
// 🌟 悬停偷瞄(Peek)自动缩回 · 点击左键固定常驻(Pin) · 右键隐藏
// ==========================================
import QtQuick
import QtQuick.Controls
import "capsule"

Item {
    id: capsuleRoot

    // =========================================================================
    // 1. 核心业务信号
    // =========================================================================
    signal timerAlert(string title, string msg)
    signal sedentaryRested()
    signal sedentarySnooze()
    signal requestExpand(string tabName)
    signal requestSettings()
    signal maskCommitRequested()

    property string chosenFont: ""
    readonly property string effectiveFont: chosenFont !== "" ? chosenFont : Theme.activeFont

    property bool isExpanded: false
    property bool isCollapsing: false
    property var enabledTabs: []

    // 🚀【核心状态机】
    // isTucked: 处于隐藏收纳状态
    // isPeeking: 隐藏状态下鼠标临时悬停探出 (移开后会自动缩回)
    property bool isTucked: false
    property bool isPeeking: false

    // 胶囊当前是否实际上物理吸顶（非悬停探出中）
    readonly property bool isActuallyTucked: isTucked && !isPeeking

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

    // -------------------------------------------------------------------------
    // 家与旅馆动力学引擎
    // -------------------------------------------------------------------------
    property real islandOffsetX: 0
    readonly property bool isAtMotel: Math.abs(islandOffsetX) > 8

    function goHome() {
        islandOffsetX = 0
        maskCommitRequested()
    }

    Behavior on islandOffsetX {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutBack
            easing.overshoot: 1.18
        }
    }

    function applyDragDelta(deltaX) {
        var next = islandOffsetX + deltaX
        islandOffsetX = Math.max(-250, Math.min(250, next))
        maskCommitRequested()
    }

    function finishDrag(velocityX) {
        if (Math.abs(islandOffsetX) < 35 || (islandOffsetX > 0 && velocityX < -6) || (islandOffsetX < 0 && velocityX > 6)) {
            goHome()
        } else {
            maskCommitRequested()
        }
    }

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

    function toggleTimerPause() {
        if (expandedCardView.timerPageRef) {
            expandedCardView.timerPageRef.togglePause()
            maskCommitRequested()
        }
    }
    function dismissTimer() {
        if (expandedCardView.timerPageRef) {
            expandedCardView.timerPageRef.dismissTimer()
            maskCommitRequested()
        }
    }
    function resetTimer() {
        if (expandedCardView.timerPageRef) {
            expandedCardView.timerPageRef.resetTimer()
            maskCommitRequested()
        }
    }

    property bool anySubBubbleHovered: false
    property bool subBubbleInteracting: false
    readonly property bool isMouseOver: sensorArea.isPointerHovered

    function lockBriefMorph() { sensorArea.lockBriefMorph() }
    function cancelCollapse() { sensorArea.cancelCollapse() }
    function requestCollapse() { sensorArea.triggerRequestCollapse() }
    function startCollapse() { sensorArea.triggerImmediateCollapse() }
    function triggerClipGlow() { capsuleBackground.triggerClipGlow() }

    readonly property bool isLongAlert: (activeTransient === "ALERT") && (((alertTitle || "").length + (alertSubtitle || "").length) > 24 || (alertSubtitle || "").indexOf("\n") !== -1)
    readonly property int currentNormalWidth: Math.max(80, Math.ceil((compactCapsuleView.textRowImplicitWidth + 24) / 2) * 2)

    readonly property int targetWidth: {
        if (isActuallyTucked) return 140
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

    readonly property bool isMorphing: widthNumAnim.running || heightNumAnim.running || topMarginAnim.running

    // 仅当下落滑动动画在进行时才标记为未就位
    readonly property bool isDroppingFromTuck: !isActuallyTucked && topMarginAnim.running
    readonly property bool isCapsuleSettled: !isActuallyTucked && !isExpanded && !isCollapsing && !isDroppingFromTuck

    readonly property color currentEffectiveAccent: {
        if (isActuallyTucked) return "#1d4ed8"
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
    anchors.horizontalCenterOffset: Math.round(Config.offsetX + capsuleRoot.islandOffsetX)

    // =========================================================================
    // 🌊 物理滑轨：isActuallyTucked 为真时吸顶，Peek 或固定显示时滑下
    // =========================================================================
    readonly property real normalTopMargin: (typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined) ? Config.capsuleTopMargin : 8
    anchors.topMargin: isActuallyTucked ? -(targetHeight - 4.5) : normalTopMargin

    Behavior on anchors.topMargin {
        NumberAnimation {
            id: topMarginAnim
            duration: capsuleRoot.isActuallyTucked ? 240 : 320
            easing.type: capsuleRoot.isActuallyTucked ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: capsuleRoot.isActuallyTucked ? 1.0 : 1.12
            onRunningChanged: {
                if (!running && !widthNumAnim.running && !heightNumAnim.running && !capsuleRoot.isExpanded) {
                    capsuleRoot.isCollapsing = false
                }
                capsuleRoot.maskCommitRequested()
            }
        }
    }

    width: targetWidth
    height: targetHeight

    onIsExpandedChanged: {
        if (isExpanded) {
            isCollapsing = false
            if (isTucked) { isTucked = false; isPeeking = false }
            if (isAtMotel) goHome()
        } else {
            collapseWatchdog.restart()
        }
        maskCommitRequested()
    }

    Timer {
        id: collapseWatchdog
        interval: 350
        onTriggered: {
            if (capsuleRoot.isCollapsing && !capsuleRoot.isExpanded) {
                capsuleRoot.isCollapsing = false
                capsuleRoot.maskCommitRequested()
            }
        }
    }

    onIsTuckedChanged: maskCommitRequested()
    onIsPeekingChanged: maskCommitRequested()

    Behavior on width {
        NumberAnimation {
            id: widthNumAnim
            duration: 240
            easing.type: Easing.OutCubic
            onRunningChanged: {
                if (!running && !heightNumAnim.running && !topMarginAnim.running && !capsuleRoot.isExpanded) {
                    capsuleRoot.isCollapsing = false
                }
                capsuleRoot.maskCommitRequested()
            }
        }
    }

    Behavior on height {
        NumberAnimation {
            id: heightNumAnim
            duration: 240
            easing.type: Easing.OutCubic
            onRunningChanged: {
                if (!running && !widthNumAnim.running && !topMarginAnim.running && !capsuleRoot.isExpanded) {
                    capsuleRoot.isCollapsing = false
                }
                capsuleRoot.maskCommitRequested()
            }
        }
    }

    // -------------------------------------------------------------------------
    // 1. 胶囊外壳底板
    // -------------------------------------------------------------------------
    CapsuleBackground {
        id: capsuleBackground
        capsuleRadius: capsuleRoot.radius
        accentColor: capsuleRoot.currentEffectiveAccent
        isHovered: sensorArea.isPointerHovered
    }

    // -------------------------------------------------------------------------
    // 2. 常态内容流
    // -------------------------------------------------------------------------
    CompactCapsuleView {
        id: compactCapsuleView
        anchors.fill: parent
        anchors.leftMargin: 2; anchors.rightMargin: 2
        height: capsuleRoot.isExpanded ? 34 : parent.height
        clip: true
        z: 5

        visible: !capsuleRoot.isExpanded
        opacity: capsuleRoot.isExpanded ? 0.0 : (capsuleRoot.isActuallyTucked ? 0.0 : 1.0)
        Behavior on opacity { NumberAnimation { duration: capsuleRoot.isActuallyTucked ? 90 : 160 } }

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
    }

    // -------------------------------------------------------------------------
    // 3. 回巢微标
    // -------------------------------------------------------------------------
    Rectangle {
        id: returnHomePill
        z: 15
        width: 18; height: 18; radius: 9
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: capsuleRoot.islandOffsetX > 0 ? parent.left : undefined
        anchors.right: capsuleRoot.islandOffsetX < 0 ? parent.right : undefined
        anchors.leftMargin: 6; anchors.rightMargin: 6

        visible: !capsuleRoot.isExpanded && !capsuleRoot.isActuallyTucked && capsuleRoot.isAtMotel && (opacity > 0.001)
        opacity: (!capsuleRoot.isExpanded && !capsuleRoot.isActuallyTucked && capsuleRoot.isAtMotel) ? (homeHover.hovered ? 0.95 : 0.45) : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        color: homeHover.hovered ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35) : Qt.rgba(255, 255, 255, 0.12)
        border.color: homeHover.hovered ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.25)
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "⌂"
            font.pixelSize: 10
            font.weight: Font.Bold
            color: "white"
        }

        HoverHandler { id: homeHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: capsuleRoot.goHome() }
    }

    // -------------------------------------------------------------------------
    // 4. 展开卡片
    // -------------------------------------------------------------------------
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

    // -------------------------------------------------------------------------
    // 5. 交互感知层 (负责右键隐藏、左键钉住恢复与悬停离开退回)
    // -------------------------------------------------------------------------
    CapsuleSensorArea {
        id: sensorArea
        z: 20
        isExpanded: capsuleRoot.isExpanded
        isCollapsing: capsuleRoot.isCollapsing
        isCalling: capsuleRoot.isCalling
        isNoticeActive: capsuleRoot.isNoticeActive
        activeTransient: capsuleRoot.activeTransient
        subBubbleInteracting: capsuleRoot.subBubbleInteracting
        isTucked: capsuleRoot.isActuallyTucked

        // 右键直接隐藏吸顶
        onRequestTuck: {
            capsuleRoot.isPeeking = false
            capsuleRoot.isTucked = true
        }

        // 🚀【点击永久固定 Pin】：在展开或 Peek 状态下左键点击主岛，取消隐藏模式，永久钉住！
        onPinnedRestoreRequested: {
            capsuleRoot.isPeeking = false
            capsuleRoot.isTucked = false
        }

        // 🚀【悬停离开退回】：如果当前只是 Peek 偷瞄状态，鼠标移开后自动缩回顶端
        onPointerExitedCapsule: {
            if (capsuleRoot.isTucked && capsuleRoot.isPeeking) {
                peekRetractTimer.restart()
            }
        }
        onPointerEnteredCapsule: {
            peekRetractTimer.stop()
        }

        onRequestExpand: (tab) => capsuleRoot.requestExpand(tab)
        onMoveOffsetRequested: (deltaX) => capsuleRoot.applyDragDelta(deltaX)
        onDragFinished: (vX) => capsuleRoot.finishDrag(vX)
        onGoHomeRequested: capsuleRoot.goHome()

        onStartCollapse: {
            capsuleRoot.isCollapsing = true
            capsuleRoot.isExpanded = false
            collapseWatchdog.restart()
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

    // Peek 离开缓冲定时器：离开胶囊 220ms 自动像水滴弹簧一样收回
    Timer {
        id: peekRetractTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (capsuleRoot.isTucked && !sensorArea.isPointerHovered && !capsuleRoot.anySubBubbleHovered) {
                capsuleRoot.isPeeking = false
            }
        }
    }

    // -------------------------------------------------------------------------
    // 6. 顶端露弧感应唤醒区 (悬停只是偷瞄 Peek，点击则是永久固定 Pin)
    // -------------------------------------------------------------------------
    MouseArea {
        id: tuckSensor
        z: 30
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: 14
        enabled: capsuleRoot.isActuallyTucked
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Timer {
            id: tuckPeekDwellTimer
            interval: 140
            onTriggered: {
                if (capsuleRoot.isActuallyTucked) {
                    capsuleRoot.isPeeking = true // 悬停：触发临时探出 Peek
                }
            }
        }

        onEntered: {
            peekRetractTimer.stop()
            tuckPeekDwellTimer.restart()
        }
        onExited: {
            tuckPeekDwellTimer.stop()
        }

        // 🚀【核心交互】：在顶弧上直接点击左键，直接永久固定展开，不缩回！
        onClicked: {
            tuckPeekDwellTimer.stop()
            peekRetractTimer.stop()
            capsuleRoot.isPeeking = false
            capsuleRoot.isTucked = false // 永久固定
        }
    }

    CapsuleTuckGesture {
        id: tuckGesture
        z: 25
        isTucked: capsuleRoot.isActuallyTucked
        onRequestRestore: {
            capsuleRoot.isPeeking = false
            capsuleRoot.isTucked = false
        }
        onRequestTuck: {
            capsuleRoot.isPeeking = false
            capsuleRoot.isTucked = true
        }
    }
}