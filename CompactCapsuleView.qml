// ==========================================
// 📄 File: CompactCapsuleView.qml
// 🌟 纯粹流体原生态 · 光学微刻线自适应分隔版
// ==========================================
import QtQuick
import QtQuick.Shapes
import "compact"

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

    property bool showNetSpeed: true
    property bool isCapsLock: (typeof Bridge !== "undefined" && Bridge.isCapsLock !== undefined) ? Bridge.isCapsLock : false
    property bool isNumLock: (typeof Bridge !== "undefined" && Bridge.isNumLock !== undefined) ? Bridge.isNumLock : false

    property string wsName: ""
    property int wsCurrent: 0
    property int wsTotal: 4
    property var wsList: []

    property bool isScrubbing: false
    property bool isScrubCanceling: false

    readonly property int scrubHoverIndex: (wsView && wsView.peakIndex !== undefined) ? wsView.peakIndex : 0
    readonly property var workspaceItems: (wsView && wsView.workspaceItems !== undefined) ? wsView.workspaceItems : []

    function updateCursorByMouseX(mx) {
        if (wsView && wsView.updateCursorByMouseX) wsView.updateCursorByMouseX(mx)
    }

    function snapToNearest() {
        if (wsView && wsView.snapToNearest) wsView.snapToNearest()
    }

    // 瞬态模式属性
    property string osdIcon: "🔊"
    property int osdValue: 50
    property string alertTitle: ""
    property string alertSubtitle: ""
    property string alertAvatar: ""
    property string alertIcon: "🔔"
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""

    // 时钟/网络属性
    property string displayDate: ""
    property string displayTime: "04:53"
    property string displaySeconds: ""
    property string displayPeriod: "pm"
    property string downCompact: "0K"
    property string upCompact: "0K"

    // 声谱参数
    property bool hasMusic: status === "Playing"
    property color dominantColor: "#22c55e"
    property real spec1: 0.2
    property real spec2: 0.2
    property real spec3: 0.2
    property real spec4: 0.2

    readonly property int barsCount: (typeof Config !== "undefined" && Config.musicVisualizerBars !== undefined) ?
                                     Math.max(3, Math.min(8, Config.musicVisualizerBars)) : 5
    readonly property real barW: 4.0
    readonly property real barGap: 2.2
    readonly property real barMaxH: 18.0

    function getBarScale(index, total) {
        if (total <= 1) return Math.max(0.25, Math.min(1.0, spec1))
        var t = index / (total - 1)
        var pos = t * 3.0
        var i0 = Math.floor(pos)
        var i1 = Math.min(3, i0 + 1)
        var frac = pos - i0

        var sArr = [spec1, spec2, spec3, spec4]
        var baseVal = sArr[i0] * (1.0 - frac) + sArr[i1] * frac
        var resonance = 1.0 + 0.22 * Math.sin(t * Math.PI)
        return Math.max(0.20, Math.min(1.0, baseVal * resonance))
    }

    // 计时器属性与刚体定宽
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

    // 通知与健康
    property int unreadNotifCount: 0
    property string latestNotifAvatar: ""
    property int memoryPercent: 0

    property int continuousSitMinutes: 45
    signal sedentaryRested()
    signal sedentarySnooze()
    signal requestExpandTab(string tabName)
    signal toggleTimer()

    readonly property int implicitCompactWidth: Math.ceil(innerContentRow.implicitWidth + 20)
    readonly property int wsContentImplicitWidth: wsView.contentImplicitWidth
    readonly property int alertContentImplicitWidth: alertView.implicitContentWidth
    readonly property bool isAlertActive: (activeTransient === "ALERT") && !isCalling
    readonly property bool isHardwareMuted: (osdIcon === "🔇" || osdIcon === "🚫")
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

    // 1. 久坐打断弹窗
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

    // 2. 来电专属模式条
    CompactCallView {
        id: callView
        chosenFont: compactRoot.effectiveFont
        callTitle: compactRoot.callTitle; callSubtitle: compactRoot.callSubtitle; callAvatar: compactRoot.callAvatar
        isCalling: compactRoot.isCalling
        visible: opacity > 0.001
        opacity: (compactRoot.isCalling && !compactRoot.isExpanded) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // 3. 高斯绝对网格鱼眼工作区标尺
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

    // 4. 音量/静音 OSD
    CompactOsdView {
        id: osdView
        anchors.fill: parent
        chosenFont: compactRoot.effectiveFont
        osdIcon: compactRoot.osdIcon
        osdValue: compactRoot.osdValue
        visible: opacity > 0.001
        opacity: compactRoot.isOsdMode ? 1.0 : 0.0
        scale: compactRoot.isOsdMode ? 1.0 : 0.88

        Behavior on opacity { NumberAnimation { duration: compactRoot.isOsdMode ? 140 : 110; easing.type: Easing.OutQuad } }
        Behavior on scale {
            NumberAnimation {
                duration: compactRoot.isOsdMode ? 180 : 110
                easing.type: compactRoot.isOsdMode ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.08
            }
        }
    }

    // 5. 通知弹窗横幅
    CompactAlertView {
        id: alertView
        chosenFont: compactRoot.effectiveFont
        alertTitle: compactRoot.alertTitle; alertSubtitle: compactRoot.alertSubtitle; alertAvatar: compactRoot.alertAvatar
        alertThemeColor: compactRoot.alertThemeColor
        isAlertActive: !compactRoot.isExpanded && compactRoot.isAlertActive
    }

    // =========================================================================
    // 6. 🌟 胶囊内部常态融合状态流 (光学微刻线分隔版)
    // =========================================================================
    readonly property bool isNormalModeActive: (!compactRoot.isExpanded && compactRoot.activeTransient === "" && !compactRoot.isCalling && !compactRoot.isScrubbing)

    Row {
        id: innerContentRow
        anchors.centerIn: parent
        spacing: 6
        height: parent.height

        opacity: compactRoot.isNormalModeActive ? 1.0 : 0.0
        scale: compactRoot.isNormalModeActive ? 1.0 : 0.90
        visible: opacity > 0.001

        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        // ---------------------------------------------------------------------
        // 【左翼 1】：高内存指示点
        // ---------------------------------------------------------------------
        Item {
            id: internalMemPill
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool shouldShow: (typeof Config === "undefined" || Config.showMemoryBubble !== false) &&
                                                compactRoot.memoryPercent >= ((typeof Config !== "undefined" && Config.memoryThreshold) ? Config.memoryThreshold : 75)
            visible: width > 0
            width: shouldShow ? 16 : 0
            height: parent.height

            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveDecel } }

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

        // ---------------------------------------------------------------------
        // 【左翼 2】：纯粹音乐律动声谱
        // ---------------------------------------------------------------------
        Item {
            id: waveWrapper
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool shouldShow: compactRoot.hasMusic
            readonly property real calculatedW: (compactRoot.barsCount * compactRoot.barW) + ((compactRoot.barsCount - 1) * compactRoot.barGap)

            visible: width > 0
            width: shouldShow ? calculatedW : 0
            height: parent.height

            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveSpring } }

            Row {
                id: waveRow
                anchors.centerIn: parent
                spacing: compactRoot.barGap
                height: compactRoot.barMaxH

                Repeater {
                    model: compactRoot.barsCount

                    Rectangle {
                        id: barSingle
                        width: compactRoot.barW
                        height: compactRoot.barMaxH
                        radius: compactRoot.barW / 2
                        color: compactRoot.dominantColor
                        anchors.verticalCenter: parent.verticalCenter

                        readonly property real targetScale: compactRoot.getBarScale(index, compactRoot.barsCount)

                        transform: Scale {
                            origin.y: compactRoot.barMaxH / 2
                            yScale: barSingle.targetScale
                            Behavior on yScale { NumberAnimation { duration: 65; easing.type: Easing.OutQuad } }
                        }
                    }
                }
            }

            HoverHandler { id: musicHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: compactRoot.requestExpandTab("media") }
            WheelHandler {
                onWheel: (event) => {
                    var step = (typeof Config !== "undefined" && Config.volumeStep !== undefined) ? Config.volumeStep : 5
                    if (typeof Bridge !== "undefined") Bridge.adjustVolume(event.angleDelta.y > 0 ? step : -step)
                }
            }
        }

        // ---------------------------------------------------------------------
        // 🚀【光学微刻线 1】：音乐声谱与中央时钟之间（仅在播放音乐时自适应显现）
        // ---------------------------------------------------------------------
        Rectangle {
            id: sepMusicToClock
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool shouldShow: compactRoot.hasMusic
            width: shouldShow ? 1 : 0
            height: 11
            radius: 0.5
            color: Qt.rgba(1, 1, 1, 0.16)
            opacity: shouldShow ? 1.0 : 0.0

            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveSpring } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // ---------------------------------------------------------------------
        // 【中央核心】：基准时钟 + 桌面微标 + 实时网速 + 键盘锁
        // ---------------------------------------------------------------------
        CompactClockView {
            id: clockView
            anchors.verticalCenter: parent.verticalCenter
            chosenFont: compactRoot.effectiveFont
            isCapsLock: compactRoot.isCapsLock
            isNumLock: compactRoot.isNumLock
            showNetSpeed: compactRoot.showNetSpeed
            downCompact: compactRoot.downCompact; upCompact: compactRoot.upCompact
            displayDate: compactRoot.displayDate; displayTime: compactRoot.displayTime; displaySeconds: compactRoot.displaySeconds; displayPeriod: compactRoot.displayPeriod

            showWorkspaceName: (typeof Config !== "undefined" && Config.showWorkspaceName !== undefined) ? Config.showWorkspaceName : true
            wsName: compactRoot.wsName
            displayWsNumber: compactRoot.displayWsNumber
            isClockActive: true
        }

        // ---------------------------------------------------------------------
        // 🚀【光学微刻线 2】：中央时钟与专注计时器之间（仅在开启计时器时自适应显现）
        // ---------------------------------------------------------------------
        Rectangle {
            id: sepClockToTimer
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool shouldShow: compactRoot.timerActive
            width: shouldShow ? 1 : 0
            height: 11
            radius: 0.5
            color: Qt.rgba(1, 1, 1, 0.16)
            opacity: shouldShow ? 1.0 : 0.0

            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveSpring } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // ---------------------------------------------------------------------
        // 【右翼 1】：绝对定宽 · 零跳动专注计时器
        // ---------------------------------------------------------------------
        Item {
            id: internalTimerPill
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool shouldShow: compactRoot.timerActive

            visible: width > 0
            width: shouldShow ? compactRoot.lockedTimerPillWidth : 0
            height: parent.height

            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Row {
                anchors.centerIn: parent
                spacing: 5

                // 物理尺寸固定为 13x13 的精准进度环
                Item {
                    width: 13; height: 13
                    anchors.verticalCenter: parent.verticalCenter

                    Shape {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.samples: 4
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

                // 定宽文本容器，开启等宽特性
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

            HoverHandler { id: timerHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: (event) => {
                    if (event.button === Qt.LeftButton) compactRoot.toggleTimer()
                }
            }
        }

        // ---------------------------------------------------------------------
        // 🚀【光学微刻线 3】：计时器与未读通知之间（两者同时存在时显现）
        // ---------------------------------------------------------------------
        Rectangle {
            id: sepTimerToNotif
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool shouldShow: compactRoot.timerActive && (compactRoot.unreadNotifCount > 0)
            width: shouldShow ? 1 : 0
            height: 11
            radius: 0.5
            color: Qt.rgba(1, 1, 1, 0.16)
            opacity: shouldShow ? 1.0 : 0.0

            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveSpring } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // ---------------------------------------------------------------------
        // 【右翼 2】：未读消息通知（水滴微胶囊）
        // ---------------------------------------------------------------------
        Rectangle {
            id: internalNotifPill
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool shouldShow: compactRoot.unreadNotifCount > 0
            visible: width > 0
            width: shouldShow ? Math.max(16, notifBadgeText.implicitWidth + 8) : 0
            height: 16; radius: 8
            color: notifHover.hovered ? "#4338ca" : "#6366f1"
            clip: true

            Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveSpring } }

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