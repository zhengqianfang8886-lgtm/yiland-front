// ==========================================
// 📄 File: ui/views/CompactCapsuleView.qml
// 🌟 恢复音乐暂停延时退场 · 物理防挤压保护版
// ==========================================
import QtQuick
import QtQuick.Shapes
import "../components/compact"

Item {
    id: compactRoot

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property string activeTransient: ""
    property string status: "Paused"
    property bool isCalling: false
    property bool isExpanded: false
    property bool isCollapsing: false

    property bool showNetSpeed: false
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
    property string downCompact: "0K"
    property string upCompact: "0K"

    readonly property bool isActivelyPlaying: status === "Playing"

    // 🚀【功能恢复】：音乐暂停后的 4 秒（加上动画约 5 秒）优雅退场逻辑
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
            if (!compactRoot.isActivelyPlaying) {
                compactRoot.waveVisible = false
            }
        }
    }

    property color dominantColor: "#22c55e"
    property real spec1: 0.2
    property real spec2: 0.2
    property real spec3: 0.2
    property real spec4: 0.2

    readonly property int barsCount: (typeof Config !== "undefined" && Config.musicVisualizerBars !== undefined) ?
                                     Math.max(3, Math.min(8, Config.musicVisualizerBars)) : 5
    readonly property real barW: 3.8
    readonly property real barGap: 2.2
    readonly property real barMaxH: 16.0
    readonly property real fullWaveWidth: (barsCount * barW) + ((barsCount - 1) * barGap)

    function getBarScale(index, total) {
        if (!isActivelyPlaying) return 0.22;
        if (total <= 1) return spec1;
        var t = index / (total - 1);
        var pos = t * 3.0;
        var i0 = Math.floor(pos);
        var i1 = Math.min(3, i0 + 1);
        var frac = pos - i0;
        var sArr = [spec1, spec2, spec3, spec4];
        var val = sArr[i0] * (1.0 - frac) + sArr[i1] * frac;
        var resonance = 0.85 + 0.35 * Math.sin(t * Math.PI);
        return Math.max(0.15, Math.min(1.0, val * resonance));
    }

    property bool timerActive: false
    property string timerFormattedText: "25:00"
    property bool timerIsPaused: false
    property bool timerIsCompleted: false
    property real timerProgress: 1.0

    readonly property bool timerHasDays: (timerFormattedText.indexOf("d") !== -1 || timerFormattedText.indexOf("天") !== -1)
    readonly property bool timerHasHours: (!timerHasDays && timerFormattedText.split(":").length >= 3)
    readonly property real lockedTimerPillWidth: {
        if (timerHasDays) return 84
        if (timerHasHours) return 74
        return 54
    }

    property int unreadNotifCount: 0
    property string latestNotifAvatar: ""
    property int memoryPercent: 0
    property int continuousSitMinutes: 45

    signal sedentaryRested()
    signal sedentarySnooze()
    signal requestExpandTab(string tabName)
    signal toggleTimer()

    // 🚀 逻辑修正：胶囊宽度判断重新使用 waveVisible，保护延时退场阶段不塌缩
    readonly property int implicitCompactWidth: {
        var base = clockView.implicitWidth + 36
        if (internalMemPill.shouldShow) base += 22
        if (waveVisible) base += (fullWaveWidth + 14)
        if (timerActive) base += (lockedTimerPillWidth + 14)
        if (unreadNotifCount > 0) base += 24
        return Math.ceil(Math.max(160, base))
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

    readonly property int displayWsNumber: {
        var n = Number(wsCurrent)
        if (isNaN(n)) return 0
        if (wsName && /^\d+$/.test(wsName.trim())) return Number(wsName.trim())
        return n
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
        anchors.centerIn: parent
        chosenFont: compactRoot.effectiveFont
        wsName: compactRoot.wsName
        wsTotal: compactRoot.wsTotal
        wsList: compactRoot.wsList
        displayWsNumber: compactRoot.displayWsNumber
        isScrubbing: compactRoot.isScrubbing
        isScrubCanceling: compactRoot.isScrubCanceling

        visible: opacity > 0.001
        opacity: ((compactRoot.activeTransient === "WORKSPACE" || compactRoot.isScrubbing) && !compactRoot.isCalling && !compactRoot.isExpanded) ? 1.0 : 0.0
        scale: opacity > 0.01 ? 1.0 : 0.94
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
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

    readonly property bool isNormalModeActive: (!compactRoot.isExpanded && 
                                               (compactRoot.activeTransient === "" || compactRoot.activeTransient === "MEDIA_PEEK") && 
                                               !compactRoot.isCalling && 
                                               !compactRoot.isScrubbing)

    Row {
        id: innerContentRow
        anchors.centerIn: parent
        spacing: 7
        height: parent.height
        opacity: compactRoot.isNormalModeActive ? 1.0 : 0.0
        scale: compactRoot.isNormalModeActive ? 1.0 : 0.90
        visible: opacity > 0.001

        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 160 } }

        Item {
            id: internalMemPill
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool shouldShow: (typeof Config === "undefined" || Config.showMemoryBubble !== false) &&
                                                compactRoot.memoryPercent >= ((typeof Config !== "undefined" && Config.memoryThreshold) ? Config.memoryThreshold : 75)
            visible: width > 0
            width: shouldShow ? 16 : 0
            height: parent.height

            Text {
                anchors.centerIn: parent
                text: "⚡"
                font.pixelSize: 11
                color: compactRoot.memoryPercent >= 85 ? Theme.danger : Theme.clock
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: if (typeof Bridge !== "undefined") Bridge.openSystemMonitor()
            }
        }

        // 音乐律动区域：绑定 waveVisible，确保暂停后 4 秒不消失
        Item {
            id: waveWrapper
            anchors.verticalCenter: parent.verticalCenter
            width: compactRoot.waveVisible ? compactRoot.fullWaveWidth : 0
            height: parent.height
            clip: true
            
            // 暂停期间变暗，4秒后彻底消失
            opacity: compactRoot.waveVisible ? (compactRoot.isActivelyPlaying ? 1.0 : 0.6) : 0.0

            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }

            Row {
                anchors.centerIn: parent
                spacing: compactRoot.barGap
                height: compactRoot.barMaxH

                Repeater {
                    // 仅当 waveVisible 时才渲染柱子，否则释放 GPU
                    model: compactRoot.waveVisible ? compactRoot.barsCount : 0
                    Rectangle {
                        width: compactRoot.barW
                        height: compactRoot.barMaxH
                        radius: compactRoot.barW / 2
                        color: compactRoot.dominantColor
                        anchors.verticalCenter: parent.verticalCenter

                        // GPU 零延迟变形
                        transform: Scale {
                            origin.y: compactRoot.barMaxH / 2
                            yScale: compactRoot.getBarScale(index, compactRoot.barsCount)
                        }
                    }
                }
            }

            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: compactRoot.requestExpandTab("media") }
            WheelHandler {
                onWheel: (event) => {
                    var step = (typeof Config !== "undefined" && Config.volumeStep !== undefined) ? Config.volumeStep : 5
                    if (typeof Bridge !== "undefined") Bridge.adjustVolume(event.angleDelta.y > 0 ? step : -step)
                }
            }
        }

        CompactClockView {
            id: clockView
            anchors.verticalCenter: parent.verticalCenter
            chosenFont: compactRoot.effectiveFont
            isCapsLock: compactRoot.isCapsLock
            isNumLock: compactRoot.isNumLock
            showNetSpeed: false
            downCompact: compactRoot.downCompact; upCompact: compactRoot.upCompact
            displayDate: compactRoot.displayDate; displayTime: compactRoot.displayTime; displaySeconds: compactRoot.displaySeconds; displayPeriod: compactRoot.displayPeriod
            showWorkspaceName: (typeof Config !== "undefined" && Config.showWorkspaceName !== undefined) ? Config.showWorkspaceName : true
            wsName: compactRoot.wsName
            displayWsNumber: compactRoot.displayWsNumber
            isClockActive: true
        }

        Item {
            id: internalTimerPill
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool shouldShow: compactRoot.timerActive
            visible: width > 0
            width: shouldShow ? compactRoot.lockedTimerPillWidth : 0
            height: parent.height

            Row {
                anchors.centerIn: parent
                spacing: 5

                Item {
                    width: 13; height: 13
                    anchors.verticalCenter: parent.verticalCenter
                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            strokeWidth: 1.8; strokeColor: Qt.rgba(1, 1, 1, 0.18); fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc { centerX: 6.5; centerY: 6.5; radiusX: 5.0; radiusY: 5.0; startAngle: -90; sweepAngle: 360 }
                        }
                        ShapePath {
                            strokeWidth: 1.8
                            strokeColor: compactRoot.timerIsPaused ? "#f59e0b" : (compactRoot.timerIsCompleted ? "#10b981" : "#f97316")
                            fillColor: "transparent"; capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 6.5; centerY: 6.5; radiusX: 5.0; radiusY: 5.0; startAngle: -90
                                sweepAngle: compactRoot.timerIsCompleted ? 360 : 360 * Math.min(1.0, Math.max(0.0, compactRoot.timerProgress))
                            }
                        }
                    }
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: compactRoot.lockedTimerPillWidth - 13 - 5
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: compactRoot.timerFormattedText
                        color: compactRoot.timerIsPaused ? "#fcd34d" : (compactRoot.timerIsCompleted ? "#6ee7b7" : "#ffffff")
                        font.family: compactRoot.displayFont
                        font.pixelSize: 11
                        font.weight: Font.Black
                        font.features: { "tnum": 1 }
                        renderType: Text.QtRendering
                    }
                }
            }

            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: (event) => {
                    if (event.button === Qt.LeftButton) compactRoot.toggleTimer()
                }
            }
        }

        Rectangle {
            id: internalNotifPill
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool shouldShow: compactRoot.unreadNotifCount > 0
            visible: width > 0
            width: shouldShow ? Math.max(16, notifBadgeText.implicitWidth + 8) : 0
            height: 16; radius: 8
            color: notifHover.hovered ? "#4338ca" : "#6366f1"
            clip: true

            Text {
                id: notifBadgeText
                anchors.centerIn: parent
                text: compactRoot.unreadNotifCount > 99 ? "99+" : compactRoot.unreadNotifCount
                color: "white"
                font.pixelSize: 9
                font.weight: Font.Black
                font.family: compactRoot.displayFont
            }

            HoverHandler { id: notifHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: compactRoot.requestExpandTab("notification") }
        }
    }
}