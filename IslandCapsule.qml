import QtQuick
import QtQuick.Controls

Rectangle {
    id: capsuleRoot

    property string chosenFont: ""
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isMorphing: false
    property string expandedTab: "workspace"
    property var enabledTabs: []

    // 业务数据属性
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

    // 基础状态派发 (零别名链死锁)
    readonly property bool timerRunning: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.isRunning : false
    readonly property string timerFormattedText: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.formattedTime : "25:00"
    readonly property bool timerHasHours: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.hasHours : false
    readonly property bool timerIsCountUp: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.isCountUp : false
    readonly property real timerProgress: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.progress : 0.0
    readonly property int timerRemaining: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.remainingSeconds : 0
    readonly property int timerTotal: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.totalSeconds : 0

    // 🚀 核心优化：全岛互保状态——主岛或任何一个副岛处于悬停，整体都不收拢！(唯一声明)
    property bool anySubBubbleHovered: false
    readonly property bool isMouseOver: (typeof capsuleHover !== "undefined" && capsuleHover.hovered) || 
                                        (typeof capsuleMouseArea !== "undefined" && capsuleMouseArea.containsMouse) || 
                                        anySubBubbleHovered

    signal requestExpand(string tabName)
    signal requestSettings()
    signal maskCommitRequested()
    signal timerAlert(string title, string msg)

    readonly property bool isLongAlert: {
        if (capsuleRoot.activeTransient !== "ALERT") return false
        var totalLen = (capsuleRoot.alertTitle || "").length + (capsuleRoot.alertSubtitle || "").length
        return totalLen > 18 || (capsuleRoot.alertSubtitle || "").indexOf("\n") !== -1
    }

    readonly property int targetWidth: {
        if (capsuleRoot.isExpanded) return 430
        if (capsuleRoot.isCalling) return 250
        if (capsuleRoot.activeTransient === "ALERT") {
            var rawLen = (capsuleRoot.alertTitle || "").length + (capsuleRoot.alertSubtitle || "").length
            return rawLen > 30 ? 430 : (rawLen > 16 ? 400 : 360)
        }
        if (capsuleRoot.activeTransient === "WORKSPACE") return Math.max(148, compactCapsuleView.wsRowImplicitWidth + 48)
        if (capsuleRoot.activeTransient === "OSD") return 175
        return Math.max(124, compactCapsuleView.textRowImplicitWidth + 46)
    }

    readonly property int targetHeight: {
        if (capsuleRoot.isExpanded) return 240
        if (capsuleRoot.activeTransient === "ALERT") return capsuleRoot.isLongAlert ? 68 : 52
        return capsuleRoot.isCalling ? 38 : 36
    }

    // 阻尼物理参数
    readonly property bool isJellyStyle: (typeof Config !== "undefined" && Config.animStyle === "jelly")
    readonly property int durExpandW: isJellyStyle ? 340 : 240
    readonly property int durExpandH: isJellyStyle ? 260 : 230
    readonly property real overshootW: isJellyStyle ? 1.08 : 1.018
    readonly property real overshootH: isJellyStyle ? 1.15 : 1.025
    readonly property int durCollapseW: isJellyStyle ? 210 : 220
    readonly property int durCollapseH: isJellyStyle ? 190 : 210

    z: 2
    anchors.top: parent.top
    anchors.topMargin: capsuleRoot.isExpanded ? 8 : 6
    Behavior on anchors.topMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: Config.offsetX
    Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

    width: targetWidth
    height: targetHeight
    radius: isExpanded ? 28 : (activeTransient === "ALERT" ? 26 : Math.min(height / 2, 27))
    clip: true
    color: Theme.bgCapsule
    border.color: (activeTransient === "ALERT") ? Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.6) :
                  ((capsuleMouseArea.containsMouse || isExpanded) ? Theme.borderFocus : Theme.borderSubtle)
    border.width: activeTransient === "ALERT" ? 1.5 : 1

    Behavior on width {
        NumberAnimation {
            id: widthNumAnim
            duration: capsuleRoot.isExpanded ? capsuleRoot.durExpandW : capsuleRoot.durCollapseW
            easing.type: capsuleRoot.isExpanded ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: capsuleRoot.isExpanded ? capsuleRoot.overshootW : 1.0
            onRunningChanged: {
                capsuleRoot.isMorphing = running || heightNumAnim.running
                if (!running) {
                    capsuleRoot.maskCommitRequested()
                    if (!capsuleRoot.isExpanded) cooldownTimer.restart()
                }
            }
        }
    }

    Behavior on height {
        NumberAnimation {
            id: heightNumAnim
            duration: capsuleRoot.isExpanded ? capsuleRoot.durExpandH : capsuleRoot.durCollapseH
            easing.type: capsuleRoot.isExpanded ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: capsuleRoot.isExpanded ? capsuleRoot.overshootH : 1.0
            onRunningChanged: {
                capsuleRoot.isMorphing = running || widthNumAnim.running
                if (!running) capsuleRoot.maskCommitRequested()
            }
        }
    }

    Behavior on radius { NumberAnimation { duration: capsuleRoot.isExpanded ? 200 : 170; easing.type: Easing.OutCubic } }

    Timer {
        id: hoverDwellTimer
        interval: 180
        onTriggered: {
            if (!capsuleRoot.isCollapsing && capsuleRoot.isMouseOver && !capsuleRoot.isExpanded) {
                if (capsuleRoot.activeTransient === "ALERT") capsuleRoot.requestExpand("notification")
                else capsuleRoot.requestExpand("workspace")
            }
        }
    }

    Timer {
        id: leaveGraceTimer
        interval: 280
        onTriggered: { if (!capsuleRoot.isCalling && !capsuleRoot.isMouseOver) capsuleRoot.startCollapse() }
    }

    Timer {
        id: cooldownTimer
        interval: 140
        onTriggered: {
            capsuleRoot.isCollapsing = false
            capsuleRoot.maskCommitRequested()
            if (capsuleRoot.isMouseOver && !capsuleRoot.isExpanded) hoverDwellTimer.restart()
        }
    }

    function cancelCollapse() { leaveGraceTimer.stop() }
    function requestCollapse() { if (!isCalling && isExpanded) leaveGraceTimer.restart() }
    function startCollapse() {
        if (!isExpanded) return
        isCollapsing = true
        hoverDwellTimer.stop()
        leaveGraceTimer.stop()
        isExpanded = false
        if (activeTransient === "ALERT") activeTransient = ""
    }

    HoverHandler {
        id: capsuleHover
        onHoveredChanged: {
            if (hovered) {
                capsuleRoot.cancelCollapse()
                if (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) hoverDwellTimer.restart()
            } else {
                hoverDwellTimer.stop()
                capsuleRoot.requestCollapse()
            }
        }
    }

    MouseArea {
        id: capsuleMouseArea
        anchors.fill: parent; hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onEntered: { capsuleRoot.cancelCollapse(); if (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) hoverDwellTimer.restart() }
        onExited: { hoverDwellTimer.stop(); capsuleRoot.requestCollapse() }
        onWheel: (wheel) => {
            if (!capsuleRoot.isExpanded || capsuleRoot.expandedTab === "workspace") {
                if (typeof Bridge !== "undefined") {
                    if (wheel.angleDelta.y > 0) Bridge.switchWorkspacePrev()
                    else if (wheel.angleDelta.y < 0) Bridge.switchWorkspaceNext()
                }
            }
        }
        onClicked: (mouse) => {
            hoverDwellTimer.stop(); leaveGraceTimer.stop()
            if (mouse.button === Qt.RightButton) { capsuleRoot.requestSettings(); return }
            if (capsuleRoot.isCalling) { Bridge.focusTeamsWindow(); return }
            if (capsuleRoot.activeTransient === "ALERT") { capsuleRoot.requestExpand("notification"); return }
            capsuleRoot.requestExpand("workspace")
        }
    }

    // 常态小文字：收拢等待 150ms 后柔光呼吸点亮
    CompactCapsuleView {
        id: compactCapsuleView
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
        opacity: (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? 1 : 0
        scale: (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? 1.0 : 0.94
        visible: opacity > 0.01

        showNetSpeed: Config.showNetSpeed; chosenFont: capsuleRoot.chosenFont; activeTransient: capsuleRoot.activeTransient
        status: capsuleRoot.status; isCalling: capsuleRoot.isCalling; isExpanded: capsuleRoot.isExpanded; isCollapsing: capsuleRoot.isCollapsing
        wsName: capsuleRoot.wsName; wsCurrent: capsuleRoot.wsCurrent; wsTotal: capsuleRoot.wsTotal
        osdIcon: capsuleRoot.osdIcon; osdValue: capsuleRoot.osdValue
        alertTitle: capsuleRoot.alertTitle; alertSubtitle: capsuleRoot.alertSubtitle; alertAvatar: capsuleRoot.alertAvatar; alertIcon: capsuleRoot.alertIcon
        callTitle: capsuleRoot.callTitle; callSubtitle: capsuleRoot.callSubtitle; callAvatar: capsuleRoot.callAvatar
        displayDate: capsuleRoot.displayDate; displayTime: capsuleRoot.displayTime; displaySeconds: capsuleRoot.displaySeconds; displayPeriod: capsuleRoot.displayPeriod
        downCompact: capsuleRoot.downCompact; upCompact: capsuleRoot.upCompact

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? 150 : 0 }
                NumberAnimation {
                    duration: (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? 120 : 0
                    easing.type: Easing.OutCubic
                }
            }
        }
        Behavior on scale {
            SequentialAnimation {
                PauseAnimation { duration: (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? 150 : 0 }
                NumberAnimation {
                    duration: (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? 160 : 0
                    easing.type: Easing.OutBack; easing.overshoot: 1.05
                }
            }
        }
    }

    // 大卡片内容：收起时 0ms 瞬间蒸发隐形
    ExpandedCardView {
        id: expandedCardView
        width: 398; height: 208
        anchors.top: parent.top; anchors.topMargin: 16; anchors.horizontalCenter: parent.horizontalCenter
        opacity: (capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? 1 : 0
        scale: (capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? 1.0 : (capsuleRoot.isJellyStyle ? 0.92 : 0.97)
        visible: opacity > 0.01
        chosenFont: capsuleRoot.chosenFont
        
        expandedTab: capsuleRoot.expandedTab
        enabledTabs: capsuleRoot.enabledTabs
        
        isCalling: capsuleRoot.isCalling; callTitle: capsuleRoot.callTitle; callSubtitle: capsuleRoot.callSubtitle; callAvatar: capsuleRoot.callAvatar
        title: capsuleRoot.title; artist: capsuleRoot.artist; status: capsuleRoot.status; artUrl: capsuleRoot.artUrl; position: capsuleRoot.position; duration: capsuleRoot.duration
        wsCurrent: capsuleRoot.wsCurrent; wsTotal: capsuleRoot.wsTotal; wsName: capsuleRoot.wsName; wsList: capsuleRoot.wsList
        downSpeedStr: capsuleRoot.downSpeedStr; upSpeedStr: capsuleRoot.upSpeedStr; localIp: capsuleRoot.localIp; activeTransient: capsuleRoot.activeTransient

        onCancelCollapse: capsuleRoot.cancelCollapse()
        onRequestCollapse: capsuleRoot.requestCollapse()
        onStartCollapse: capsuleRoot.startCollapse()
        onTimerCompleted: (t, msg) => capsuleRoot.timerAlert(t, msg)
        onTabSelected: (key) => capsuleRoot.expandedTab = key

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: (capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? (capsuleRoot.isJellyStyle ? 80 : 50) : 0 }
                NumberAnimation {
                    duration: (capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? 140 : 0
                    easing.type: Easing.OutQuad
                }
            }
        }
        Behavior on scale {
            SequentialAnimation {
                PauseAnimation { duration: (capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? (capsuleRoot.isJellyStyle ? 80 : 50) : 0 }
                NumberAnimation {
                    duration: (capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? (capsuleRoot.isJellyStyle ? 240 : 170) : 0
                    easing.type: (capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? Easing.OutBack : Easing.InQuad
                    easing.overshoot: (capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) ? (capsuleRoot.isJellyStyle ? 1.08 : 1.02) : 1.0
                }
            }
        }
    }
}