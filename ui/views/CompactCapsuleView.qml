// =========================================================================
// 📄 File: ui/views/CompactCapsuleView.qml
// 🌟 黄金比例舒适边距视口 (微增2px透气余量 · 饱满紧致 · 绝对贴合版)
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

    property int cachedOsdValue: (typeof Bridge !== "undefined" && Bridge.currentVolume !== undefined) ? Bridge.currentVolume : 50
    property string cachedOsdIcon: "🔊"

    onCurrentPayloadChanged: {
        if (currentPayload && currentPayload.value !== undefined) cachedOsdValue = currentPayload.value;
        if (currentPayload && currentPayload.icon) cachedOsdIcon = currentPayload.icon;
    }

    function getSixBandValue(idx) {
        if (!compactRoot.relay) return 0.2;
        var s1 = compactRoot.relay.spec1 || 0.2, s2 = compactRoot.relay.spec2 || 0.2;
        var s3 = compactRoot.relay.spec3 || 0.2, s4 = compactRoot.relay.spec4 || 0.2;
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

    // 真实尺寸
    readonly property int realLeftW: (typeof Config !== "undefined" && Config.showWorkspaceName !== false) ? Math.max(34, wsLabel.implicitWidth + 12) : 0
    readonly property int realClockW: clockView.implicitWidth

    readonly property int realTimerW: hasActiveTimer ? 64 : 0
    readonly property int realNoticeW: unreadNoticeCount > 0 ? (unreadNoticeCount >= 10 ? 36 : 30) : 0
    readonly property int realMusicW: isMusicPlaying ? 36 : 0

    readonly property int realRightW: {
        var w = 0, cnt = 0;
        if (realTimerW > 0) { w += realTimerW; cnt++; }
        if (realNoticeW > 0) { w += realNoticeW; cnt++; }
        if (realMusicW > 0) { w += realMusicW; cnt++; }
        if (cnt > 1) w += (cnt - 1) * 6;
        return w;
    }

    // 🚀【黄金微边距】：总边距调至 22px（左右单边 11px），微增 3px 绝佳透气感！
    readonly property int naturalWidth: {
        if (compactRoot.isScrubbing) return 320;

        if (hasActiveTransient) {
            switch (compactRoot.currentKey) {
                case "CALL": return 340;
                case "VOICE_INPUT":
                case "VOICE": return 340;
                case "SEDENTARY": return 430;
                case "ALERT": return 300;
                case "WORKSPACE": return 260;
                case "OSD": return 220;
                case "MEDIA_PEEK": {
                    var titleLen = (currentPayload && currentPayload.title) ? currentPayload.title.length : 0;
                    return Math.min(360, Math.max(260, 140 + titleLen * 12));
                }
                default: return 280;
            }
        }

        // 左右总内边距 22px (单侧 11px)，模块间隙 7px
        var w = 22 + realClockW;
        if (realLeftW > 0) w += (realLeftW + 7);
        if (realRightW > 0) w += (realRightW + 7);

        return (w % 2 === 0) ? w : (w + 1);
    }

    function handleScrubMove(mx, my) { if (wsView) wsView.updateCursorByMouseX(mx); }
    function getScrubTargetIndex() { return wsView ? wsView.scrubHoverIndex : 0; }

    // =========================================================================
    // 🌟 常态主视口 (微增呼吸间隙，完美贴合圆角)
    // =========================================================================
    Item {
        id: normalViewContainer
        anchors.fill: parent
        clip: true
        visible: opacity > 0.001

        opacity: (!compactRoot.hasActiveTransient && !compactRoot.isScrubbing) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Row {
            id: contentStream
            anchors.centerIn: parent
            spacing: 7 // 稍微舒展 1px

            // 1. 左翼：工作区微囊
            Item {
                id: leftSlot
                height: 22
                width: compactRoot.realLeftW
                visible: width > 0
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: wsHover.hovered ? Qt.rgba(255, 255, 255, 0.18) : Qt.rgba(255, 255, 255, 0.10)
                    border.color: wsHover.hovered ? Qt.rgba(255, 255, 255, 0.45) : Qt.rgba(255, 255, 255, 0.15)
                    border.width: 1

                    Text {
                        id: wsLabel
                        anchors.centerIn: parent
                        text: (compactRoot.relay && compactRoot.relay.wsName) ? compactRoot.relay.wsName : (compactRoot.relay ? compactRoot.relay.wsCurrent : "1")
                        color: "#f8fafc"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.family: compactRoot.displayFont
                        renderType: Text.QtRendering
                    }

                    HoverHandler { id: wsHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: if (typeof Bridge !== "undefined") Bridge.switchWorkspaceNext() }
                }
            }

            // 2. 中央：饱满大字号时钟
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

            // 3. 右翼微囊组
            Row {
                id: rightSlotGroup
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: compactRoot.realRightW > 0

                // 倒计时
                Item {
                    id: timerPod
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    width: compactRoot.realTimerW
                    visible: width > 0

                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 11
                        color: Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.20)
                        border.color: Qt.rgba(249 / 255, 115 / 255, 22 / 255, 0.6)
                        border.width: 1

                        CompactTimerView {
                            anchors.centerIn: parent
                            fontFam: compactRoot.displayFont
                            pixelSize: 11
                            textColor: "#fdba74"
                            totalSeconds: {
                                if (typeof Bridge === "undefined") return 1500;
                                return Bridge.timerType === "stopwatch" ? Bridge.timerElapsedSec : Bridge.timerRemainingSec;
                            }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: if (typeof Bridge !== "undefined") Bridge.toggleTimerPause() }
                    }
                }

                // 未读通知
                Item {
                    id: noticePod
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    width: compactRoot.realNoticeW
                    visible: width > 0

                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 11
                        color: Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.22)
                        border.color: Qt.rgba(129 / 255, 140 / 255, 248 / 255, 0.6)
                        border.width: 1

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

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "notification" }) }
                    }
                }

                // 音乐律动
                Item {
                    id: musicPod
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    width: compactRoot.realMusicW
                    visible: width > 0

                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 11
                        color: Qt.rgba(34 / 255, 197 / 255, 94 / 255, 0.16)
                        border.color: Qt.rgba(34 / 255, 197 / 255, 94 / 255, 0.4)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 2.2

                            Repeater {
                                model: 6
                                Rectangle {
                                    width: 2.6; height: 13; radius: 1.3
                                    color: compactRoot.relay ? compactRoot.relay.dominantColor : "#22c55e"
                                    anchors.verticalCenter: parent.verticalCenter
                                    transform: Scale {
                                        origin.y: 6.5
                                        yScale: compactRoot.isMusicPlaying ? compactRoot.getSixBandValue(index) : 0.15
                                        Behavior on yScale {
                                            enabled: compactRoot.isMusicPlaying
                                            NumberAnimation { duration: 75 }
                                        }
                                    }
                                }
                            }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "media" }) }
                    }
                }
            }
        }
    }

    // 瞬态打断单一 Loader
    Loader {
        id: overlayLoader
        anchors.fill: parent
        clip: true
        active: compactRoot.hasActiveTransient && !compactRoot.isScrubbing
        visible: opacity > 0.001
        opacity: (compactRoot.hasActiveTransient && !compactRoot.isScrubbing) ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        sourceComponent: {
            if (!compactRoot.hasActiveTransient) return null;
            switch (compactRoot.currentKey) {
                case "CALL": return compCall;
                case "VOICE_INPUT":
                case "VOICE": return compVoice;
                case "SEDENTARY": return compSedentary;
                case "ALERT": return compAlert;
                case "OSD": return compOsd;
                case "MEDIA_PEEK": return compMediaPeek;
                default: return null;
            }
        }
    }

    Component {
        id: compAlert
        CompactAlertView {
            chosenFont: compactRoot.effectiveFont
            isAlertActive: true
            alertTitle: (compactRoot.currentPayload && compactRoot.currentPayload.title) || ""
            alertSubtitle: (compactRoot.currentPayload && compactRoot.currentPayload.subtitle) || ""
            alertAvatar: (compactRoot.currentPayload && compactRoot.currentPayload.avatar) || ""
            alertThemeColor: (compactRoot.currentPayload && compactRoot.currentPayload.color) || Theme.notification
            implicitWidth: 300
        }
    }

    Component {
        id: compOsd
        CompactOsdView {
            chosenFont: compactRoot.effectiveFont
            osdIcon: (compactRoot.currentPayload && compactRoot.currentPayload.icon) || compactRoot.cachedOsdIcon
            osdValue: (compactRoot.currentPayload && compactRoot.currentPayload.value !== undefined) ? compactRoot.currentPayload.value : compactRoot.cachedOsdValue
            implicitWidth: 220
        }
    }

    Component {
        id: compCall
        CompactCallView {
            chosenFont: compactRoot.effectiveFont
            isCalling: true
            callTitle: (compactRoot.currentPayload && compactRoot.currentPayload.title) || ""
            callSubtitle: (compactRoot.currentPayload && compactRoot.currentPayload.subtitle) || ""
            callAvatar: (compactRoot.currentPayload && compactRoot.currentPayload.avatar) || ""
            implicitWidth: 340
        }
    }

    Component {
        id: compVoice
        CompactVoiceView {
            chosenFont: compactRoot.effectiveFont
            isListening: true
            voiceLevel: (typeof Bridge !== "undefined" && Bridge.voiceInputLevel !== undefined) ? Bridge.voiceInputLevel : 0.2
            streamText: (typeof Bridge !== "undefined" && Bridge.voiceInputText !== undefined) ? Bridge.voiceInputText : ""
            onStopRequested: if (typeof Bridge !== "undefined") Bridge.stopVoiceInput()
            implicitWidth: 340
        }
    }

    Component {
        id: compSedentary
        CompactSedentaryView {
            chosenFont: compactRoot.effectiveFont
            continuousSitMinutes: 45
            onSedentaryRested: if (compactRoot.fsm) compactRoot.fsm.dismissTransient("SEDENTARY")
            onSedentarySnooze: if (compactRoot.fsm) compactRoot.fsm.dismissTransient("SEDENTARY")
            implicitWidth: 430
        }
    }

    Component {
        id: compMediaPeek
        Item {
            anchors.fill: parent
            anchors.leftMargin: 14; anchors.rightMargin: 14
            implicitWidth: Math.min(360, Math.max(260, 140 + ((compactRoot.currentPayload && compactRoot.currentPayload.title) ? compactRoot.currentPayload.title.length * 12 : 0)))

            Row {
                anchors.fill: parent
                spacing: 10
                Rectangle {
                    width: 24; height: 24; radius: 6; anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(255, 255, 255, 0.10)
                    Text { anchors.centerIn: parent; text: "🎵"; font.pixelSize: 13 }
                }
                Column {
                    width: parent.width - 24 - 10 - 46 - 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1; clip: true
                    Text {
                        text: (compactRoot.currentPayload && compactRoot.currentPayload.title) ? compactRoot.currentPayload.title : "正在播放"
                        color: "#ffffff"; font.family: compactRoot.effectiveFont; font.pixelSize: 12; font.weight: Font.Bold; elide: Text.ElideRight; width: parent.width
                    }
                    Text {
                        text: (compactRoot.currentPayload && compactRoot.currentPayload.subtitle) ? compactRoot.currentPayload.subtitle : "音乐媒体"
                        color: (compactRoot.currentPayload && compactRoot.currentPayload.color) ? compactRoot.currentPayload.color : "#22c55e"
                        font.family: compactRoot.effectiveFont; font.pixelSize: 10; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 2.5
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

        Behavior on opacity { NumberAnimation { duration: 160 } }
    }
}