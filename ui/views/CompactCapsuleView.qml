// ==========================================
// 📄 File: ui/views/CompactCapsuleView.qml
// 🌟 槽位全生命周期共振排版引擎 (零间距断层 · 相位锁相对齐版)
// ==========================================
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
    readonly property bool isImeActive: (typeof Bridge !== "undefined" && Bridge.isImeActive !== undefined) ? Bridge.isImeActive : false
    readonly property bool isRecordingActive: (typeof Bridge !== "undefined" && Bridge.isRecordingActive !== undefined) ? Bridge.isRecordingActive : false

    readonly property bool hasCountdown: (typeof Bridge !== "undefined") && Bridge.cdActive
    readonly property bool hasStopwatch: (typeof Bridge !== "undefined") && Bridge.swActive

    // 槽位物理宽度 (纯内容宽度)
    readonly property int slotLeftWidth: (typeof Config !== "undefined" && Config.showWorkspaceName !== false) 
        ? Math.max(38, wsLabel.implicitWidth + 16) : 0

    readonly property int slotCdWidth: {
        if (!hasCountdown) return 0;
        var isOt = Bridge.cdIsOvertime;
        var s = isOt ? Bridge.cdOvertimeSec : Bridge.cdRemainingSec;
        if (s >= 3600) return isOt ? 114 : 102;
        return isOt ? 84 : 76;
    }

    readonly property int slotSwWidth: {
        if (!hasStopwatch) return 0;
        var s = Bridge.swElapsedSec;
        if (s >= 3600) return 102;
        return 76;
    }

    readonly property int slotNetSpeedWidth: (typeof Config !== "undefined" && Config.showNetSpeed !== false) ? 56 : 0
    readonly property int slotRecordWidth: compactRoot.isRecordingActive ? 28 : 0
    readonly property int slotImeWidth: compactRoot.isImeActive ? 26 : 0
    readonly property int slotNoticeWidth: compactRoot.unreadNoticeCount > 0 ? (compactRoot.unreadNoticeCount >= 10 ? 40 : 34) : 0
    readonly property int slotMusicWidth: compactRoot.isMusicPlaying ? 40 : 0

    // 自然宽度：包含各槽位的 4px 动态呼吸间距
    readonly property int naturalWidth: {
        if (hasActiveTransient) {
            switch (compactRoot.currentKey) {
                case "CALL": return 340;
                case "VOICE_INPUT":
                case "VOICE": return 340;
                case "SEDENTARY": return 430;
                case "ALERT": return 300;
                case "WORKSPACE": return 260;
                case "MEDIA_PEEK": {
                    var titleLen = (currentPayload && currentPayload.title) ? currentPayload.title.length : 0;
                    return Math.min(360, Math.max(260, 140 + titleLen * 12));
                }
                default: return 280;
            }
        }

        var total = 24 + clockView.implicitWidth;
        if (compactRoot.slotLeftWidth > 0) total += (compactRoot.slotLeftWidth + 5);

        var rightTotal = 0;
        if (compactRoot.slotCdWidth > 0) rightTotal += (compactRoot.slotCdWidth + 4);
        if (compactRoot.slotSwWidth > 0) rightTotal += (compactRoot.slotSwWidth + 4);
        if (compactRoot.slotNetSpeedWidth > 0) rightTotal += (compactRoot.slotNetSpeedWidth + 4);
        if (compactRoot.slotRecordWidth > 0) rightTotal += (compactRoot.slotRecordWidth + 4);
        if (compactRoot.slotImeWidth > 0) rightTotal += (compactRoot.slotImeWidth + 4);
        if (compactRoot.slotNoticeWidth > 0) rightTotal += (compactRoot.slotNoticeWidth + 4);
        if (compactRoot.slotMusicWidth > 0) rightTotal += (compactRoot.slotMusicWidth + 4);

        if (rightTotal > 0) total += rightTotal;

        return Math.ceil(total / 4.0) * 4;
    }

    Item {
        id: normalViewContainer
        anchors.fill: parent
        visible: opacity > 0.001

        opacity: !compactRoot.hasActiveTransient ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: compactRoot.hasActiveTransient ? 60 : 150
                easing.type: Easing.OutQuad
            }
        }

        Row {
            id: contentStream
            anchors.centerIn: parent
            spacing: 5

            // 左侧：工作区
            FluidPill {
                id: leftSlotPill
                pillName: "workspace"
                targetWidth: compactRoot.slotLeftWidth
                gapSpacing: 5
                pillHeight: 22
                pillColor: Qt.rgba(255, 255, 255, 0.12)
                pillBorderColor: Qt.rgba(255, 255, 255, 0.22)
                interactive: false

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

            // 中间：时钟主座
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

            // 🚀【核心改动】：spacing 严格设为 0！所有间距内化到每个微囊的 gapSpacing 中！
            Row {
                id: rightSlotGroup
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                // 倒计时
                FluidPill {
                    id: cdPill
                    pillName: "countdown"
                    targetWidth: compactRoot.slotCdWidth
                    gapSpacing: 4
                    readonly property bool isOvertime: (typeof Bridge !== "undefined") && Bridge.cdIsOvertime

                    pillColor: isOvertime ? Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.10) : Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.08)
                    hoverColor: isOvertime ? Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.18) : Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.14)
                    pressColor: isOvertime ? Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.28) : Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.22)
                    pillBorderColor: isOvertime ? Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.50) : Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.25)
                    hoverBorderColor: isOvertime ? "#FF453A" : Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.65)

                    onClicked: {
                        if (typeof Bridge !== "undefined" && Bridge.switchTimerType) Bridge.switchTimerType("countdown");
                        if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "timer", source: "Click_CdPill" });
                    }
                    onRightClicked: {
                        if (typeof Bridge !== "undefined" && Bridge.resetSpecificTimer) Bridge.resetSpecificTimer("countdown");
                    }

                    CompactTimerView {
                        anchors.centerIn: parent
                        fontFam: compactRoot.displayFont
                        pixelSize: 14
                        textColor: cdPill.isOvertime ? "#FF453A" : (Bridge.cdMode === "break" ? "#30D158" : "#FF9F0A")
                        isOvertime: cdPill.isOvertime
                        totalSeconds: (typeof Bridge !== "undefined") ? (cdPill.isOvertime ? Bridge.cdOvertimeSec : Bridge.cdRemainingSec) : 1500
                        isPaused: (typeof Bridge !== "undefined") ? Bridge.cdIsPaused : false
                    }
                }

                // 秒表
                FluidPill {
                    id: swPill
                    pillName: "stopwatch"
                    targetWidth: compactRoot.slotSwWidth
                    gapSpacing: 4
                    pillColor: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.10)
                    hoverColor: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.18)
                    pressColor: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.28)
                    pillBorderColor: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.25)
                    hoverBorderColor: "#38BDF8"

                    onClicked: {
                        if (typeof Bridge !== "undefined" && Bridge.switchTimerType) Bridge.switchTimerType("stopwatch");
                        if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "timer", source: "Click_SwPill" });
                    }
                    onRightClicked: {
                        if (typeof Bridge !== "undefined" && Bridge.resetSpecificTimer) Bridge.resetSpecificTimer("stopwatch");
                    }

                    CompactTimerView {
                        anchors.centerIn: parent
                        fontFam: compactRoot.displayFont
                        pixelSize: 14
                        textColor: "#38BDF8"
                        isOvertime: false
                        totalSeconds: (typeof Bridge !== "undefined") ? Bridge.swElapsedSec : 0
                        isPaused: (typeof Bridge !== "undefined") ? Bridge.swIsPaused : false
                    }
                }

                // 网速
                FluidPill {
                    id: netSpeedPillWrapper
                    pillName: "netspeed"
                    targetWidth: compactRoot.slotNetSpeedWidth
                    gapSpacing: 4
                    interactive: false
                    pillColor: "transparent"
                    pillBorderColor: "transparent"

                    CompactNetSpeedView {
                        anchors.centerIn: parent
                        fontFam: compactRoot.displayFont
                        downVal: compactRoot.relay ? compactRoot.relay.netDownVal : "0"
                        downUnit: compactRoot.relay ? compactRoot.relay.netDownUnit : "B/s"
                        upVal: compactRoot.relay ? compactRoot.relay.netUpVal : "0"
                        upUnit: compactRoot.relay ? compactRoot.relay.netUpUnit : "B/s"
                        downCompact: compactRoot.relay ? compactRoot.relay.downCompact : "0B"
                        upCompact: compactRoot.relay ? compactRoot.relay.upCompact : "0B"
                    }
                }

                // 录制指示器 (OBS / 麦克风)
                FluidPill {
                    id: recordPillWrapper
                    pillName: "recording"
                    targetWidth: compactRoot.slotRecordWidth
                    gapSpacing: 4
                    interactive: false
                    pillColor: "transparent"
                    pillBorderColor: "transparent"

                    CompactRecordPill {
                        anchors.centerIn: parent
                    }
                }

                // 输入法
                FluidPill {
                    id: imePillWrapper
                    pillName: "ime"
                    targetWidth: compactRoot.slotImeWidth
                    gapSpacing: 4
                    interactive: false
                    pillColor: "transparent"
                    pillBorderColor: "transparent"

                    CompactImeView {
                        anchors.centerIn: parent
                    }
                }

                // 通知
                FluidPill {
                    id: noticePill
                    pillName: "notification"
                    targetWidth: compactRoot.slotNoticeWidth
                    gapSpacing: 4
                    pillColor: Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.22)
                    hoverColor: Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.32)
                    pressColor: Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.45)
                    pillBorderColor: Qt.rgba(129 / 255, 140 / 255, 248 / 255, 0.6)
                    hoverBorderColor: "#a5b4fc"

                    onClicked: {
                        if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "notification", source: "Click_NoticePill" });
                    }
                    onRightClicked: {
                        if (typeof Bridge !== "undefined" && Bridge.notificationModel) Bridge.notificationModel.clearAll();
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 2
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
                }

                // 音乐律动
                FluidPill {
                    id: musicPill
                    pillName: "music"
                    targetWidth: compactRoot.slotMusicWidth
                    gapSpacing: 4
                    readonly property color themeColor: {
                        if (compactRoot.relay && compactRoot.relay.dominantColor) return compactRoot.relay.dominantColor;
                        return "#22c55e";
                    }

                    pillColor: Qt.rgba(255, 255, 255, 0.06)
                    hoverColor: Qt.rgba(255, 255, 255, 0.12)
                    pressColor: Qt.rgba(themeColor.r, themeColor.g, themeColor.b, 0.25)
                    pillBorderColor: Qt.rgba(255, 255, 255, 0.14)
                    hoverBorderColor: themeColor

                    onClicked: {
                        if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "media", source: "Click_MusicPill" });
                    }
                    onRightClicked: {
                        if (typeof Bridge !== "undefined") Bridge.sendMediaCmd("MEDIA_PLAY_PAUSE");
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 2.2

                        Repeater {
                            model: 5
                            Rectangle {
                                width: 2.8; height: 14; radius: 1.4
                                color: musicPill.themeColor
                                anchors.verticalCenter: parent.verticalCenter

                                transform: Scale {
                                    origin.y: 7
                                    yScale: {
                                        if (!compactRoot.isMusicPlaying) return 0.22;
                                        var s1 = compactRoot.relay ? compactRoot.relay.spec1 : 0.2;
                                        var s2 = compactRoot.relay ? compactRoot.relay.spec2 : 0.2;
                                        var s3 = compactRoot.relay ? compactRoot.relay.spec3 : 0.2;
                                        var s4 = compactRoot.relay ? compactRoot.relay.spec4 : 0.2;

                                        switch (index) {
                                            case 0: return Math.max(0.24, Math.min(0.80, s1 * 0.90));
                                            case 1: return Math.max(0.30, Math.min(0.95, s2 * 1.15));
                                            case 2: return Math.max(0.36, Math.min(1.00, (s2 + s3) * 0.70));
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
                }
            }
        }
    }

    // 打断态
    Loader {
        id: overlayLoader
        anchors.fill: parent
        clip: true
        active: compactRoot.hasActiveTransient
        visible: opacity > 0.001
        opacity: compactRoot.hasActiveTransient ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        sourceComponent: {
            if (!compactRoot.hasActiveTransient) return null;
            switch (compactRoot.currentKey) {
                case "CALL": return compCall;
                case "VOICE_INPUT":
                case "VOICE": return compVoice;
                case "SEDENTARY": return compSedentary;
                case "ALERT": return compAlert;
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