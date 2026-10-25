// =========================================================================
// 📄 File: ui/views/CompactCapsuleView.qml
// 🌟 紧凑态视口 (完美融合：高级磨砂视觉 + 凸透镜拖拽桌面完全复活版)
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

    // 🚀【核心复活】：向外暴露拖拽状态，与父级手势传感器完全打通
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

    // 🚀【视觉优化】：外边距由 24 优化到 28，间距拉开到 10，解决局促感
    readonly property int fixedOuterPadding: 28
    readonly property int fixedInterSpacing: 10

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

    // 1. 左侧槽位宽度
    readonly property int leadingSlotBucket: {
        var showWs = (typeof Config !== "undefined" && Config.showWorkspaceName !== false);
        if (!showWs) return 0;
        var nameStr = (compactRoot.relay && compactRoot.relay.wsName) ? compactRoot.relay.wsName.trim() : "";
        if (/^\d+$/.test(nameStr) || nameStr.length <= 1) return 28;
        return Math.min(72, Math.max(40, nameStr.length * 9 + 18));
    }

    // 2. 中间槽位宽度
    readonly property int centerSlotBucket: (clockView && clockView.allocatedWidth > 0) ? clockView.allocatedWidth : 52

    // 3. 右侧微模块宽度
    readonly property int timerSlotWidth: hasActiveTimer ? 58 : 0
    readonly property int noticeBadgeSlotWidth: unreadNoticeCount > 0 ? (unreadNoticeCount >= 10 ? 34 : 28) : 0
    readonly property int musicWaveSlotWidth: isMusicPlaying ? 34 : 0

    readonly property int trailingSlotBucket: {
        var w = 0;
        var activeCount = 0;
        if (timerSlotWidth > 0) { w += timerSlotWidth; activeCount++; }
        if (noticeBadgeSlotWidth > 0) { w += noticeBadgeSlotWidth; activeCount++; }
        if (musicWaveSlotWidth > 0) { w += musicWaveSlotWidth; activeCount++; }
        if (activeCount > 1) { w += (activeCount - 1) * 6; }
        return w;
    }

    // 4. 自然宽度：拖拽时固定展开为宽裕的标尺视口 (300px)
    readonly property int naturalWidth: {
        if (compactRoot.isScrubbing) return 300;

        if (hasActiveTransient) {
            if (currentKey === "CALL") return 320;
            if (currentKey === "VOICE_INPUT" || currentKey === "VOICE") return 320;
            if (currentKey === "SEDENTARY") return 420;
            if (currentKey === "ALERT") return 280;
            if (currentKey === "WORKSPACE") return 240;
            if (currentKey === "OSD") return 200;
            if (currentKey === "MEDIA_PEEK") {
                var titleLen = (currentPayload && currentPayload.title) ? currentPayload.title.length : 0;
                return Math.min(360, Math.max(250, 110 + titleLen * 13));
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

    // 供外层传感器调用的拖拽代理方法
    function handleScrubMove(mx, my) {
        if (wsView) wsView.updateCursorByMouseX(mx);
    }
    function getScrubTargetIndex() {
        return wsView ? wsView.scrubHoverIndex : 0;
    }

    // =========================================================================
    // 视图层
    // =========================================================================
    Item {
        anchors.fill: parent
        clip: true

        // ---------------------------------------------------------------------
        // A. 常态流水线 (拖拽中或有弹窗时平滑隐去)
        // ---------------------------------------------------------------------
        Row {
            id: flowPipeline
            anchors.centerIn: parent
            spacing: compactRoot.fixedInterSpacing
            visible: !compactRoot.hasActiveTransient && !compactRoot.isScrubbing
            opacity: (!compactRoot.hasActiveTransient && !compactRoot.isScrubbing) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            // 左侧：空间药丸
            Item {
                id: wsSlotItem
                anchors.verticalCenter: parent.verticalCenter
                visible: compactRoot.leadingSlotBucket > 0
                width: compactRoot.leadingSlotBucket
                height: 20
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: wsHover.hovered ? Qt.rgba(255, 255, 255, 0.16) : Qt.rgba(255, 255, 255, 0.08)
                    border.color: wsHover.hovered ? Qt.rgba(255, 255, 255, 0.35) : Qt.rgba(255, 255, 255, 0.12)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 6
                        text: (compactRoot.relay && compactRoot.relay.wsName) ? compactRoot.relay.wsName : (compactRoot.relay ? compactRoot.relay.wsCurrent : "1")
                        color: "#f1f5f9"
                        font.pixelSize: 10
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

            // 中间：时钟核心
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
                spacing: 6
                visible: compactRoot.trailingSlotBucket > 0

                // 专注倒计时微囊
                Rectangle {
                    width: compactRoot.timerSlotWidth
                    height: 20
                    radius: 10
                    visible: compactRoot.hasActiveTimer
                    color: Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.16)
                    border.color: Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.5)
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
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.features: { "tnum": 1 }
                        renderType: Text.QtRendering
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: if (typeof Bridge !== "undefined") Bridge.toggleTimerPause() }
                }

                // 消息未读微囊
                Rectangle {
                    id: unreadBadgePod
                    width: compactRoot.noticeBadgeSlotWidth
                    height: 20
                    radius: 10
                    visible: compactRoot.unreadNoticeCount > 0
                    color: notifTipHover.hovered ? Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.32) : Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.18)
                    border.color: Qt.rgba(129 / 255, 140 / 255, 248 / 255, 0.5)
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        anchors.centerIn: parent
                        spacing: 2
                        Text { text: "💬"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: compactRoot.unreadNoticeCount
                            color: "white"
                            font.pixelSize: 10
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

                // 独立 6 柱动态声谱
                Item {
                    id: musicWaveIsland
                    width: compactRoot.musicWaveSlotWidth
                    height: 22
                    visible: compactRoot.isMusicPlaying
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        anchors.centerIn: parent
                        spacing: 2.2

                        Repeater {
                            model: 6
                            Rectangle {
                                width: 2.5
                                height: 13
                                radius: 1.25
                                color: compactRoot.relay ? compactRoot.relay.dominantColor : "#22c55e"
                                anchors.verticalCenter: parent.verticalCenter
                                transform: Scale {
                                    origin.y: 6.5
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

        // ---------------------------------------------------------------------
        // B. 🚀【核心复活】：拖拽桌面标尺视图 (Scrubbing / Transient 共同宿主)
        // ---------------------------------------------------------------------
        CompactWorkspaceView {
            id: wsView
            anchors.fill: parent
            chosenFont: compactRoot.effectiveFont
            wsName: compactRoot.relay ? compactRoot.relay.wsName : ""
            wsTotal: compactRoot.relay ? compactRoot.relay.wsTotal : 4
            wsList: compactRoot.relay ? compactRoot.relay.wsList : []
            displayWsNumber: compactRoot.relay ? compactRoot.relay.wsCurrent : 1

            // 联动拖拽状态
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
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        clip: true
        visible: opacity > 0.001
        opacity: (!compactRoot.isScrubbing && compactRoot.hasActiveTransient && compactRoot.currentKey === "MEDIA_PEEK") ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Row {
            anchors.fill: parent
            spacing: 8

            Rectangle {
                width: 20; height: 20; radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(255, 255, 255, 0.08)
                Text { anchors.centerIn: parent; text: "🎵"; font.pixelSize: 11 }
            }

            Column {
                width: parent.width - 20 - 8 - 42 - 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                clip: true

                Text {
                    text: (compactRoot.currentPayload && compactRoot.currentPayload.title) ? compactRoot.currentPayload.title : "正在播放"
                    color: "#ffffff"
                    font.family: compactRoot.effectiveFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: (compactRoot.currentPayload && compactRoot.currentPayload.subtitle) ? compactRoot.currentPayload.subtitle : "音乐媒体"
                    color: (compactRoot.currentPayload && compactRoot.currentPayload.color) ? compactRoot.currentPayload.color : "#22c55e"
                    font.family: compactRoot.effectiveFont
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2.2
                Repeater {
                    model: 6
                    Rectangle {
                        width: 2.5; height: 13; radius: 1.25
                        color: (compactRoot.currentPayload && compactRoot.currentPayload.color) ? compactRoot.currentPayload.color : "#22c55e"
                        anchors.verticalCenter: parent.verticalCenter
                        transform: Scale {
                            origin.y: 6.5
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