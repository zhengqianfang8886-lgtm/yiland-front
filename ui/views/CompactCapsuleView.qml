// =========================================================================
// 📄 File: ui/views/CompactCapsuleView.qml
// 🌟 紧凑态视口 · 44px 舒展开阔布局版 (实用性大幅增强)
// =========================================================================
import QtQuick
import "../components/capsule"
import "../components/compact"

Item {
    id: compactRoot
    anchors.fill: parent

    property var fsm: null
    property var relay: null
    property var timeService: null

    property bool isScrubbing: false
    property bool isScrubCanceling: false

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    readonly property bool hasActiveTransient: fsm ? (fsm.activeTransientKey !== "") : false
    readonly property string currentKey: fsm ? fsm.activeTransientKey : ""
    readonly property var currentPayload: (fsm && fsm.activePayload) ? fsm.activePayload : ({})

    readonly property bool isMusicPlaying: (compactRoot.relay && compactRoot.relay.visualPlaying)
    readonly property int unreadNoticeCount: (compactRoot.relay && compactRoot.relay.unreadCount > 0) ? compactRoot.relay.unreadCount : 0
    readonly property bool hasActiveTimer: (typeof Bridge !== "undefined") && (Bridge.timerIsRunning || Bridge.timerIsPaused || Bridge.timerIsCompleted)

    // 🚀【人体工学优化】：外留白增至 32px，模块间隙增至 12px，彻底摆脱局促感
    readonly property int fixedOuterPadding: 32
    readonly property int fixedInterSpacing: 12

    property int cachedOsdValue: (typeof Bridge !== "undefined" && Bridge.currentVolume !== undefined) ? Bridge.currentVolume : 50
    property string cachedOsdIcon: "🔊"

    onCurrentPayloadChanged: {
        if (currentPayload && currentPayload.value !== undefined) {
            cachedOsdValue = currentPayload.value;
        }
        if (currentPayload && currentPayload.icon) {
            cachedOsdIcon = currentPayload.icon;
        }
    }

    function getSixBandValue(idx) {
        if (!compactRoot.relay) return 0.2;
        var s1 = compactRoot.relay.spec1 || 0.2;
        var s2 = compactRoot.relay.spec2 || 0.2;
        var s3 = compactRoot.relay.spec3 || 0.2;
        var s4 = compactRoot.relay.spec4 || 0.2;
        
        switch (idx) {
            case 0: return Math.max(0.18, Math.min(1.0, s1 * 0.82));
            case 1: return Math.max(0.20, Math.min(1.0, s1));
            case 2: return Math.max(0.24, Math.min(1.0, s2));
            case 3: return Math.max(0.24, Math.min(1.0, s3));
            case 4: return Math.max(0.20, Math.min(1.0, s4));
            case 5: return Math.max(0.18, Math.min(1.0, (s3 + s4) * 0.52));
            default: return 0.2;
        }
    }

    // 1. 左侧工作区宽度计算
    readonly property int leadingSlotBucket: {
        var showWs = (typeof Config !== "undefined" && Config.showWorkspaceName !== false);
        if (!showWs) return 0;
        var nameStr = (compactRoot.relay && compactRoot.relay.wsName) ? compactRoot.relay.wsName.trim() : "";
        if (/^\d+$/.test(nameStr) || nameStr.length <= 1) return 32;
        return Math.min(84, Math.max(46, nameStr.length * 10 + 20));
    }

    // 2. 中间时钟宽度
    readonly property int centerSlotBucket: (clockView && clockView.allocatedWidth > 0) ? clockView.allocatedWidth : 62

    // 3. 右侧微模块宽度
    readonly property int timerSlotWidth: hasActiveTimer ? 66 : 0
    readonly property int noticeBadgeSlotWidth: unreadNoticeCount > 0 ? (unreadNoticeCount >= 10 ? 38 : 32) : 0
    readonly property int musicWaveSlotWidth: isMusicPlaying ? 38 : 0

    readonly property int trailingSlotBucket: {
        var w = 0;
        var activeCount = 0;
        if (timerSlotWidth > 0) { w += timerSlotWidth; activeCount++; }
        if (noticeBadgeSlotWidth > 0) { w += noticeBadgeSlotWidth; activeCount++; }
        if (musicWaveSlotWidth > 0) { w += musicWaveSlotWidth; activeCount++; }
        if (activeCount > 1) { w += (activeCount - 1) * 8; }
        return w;
    }

    readonly property int naturalWidth: {
        if (compactRoot.isScrubbing) return 320;

        if (hasActiveTransient) {
            if (currentKey === "CALL") return 340;
            if (currentKey === "VOICE_INPUT" || currentKey === "VOICE") return 340;
            if (currentKey === "SEDENTARY") return 430;
            if (currentKey === "ALERT") return 300;
            if (currentKey === "WORKSPACE") return 260;
            if (currentKey === "OSD") return 220;
            if (currentKey === "MEDIA_PEEK") {
                var titleLen = (currentPayload && currentPayload.title) ? currentPayload.title.length : 0;
                return Math.min(380, Math.max(260, 120 + titleLen * 14));
            }
        }

        var sum = fixedOuterPadding;
        var validSlots = 0;
        if (leadingSlotBucket > 0) { sum += leadingSlotBucket; validSlots++; }
        sum += centerSlotBucket; validSlots++;
        if (trailingSlotBucket > 0) { sum += trailingSlotBucket; validSlots++; }
        sum += (validSlots - 1) * fixedInterSpacing;

        return (sum % 2 === 0) ? sum : (sum + 1);
    }

    function handleScrubMove(mx, my) {
        if (wsView) wsView.updateCursorByMouseX(mx);
    }
    function getScrubTargetIndex() {
        return wsView ? wsView.scrubHoverIndex : 0;
    }

    Item {
        anchors.fill: parent
        clip: true

        Row {
            id: flowPipeline
            anchors.centerIn: parent
            spacing: compactRoot.fixedInterSpacing
            visible: !compactRoot.hasActiveTransient && !compactRoot.isScrubbing
            opacity: (!compactRoot.hasActiveTransient && !compactRoot.isScrubbing) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            // 🚀 左侧：工作区标识药丸（高 24px，字号 11px，点击手感极佳）
            Item {
                id: wsSlotItem
                anchors.verticalCenter: parent.verticalCenter
                visible: compactRoot.leadingSlotBucket > 0
                width: compactRoot.leadingSlotBucket
                height: 24
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: wsHover.hovered ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.09)
                    border.color: wsHover.hovered ? Qt.rgba(255, 255, 255, 0.40) : Qt.rgba(255, 255, 255, 0.15)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        text: (compactRoot.relay && compactRoot.relay.wsName) ? compactRoot.relay.wsName : (compactRoot.relay ? compactRoot.relay.wsCurrent : "1")
                        color: "#f1f5f9"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.family: compactRoot.displayFont
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        renderType: Text.QtRendering
                    }

                    HoverHandler { id: wsHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: if (typeof Bridge !== "undefined") Bridge.switchWorkspaceNext() }
                }
            }

            // 中间：时间主干
            CompactClockView {
                id: clockView
                anchors.verticalCenter: parent.verticalCenter
                chosenFont: compactRoot.effectiveFont
                isCapsLock: (typeof Bridge !== "undefined" && Bridge.isCapsLock !== undefined) ? Bridge.isCapsLock : false
                displayDate: compactRoot.timeService ? compactRoot.timeService.displayDate : ""
                displayTime: compactRoot.timeService ? compactRoot.timeService.displayTime : "12:00"
                displaySeconds: compactRoot.timeService ? compactRoot.timeService.displaySeconds : ""
                displayPeriod: compactRoot.timeService ? compactRoot.timeService.displayPeriod : ""
            }

            // 右侧组合槽位
            Row {
                id: trailingCombinedRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: compactRoot.trailingSlotBucket > 0

                // 专注倒计时微囊（高度同步提升至 24px）
                Rectangle {
                    width: compactRoot.timerSlotWidth
                    height: 24
                    radius: 12
                    visible: compactRoot.hasActiveTimer
                    color: Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.18)
                    border.color: Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.55)
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (typeof Bridge === "undefined") return "25:00";
                            var sec = Bridge.timerType === "stopwatch" ? Bridge.timerElapsedSec : Bridge.timerRemainingSec;
                            var m = Math.floor(sec / 60);
                            var s = sec % 60;
                            return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                        }
                        color: "#fdba74"
                        font.family: compactRoot.displayFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                        renderType: Text.QtRendering
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: if (typeof Bridge !== "undefined") Bridge.toggleTimerPause() }
                }

                // 消息未读微囊（高度同步提升至 24px）
                Rectangle {
                    id: unreadBadgePod
                    width: compactRoot.noticeBadgeSlotWidth
                    height: 24
                    radius: 12
                    visible: compactRoot.unreadNoticeCount > 0
                    color: notifTipHover.hovered ? Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.35) : Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.20)
                    border.color: Qt.rgba(129 / 255, 140 / 255, 248 / 255, 0.55)
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: "💬"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: compactRoot.unreadNoticeCount
                            color: "white"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.family: compactRoot.displayFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: notifTipHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "notification" })
                    }
                }

                // 声谱动画
                Item {
                    id: musicWaveIsland
                    width: compactRoot.musicWaveSlotWidth
                    height: 24
                    visible: compactRoot.isMusicPlaying
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        anchors.centerIn: parent
                        spacing: 2.5

                        Repeater {
                            model: 6
                            Rectangle {
                                width: 2.8
                                height: 15
                                radius: 1.4
                                color: compactRoot.relay ? compactRoot.relay.dominantColor : "#22c55e"
                                anchors.verticalCenter: parent.verticalCenter
                                transform: Scale {
                                    origin.y: 7.5
                                    yScale: {
                                        if (!compactRoot.isMusicPlaying) return 0.15;
                                        return compactRoot.getSixBandValue(index);
                                    }
                                    Behavior on yScale { NumberAnimation { duration: 75; easing.type: Easing.OutQuad } }
                                }
                            }
                        }
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "media" })
                    }
                }
            }
        }

        CompactWorkspaceView {
            id: wsView
            anchors.fill: parent
            chosenFont: compactRoot.effectiveFont
            wsName: compactRoot.relay ? compactRoot.relay.wsName : ""
            wsTotal: compactRoot.relay ? compactRoot.relay.wsTotal : 4
            wsList: compactRoot.relay ? compactRoot.relay.wsList : []
            displayWsNumber: compactRoot.relay ? compactRoot.relay.wsCurrent : 1
            isScrubbing: compactRoot.isScrubbing
            isScrubCanceling: compactRoot.isScrubCanceling

            visible: opacity > 0.001
            opacity: (compactRoot.isScrubbing || (compactRoot.hasActiveTransient && compactRoot.currentKey === "WORKSPACE")) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 130 } }
        }
    }

    // 瞬态视图插槽
    Item {
        id: mediaPeekView
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        clip: true
        visible: opacity > 0.001
        opacity: (!compactRoot.isScrubbing && compactRoot.hasActiveTransient && compactRoot.currentKey === "MEDIA_PEEK") ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Row {
            anchors.fill: parent
            spacing: 10

            Rectangle {
                width: 24; height: 24; radius: 6
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(255, 255, 255, 0.10)
                Text { anchors.centerIn: parent; text: "🎵"; font.pixelSize: 13 }
            }

            Column {
                width: parent.width - 24 - 10 - 46 - 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                clip: true

                Text {
                    text: (compactRoot.currentPayload && compactRoot.currentPayload.title) ? compactRoot.currentPayload.title : "正在播放"
                    color: "#ffffff"
                    font.family: compactRoot.effectiveFont
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: (compactRoot.currentPayload && compactRoot.currentPayload.subtitle) ? compactRoot.currentPayload.subtitle : "音乐媒体"
                    color: (compactRoot.currentPayload && compactRoot.currentPayload.color) ? compactRoot.currentPayload.color : "#22c55e"
                    font.family: compactRoot.effectiveFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2.5
                Repeater {
                    model: 6
                    Rectangle {
                        width: 2.8; height: 15; radius: 1.4
                        color: (compactRoot.currentPayload && compactRoot.currentPayload.color) ? compactRoot.currentPayload.color : "#22c55e"
                        anchors.verticalCenter: parent.verticalCenter
                        transform: Scale {
                            origin.y: 7.5
                            yScale: compactRoot.getSixBandValue(index)
                            Behavior on yScale { NumberAnimation { duration: 75 } }
                        }
                    }
                }
            }
        }
    }

    CompactAlertView {
        id: alertView
        anchors.fill: parent
        chosenFont: compactRoot.effectiveFont
        isAlertActive: !compactRoot.isScrubbing && compactRoot.hasActiveTransient && compactRoot.currentKey === "ALERT"
        alertTitle: (compactRoot.currentPayload && compactRoot.currentPayload.title) || ""
        alertSubtitle: (compactRoot.currentPayload && compactRoot.currentPayload.subtitle) || ""
        alertAvatar: (compactRoot.currentPayload && compactRoot.currentPayload.avatar) || ""
        alertThemeColor: (compactRoot.currentPayload && compactRoot.currentPayload.color) || Theme.notification
    }

    CompactOsdView {
        id: osdView
        anchors.fill: parent
        chosenFont: compactRoot.effectiveFont
        osdIcon: (compactRoot.hasActiveTransient && compactRoot.currentKey === "OSD")
                 ? ((compactRoot.currentPayload && compactRoot.currentPayload.icon) || compactRoot.cachedOsdIcon)
                 : compactRoot.cachedOsdIcon
        osdValue: (compactRoot.hasActiveTransient && compactRoot.currentKey === "OSD")
                  ? ((compactRoot.currentPayload && compactRoot.currentPayload.value !== undefined) ? compactRoot.currentPayload.value : compactRoot.cachedOsdValue)
                  : compactRoot.cachedOsdValue
        visible: opacity > 0.001
        opacity: (!compactRoot.isScrubbing && compactRoot.hasActiveTransient && compactRoot.currentKey === "OSD") ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    CompactCallView {
        id: callView
        anchors.fill: parent
        chosenFont: compactRoot.effectiveFont
        isCalling: !compactRoot.isScrubbing && compactRoot.hasActiveTransient && compactRoot.currentKey === "CALL"
        callTitle: (compactRoot.currentPayload && compactRoot.currentPayload.title) || ""
        callSubtitle: (compactRoot.currentPayload && compactRoot.currentPayload.subtitle) || ""
        callAvatar: (compactRoot.currentPayload && compactRoot.currentPayload.avatar) || ""
        visible: opacity > 0.001
        opacity: isCalling ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    CompactVoiceView {
        id: voiceView
        anchors.fill: parent
        chosenFont: compactRoot.effectiveFont
        isListening: !compactRoot.isScrubbing && compactRoot.hasActiveTransient && (compactRoot.currentKey === "VOICE_INPUT" || compactRoot.currentKey === "VOICE")
        voiceLevel: (typeof Bridge !== "undefined" && Bridge.voiceInputLevel !== undefined) ? Bridge.voiceInputLevel : 0.2
        streamText: (typeof Bridge !== "undefined" && Bridge.voiceInputText !== undefined) ? Bridge.voiceInputText : ""
        onStopRequested: if (typeof Bridge !== "undefined") Bridge.stopVoiceInput()
    }

    CompactSedentaryView {
        id: sedentaryView
        anchors.fill: parent
        chosenFont: compactRoot.effectiveFont
        continuousSitMinutes: 45
        visible: opacity > 0.001
        opacity: (!compactRoot.isScrubbing && compactRoot.hasActiveTransient && compactRoot.currentKey === "SEDENTARY") ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        onSedentaryRested: if (compactRoot.fsm) compactRoot.fsm.dismissTransient("SEDENTARY")
        onSedentarySnooze: if (compactRoot.fsm) compactRoot.fsm.dismissTransient("SEDENTARY")
    }
}