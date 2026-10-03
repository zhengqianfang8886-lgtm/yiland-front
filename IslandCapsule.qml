import QtQuick
import QtQuick.Controls

Rectangle {
    id: capsuleRoot

    property string chosenFont: ""
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isMorphing: false
    property var enabledTabs: []

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
        NumberAnimation { target: capsuleRoot; property: "clipGlowOpacity"; to: 0.95; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: capsuleRoot; property: "clipGlowOpacity"; to: 0.0; duration: 340; easing.type: Easing.InOutQuad }
    }

    function triggerClipGlow() {
        clipGlowAnim.restart()
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
        }
    }

    function resetTimer() {
        if (expandedCardView.timerPageRef) {
            expandedCardView.timerPageRef.resetTimer()
        }
    }

    property bool anySubBubbleHovered: false
    property bool subBubbleInteracting: false

    readonly property bool isCapsuleDirectHovered: capsuleRootHover.hovered || (typeof hitSensorArea !== "undefined" && hitSensorArea.containsMouse)
    readonly property bool isMouseOver: isCapsuleDirectHovered || (isExpanded && anySubBubbleHovered)

    signal requestExpand(string tabName)
    signal requestSettings()
    signal maskCommitRequested()
    signal timerAlert(string title, string msg)

    readonly property bool isLongAlert: {
        if (capsuleRoot.activeTransient !== "ALERT") return false
        var totalLen = (capsuleRoot.alertTitle || "").length + (capsuleRoot.alertSubtitle || "").length
        return totalLen > 24 || (capsuleRoot.alertSubtitle || "").indexOf("\n") !== -1
    }

    readonly property int targetWidth: {
        if (capsuleRoot.isExpanded) return 430
        if (capsuleRoot.isCalling) return 320
        if (capsuleRoot.activeTransient === "SEDENTARY") return 520
        if (capsuleRoot.activeTransient === "ALERT") {
            var dynamicW = compactCapsuleView.alertContentImplicitWidth + 34
            return Math.min(450, Math.max(260, dynamicW))
        }
        if (capsuleRoot.activeTransient === "WORKSPACE") return 184
        return Math.max(130, compactCapsuleView.textRowImplicitWidth + 38)
    }

    readonly property int targetHeight: {
        if (capsuleRoot.isExpanded) return 240
        if (capsuleRoot.activeTransient === "SEDENTARY") return 108
        if (capsuleRoot.activeTransient === "ALERT") return capsuleRoot.isLongAlert ? 68 : 52
        return capsuleRoot.isCalling ? 44 : 36
    }

    readonly property bool isJellyStyle: (typeof Config !== "undefined" && Config.animStyle === "jelly")
    readonly property bool isNoticeActive: (activeTransient === "ALERT") || (activeTransient === "SEDENTARY") || isCalling
    readonly property bool isMorphGrowing: isExpanded || isNoticeActive

    z: 2
    anchors.top: parent.top
    anchors.topMargin: (typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined) ? Config.capsuleTopMargin : 6

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: Config.offsetX
    Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

    width: targetWidth
    height: targetHeight
    radius: isExpanded ? 28 : (activeTransient === "SEDENTARY" ? 26 : (isCalling ? 22 : (activeTransient === "ALERT" ? 20 : Math.min(height / 2, 27))))
    clip: false

    antialiasing: true
    smooth: true
    color: Theme.bgCapsule

    border.color: clipGlowOpacity > 0.01 ?
                  Qt.rgba(1.0, 1.0, 1.0, 0.35 + clipGlowOpacity * 0.65) :
                  (isCalling ? Qt.rgba(Theme.media.r, Theme.media.g, Theme.media.b, 0.85) :
                  ((activeTransient === "SEDENTARY") ? Qt.rgba(52, 211, 153, 0.8) :
                  ((activeTransient === "ALERT") ? Qt.rgba(compactCapsuleView.alertThemeColor.r, compactCapsuleView.alertThemeColor.g, compactCapsuleView.alertThemeColor.b, 0.7) :
                  ((status === "Playing" && !isExpanded) ? Qt.rgba(dominantColor.r, dominantColor.g, dominantColor.b, 0.55) :
                  ((isMouseOver || isExpanded) ? Qt.rgba(1, 1, 1, 0.32) : Qt.rgba(1, 1, 1, 0.18))))))

    border.width: 3

    Behavior on border.color {
        enabled: clipGlowOpacity <= 0.01
        ColorAnimation { duration: 200 }
    }

    Behavior on width {
        NumberAnimation {
            id: widthNumAnim
            duration: capsuleRoot.isMorphGrowing ? (capsuleRoot.isJellyStyle ? 280 : 220) : 170
            easing.type: capsuleRoot.isMorphGrowing ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: capsuleRoot.isMorphGrowing ? (capsuleRoot.isJellyStyle ? 1.10 : 1.05) : 1.0
            onRunningChanged: {
                capsuleRoot.isMorphing = running || heightNumAnim.running
                capsuleRoot.maskCommitRequested()
                if (!running && !heightNumAnim.running) {
                    capsuleRoot.onMorphFinished()
                }
            }
        }
    }

    Behavior on height {
        NumberAnimation {
            id: heightNumAnim
            duration: capsuleRoot.isMorphGrowing ? (capsuleRoot.isJellyStyle ? 240 : 200) : 160
            easing.type: capsuleRoot.isMorphGrowing ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: capsuleRoot.isMorphGrowing ? (capsuleRoot.isJellyStyle ? 1.12 : 1.04) : 1.0
            onRunningChanged: {
                capsuleRoot.isMorphing = running || widthNumAnim.running
                capsuleRoot.maskCommitRequested()
                if (!running && !widthNumAnim.running) {
                    capsuleRoot.onMorphFinished()
                }
            }
        }
    }

    Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    function onMorphFinished() {
        if (!isExpanded) {
            isCollapsing = false
            maskCommitRequested()
            if (typeof Bridge !== "undefined" && Bridge.forceClearWindow) {
                Bridge.forceClearWindow()
            }
        } else {
            if (!capsuleRoot.isMouseOver) {
                capsuleRoot.startCollapse()
            }
        }
    }

    property bool scrollSessionLocked: false

    HoverHandler {
        id: capsuleRootHover
        onHoveredChanged: {
            if (hovered) {
                capsuleRoot.cancelCollapse()
                if (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing && !capsuleRoot.subBubbleInteracting) {
                    hoverDwellTimer.restart()
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
            if (!capsuleRoot.scrollSessionLocked && !capsuleRoot.subBubbleInteracting && !capsuleRoot.isCollapsing && capsuleRoot.isCapsuleDirectHovered && !capsuleRoot.isExpanded) {
                if (capsuleRoot.isCalling) {
                    capsuleRoot.requestExpand("media")
                } else if (capsuleRoot.activeTransient === "ALERT") {
                    capsuleRoot.requestExpand("notification")
                } else if (capsuleRoot.activeTransient === "SEDENTARY") {
                    return
                } else {
                    capsuleRoot.requestExpand("workspace")
                }
            }
        }
    }

    Timer {
        id: leaveGraceTimer
        interval: 180
        onTriggered: {
            if (!capsuleRoot.isMouseOver && capsuleRoot.isExpanded) {
                capsuleRoot.startCollapse()
            }
        }
    }

    function cancelCollapse() { leaveGraceTimer.stop() }

    function requestCollapse() {
        if (isExpanded) {
            leaveGraceTimer.restart()
        }
    }

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
        if (capsuleRoot.isExpanded && capsuleRoot.expandedTab !== "workspace") {
            return
        }

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

    // 🚀 确保弹窗出现时，透明感应层不会遮挡弹窗内的点击
    MouseArea {
        id: hitSensorArea
        anchors.fill: parent
        anchors.topMargin: 0
        z: (capsuleRoot.isExpanded || capsuleRoot.isNoticeActive) ? -1 : 1
        hoverEnabled: true

        acceptedButtons: capsuleRoot.isExpanded ? Qt.NoButton : (Qt.LeftButton | Qt.RightButton)
        cursorShape: capsuleRoot.isExpanded ? Qt.ArrowCursor : Qt.PointingHandCursor

        onEntered: {
            capsuleRoot.cancelCollapse()
            capsuleRoot.scrollSessionLocked = false
            if (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing && !capsuleRoot.subBubbleInteracting) {
                hoverDwellTimer.restart()
            }
        }
        onExited: {
            hoverDwellTimer.stop()
            capsuleRoot.scrollSessionLocked = false
            capsuleRoot.requestCollapse()
        }
        onWheel: (wheel) => {
            wheel.accepted = true
            if (!capsuleRoot.isExpanded || capsuleRoot.expandedTab === "workspace") {
                capsuleRoot.handleWheelAction(wheel.angleDelta.y)
            }
        }
        onClicked: (mouse) => {
            if (capsuleRoot.isExpanded || capsuleRoot.activeTransient === "SEDENTARY") return

            hoverDwellTimer.stop()
            leaveGraceTimer.stop()
            capsuleRoot.scrollSessionLocked = false

            if (mouse.button === Qt.RightButton) { capsuleRoot.requestSettings(); return }
            if (capsuleRoot.isCalling) { capsuleRoot.requestExpand("media"); return }
            if (capsuleRoot.activeTransient === "ALERT") { capsuleRoot.requestExpand("notification"); return }

            capsuleRoot.requestExpand("time")
        }
    }

    // 1. 常态与所有瞬态弹窗视图 (ALERT, SEDENTARY, OSD, WORKSPACE, CALL)
    CompactCapsuleView {
        id: compactCapsuleView
        anchors.fill: parent
        z: 5

        // 🚀【核心修复】：移除 height <= 44 的致命判定！
        // 只要不是点击展开大卡片，所有小胶囊弹窗均无条件渲染显示
        visible: opacity > 0.01
        opacity: !capsuleRoot.isExpanded ? 1.0 : 0.0
        scale: opacity > 0.5 ? 1.0 : 0.94

        showNetSpeed: Config.showNetSpeed; chosenFont: capsuleRoot.chosenFont; activeTransient: capsuleRoot.activeTransient
        status: capsuleRoot.status; isCalling: capsuleRoot.isCalling; isExpanded: capsuleRoot.isExpanded; isCollapsing: capsuleRoot.isCollapsing
        wsName: capsuleRoot.wsName; wsCurrent: capsuleRoot.wsCurrent; wsTotal: capsuleRoot.wsTotal
        osdIcon: capsuleRoot.osdIcon; osdValue: capsuleRoot.osdValue
        alertTitle: capsuleRoot.alertTitle; alertSubtitle: capsuleRoot.alertSubtitle; alertAvatar: capsuleRoot.alertAvatar; alertIcon: capsuleRoot.alertIcon
        callTitle: capsuleRoot.callTitle; callSubtitle: capsuleRoot.callSubtitle; callAvatar: capsuleRoot.callAvatar
        displayDate: capsuleRoot.displayDate; displayTime: capsuleRoot.displayTime; displaySeconds: capsuleRoot.displaySeconds; displayPeriod: capsuleRoot.displayPeriod
        downCompact: capsuleRoot.downCompact; upCompact: capsuleRoot.upCompact

        continuousSitMinutes: capsuleRoot.continuousSitMinutes
        onSedentaryRested: capsuleRoot.sedentaryRested()
        onSedentarySnooze: capsuleRoot.sedentarySnooze()

        Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
    }

    // 2. 展开大卡片视图容器 (仅在主动点击展开时呈现)
    Item {
        anchors.fill: parent
        clip: false

        ExpandedCardView {
            id: expandedCardView
            width: 398; height: 208
            z: 20
            anchors.top: parent.top
            anchors.topMargin: (typeof Config !== "undefined" && Config.expandedTopMargin !== undefined) ? Config.expandedTopMargin : 16
            anchors.horizontalCenter: parent.horizontalCenter

            visible: opacity > 0.01
            opacity: (capsuleRoot.isExpanded && capsuleRoot.height > 100) ? 1.0 : 0.0
            scale: capsuleRoot.isExpanded ? 1.0 : 0.94
            chosenFont: capsuleRoot.chosenFont

            enabledTabs: capsuleRoot.enabledTabs
            dominantColor: capsuleRoot.dominantColor

            isCalling: capsuleRoot.isCalling; callTitle: capsuleRoot.callTitle; callSubtitle: capsuleRoot.callSubtitle; callAvatar: capsuleRoot.callAvatar
            title: capsuleRoot.title; artist: capsuleRoot.artist; status: capsuleRoot.status; artUrl: capsuleRoot.artUrl; position: capsuleRoot.position; duration: capsuleRoot.duration
            wsCurrent: capsuleRoot.wsCurrent; wsTotal: capsuleRoot.wsTotal; wsName: capsuleRoot.wsName; wsList: capsuleRoot.wsList
            downSpeedStr: capsuleRoot.downSpeedStr; upSpeedStr: capsuleRoot.upSpeedStr; localIp: capsuleRoot.localIp; activeTransient: capsuleRoot.activeTransient

            onCancelCollapse: capsuleRoot.cancelCollapse()
            onRequestCollapse: capsuleRoot.requestCollapse()
            onStartCollapse: capsuleRoot.startCollapse()
            onTimerCompleted: (t, msg) => capsuleRoot.timerAlert(t, msg)

            Behavior on opacity {
                NumberAnimation { duration: capsuleRoot.isExpanded ? 140 : 40; easing.type: Easing.OutQuad }
            }
            Behavior on scale {
                NumberAnimation { duration: capsuleRoot.isExpanded ? 180 : 60; easing.type: Easing.OutBack; easing.overshoot: 1.04 }
            }
        }
    }
}