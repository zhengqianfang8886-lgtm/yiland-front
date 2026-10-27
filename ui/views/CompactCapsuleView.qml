// =========================================================================
// 📄 File: ui/views/CompactCapsuleView.qml
// 🌟 槽位离散量化主视口 (彻底移除鱼眼与洗牌态依赖版)
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
    property var sedentaryService: null

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    readonly property bool hasActiveTransient: fsm ? (fsm.activeTransientKey !== "") : false
    readonly property string currentKey: fsm ? fsm.activeTransientKey : ""
    readonly property var currentPayload: (fsm && fsm.activePayload) ? fsm.activePayload : ({})

    readonly property bool isMusicPlaying: (compactRoot.relay && compactRoot.relay.visualPlaying)
    readonly property int unreadNoticeCount: (compactRoot.relay && compactRoot.relay.unreadCount > 0) ? compactRoot.relay.unreadCount : 0
    readonly property bool hasActiveTimer: (typeof Bridge !== "undefined") && (Bridge.timerIsRunning || Bridge.timerIsPaused || Bridge.timerIsCompleted || Bridge.timerIsOvertime)
    readonly property bool isImeActive: (typeof Bridge !== "undefined" && Bridge.isImeActive !== undefined)

    readonly property bool isImeMenuOpen: typeof imePill !== "undefined" ? imePill.isMenuOpen : false

    property int cachedOsdValue: (typeof Bridge !== "undefined" && Bridge.currentVolume !== undefined) ? Bridge.currentVolume : 50
    property string cachedOsdIcon: "🔊"

    onCurrentPayloadChanged: {
        if (currentPayload && currentPayload.value !== undefined) cachedOsdValue = currentPayload.value;
        if (currentPayload && currentPayload.icon) cachedOsdIcon = currentPayload.icon;
    }

    // =========================================================================
    // 槽位物理宽度测算引擎
    // =========================================================================
    readonly property int slotLeftWidth: (typeof Config !== "undefined" && Config.showWorkspaceName !== false) 
        ? Math.max(42, wsLabel.implicitWidth + 20) : 0

    readonly property int slotClockWidth: clockView.implicitWidth

    readonly property int slotTimerWidth: {
        if (!hasActiveTimer) return 0;
        var isOt = (typeof Bridge !== "undefined") && Bridge.timerIsOvertime;
        var s = 0;
        if (typeof Bridge !== "undefined") {
            if (Bridge.timerType === "stopwatch") s = Bridge.timerElapsedSec;
            else if (isOt) s = Bridge.timerOvertimeSec;
            else s = Bridge.timerRemainingSec;
        }
        if (s >= 3600) return isOt ? 104 : 92;
        return isOt ? 78 : 68;
    }

    readonly property int slotNetWidth: (typeof Config !== "undefined" && Config.showNetSpeed === false) ? 0 : 68
    readonly property int slotImeWidth: isImeActive ? 30 : 0
    readonly property int slotNoticeWidth: unreadNoticeCount > 0 ? (unreadNoticeCount >= 10 ? 38 : 32) : 0
    readonly property int slotMusicWidth: isMusicPlaying ? 48 : 0

    readonly property int slotRightGroupWidth: {
        var w = 0, count = 0;
        if (slotTimerWidth > 0)  { w += slotTimerWidth; count++; }
        if (slotNetWidth > 0)    { w += slotNetWidth; count++; }
        if (slotImeWidth > 0)    { w += slotImeWidth; count++; }
        if (slotNoticeWidth > 0) { w += slotNoticeWidth; count++; }
        if (slotMusicWidth > 0)  { w += slotMusicWidth; count++; }
        if (count > 1) w += (count - 1) * 6;
        return w;
    }

    readonly property int naturalWidth: {
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

        var total = 24 + slotClockWidth;
        if (slotLeftWidth > 0) total += (slotLeftWidth + 8);
        if (slotRightGroupWidth > 0) total += (slotRightGroupWidth + 8);

        return Math.ceil(total / 4.0) * 4;
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

    // =========================================================================
    // 1. 常态视口
    // =========================================================================
    Item {
        id: normalViewContainer
        anchors.fill: parent
        clip: true
        visible: opacity > 0.001
        opacity: !compactRoot.hasActiveTransient ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Row {
            id: contentStream
            anchors.centerIn: parent
            spacing: 7

            Item {
                id: leftSlot
                height: 24
                width: compactRoot.slotLeftWidth
                visible: width > 0
                anchors.verticalCenter: parent.verticalCenter
                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(255, 255, 255, 0.12)
                    border.color: Qt.rgba(255, 255, 255, 0.20)
                    border.width: 1

                    Text {
                        id: wsLabel
                        anchors.centerIn: parent
                        text: (compactRoot.relay && compactRoot.relay.wsName) ? compactRoot.relay.wsName : (compactRoot.relay ? compactRoot.relay.wsCurrent : "1")
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.weight: Font.Black
                        font.family: compactRoot.displayFont
                        renderType: Text.QtRendering
                    }
                }
            }

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

            Row {
                id: rightSlotGroup
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: compactRoot.slotRightGroupWidth > 0

                Item {
                    id: timerPod
                    height: 26
                    width: compactRoot.slotTimerWidth
                    visible: width > 0
                    anchors.verticalCenter: parent.verticalCenter

                    readonly property bool isOvertime: (typeof Bridge !== "undefined") && Bridge.timerIsOvertime

                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    Rectangle {
                        id: timerRect
                        anchors.fill: parent
                        radius: 13

                        color: timerPod.isOvertime ?
                               (timerMouse.pressed ? Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.28) :
                               (timerMouse.containsMouse ? Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.18) : Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.10))) :
                               (timerMouse.pressed ? Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.22) :
                               (timerMouse.containsMouse ? Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.14) : Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.08)))

                        border.color: timerPod.isOvertime ?
                                      (timerMouse.containsMouse ? "#FF453A" : Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.50)) :
                                      (timerMouse.containsMouse ? Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.65) : Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.25))
                        border.width: 1

                        scale: timerMouse.pressed ? 0.94 : (timerMouse.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        CompactTimerView {
                            anchors.centerIn: parent
                            fontFam: compactRoot.displayFont
                            pixelSize: 15
                            textColor: {
                                if (typeof Bridge === "undefined") return "#FF9F0A";
                                if (Bridge.timerIsOvertime) return "#FF453A";
                                if (Bridge.timerIsCompleted) return "#30D158";
                                if (Bridge.timerType === "stopwatch") return "#38BDF8";
                                return "#FF9F0A";
                            }
                            isOvertime: timerPod.isOvertime
                            totalSeconds: {
                                if (typeof Bridge === "undefined") return 1500;
                                if (Bridge.timerType === "stopwatch") return Bridge.timerElapsedSec;
                                if (Bridge.timerIsOvertime) return Bridge.timerOvertimeSec;
                                return Bridge.timerRemainingSec;
                            }
                            isPaused: (typeof Bridge !== "undefined") ? Bridge.timerIsPaused : false
                        }

                        MouseArea {
                            id: timerMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                mouse.accepted = true;
                                if (mouse.button === Qt.LeftButton) {
                                    if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "timer", source: "Click_TimerPod" });
                                } else if (mouse.button === Qt.RightButton) {
                                    if (typeof Bridge !== "undefined" && Bridge.resetTimer) Bridge.resetTimer();
                                }
                            }
                            onWheel: (wheel) => { wheel.accepted = false; }
                        }
                    }
                }

                CompactNetSpeedView {
                    id: netSpeedPill
                    anchors.verticalCenter: parent.verticalCenter
                    visible: compactRoot.slotNetWidth > 0
                    fontFam: compactRoot.displayFont
                    downVal: compactRoot.relay ? compactRoot.relay.netDownVal : "0"
                    downUnit: compactRoot.relay ? compactRoot.relay.netDownUnit : "B/s"
                    upVal: compactRoot.relay ? compactRoot.relay.netUpVal : "0"
                    upUnit: compactRoot.relay ? compactRoot.relay.netUpUnit : "B/s"
                    downCompact: compactRoot.relay ? compactRoot.relay.downCompact : "0B"
                    upCompact: compactRoot.relay ? compactRoot.relay.upCompact : "0B"
                }

                CompactImeView {
                    id: imePill
                    anchors.verticalCenter: parent.verticalCenter
                    visible: compactRoot.slotImeWidth > 0
                }

                Item {
                    id: noticePod
                    height: 24
                    width: compactRoot.slotNoticeWidth
                    visible: width > 0
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: noticeMouse.pressed ? Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.45) :
                               (noticeMouse.containsMouse ? Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.32) : Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.22))
                        border.color: noticeMouse.containsMouse ? "#a5b4fc" : Qt.rgba(129 / 255, 140 / 255, 248 / 255, 0.6)
                        border.width: 1

                        scale: noticeMouse.pressed ? 0.92 : (noticeMouse.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

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

                        MouseArea {
                            id: noticeMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                mouse.accepted = true;
                                if (mouse.button === Qt.LeftButton) {
                                    if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "notification", source: "Click_NoticePod" });
                                } else if (mouse.button === Qt.RightButton) {
                                    if (typeof Bridge !== "undefined" && Bridge.notificationModel) Bridge.notificationModel.clearAll();
                                }
                            }
                            onWheel: (wheel) => { wheel.accepted = false; }
                        }
                    }
                }

                // =========================================================================
                // 🌟 纯粹苹果级声学微囊 (彻底移除照片 · HSL 强力增艳 · 5柱对称流体律动版)
                // =========================================================================
                Item {
                    id: musicPod
                    height: 26
                    width: compactRoot.isMusicPlaying ? 44 : 0
                    visible: width > 0
                    anchors.verticalCenter: parent.verticalCenter

                    // 🚀【HSL 色彩提纯重构】：保留封面色相，强制锁死高饱和度与明度，绝对不发褐发淡
                    readonly property color vividMusicColor: {
                        var rawColor = (compactRoot.relay && compactRoot.relay.dominantColor) ? Qt.color(compactRoot.relay.dominantColor) : Qt.color("#22c55e");
                        var r = rawColor.r, g = rawColor.g, b = rawColor.b;
                        var maxC = Math.max(r, Math.max(g, b));
                        var minC = Math.min(r, Math.min(g, b));
                        var delta = maxC - minC;

                        // 若饱和度极低（黑白灰杂色），直接赋予纯正 Apple/Spotify 活力翡翠绿
                        if (delta < 0.08) {
                            return "#22c55e";
                        }

                        // 计算真实色相 (Hue: 0.0 ~ 1.0)
                        var h = 0.0;
                        if (maxC === r) {
                            h = (g - b) / delta + (g < b ? 6 : 0);
                        } else if (maxC === g) {
                            h = (b - r) / delta + 2;
                        } else {
                            h = (r - g) / delta + 4;
                        }
                        h /= 6.0;

                        // 强行锁死：95% 极高饱和度 + 54% 黄金明度，枯黄暗褐瞬间变为璀璨琥珀金！
                        return Qt.hsla(h, 0.95, 0.54, 1.0);
                    }

                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                    Rectangle {
                        id: musicRect
                        anchors.fill: parent
                        radius: 13

                        // 深黑暗晶微透材质，悬停时产生微光外扩
                        color: musicMouse.pressed ? Qt.rgba(musicPod.vividMusicColor.r, musicPod.vividMusicColor.g, musicPod.vividMusicColor.b, 0.25) :
                               (musicMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06))

                        border.color: musicMouse.containsMouse ? musicPod.vividMusicColor : Qt.rgba(255, 255, 255, 0.14)
                        border.width: 1

                        scale: musicMouse.pressed ? 0.94 : (musicMouse.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        // =====================================================================
                        // 5 柱自然声学包络波形 (中间高、两侧逐渐收拢)
                        // =====================================================================
                        Row {
                            anchors.centerIn: parent
                            spacing: 2.4

                            Repeater {
                                model: 5

                                Rectangle {
                                    width: 2.8
                                    height: 14
                                    radius: 1.4
                                    color: musicPod.vividMusicColor
                                    anchors.verticalCenter: parent.verticalCenter

                                    transform: Scale {
                                        origin.y: 7
                                        yScale: {
                                            if (!compactRoot.isMusicPlaying) return 0.22;
                                            var s1 = compactRoot.relay ? compactRoot.relay.spec1 : 0.2;
                                            var s2 = compactRoot.relay ? compactRoot.relay.spec2 : 0.2;
                                            var s3 = compactRoot.relay ? compactRoot.relay.spec3 : 0.2;
                                            var s4 = compactRoot.relay ? compactRoot.relay.spec4 : 0.2;

                                            // 对称声学生长系数：中间柱起伏最大，两侧柔和递减
                                            switch (index) {
                                                case 0: return Math.max(0.24, Math.min(0.80, s1 * 0.90));
                                                case 1: return Math.max(0.30, Math.min(0.95, s2 * 1.15));
                                                case 2: return Math.max(0.36, Math.min(1.00, (s2 + s3) * 0.70)); // 中间主峰
                                                case 3: return Math.max(0.30, Math.min(0.95, s3 * 1.15));
                                                case 4: return Math.max(0.24, Math.min(0.80, s4 * 0.90));
                                                default: return 0.24;
                                            }
                                        }
                                        Behavior on yScale {
                                            enabled: compactRoot.isMusicPlaying
                                            NumberAnimation { duration: 75; easing.type: Easing.OutQuad }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: musicMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: (mouse) => {
                                mouse.accepted = true;
                                if (mouse.button === Qt.LeftButton) {
                                    // 左键展开音乐大卡片
                                    if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "media", source: "Click_MusicPod" });
                                } else if (mouse.button === Qt.RightButton) {
                                    // 右键直接播放/暂停
                                    if (typeof Bridge !== "undefined") Bridge.sendMediaCmd("MEDIA_PLAY_PAUSE");
                                }
                            }
                            onWheel: (wheel) => { wheel.accepted = false; }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 2. 打断态暂态悬浮栈
    // =========================================================================
    Loader {
        id: overlayLoader
        anchors.fill: parent
        clip: true
        active: compactRoot.hasActiveTransient
        visible: opacity > 0.001
        opacity: compactRoot.hasActiveTransient ? 1.0 : 0.0
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
                case "WORKSPACE": return compWs;
                default: return null;
            }
        }
    }

    Component {
        id: compWs
        CompactWorkspaceView {
            chosenFont: compactRoot.effectiveFont
            wsName: compactRoot.relay ? compactRoot.relay.wsName : ""
            wsTotal: compactRoot.relay ? compactRoot.relay.wsTotal : 4
            wsList: compactRoot.relay ? compactRoot.relay.wsList : []
            displayWsNumber: compactRoot.relay ? compactRoot.relay.wsCurrent : 1
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
            continuousSitMinutes: (compactRoot.currentPayload && compactRoot.currentPayload.continuousMinutes) ? compactRoot.currentPayload.continuousMinutes : 45
            onSedentaryRested: {
                if (compactRoot.sedentaryService) compactRoot.sedentaryService.markRested();
                else if (compactRoot.fsm) compactRoot.fsm.dismissTransient("SEDENTARY");
            }
            onSedentarySnooze: {
                if (compactRoot.sedentaryService) compactRoot.sedentaryService.snooze();
                else if (compactRoot.fsm) compactRoot.fsm.dismissTransient("SEDENTARY");
            }
            implicitWidth: 430
        }
    }

    Component {
        id: compMediaPeek
        CompactMediaPeekView {
            payload: compactRoot.currentPayload
            effectiveFont: compactRoot.effectiveFont
            relay: compactRoot.relay
        }
    }
}