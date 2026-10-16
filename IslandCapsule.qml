// ==========================================
// 📄 File: IslandCapsule.qml
// 🌟 纯刚体潜航吸顶 · 动态安全包络线 · 零切边完整版
// ==========================================
import QtQuick
import QtQuick.Controls
import "capsule"

Item {
    id: capsuleRoot

    property var fsm: null

    property bool isExpanded: fsm ? (fsm.stateName === "EXPANDED") : false
    property bool isCollapsing: false
    property bool isTucked: fsm ? (fsm.stateName === "TUCKED") : false
    property bool isPeeking: fsm ? (fsm.stateName === "PEEKING") : false

    signal timerAlert(string title, string msg)
    signal sedentaryRested()
    signal sedentarySnooze()
    signal requestExpand(string tabName)
    signal requestSettings()

    function lockBriefMorph() {
        if (sensorArea && sensorArea.lockBriefMorph) sensorArea.lockBriefMorph()
    }
    function cancelCollapse() {
        if (sensorArea && sensorArea.cancelCollapse) sensorArea.cancelCollapse()
    }
    function requestCollapse() {
        if (sensorArea && sensorArea.triggerRequestCollapse) sensorArea.triggerRequestCollapse()
    }
    function startCollapse() {
        if (sensorArea && sensorArea.triggerImmediateCollapse) sensorArea.triggerImmediateCollapse()
    }
    function triggerClipGlow() {
        if (capsuleBackground && capsuleBackground.triggerClipGlow) capsuleBackground.triggerClipGlow()
    }

    property string chosenFont: ""
    readonly property string effectiveFont: chosenFont !== "" ? chosenFont : Theme.activeFont

    property var enabledTabs: []
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
    property real spec1: 0.2
    property real spec2: 0.2
    property real spec3: 0.2
    property real spec4: 0.2

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

    property int unreadCount: 0
    property string latestNotifAvatar: ""
    property int memoryPercent: 0

    property int continuousSitMinutes: 45

    property real islandOffsetX: 0
    readonly property bool isAtMotel: Math.abs(islandOffsetX) > 8

    function goHome() { islandOffsetX = 0 }

    Behavior on islandOffsetX {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
    }

    function applyDragDelta(deltaX) {
        var next = islandOffsetX + deltaX
        islandOffsetX = Math.max(-100, Math.min(100, next))
    }

    function finishDrag(velocityX) {
        if (Math.abs(islandOffsetX) < 35 || (islandOffsetX > 0 && velocityX < -6) || (islandOffsetX < 0 && velocityX > 6)) {
            goHome()
        }
    }

    readonly property bool timerRunning: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.isRunning : false
    readonly property bool timerIsPaused: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.isPaused : false
    readonly property bool timerIsCompleted: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.isCompleted : false
    readonly property bool timerActive: timerRunning || timerIsPaused || timerIsCompleted
    readonly property string timerFormattedText: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.formattedTime : "25:00"
    readonly property real timerProgress: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.progress : 0.0

    function toggleTimerPause() { if (expandedCardView.timerPageRef) expandedCardView.timerPageRef.togglePause() }
    function dismissTimer() { if (expandedCardView.timerPageRef) expandedCardView.timerPageRef.dismissTimer() }

    readonly property bool isLongAlert: (activeTransient === "ALERT") && (((alertTitle || "").length + (alertSubtitle || "").length) > 24 || (alertSubtitle || "").indexOf("\n") !== -1)
    
    // 基础安全定界宽度
    readonly property int currentNormalWidth: Math.max(140, compactCapsuleView.implicitCompactWidth)

    // =========================================================================
    // 1. 流体自适应目标宽度计算
    // =========================================================================
    readonly property int targetWidth: {
        if (isExpanded) return 420
        if (isCalling) return 320
        if (activeTransient === "SEDENTARY") return 420
        if (sensorArea.isScrubbing) return 300
        if (activeTransient === "ALERT") return Math.round(Math.min(420, Math.max(160, compactCapsuleView.alertContentImplicitWidth + 28)))
        if (activeTransient === "OSD") return currentNormalWidth
        if (activeTransient === "WORKSPACE") return Math.max(168, Math.max(compactCapsuleView.wsContentImplicitWidth + 20, currentNormalWidth))
        return currentNormalWidth
    }

    // =========================================================================
    // 2. 纯刚体高度：吸顶时高度永远保持 34px，绝不压瘪成黑条
    // =========================================================================
    readonly property int targetHeight: {
        if (isExpanded) return 240
        if (activeTransient === "SEDENTARY") return 108
        if (activeTransient === "ALERT") return isLongAlert ? 64 : 48
        return isCalling ? 44 : 34
    }

    // 饱满跑道圆角
    readonly property int radius: isExpanded ? 24 : (activeTransient === "SEDENTARY" ? 26 : (isCalling ? 22 : (activeTransient === "ALERT" ? 24 : 17)))

    // 常态悬浮距离屏幕顶部的间距
    readonly property real normalTopMargin: (typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined) ? Config.capsuleTopMargin : 8
    
    // 隐藏时在屏幕最顶端保留的圆润底弧露出高度（4.5px）
    readonly property real peekHeight: 4.5

    // =========================================================================
    // 3. 刚体潜水艇式 Y 轴负偏移潜航
    // =========================================================================
    y: isTucked ? -(targetHeight - peekHeight) : normalTopMargin

    Behavior on y {
        NumberAnimation {
            duration: capsuleRoot.isTucked ? 240 : 280
            easing.type: capsuleRoot.isTucked ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: capsuleRoot.isTucked ? 1.0 : 1.15
            onRunningChanged: {
                if (fsm) {
                    if (running) fsm.reportMotionStart()
                    else fsm.reportMotionSettled()
                }
            }
        }
    }

    // =========================================================================
    // 4. 流水般丝滑的宽度弹簧动画（Apple Fluid Spring）
    // =========================================================================
    width: targetWidth
    height: targetHeight

    Behavior on width {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutBack
            easing.overshoot: 1.08
            onRunningChanged: {
                if (fsm) {
                    if (running) fsm.reportMotionStart()
                    else fsm.reportMotionSettled()
                }
            }
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutBack
            easing.overshoot: 1.06
            onRunningChanged: {
                if (fsm) {
                    if (running) fsm.reportMotionStart()
                    else fsm.reportMotionSettled()
                }
            }
        }
    }

    readonly property color currentEffectiveAccent: {
        if (isTucked) return Qt.rgba(255, 255, 255, 0.20)
        if (isCalling) return Theme.media
        if (activeTransient === "SEDENTARY") return Qt.rgba(52 / 255, 211 / 255, 153 / 255, 1.0)
        if (activeTransient === "ALERT") return compactCapsuleView.alertThemeColor
        if (activeTransient === "OSD" && compactCapsuleView.isHardwareMuted) return Theme.danger
        if (sensorArea.isScrubbing) return sensorArea.isScrubCanceling ? Theme.danger : Theme.workspace
        if (status === "Playing" && !isExpanded) return dominantColor
        return Qt.rgba(0, 0, 0, 0)
    }

    // 1. 材质底板 (100% 遮光纯黑跑道圆)
    CapsuleBackground {
        id: capsuleBackground
        capsuleRadius: capsuleRoot.radius
        accentColor: capsuleRoot.currentEffectiveAccent
        isHovered: capsuleRoot.isHoverActive
    }

    // 2. 常态内容流 (🚀 彻底去除内部 clip: true，根除内部硬切边)
    CompactCapsuleView {
        id: compactCapsuleView
        anchors.fill: parent
        anchors.leftMargin: 2; anchors.rightMargin: 2
        height: capsuleRoot.isExpanded ? 34 : parent.height
        z: 5

        visible: opacity > 0.001
        opacity: (!capsuleRoot.isTucked && !capsuleRoot.isExpanded) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        showNetSpeed: (typeof Config !== "undefined") ? Config.showNetSpeed : true
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

        hasMusic: capsuleRoot.status === "Playing"
        dominantColor: capsuleRoot.dominantColor
        spec1: capsuleRoot.spec1
        spec2: capsuleRoot.spec2
        spec3: capsuleRoot.spec3
        spec4: capsuleRoot.spec4

        timerActive: capsuleRoot.timerActive
        timerFormattedText: capsuleRoot.timerFormattedText
        timerIsPaused: capsuleRoot.timerIsPaused
        timerIsCompleted: capsuleRoot.timerIsCompleted
        timerProgress: capsuleRoot.timerProgress

        unreadNotifCount: capsuleRoot.unreadCount
        latestNotifAvatar: capsuleRoot.latestNotifAvatar
        memoryPercent: capsuleRoot.memoryPercent

        continuousSitMinutes: capsuleRoot.continuousSitMinutes
        onSedentaryRested: capsuleRoot.sedentaryRested()
        onSedentarySnooze: capsuleRoot.sedentarySnooze()
        onRequestExpandTab: (tab) => capsuleRoot.requestExpand(tab)
        onToggleTimer: capsuleRoot.toggleTimerPause()
    }

    // 3. 展开大卡片
    Item {
        anchors.fill: parent
        anchors.margins: 12
        clip: true
        z: 10

        ExpandedCardView {
            id: expandedCardView
            anchors.fill: parent

            visible: opacity > 0.01
            opacity: capsuleRoot.isExpanded ? 1.0 : 0.0
            scale: capsuleRoot.isExpanded ? 1.0 : 0.95
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

            onCancelCollapse: sensorArea.cancelCollapse()
            onRequestCollapse: sensorArea.triggerRequestCollapse()
            onStartCollapse: { if (fsm) fsm.evCollapseCard() }
            onTimerCompleted: (t, msg) => capsuleRoot.timerAlert(t, msg)
            onRequestSettings: capsuleRoot.requestSettings()

            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        }
    }

    // 4. 交互感知层
    CapsuleSensorArea {
        id: sensorArea
        anchors.fill: parent
        z: 20
        isExpanded: capsuleRoot.isExpanded
        isCollapsing: false
        isCalling: capsuleRoot.isCalling
        activeTransient: capsuleRoot.activeTransient
        isTucked: capsuleRoot.isTucked
        isPeeking: capsuleRoot.isPeeking

        onRequestTuck: { if (fsm) fsm.evRightClickHide() }
        onPinnedRestoreRequested: { if (fsm) fsm.evLeftClickPin() }
        onRequestSettingsWindow: capsuleRoot.requestSettings()
        onRequestExpand: (tab) => {
            if (fsm) fsm.evExpandCard()
            capsuleRoot.requestExpand(tab)
        }
        onMoveOffsetRequested: (deltaX) => capsuleRoot.applyDragDelta(deltaX)
        onDragFinished: (vX) => capsuleRoot.finishDrag(vX)
        onGoHomeRequested: capsuleRoot.goHome()
        onStartCollapse: { if (fsm) fsm.evCollapseCard() }
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
        }
    }

    // 5. 顶端微弧唤醒区 (紧密贴合露出的 4.5px 优雅圆弧)
    MouseArea {
        id: tuckSensor
        z: 30
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(14, capsuleRoot.peekHeight + 6)
        enabled: capsuleRoot.isTucked
        visible: capsuleRoot.isTucked
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: { if (fsm) fsm.evHoverPeek() }
        onClicked: { if (fsm) fsm.evLeftClickPin() }
    }

    readonly property bool isHoverActive: sensorArea.isPointerHovered || (tuckSensor.enabled && tuckSensor.containsMouse)

    onIsHoverActiveChanged: {
        if (!isHoverActive) {
            if (fsm && fsm.stateName === "PEEKING") fsm.evHoverLeave()
        } else {
            if (fsm && fsm.stateName === "PEEKING") fsm.evHoverKeep()
        }
    }
}