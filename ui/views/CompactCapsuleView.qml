// ==========================================
// 📄 File: ui/views/CompactCapsuleView.qml
// 🌟 槽位自动化排版引擎 (修复 QML 单行解析 Bug 版)
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
    readonly property bool isImeActive: (typeof Bridge !== "undefined" && Bridge.isImeActive !== undefined)
    readonly property bool isImeMenuOpen: typeof imePill !== "undefined" ? imePill.isMenuOpen : false

    // 双轨计时状态
    readonly property bool hasCountdown: (typeof Bridge !== "undefined") && Bridge.cdActive
    readonly property bool hasStopwatch: (typeof Bridge !== "undefined") && Bridge.swActive

    // 宽度精简收敛
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

    readonly property int slotLeftWidth: (typeof Config !== "undefined" && Config.showWorkspaceName !== false) 
        ? Math.max(38, wsLabel.implicitWidth + 16) : 0

    // 🚀【自动化槽位引擎】：直接利用 QML Row 的原生排版能力
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

        var total = 20 + clockView.implicitWidth;
        if (leftSlot.width > 0) total += (leftSlot.width + 5); 
        if (rightSlotGroup.width > 0) total += (rightSlotGroup.width + 5);

        return Math.ceil(total / 4.0) * 4;
    }

    // =========================================================================
    // 常态视口 (打断来临 60ms 极速隐退)
    // =========================================================================
    Item {
        id: normalViewContainer
        anchors.fill: parent
        clip: true
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

            // 左侧桌面名称
            Item {
                id: leftSlot
                height: 24
                width: compactRoot.slotLeftWidth
                visible: width > 0 || wsBgRect.opacity > 0.01
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                readonly property bool isDying: compactRoot.slotLeftWidth <= 0 || compactRoot.hasActiveTransient

                Behavior on width {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    id: wsBgRect
                    anchors.fill: parent
                    radius: 12
                    color: Qt.rgba(255, 255, 255, 0.12)
                    border.color: Qt.rgba(255, 255, 255, 0.22)
                    border.width: 1

                    opacity: leftSlot.isDying ? 0.0 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Item {
                        id: wsTextSlot
                        anchors.fill: parent
                        readonly property bool shouldVaporize: leftSlot.isDying || (leftSlot.width < 28)

                        opacity: shouldVaporize ? 0.0 : 1.0
                        scale: shouldVaporize ? 0.70 : 1.0

                        Behavior on opacity { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                        Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

                        Text {
                            id: wsLabel
                            anchors.centerIn: parent
                            text: (compactRoot.relay && compactRoot.relay.wsName) ? compactRoot.relay.wsName : (compactRoot.relay ? compactRoot.relay.wsCurrent : "1")
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.weight: Font.Black
                            font.family: compactRoot.displayFont
                            renderType: Text.QtRendering
                        }
                    }
                }
            }

            // 时钟主区
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

            // =================================================================
            // 🚀 右侧自动化槽位 (Slot Engine)：微囊增删全自动流式响应
            // =================================================================
            Row {
                id: rightSlotGroup
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                FluidPill {
                    id: cdPill
                    targetWidth: compactRoot.slotCdWidth
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
                        pixelSize: 15
                        textColor: cdPill.isOvertime ? "#FF453A" : (Bridge.cdMode === "break" ? "#30D158" : "#FF9F0A")
                        isOvertime: cdPill.isOvertime
                        totalSeconds: (typeof Bridge !== "undefined") ? (cdPill.isOvertime ? Bridge.cdOvertimeSec : Bridge.cdRemainingSec) : 1500
                        isPaused: (typeof Bridge !== "undefined") ? Bridge.cdIsPaused : false
                    }
                }

                FluidPill {
                    id: swPill
                    targetWidth: compactRoot.slotSwWidth
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
                        pixelSize: 15
                        textColor: "#38BDF8"
                        isOvertime: false
                        totalSeconds: (typeof Bridge !== "undefined") ? Bridge.swElapsedSec : 0
                        isPaused: (typeof Bridge !== "undefined") ? Bridge.swIsPaused : false
                    }
                }

                CompactNetSpeedView {
                    id: netSpeedPill
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (typeof Config !== "undefined" && Config.showNetSpeed !== false)
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
                    visible: isImeActive
                }

                FluidPill {
                    id: noticePill
                    targetWidth: compactRoot.unreadNoticeCount > 0 ? (compactRoot.unreadNoticeCount >= 10 ? 40 : 34) : 0
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

                FluidPill {
                    id: musicPill
                    targetWidth: compactRoot.isMusicPlaying ? 40 : 0
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

    // 🚀【组件安全包裹区：每个 Component 严格独立分行，杜绝解析崩溃】
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