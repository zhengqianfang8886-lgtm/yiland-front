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

    readonly property bool timerRunning: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.isRunning : false
    readonly property string timerFormattedText: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.formattedTime : "25:00"
    readonly property bool timerHasHours: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.hasHours : false
    readonly property bool timerIsCountUp: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.isCountUp : false
    readonly property real timerProgress: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.progress : 0.0
    readonly property int timerRemaining: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.remainingSeconds : 0
    readonly property int timerTotal: expandedCardView.timerPageRef ? expandedCardView.timerPageRef.totalSeconds : 0

    property bool anySubBubbleHovered: false

    readonly property bool isMouseOver: capsuleRootHover.hovered || (typeof hitSensorArea !== "undefined" && hitSensorArea.containsMouse) || anySubBubbleHovered

    signal requestExpand(string tabName)
    signal requestSettings()
    signal maskCommitRequested()
    signal timerAlert(string title, string msg)

    readonly property bool isLongAlert: {
        if (capsuleRoot.activeTransient !== "ALERT") return false
        var totalLen = (capsuleRoot.alertTitle || "").length + (capsuleRoot.alertSubtitle || "").length
        return totalLen > 20 || (capsuleRoot.alertSubtitle || "").indexOf("\n") !== -1
    }

    readonly property int targetWidth: {
        if (capsuleRoot.isExpanded) return 430
        if (capsuleRoot.isCalling) return 260
        if (capsuleRoot.activeTransient === "ALERT") {
            var rawLen = (capsuleRoot.alertTitle || "").length + (capsuleRoot.alertSubtitle || "").length
            return rawLen > 24 ? 470 : (rawLen > 12 ? 430 : 400)
        }
        if (capsuleRoot.activeTransient === "WORKSPACE") return 184
        if (capsuleRoot.activeTransient === "OSD") return 175
        return Math.max(130, compactCapsuleView.textRowImplicitWidth + 48)
    }

    readonly property int targetHeight: {
        if (capsuleRoot.isExpanded) return 240
        if (capsuleRoot.activeTransient === "ALERT") return capsuleRoot.isLongAlert ? 72 : 58
        return capsuleRoot.isCalling ? 38 : 36
    }

    readonly property bool isJellyStyle: (typeof Config !== "undefined" && Config.animStyle === "jelly")
    readonly property int durExpandW: isJellyStyle ? 340 : 240
    readonly property int durExpandH: isJellyStyle ? 260 : 230
    readonly property real overshootW: isJellyStyle ? 1.08 : 1.018
    readonly property real overshootH: isJellyStyle ? 1.15 : 1.025
    readonly property int durCollapseW: isJellyStyle ? 200 : 210
    readonly property int durCollapseH: isJellyStyle ? 180 : 190

    z: 2
    anchors.top: parent.top
    anchors.topMargin: (typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined) ? Config.capsuleTopMargin : 6

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: Config.offsetX
    Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

    width: targetWidth
    height: targetHeight
    radius: isExpanded ? 28 : (activeTransient === "ALERT" ? 22 : Math.min(height / 2, 27))
    clip: false
    
    color: Theme.bgCapsule
    border.color: (activeTransient === "ALERT") ? Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.75) :
                  ((isMouseOver || isExpanded) ? Theme.borderFocus : Theme.borderSubtle)
    border.width: activeTransient === "ALERT" ? 1.8 : 1

    Behavior on width {
        NumberAnimation {
            id: widthNumAnim
            duration: capsuleRoot.isExpanded ? capsuleRoot.durExpandW : capsuleRoot.durCollapseW
            easing.type: capsuleRoot.isExpanded ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: capsuleRoot.isExpanded ? capsuleRoot.overshootW : 1.0
            onRunningChanged: {
                capsuleRoot.isMorphing = running || heightNumAnim.running
                capsuleRoot.maskCommitRequested()
                if (!running) {
                    if (!capsuleRoot.isExpanded) cooldownTimer.restart()
                    if (capsuleRoot.isExpanded && !capsuleRoot.isMouseOver && !capsuleRoot.isCalling) {
                        capsuleRoot.startCollapse()
                    }
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
                capsuleRoot.maskCommitRequested()
                if (!running && capsuleRoot.isExpanded && !capsuleRoot.isMouseOver && !capsuleRoot.isCalling) {
                    capsuleRoot.startCollapse()
                }
            }
        }
    }

    Behavior on radius { NumberAnimation { duration: capsuleRoot.isExpanded ? 200 : 170; easing.type: Easing.OutCubic } }

    // ========================================================
    // 🚀 核心状态机：严格错峰显隐，彻底杜绝浮空残影与双重曝光
    // ========================================================
    property bool contentReady: false
    property bool clockReady: true

    Timer {
        id: contentRevealTimer
        interval: capsuleRoot.isJellyStyle ? 160 : 130
        onTriggered: capsuleRoot.contentReady = true
    }

    Timer {
        id: clockRevealTimer
        interval: 140
        onTriggered: capsuleRoot.clockReady = true
    }

    onIsExpandedChanged: {
        if (isExpanded) {
            // 展开开始：小时间立即灭灯（0ms），卡片内容暂不开启，等黑底撑开 130ms 后再优雅浮现
            clockReady = false
            clockRevealTimer.stop()
            contentReady = false
            contentRevealTimer.restart()
        } else {
            // 收缩开始：大卡片内容已在 startCollapse 瞬间掐灭，启动定时器等黑壳缩回后淡入时钟
            contentRevealTimer.stop()
            contentReady = false
            clockReady = false
            clockRevealTimer.restart()
        }
    }

    property bool scrollSessionLocked: false

    HoverHandler {
        id: capsuleRootHover
        onHoveredChanged: {
            if (hovered) {
                capsuleRoot.cancelCollapse()
                if (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) {
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
            if (!capsuleRoot.scrollSessionLocked && !capsuleRoot.isCollapsing && capsuleRoot.isMouseOver && !capsuleRoot.isExpanded) {
                if (capsuleRoot.activeTransient === "ALERT") capsuleRoot.requestExpand("notification")
                else capsuleRoot.requestExpand("workspace")
            }
        }
    }

    Timer {
        id: leaveGraceTimer
        interval: 180
        onTriggered: {
            if (!capsuleRoot.isCalling && !capsuleRoot.isMouseOver && capsuleRoot.isExpanded) {
                capsuleRoot.startCollapse()
            }
        }
    }

    Timer {
        id: cooldownTimer
        interval: 100
        onTriggered: {
            capsuleRoot.isCollapsing = false
            capsuleRoot.maskCommitRequested()
            if (capsuleRoot.isMouseOver && !capsuleRoot.isExpanded && !capsuleRoot.scrollSessionLocked) hoverDwellTimer.restart()
        }
    }

    function cancelCollapse() { leaveGraceTimer.stop() }

    function requestCollapse() {
        if (!isCalling && isExpanded) {
            leaveGraceTimer.restart()
        }
    }

    function startCollapse() {
        if (!isExpanded) return
        // 🚀 核心关键：收拢第一帧（0ms）瞬间灭灯！绝不在收缩过程中产生任何浮空拖影
        contentRevealTimer.stop()
        contentReady = false
        isCollapsing = true
        hoverDwellTimer.stop()
        leaveGraceTimer.stop()
        isExpanded = false
        if (activeTransient === "ALERT") activeTransient = ""
        capsuleRoot.maskCommitRequested()
    }

    function handleWheelAction(deltaY) {
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
        anchors.topMargin: -(typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined ? Config.capsuleTopMargin : 6) - 2
        z: capsuleRoot.isExpanded ? -1 : 10
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            capsuleRoot.cancelCollapse()
            capsuleRoot.scrollSessionLocked = false
            if (!capsuleRoot.isExpanded && !capsuleRoot.isCollapsing) {
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
            capsuleRoot.handleWheelAction(wheel.angleDelta.y)
        }
        onClicked: (mouse) => {
            hoverDwellTimer.stop()
            leaveGraceTimer.stop()
            capsuleRoot.scrollSessionLocked = false

            if (mouse.button === Qt.RightButton) { capsuleRoot.requestSettings(); return }
            if (capsuleRoot.isCalling) { Bridge.focusTeamsWindow(); return }
            if (capsuleRoot.activeTransient === "ALERT") { capsuleRoot.requestExpand("notification"); return }
            capsuleRoot.requestExpand("workspace")
        }
    }

    // 1. 紧凑时钟视图（干净利落的单向淡出/淡入，彻底杜绝与大卡片重影）
    CompactCapsuleView {
        id: compactCapsuleView
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        visible: capsuleRoot.clockReady && !capsuleRoot.isExpanded
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.94

        showNetSpeed: Config.showNetSpeed; chosenFont: capsuleRoot.chosenFont; activeTransient: capsuleRoot.activeTransient
        status: capsuleRoot.status; isCalling: capsuleRoot.isCalling; isExpanded: capsuleRoot.isExpanded; isCollapsing: capsuleRoot.isCollapsing
        wsName: capsuleRoot.wsName; wsCurrent: capsuleRoot.wsCurrent; wsTotal: capsuleRoot.wsTotal
        osdIcon: capsuleRoot.osdIcon; osdValue: capsuleRoot.osdValue
        alertTitle: capsuleRoot.alertTitle; alertSubtitle: capsuleRoot.alertSubtitle; alertAvatar: capsuleRoot.alertAvatar; alertIcon: capsuleRoot.alertIcon
        callTitle: capsuleRoot.callTitle; callSubtitle: capsuleRoot.callSubtitle; callAvatar: capsuleRoot.callAvatar
        displayDate: capsuleRoot.displayDate; displayTime: capsuleRoot.displayTime; displaySeconds: capsuleRoot.displaySeconds; displayPeriod: capsuleRoot.displayPeriod
        downCompact: capsuleRoot.downCompact; upCompact: capsuleRoot.upCompact

        Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
    }

    // 2. 展开大卡片（🚀 物理裁剪安全容器 + 错峰显隐，彻底消除收放双向残影）
    Item {
        anchors.fill: parent
        clip: true // 物理底线：内容尺寸哪怕有半个像素超出当前黑底药丸，立刻被剪切，绝对无法在桌面上悬空裸露！

        ExpandedCardView {
            id: expandedCardView
            width: 398; height: 208
            z: 20
            anchors.top: parent.top
            anchors.topMargin: (typeof Config !== "undefined" && Config.expandedTopMargin !== undefined) ? Config.expandedTopMargin : 16
            anchors.horizontalCenter: parent.horizontalCenter

            // 展开时等待 130ms 黑底撑大后才变为 true；收缩时第 0 毫秒瞬间变为 false
            visible: capsuleRoot.contentReady && capsuleRoot.isExpanded
            opacity: visible ? 1.0 : 0.0
            scale: visible ? 1.0 : 0.95
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

            // 单向纯粹的展开淡入动画，不再有任何 QML 引擎未定义行为
            Behavior on opacity {
                NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
            }
            Behavior on scale {
                NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.04 }
            }
        }
    }
}