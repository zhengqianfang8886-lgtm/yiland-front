// ==========================================
// 📄 File: ui/views/CompactCapsuleView.qml
// 🌟 方案 A 微胶囊流体灌浆计时器 · 挂载语音动态视口版
// ==========================================
import QtQuick
import QtQuick.Shapes
import "../components/compact"

Item {
    id: compactRoot

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property bool isCapsuleHovered: false

    property string activeTransient: ""
    property string status: "Paused"
    property bool isCalling: false
    property bool isExpanded: false

    property bool isCapsLock: (typeof Bridge !== "undefined" && Bridge.isCapsLock !== undefined) ? Bridge.isCapsLock : false
    property bool isNumLock: (typeof Bridge !== "undefined" && Bridge.isNumLock !== undefined) ? Bridge.isNumLock : false

    property string wsName: ""
    property int wsCurrent: 0
    property int wsTotal: 4
    property var wsList: []

    property bool isScrubbing: false
    property bool isScrubCanceling: false

    property string osdIcon: "🔊"
    property int osdValue: 50
    property string alertTitle: ""
    property string alertSubtitle: ""
    property string alertAvatar: ""
    property string alertIcon: "🔔"
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""

    property string displayDate: ""
    property string displayTime: "04:53"
    property string displaySeconds: ""
    property string displayPeriod: "pm"

    readonly property bool isActivelyPlaying: status === "Playing"
    property bool waveVisible: false
    property bool hasEverPlayed: false

    onIsActivelyPlayingChanged: {
        if (isActivelyPlaying) {
            hasEverPlayed = true
            musicHideGraceTimer.stop()
            waveVisible = true
        } else {
            if (hasEverPlayed && waveVisible) {
                musicHideGraceTimer.restart()
            }
        }
    }

    Timer {
        id: musicHideGraceTimer
        interval: 4000
        repeat: false
        onTriggered: {
            if (!compactRoot.isActivelyPlaying) compactRoot.waveVisible = false
        }
    }

    property color dominantColor: "#22c55e"
    property real spec1: 0.2
    property real spec2: 0.2
    property real spec3: 0.2
    property real spec4: 0.2

    readonly property int barsCount: (typeof Config !== "undefined" && Config.musicVisualizerBars !== undefined) ?
                                     Math.max(3, Math.min(8, Config.musicVisualizerBars)) : 5
    readonly property real barW: 4.0
    readonly property real barGap: 2.5
    readonly property real barMaxH: 16.0
    readonly property int fullWaveWidth: Math.ceil((barsCount * barW) + ((barsCount - 1) * barGap))

    function getBarScale(index, total) {
        if (!isActivelyPlaying) return 0.22
        if (total <= 1) return spec1
        var t = index / (total - 1)
        var pos = t * 3.0
        var i0 = Math.floor(pos)
        var i1 = Math.min(3, i0 + 1)
        var frac = pos - i0
        var sArr = [spec1, spec2, spec3, spec4]
        var val = sArr[i0] * (1.0 - frac) + sArr[i1] * frac
        var resonance = 0.85 + 0.35 * Math.sin(t * Math.PI)
        return Math.max(0.15, Math.min(1.0, val * resonance))
    }

    property bool timerActive: false
    property string timerFormattedText: "25:00"
    property bool timerIsPaused: false
    property bool timerIsCompleted: false
    property real timerProgress: 1.0

    property int unreadNotifCount: 0
    property string latestNotifAvatar: ""
    property int memoryPercent: 0
    property int continuousSitMinutes: 45

    signal sedentaryRested()
    signal sedentarySnooze()
    signal requestExpandTab(string tabName)
    signal toggleTimer()

    readonly property int displayWsNumber: {
        var n = Number(wsCurrent)
        if (isNaN(n)) return 0
        if (wsName && /^\d+$/.test(wsName.trim())) return Number(wsName.trim())
        return n
    }

    readonly property bool showWsBadge: (typeof Config !== "undefined" && Config.showWorkspaceName !== false) && (compactRoot.wsName !== "" || compactRoot.displayWsNumber > 0)
    readonly property int slotWidthWs: showWsBadge ? Math.max(22, Math.ceil(wsBadgeDummy.implicitWidth + 14)) : 0

    Text {
        id: wsBadgeDummy
        text: compactRoot.wsName ? compactRoot.wsName : ("" + compactRoot.displayWsNumber)
        font.pixelSize: 11
        font.weight: Font.Black
        font.family: compactRoot.displayFont
        visible: false
    }

    readonly property int slotWidthWave: compactRoot.waveVisible ? compactRoot.fullWaveWidth : 0
    readonly property int slotWidthMem: (!compactRoot.waveVisible && compactRoot.memoryPercent >= ((typeof Config !== "undefined" && Config.memoryThreshold) ? Config.memoryThreshold : 75)) ? 18 : 0
    readonly property int slotWidthClock: Math.ceil(clockView.implicitWidth)

    property bool numLockToastActive: false
    property bool numLockActiveState: false
    readonly property int slotWidthNumLock: numLockToastActive ? Math.ceil(numLockTextDummy.implicitWidth + 14) : 0

    Text {
        id: numLockTextDummy
        text: compactRoot.numLockActiveState ? "123 ON" : "123 OFF"
        font.pixelSize: 10
        font.weight: Font.Black
        font.family: compactRoot.displayFont
        visible: false
    }

    readonly property int slotWidthTimer: compactRoot.timerActive ? 56 : 0
    readonly property int slotWidthNotif: compactRoot.unreadNotifCount > 0 ? Math.max(18, notifBadgeText.implicitWidth + 9) : 0

    readonly property bool showExpandBtn: compactRoot.isCapsuleHovered && !compactRoot.isCalling && (compactRoot.activeTransient === "" || compactRoot.activeTransient === "MEDIA_PEEK")
    readonly property int slotWidthExpandBtn: showExpandBtn ? 22 : 0

    readonly property int naturalPillWidth: {
        if (compactRoot.activeTransient === "VOICE_INPUT") return 320
        var slots = []
        if (slotWidthWs > 0) slots.push(slotWidthWs)
        if (slotWidthWave > 0) slots.push(slotWidthWave)
        else if (slotWidthMem > 0) slots.push(slotWidthMem)
        if (slotWidthClock > 0) slots.push(slotWidthClock)
        if (slotWidthNumLock > 0) slots.push(slotWidthNumLock)
        if (slotWidthTimer > 0) slots.push(slotWidthTimer)
        if (slotWidthNotif > 0) slots.push(slotWidthNotif)
        if (slotWidthExpandBtn > 0) slots.push(slotWidthExpandBtn)

        var total = 16 + 16
        for (var i = 0; i < slots.length; i++) {
            total += slots[i]
            if (i < slots.length - 1) total += 10
        }
        return Math.max(180, Math.ceil(total / 2) * 2)
    }

    readonly property int wsContentImplicitWidth: wsView.contentImplicitWidth
    readonly property int alertContentImplicitWidth: alertView.implicitContentWidth
    readonly property bool isAlertActive: (activeTransient === "ALERT") && !isCalling
    readonly property bool isOsdMode: (activeTransient === "OSD" && !isCalling && !isExpanded)

    readonly property color alertThemeColor: {
        if (alertIcon === "⏰") return Theme.timer
        if (["bluetooth", "ᛒ", "🎧", "🖱️", "⌨️", "📱"].indexOf(alertIcon) !== -1) return Theme.bluetooth
        if (alertIcon === "🛡️") return Theme.network
        if (alertIcon === "📞") return Theme.media
        return Theme.notification
    }

    property bool numLockInitialized: false
    onIsNumLockChanged: {
        if (!numLockInitialized) {
            numLockInitialized = true
            return
        }
        compactRoot.numLockActiveState = isNumLock
        compactRoot.numLockToastActive = true
        numLockLifecycleAnim.restart()
    }

    SequentialAnimation {
        id: numLockLifecycleAnim
        PauseAnimation { duration: 950 }
        ParallelAnimation {
            NumberAnimation { target: numLockToastItem; property: "opacity"; to: 0.0; duration: 250 }
            NumberAnimation { target: numLockToastItem; property: "scale"; to: 0.7; duration: 250 }
        }
        ScriptAction {
            script: {
                compactRoot.numLockToastActive = false
                numLockToastItem.opacity = 1.0
                numLockToastItem.scale = 1.0
            }
        }
    }

    CompactSedentaryView {
        id: sedentaryView
        chosenFont: compactRoot.effectiveFont
        continuousSitMinutes: compactRoot.continuousSitMinutes
        visible: opacity > 0.001
        opacity: (compactRoot.activeTransient === "SEDENTARY" && !compactRoot.isCalling && !compactRoot.isExpanded) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        onSedentaryRested: compactRoot.sedentaryRested()
        onSedentarySnooze: compactRoot.sedentarySnooze()
    }

    CompactCallView {
        id: callView
        chosenFont: compactRoot.effectiveFont
        callTitle: compactRoot.callTitle; callSubtitle: compactRoot.callSubtitle; callAvatar: compactRoot.callAvatar
        isCalling: compactRoot.isCalling
        visible: opacity > 0.001
        opacity: (compactRoot.isCalling && !compactRoot.isExpanded) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    CompactWorkspaceView {
        id: wsView
        anchors.fill: parent
        chosenFont: compactRoot.effectiveFont
        wsName: compactRoot.wsName
        wsTotal: compactRoot.wsTotal
        wsList: compactRoot.wsList
        displayWsNumber: compactRoot.displayWsNumber
        isScrubbing: compactRoot.isScrubbing
        isScrubCanceling: compactRoot.isScrubCanceling
        visible: opacity > 0.001
        opacity: ((compactRoot.activeTransient === "WORKSPACE" || compactRoot.isScrubbing) && !compactRoot.isCalling && !compactRoot.isExpanded) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    CompactOsdView {
        id: osdView
        anchors.fill: parent
        chosenFont: compactRoot.effectiveFont
        osdIcon: compactRoot.osdIcon
        osdValue: compactRoot.osdValue
        visible: opacity > 0.001
        opacity: compactRoot.isOsdMode ? 1.0 : 0.0
        scale: compactRoot.isOsdMode ? 1.0 : 0.88
        Behavior on opacity { NumberAnimation { duration: compactRoot.isOsdMode ? 140 : 110 } }
    }

    CompactAlertView {
        id: alertView
        chosenFont: compactRoot.effectiveFont
        alertTitle: compactRoot.alertTitle; alertSubtitle: compactRoot.alertSubtitle; alertAvatar: compactRoot.alertAvatar
        alertThemeColor: compactRoot.alertThemeColor
        isAlertActive: !compactRoot.isExpanded && compactRoot.isAlertActive
    }

    // 挂载端侧语音组件
    CompactVoiceView {
        id: voiceView
        chosenFont: compactRoot.effectiveFont
        isListening: (compactRoot.activeTransient === "VOICE_INPUT" && !compactRoot.isExpanded)
        voiceLevel: (typeof Bridge !== "undefined" && Bridge.voiceInputLevel !== undefined) ? Bridge.voiceInputLevel : 0.2
        streamText: (typeof Bridge !== "undefined" && Bridge.voiceInputText !== undefined) ? Bridge.voiceInputText : ""
        onStopRequested: if (typeof Bridge !== "undefined") Bridge.stopVoiceInput()
    }

    Item {
        id: contentViewport
        anchors.fill: parent
        readonly property bool isNormal: (!compactRoot.isExpanded &&
                                          (compactRoot.activeTransient === "" || compactRoot.activeTransient === "MEDIA_PEEK") &&
                                          !compactRoot.isCalling &&
                                          !compactRoot.isScrubbing &&
                                          compactRoot.activeTransient !== "VOICE_INPUT")
        visible: opacity > 0.001
        opacity: isNormal ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Row {
            id: pipelineRow
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                id: wsSlot
                visible: compactRoot.showWsBadge
                width: compactRoot.slotWidthWs
                height: 20
                radius: 6
                anchors.verticalCenter: parent.verticalCenter
                color: wsBadgeHover.hovered ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.35) : Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.20)
                border.color: wsBadgeHover.hovered ? Theme.workspace : Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.6)
                border.width: 1
                clip: true

                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -0.5
                    text: compactRoot.wsName ? compactRoot.wsName : ("" + compactRoot.displayWsNumber)
                    color: "white"
                    font.pixelSize: 11
                    font.weight: Font.Black
                    font.family: compactRoot.displayFont
                }

                HoverHandler { id: wsBadgeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: if (typeof Bridge !== "undefined") Bridge.switchWorkspaceNext()
                }
                WheelHandler {
                    onWheel: (event) => {
                        if (typeof Bridge !== "undefined") {
                            if (event.angleDelta.y > 0) Bridge.switchWorkspacePrev()
                            else Bridge.switchWorkspaceNext()
                        }
                    }
                }
            }

            Item {
                id: mediaSlot
                anchors.verticalCenter: parent.verticalCenter
                width: compactRoot.slotWidthWave > 0 ? compactRoot.slotWidthWave : compactRoot.slotWidthMem
                height: 22
                visible: width > 0
                clip: true

                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                Item {
                    id: waveWrapper
                    anchors.centerIn: parent
                    width: compactRoot.fullWaveWidth
                    height: compactRoot.barMaxH
                    opacity: compactRoot.waveVisible ? (compactRoot.isActivelyPlaying ? 1.0 : 0.85) : 0.0
                    scale: compactRoot.waveVisible ? 1.0 : 0.5
                    visible: opacity > 0.01

                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }

                    Row {
                        anchors.centerIn: parent
                        spacing: compactRoot.barGap
                        height: compactRoot.barMaxH

                        Repeater {
                            model: compactRoot.waveVisible ? compactRoot.barsCount : 0
                            Rectangle {
                                width: compactRoot.barW
                                height: compactRoot.barMaxH
                                radius: compactRoot.barW / 2
                                color: compactRoot.dominantColor
                                anchors.verticalCenter: parent.verticalCenter

                                Behavior on color { ColorAnimation { duration: 240 } }

                                transform: Scale {
                                    origin.y: compactRoot.barMaxH / 2
                                    yScale: compactRoot.getBarScale(index, compactRoot.barsCount)

                                    Behavior on yScale {
                                        NumberAnimation {
                                            duration: 70
                                            easing.type: Easing.OutQuad
                                        }
                                    }
                                }
                            }
                        }
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: compactRoot.requestExpandTab("media") }
                }

                Item {
                    anchors.centerIn: parent
                    visible: !compactRoot.waveVisible && (compactRoot.memoryPercent >= ((typeof Config !== "undefined" && Config.memoryThreshold) ? Config.memoryThreshold : 75))
                    width: 18; height: 18

                    Text {
                        anchors.centerIn: parent
                        text: "⚡"
                        font.pixelSize: 12
                        color: compactRoot.memoryPercent >= 85 ? Theme.danger : Theme.clock
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (typeof Bridge !== "undefined") Bridge.openSystemMonitor()
                    }
                }
            }

            Item {
                id: clockSlot
                anchors.verticalCenter: parent.verticalCenter
                width: clockView.implicitWidth
                height: 24

                CompactClockView {
                    id: clockView
                    anchors.centerIn: parent
                    chosenFont: compactRoot.effectiveFont
                    isCapsLock: compactRoot.isCapsLock
                    displayDate: compactRoot.displayDate
                    displayTime: compactRoot.displayTime
                    displaySeconds: compactRoot.displaySeconds
                    displayPeriod: compactRoot.displayPeriod
                }
            }

            Item {
                id: numLockSlot
                anchors.verticalCenter: parent.verticalCenter
                width: compactRoot.slotWidthNumLock
                height: 20
                visible: width > 0
                clip: true

                Behavior on width {
                    NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.08 }
                }

                Rectangle {
                    id: numLockToastItem
                    anchors.centerIn: parent
                    width: Math.ceil(numLockText.implicitWidth + 12)
                    height: 20
                    radius: 10

                    color: compactRoot.numLockActiveState ? Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                    border.color: compactRoot.numLockActiveState ? "#34d399" : Qt.rgba(1, 1, 1, 0.35)
                    border.width: 1

                    Text {
                        id: numLockText
                        anchors.centerIn: parent
                        text: compactRoot.numLockActiveState ? "123 ON" : "123 OFF"
                        color: compactRoot.numLockActiveState ? "#34d399" : "#9ca3af"
                        font.pixelSize: 10
                        font.weight: Font.Black
                        font.family: compactRoot.displayFont
                    }
                }
            }

            Item {
                id: timerSlot
                anchors.verticalCenter: parent.verticalCenter
                width: compactRoot.slotWidthTimer
                height: 20
                visible: width > 0
                clip: true

                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                readonly property color timerAccent: compactRoot.timerIsPaused ? "#f59e0b" :
                                                      (compactRoot.timerIsCompleted ? "#10b981" : "#f97316")

                Rectangle {
                    id: timerPillBody
                    anchors.fill: parent
                    radius: 10
                    color: Qt.rgba(timerSlot.timerAccent.r, timerSlot.timerAccent.g, timerSlot.timerAccent.b, 0.12)
                    border.color: timerHover.hovered ? timerSlot.timerAccent :
                                  Qt.rgba(timerSlot.timerAccent.r, timerSlot.timerAccent.g, timerSlot.timerAccent.b, 0.38)
                    border.width: 1
                    clip: true

                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Rectangle {
                        id: progressFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: 10

                        width: compactRoot.timerIsCompleted ? parent.width :
                               Math.round(parent.width * Math.min(1.0, Math.max(0.0, compactRoot.timerProgress)))

                        color: Qt.rgba(timerSlot.timerAccent.r, timerSlot.timerAccent.g, timerSlot.timerAccent.b, 0.32)

                        Behavior on width {
                            NumberAnimation {
                                duration: 350
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: compactRoot.timerIsCompleted ? "✓" : (compactRoot.timerIsPaused ? "⏸" : "")
                            visible: text !== ""
                            color: compactRoot.timerIsCompleted ? "#6ee7b7" : "#fcd34d"
                            font.pixelSize: 8
                            font.weight: Font.Black
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: compactRoot.timerFormattedText
                            color: compactRoot.timerIsCompleted ? "#6ee7b7" :
                                   (compactRoot.timerIsPaused ? "#fcd34d" : "#ffffff")
                            font.family: compactRoot.displayFont
                            font.pixelSize: 11
                            font.weight: Font.Black
                            font.letterSpacing: 0.3
                            font.features: { "tnum": 1 }
                        }
                    }
                }

                HoverHandler { id: timerHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: compactRoot.toggleTimer() }
            }

            Rectangle {
                id: notifSlot
                anchors.verticalCenter: parent.verticalCenter
                width: compactRoot.slotWidthNotif
                height: 18
                radius: 9
                color: "#6366f1"
                visible: width > 0
                clip: true

                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                Text {
                    id: notifBadgeText
                    anchors.centerIn: parent
                    text: compactRoot.unreadNotifCount > 99 ? "99+" : compactRoot.unreadNotifCount
                    color: "white"
                    font.pixelSize: 10
                    font.weight: Font.Black
                    font.family: compactRoot.displayFont
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: compactRoot.requestExpandTab("notification") }
            }

            Item {
                id: expandSlot
                anchors.verticalCenter: parent.verticalCenter
                width: compactRoot.slotWidthExpandBtn
                height: 20
                visible: width > 0
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.08
                    }
                }

                Rectangle {
                    id: chevronPill
                    anchors.centerIn: parent
                    width: 22
                    height: 20
                    radius: 10
                    scale: chevronTap.pressed ? 0.90 : (chevronHover.hovered ? 1.06 : 1.0)
                    opacity: compactRoot.showExpandBtn ? 1.0 : 0.0

                    color: chevronTap.pressed ?
                           Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.38) :
                           (chevronHover.hovered ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.22) : Qt.rgba(1, 1, 1, 0.08))
                    border.color: chevronHover.hovered ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.18)
                    border.width: 1

                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    Behavior on opacity { NumberAnimation { duration: 220 } }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 0.5
                        text: "▾"
                        color: chevronHover.hovered ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.70)
                        font.pixelSize: 10
                        font.weight: Font.Black
                    }

                    HoverHandler { id: chevronHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: chevronTap
                        onTapped: compactRoot.requestExpandTab("hardware")
                    }
                }
            }
        }
    }
}