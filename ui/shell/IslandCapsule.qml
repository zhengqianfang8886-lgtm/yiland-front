// ==========================================
// 📄 File: ui/shell/IslandCapsule.qml
// 🌟 纯净协调器版 (补全乐观掩码打通 · 彻底根除悬停脱靶)
// ==========================================
import QtQuick
import QtQuick.Controls
import "../views"
import "../components/capsule"

Item {
    id: capsuleRoot

    property real capsuleRadius: 19
    property real capsuleScaleX: 1.0
    property real capsuleScaleY: 1.0
    property real islandOffsetX: 0

    property var relay: null
    property var timeService: null
    property var enabledTabs: []
    property string chosenFont: ""
    readonly property string effectiveFont: chosenFont !== "" ? chosenFont : Theme.activeFont

    property real normalTopMargin: (typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined) ? Config.capsuleTopMargin : 8

    signal timerAlert(string title, string msg)
    signal sedentaryRested()
    signal sedentarySnooze()
    signal requestExpand(string tabName)
    signal requestSettings()

    width: 180; height: 38
    y: normalTopMargin
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: islandOffsetX

    transform: Scale {
        origin.x: capsuleRoot.width / 2
        origin.y: capsuleRoot.height / 2
        xScale: capsuleRoot.capsuleScaleX
        yScale: capsuleRoot.capsuleScaleY
    }

    IslandStageController {
        id: stage
        onStageGeometryRequested: (isModeSwitch) => capsuleRoot.resolveAndApplyGeometry(isModeSwitch)
        onModeSwitchTriggered: (isAnchored) => capsuleBackground.triggerModeHaptic(isAnchored)
    }

    IslandMotionCoordinator {
        id: coordinator
        targetHost: capsuleRoot
        stageCtrl: stage
        goalHeight: 38
        goalRadius: 19
        goalWidth: 180
        onMotionStarted: if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) Bridge.openFullCorridorForMotion()
        onMotionSettled: capsuleRoot.commitSettledMask()
    }

    readonly property alias isSettled: coordinator.isSettled
    readonly property alias stageEngine: stage

    readonly property bool isLongAlert: {
        if (!relay) return false
        var t = relay.alertTitle || ""
        var sub = relay.alertSubtitle || ""
        return (stage.activeOverlayKey === "ALERT") && ((t.length + sub.length) > 24 || sub.indexOf("\n") !== -1)
    }

    readonly property bool isPhysicallyDeepTucked: (stage.currentBaseTier === stage.tierTUCKED) && 
                                                  (stage.submergedSubTier === stage.subTierDEEP) &&
                                                  (capsuleRoot.y < 0) &&
                                                  !coordinator.isTuckingInProgress

    readonly property bool isExpandedState: (stage.currentBaseTier === stage.tierEXPANDED)
    readonly property bool isCompactContentVisible: !isPhysicallyDeepTucked && !isExpandedState

    onIsPhysicallyDeepTuckedChanged: {
        if (typeof Bridge !== "undefined" && Bridge.setUiActive) {
            Bridge.setUiActive(!isPhysicallyDeepTucked)
        }
        if (timeService) {
            timeService.isTucked = isPhysicallyDeepTucked
        }
    }

    function resolveAndApplyGeometry(isModeSwitch) {
        var tY = normalTopMargin
        var tW = 180
        var tH = 38
        var tR = 19

        if (isExpandedState) {
            tW = 420; tH = 240; tR = 24; tY = normalTopMargin
        } else if (stage.activeOverlayKey === "CALL") {
            tW = 320; tH = 46; tR = 23
        } else if (stage.activeOverlayKey === "SEDENTARY") {
            tW = 420; tH = 112; tR = 26
        } else if (stage.activeOverlayKey === "ALERT") {
            tW = Math.round(Math.min(420, Math.max(196, compactCapsuleView.alertContentImplicitWidth + 36)))
            tH = capsuleRoot.isLongAlert ? 66 : 50
            tR = 25
        } else if (stage.activeOverlayKey === "WORKSPACE") {
            tW = 210; tH = 38; tR = 19
        } else {
            tW = compactCapsuleView.naturalPillWidth
            tH = 38; tR = 19
        }

        if ((stage.currentBaseTier === stage.tierTUCKED) && (stage.submergedSubTier === stage.subTierDEEP)) {
            tY = -(tH - 4.5)
        }

        coordinator.syncAndAnimate(tY, tW, tH, tR, isModeSwitch === true)
    }

    // 🚀【核心补齐 1】：乐观物理掩码打通接口，彻底解决动效协调器的防御性空调用
    function commitMaskTarget(targetW, targetH) {
        if (typeof Bridge === "undefined" || !Bridge.applySettledMask) return
        var capX = Math.round((parent.width - targetW) / 2 + islandOffsetX)
        var safePad = 8
        Bridge.applySettledMask(Math.max(0, capX - safePad), 0, targetW + safePad * 2, targetH + safePad * 2)
    }

    Connections {
        target: compactCapsuleView
        enabled: !capsuleRoot.isExpandedState
        function onNaturalPillWidthChanged() {
            if (capsuleRoot.isPhysicallyDeepTucked) {
                if (Math.abs(capsuleRoot.width - compactCapsuleView.naturalPillWidth) >= 2) {
                    capsuleRoot.resolveAndApplyGeometry(false)
                }
            } else {
                capsuleRoot.resolveAndApplyGeometry(false)
            }
        }
    }

    function commitSettledMask() {
        if (typeof Bridge === "undefined" || !Bridge.applySettledMask) return
        if (!coordinator.isSettled) return

        var capW = Math.round(capsuleRoot.width)
        var capX = Math.round((parent.width - capW) / 2 + islandOffsetX)
        var safePad = 6

        if (capsuleRoot.isPhysicallyDeepTucked) {
            Bridge.applySettledMask(Math.max(0, capX - safePad), 0, capW + safePad * 2, 8)
            return
        }

        var targetH = Math.round(capsuleRoot.y + capsuleRoot.height)
        Bridge.applySettledMask(Math.max(0, capX - safePad), 0, capW + safePad * 2, targetH + safePad)
    }

    Behavior on islandOffsetX {
        NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.12 }
    }
    function goHome() { islandOffsetX = 0 }

    readonly property color currentEffectiveAccent: {
        if (stage.activeOverlayKey === "CALL") return Theme.media
        if (stage.activeOverlayKey === "SEDENTARY") return Qt.rgba(52/255, 211/255, 153/255, 1.0)
        if (stage.activeOverlayKey === "ALERT") return compactCapsuleView.alertThemeColor
        if (relay && relay.status === "Playing" && !isExpandedState) return relay.dominantColor
        return Qt.rgba(0, 0, 0, 0)
    }

    CapsuleBackground {
        id: capsuleBackground
        capsuleRadius: capsuleRoot.capsuleRadius
        accentColor: capsuleRoot.currentEffectiveAccent
        isHovered: sensorArea.isPointerHovered
    }

    Item {
        id: opticalAperture
        anchors.fill: parent
        clip: true
        visible: !capsuleRoot.isPhysicallyDeepTucked || coordinator.isTuckingInProgress

        CompactCapsuleView {
            id: compactCapsuleView
            anchors.fill: parent

            visible: capsuleRoot.isCompactContentVisible
            opacity: capsuleRoot.isCompactContentVisible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 130 } }

            chosenFont: capsuleRoot.effectiveFont
            activeTransient: stage.activeOverlayKey
            isCalling: stage.activeOverlayKey === "CALL"

            dominantColor: relay ? relay.dominantColor : "#22c55e"
            spec1: relay ? relay.spec1 : 0.2
            spec2: relay ? relay.spec2 : 0.2
            spec3: relay ? relay.spec3 : 0.2
            spec4: relay ? relay.spec4 : 0.2
            status: relay ? relay.status : "Paused"

            wsName: relay ? relay.wsName : ""
            wsCurrent: relay ? relay.wsCurrent : 1
            wsTotal: relay ? relay.wsTotal : 4
            wsList: relay ? relay.wsList : []

            displayDate: timeService ? timeService.displayDate : ""
            displayTime: timeService ? timeService.displayTime : "12:00"
            displaySeconds: timeService ? timeService.displaySeconds : ""
            displayPeriod: timeService ? timeService.displayPeriod : ""

            unreadNotifCount: relay ? relay.unreadCount : 0
            latestNotifAvatar: relay ? relay.latestNotifAvatar : ""
            memoryPercent: relay ? relay.memoryPercent : 0

            // 🚀 直接绑定 Bridge 单一事实源
            timerActive: (typeof Bridge !== "undefined") ? (Bridge.timerIsRunning || Bridge.timerIsPaused || Bridge.timerIsCompleted) : false
            timerFormattedText: {
                if (typeof Bridge === "undefined") return "25:00"
                var sec = Bridge.timerType === "stopwatch" ? Bridge.timerElapsedSec : Bridge.timerRemainingSec
                var m = Math.floor(sec / 60)
                var s = sec % 60
                return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
            }
            timerIsPaused: (typeof Bridge !== "undefined") ? Bridge.timerIsPaused : false
            timerIsCompleted: (typeof Bridge !== "undefined") ? Bridge.timerIsCompleted : false
            timerProgress: (typeof Bridge !== "undefined" && Bridge.timerTotalSec > 0) ? (Bridge.timerRemainingSec / Bridge.timerTotalSec) : 1.0

            continuousSitMinutes: 45
            onSedentaryRested: capsuleRoot.sedentaryRested()
            onSedentarySnooze: capsuleRoot.sedentarySnooze()
            onRequestExpandTab: (tab) => capsuleRoot.requestExpand(tab)
            onToggleTimer: {
                if (typeof Bridge !== "undefined") Bridge.toggleTimerPause()
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: 12
            z: 20
            visible: capsuleRoot.isExpandedState
            opacity: capsuleRoot.isExpandedState ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            ExpandedCardView {
                id: expandedCardView
                anchors.fill: parent
                chosenFont: capsuleRoot.effectiveFont
                enabledTabs: capsuleRoot.enabledTabs

                dominantColor: relay ? relay.dominantColor : "#22c55e"
                isCalling: stage.activeOverlayKey === "CALL"
                callTitle: relay ? relay.callTitle : ""
                callSubtitle: relay ? relay.callSubtitle : ""
                callAvatar: relay ? relay.callAvatar : ""

                title: relay ? relay.title : ""
                artist: relay ? relay.artist : ""
                status: relay ? relay.status : "Paused"
                artUrl: relay ? relay.artUrl : ""
                position: relay ? relay.position : 0
                duration: relay ? relay.duration : 0

                wsCurrent: relay ? relay.wsCurrent : 1
                wsTotal: relay ? relay.wsTotal : 4
                wsName: relay ? relay.wsName : ""
                wsList: relay ? relay.wsList : []

                downSpeedStr: relay ? relay.downSpeedStr : ""
                upSpeedStr: relay ? relay.upSpeedStr : ""
                localIp: relay ? relay.localIp : ""
            }

            Connections {
                target: expandedCardView
                ignoreUnknownSignals: true
                function onStartCollapse() { stage.requestCollapse() }
                function onRequestSettings() { capsuleRoot.requestSettings() }
            }
        }
    }

    CapsuleSensorArea {
        id: sensorArea
        anchors.fill: parent
        z: 10
        enabled: !capsuleRoot.isExpandedState
        isExpanded: capsuleRoot.isExpandedState
        isTucked: capsuleRoot.isPhysicallyDeepTucked
        isCalling: stage.activeOverlayKey === "CALL"
        activeTransient: stage.activeOverlayKey

        onRequestTuckToggle: stage.toggleTuck()
        onRequestSettingsWindow: capsuleRoot.requestSettings()
        onRequestExpand: (tab) => {
            if (expandedCardView) {
                expandedCardView.expandedTab = tab
            }
            stage.requestExpand()
        }
        onStartCollapse: stage.requestCollapse()
        onMoveOffsetRequested: (deltaX) => islandOffsetX = Math.max(-100, Math.min(100, islandOffsetX + deltaX))
        onDragFinished: (velocityX) => { if (Math.abs(islandOffsetX) < 35) goHome() }
        onGoHomeRequested: goHome()
        onWheelScrolled: (deltaY) => {
            if (typeof Bridge !== "undefined") {
                if (deltaY > 0) Bridge.switchWorkspacePrev()
                else Bridge.switchWorkspaceNext()
            }
        }
    }
}