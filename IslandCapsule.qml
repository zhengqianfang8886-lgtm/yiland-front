// ==========================================
// 📄 File: IslandCapsule.qml (自适应出水尺寸完整版)
// ==========================================
import QtQuick
import QtQuick.Controls
import "capsule"

Item {
    id: capsuleRoot

    property real capsuleRadius: 17
    width: 160
    height: 34
    y: 8

    signal timerAlert(string title, string msg)
    signal sedentaryRested()
    signal sedentarySnooze()
    signal requestExpand(string tabName)
    signal requestSettings()

    IslandStageController {
        id: stage
        onStageGeometryRequested: capsuleRoot.resolveAndApplyGeometry()
    }

    IslandMotionCoordinator {
        id: coordinator
        targetHost: capsuleRoot
        stageCtrl: stage
        onMotionStarted: if (typeof Bridge !== "undefined") Bridge.openFullCorridorForMotion()
        onMotionSettled: capsuleRoot.commitSettledMask()
    }

    readonly property alias isSettled: coordinator.isSettled
    readonly property alias stageEngine: stage

    property var relay: null
    property var timeService: null
    property var enabledTabs: []

    property string chosenFont: ""
    readonly property string effectiveFont: chosenFont !== "" ? chosenFont : Theme.activeFont

    function commitSettledMask() {
        if (typeof Bridge === "undefined") return
        if (!coordinator.isSettled) return

        var capW = Math.round(capsuleRoot.width)
        var capX = Math.round((parent.width - capW) / 2 + islandOffsetX)
        var safePad = 6

        if (capsuleRoot.isPhysicallyDeepTucked) {
            Bridge.applySettledMask(Math.max(0, capX - safePad), 0, capW + safePad * 2, 8)
            return
        }

        var targetH = Math.round(capsuleRoot.y + capsuleRoot.height)
        Bridge.applySettledMask(
            Math.max(0, capX - safePad),
            0,
            capW + safePad * 2,
            targetH + safePad
        )
    }

    readonly property bool isLongAlert: {
        if (!relay) return false
        var t = relay.alertTitle || ""
        var sub = relay.alertSubtitle || ""
        return (stage.activeOverlayKey === "ALERT") && ((t.length + sub.length) > 24 || sub.indexOf("\n") !== -1)
    }

    // 判断是否处于完全深潜吸顶状态
    readonly property bool isPhysicallyDeepTucked: (stage.currentBaseTier === stage.tierTUCKED) && 
                                                  (stage.submergedSubTier === stage.subTierDEEP)

    readonly property bool isCompactContentVisible: !isPhysicallyDeepTucked && (stage.currentBaseTier !== stage.tierEXPANDED)
    readonly property bool isExpandedState: stage.currentBaseTier === stage.tierEXPANDED

    // =========================================================================
    // 集中式几何解析（出水时直接按完整尺寸展开，绝不出现窄卡片切边）
    // =========================================================================
    function resolveAndApplyGeometry() {
        var normalMargin = (typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined) ? Config.capsuleTopMargin : 8
        var nW = Math.max(160, compactCapsuleView.implicitCompactWidth)
        var tY = normalMargin
        var tW = nW
        var tH = 34
        var tR = 17

        if (capsuleRoot.isExpandedState) {
            tW = 420; tH = 240; tR = 24; tY = normalMargin
        } else if (stage.activeOverlayKey === "CALL") {
            tW = 320; tH = 44; tR = 22
        } else if (stage.activeOverlayKey === "SEDENTARY") {
            tW = 420; tH = 108; tR = 26
        } else if (stage.activeOverlayKey === "ALERT") {
            tW = Math.round(Math.min(420, Math.max(160, compactCapsuleView.alertContentImplicitWidth + 28)))
            tH = capsuleRoot.isLongAlert ? 64 : 48
            tR = 24
        } else if (stage.activeOverlayKey === "WORKSPACE") {
            tW = Math.max(170, Math.min(260, compactCapsuleView.wsContentImplicitWidth + 28))
        } else {
            // 常态播放、切歌被动出水（MEDIA_PEEK）：无条件等于满额波形自适应宽度！
            tW = nW
            tH = 34
            tR = 17
        }

        // 若处于深潜状态，物理 Y 轴退回到天花板以上（仅露 4.5px 微弧）
        if (capsuleRoot.isPhysicallyDeepTucked) {
            tY = -(tH - 4.5)
        }

        coordinator.syncAndAnimate(tY, tW, tH, tR)
    }

    Connections {
        target: compactCapsuleView
        function onImplicitCompactWidthChanged() {
            capsuleRoot.resolveAndApplyGeometry()
        }
    }

    property real islandOffsetX: 0
    Behavior on islandOffsetX {
        NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.12 }
    }
    function goHome() { islandOffsetX = 0 }

    readonly property color currentEffectiveAccent: {
        if (stage.activeOverlayKey === "CALL") return Theme.media
        if (stage.activeOverlayKey === "SEDENTARY") return Qt.rgba(52/255, 211/255, 153/255, 1.0)
        if (stage.activeOverlayKey === "ALERT") return compactCapsuleView.alertThemeColor
        if (relay && relay.status === "Playing" && !capsuleRoot.isExpandedState) return relay.dominantColor
        return Qt.rgba(0, 0, 0, 0)
    }

    // 1. 底板外框
    CapsuleBackground {
        id: capsuleBackground
        capsuleRadius: capsuleRoot.capsuleRadius
        accentColor: capsuleRoot.currentEffectiveAccent
        isHovered: sensorArea.isPointerHovered
    }

    // 2. 光学视口容器
    Item {
        id: opticalAperture
        anchors.fill: parent
        clip: true
        visible: !capsuleRoot.isPhysicallyDeepTucked

        CompactCapsuleView {
            id: compactCapsuleView
            anchors.fill: parent

            visible: opacity > 0.001
            opacity: capsuleRoot.isCompactContentVisible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 130 } }

            showNetSpeed: false
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

            timerActive: (expandedCardView && expandedCardView.timerActive !== undefined) ? expandedCardView.timerActive : false
            timerFormattedText: (expandedCardView && expandedCardView.timerFormattedText !== undefined) ? expandedCardView.timerFormattedText : "25:00"
            timerIsPaused: (expandedCardView && expandedCardView.timerIsPaused !== undefined) ? expandedCardView.timerIsPaused : false
            timerIsCompleted: (expandedCardView && expandedCardView.timerIsCompleted !== undefined) ? expandedCardView.timerIsCompleted : false
            timerProgress: (expandedCardView && expandedCardView.timerProgress !== undefined) ? expandedCardView.timerProgress : 1.0

            continuousSitMinutes: 45
            onSedentaryRested: capsuleRoot.sedentaryRested()
            onSedentarySnooze: capsuleRoot.sedentarySnooze()
            onRequestExpandTab: (tab) => capsuleRoot.requestExpand(tab)
            onToggleTimer: {
                if (expandedCardView && expandedCardView.toggleTimerPause) {
                    expandedCardView.toggleTimerPause()
                }
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: 12
            z: 20
            visible: opacity > 0.01
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
                function onStartCollapse() {
                    stage.requestCollapse()
                }
                function onRequestSettings() {
                    capsuleRoot.requestSettings()
                }
                function onTimerCompleted(title, message) {
                    capsuleRoot.timerAlert(title, message)
                }
            }
        }
    }

    // 3. 紧凑态手势层
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