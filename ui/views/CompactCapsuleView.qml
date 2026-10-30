// ==========================================
// 📄 File: ui/views/CompactCapsuleView.qml
// 🌟 槽位自动化排版视图 (物理掩码提权打通版)
// ==========================================
import QtQuick
import "../core"
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
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? String(Theme.activeFont) : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? String(Theme.displayMonoFont) : "Monospace"

    readonly property bool hasActiveTransient: fsm ? Boolean(fsm.activeTransientKey !== "") : false
    readonly property string currentKey: fsm ? String(fsm.activeTransientKey) : ""
    readonly property var currentPayload: (fsm && fsm.activePayload) ? fsm.activePayload : ({})

    IslandSlotPipeline {
        id: pipeline
        bridge: (typeof Bridge !== "undefined" && Bridge !== null) ? Bridge : null
        relay: compactRoot.relay
        config: (typeof Config !== "undefined" && Config !== null) ? Config : null
        clockWidth: clockView.implicitWidth
    }

    readonly property bool isMusicPlaying: (compactRoot.relay && compactRoot.relay.visualPlaying !== undefined) ? Boolean(compactRoot.relay.visualPlaying) : false
    readonly property int unreadNoticeCount: (compactRoot.relay && compactRoot.relay.unreadCount !== undefined) ? Number(compactRoot.relay.unreadCount) : 0
    readonly property bool isImeActive: (typeof Bridge !== "undefined" && Bridge.isImeActive !== undefined) ? Boolean(Bridge.isImeActive) : false

    // 🚀【核心机制】：向外暴露菜单展开状态！
    // 将 IME 与 录制模块(OBS) 的状态合并暴露给外层 IslandCapsule 维持物理穿透掩码
    readonly property bool isImeMenuOpen: (imeSlot && imeSlot.isMenuOpen) || (recPill && recPill.isMenuOpen)

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
        return pipeline.naturalCapsuleWidth;
    }

    Item {
        id: normalViewContainer
        anchors.fill: parent
        visible: opacity > 0.001
        opacity: !compactRoot.hasActiveTransient ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: compactRoot.hasActiveTransient ? 60 : 150; easing.type: Easing.OutQuad } }

        Row {
            id: contentStream
            anchors.centerIn: parent
            spacing: 5

            // [左侧]: 工作区
            FluidSlotPod {
                id: wsSlot
                slotId: "workspace"
                slotName: "工作区标识"
                targetWidth: pipeline.wsWidth
                gapSpacing: 5
                podHeight: 22
                podColor: Qt.rgba(255, 255, 255, 0.12)
                podBorderColor: Qt.rgba(255, 255, 255, 0.22)
                interactive: false

                Text {
                    anchors.centerIn: parent
                    text: (compactRoot.relay && compactRoot.relay.wsName !== undefined) ? String(compactRoot.relay.wsName) : (compactRoot.relay && compactRoot.relay.wsCurrent !== undefined ? String(compactRoot.relay.wsCurrent) : "1")
                    color: "#ffffff"
                    font.pixelSize: 12
                    font.weight: Font.Black
                    font.family: compactRoot.displayFont
                    renderType: Text.QtRendering
                }
            }

            // [中间]: 时钟
            CompactClockView {
                id: clockView
                anchors.verticalCenter: parent.verticalCenter
                chosenFont: compactRoot.effectiveFont
                isCapsLock: (typeof Bridge !== "undefined" && Bridge.isCapsLock !== undefined) ? Boolean(Bridge.isCapsLock) : false
                displayDate: (compactRoot.timeService && compactRoot.timeService.displayDate !== undefined) ? String(compactRoot.timeService.displayDate) : ""
                displayTime: (compactRoot.timeService && compactRoot.timeService.displayTime !== undefined) ? String(compactRoot.timeService.displayTime) : "12:00"
                displaySeconds: (compactRoot.timeService && compactRoot.timeService.displaySeconds !== undefined) ? String(compactRoot.timeService.displaySeconds) : ""
                displayPeriod: (compactRoot.timeService && compactRoot.timeService.displayPeriod !== undefined) ? String(compactRoot.timeService.displayPeriod) : ""
            }

            // [右侧]: 零间距流体插槽
            Row {
                id: rightSlotGroup
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                // 倒计时
                FluidSlotPod {
                    id: cdSlot
                    slotId: "countdown"
                    targetWidth: pipeline.cdWidth
                    gapSpacing: 4
                    readonly property bool isOvertime: (typeof Bridge !== "undefined" && Bridge.cdIsOvertime !== undefined) ? Boolean(Bridge.cdIsOvertime) : false
                    podColor: isOvertime ? Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.10) : Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.08)
                    hoverColor: isOvertime ? Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.18) : Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.14)
                    pressColor: isOvertime ? Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.28) : Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.22)
                    podBorderColor: isOvertime ? Qt.rgba(255 / 255, 69 / 255, 58 / 255, 0.50) : Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.25)
                    hoverBorderColor: isOvertime ? "#FF453A" : Qt.rgba(255 / 255, 159 / 255, 10 / 255, 0.65)

                    onClicked: {
                        if (typeof Bridge !== "undefined" && Bridge.switchTimerType) Bridge.switchTimerType("countdown");
                        if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "timer", source: "Click_CdSlot" });
                    }
                    onRightClicked: {
                        if (typeof Bridge !== "undefined" && Bridge.resetSpecificTimer) Bridge.resetSpecificTimer("countdown");
                    }

                    CompactTimerView {
                        anchors.centerIn: parent
                        fontFam: compactRoot.displayFont
                        pixelSize: 14
                        textColor: cdSlot.isOvertime ? "#FF453A" : ((typeof Bridge !== "undefined" && Bridge.cdMode === "break") ? "#30D158" : "#FF9F0A")
                        isOvertime: cdSlot.isOvertime
                        totalSeconds: (typeof Bridge !== "undefined") ? (cdSlot.isOvertime ? Number(Bridge.cdOvertimeSec) : Number(Bridge.cdRemainingSec)) : 1500
                        isPaused: (typeof Bridge !== "undefined" && Bridge.cdIsPaused !== undefined) ? Boolean(Bridge.cdIsPaused) : false
                    }
                }

                // 秒表
                FluidSlotPod {
                    id: swSlot
                    slotId: "stopwatch"
                    targetWidth: pipeline.swWidth
                    gapSpacing: 4
                    podColor: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.10)
                    hoverColor: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.18)
                    pressColor: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.28)
                    podBorderColor: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.25)
                    hoverBorderColor: "#38BDF8"

                    onClicked: {
                        if (typeof Bridge !== "undefined" && Bridge.switchTimerType) Bridge.switchTimerType("stopwatch");
                        if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "timer", source: "Click_SwSlot" });
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
                        totalSeconds: (typeof Bridge !== "undefined" && Bridge.swElapsedSec !== undefined) ? Number(Bridge.swElapsedSec) : 0
                        isPaused: (typeof Bridge !== "undefined" && Bridge.swIsPaused !== undefined) ? Boolean(Bridge.swIsPaused) : false
                    }
                }

                // 实时网速
                FluidSlotPod {
                    id: netSlot
                    slotId: "netspeed"
                    targetWidth: pipeline.netWidth
                    gapSpacing: 4
                    interactive: false
                    podColor: "transparent"
                    podBorderColor: "transparent"

                    CompactNetSpeedView {
                        anchors.centerIn: parent
                        fontFam: compactRoot.displayFont
                        downVal: (compactRoot.relay && compactRoot.relay.netDownVal !== undefined) ? String(compactRoot.relay.netDownVal) : "0"
                        downUnit: (compactRoot.relay && compactRoot.relay.netDownUnit !== undefined) ? String(compactRoot.relay.netDownUnit) : "B/s"
                        upVal: (compactRoot.relay && compactRoot.relay.netUpVal !== undefined) ? String(compactRoot.relay.netUpVal) : "0"
                        upUnit: (compactRoot.relay && compactRoot.relay.netUpUnit !== undefined) ? String(compactRoot.relay.netUpUnit) : "B/s"
                    }
                }

                // 🚀【挂载标识 ID】：录制微囊，暴露 recPill
                FluidSlotPod {
                    id: recSlot
                    slotId: "recording"
                    targetWidth: pipeline.recWidth
                    gapSpacing: 4
                    interactive: false
                    podColor: "transparent"
                    podBorderColor: "transparent"

                    CompactRecordPill {
                        id: recPill
                        anchors.centerIn: parent
                    }
                }

                // 输入法
                FluidSlotPod {
                    id: imeSlotWrapper
                    slotId: "ime"
                    targetWidth: pipeline.imeWidth
                    gapSpacing: 4
                    interactive: false
                    podColor: "transparent"
                    podBorderColor: "transparent"

                    CompactImeView {
                        id: imeSlot
                        anchors.centerIn: parent
                    }
                }

                // 通知角标
                FluidSlotPod {
                    id: noticeSlot
                    slotId: "notification"
                    targetWidth: pipeline.noticeWidth
                    gapSpacing: 4
                    podColor: Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.22)
                    hoverColor: Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.32)
                    pressColor: Qt.rgba(99 / 255, 102 / 255, 241 / 255, 0.45)
                    podBorderColor: Qt.rgba(129 / 255, 140 / 255, 248 / 255, 0.6)
                    hoverBorderColor: "#a5b4fc"

                    onClicked: {
                        if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "notification", source: "Click_NoticeSlot" });
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
                FluidSlotPod {
                    id: musicSlot
                    slotId: "music"
                    targetWidth: pipeline.musicWidth
                    gapSpacing: 4
                    readonly property color themeColor: (compactRoot.relay && compactRoot.relay.dominantColor !== undefined) ? compactRoot.relay.dominantColor : "#22c55e"

                    podColor: Qt.rgba(255, 255, 255, 0.06)
                    hoverColor: Qt.rgba(255, 255, 255, 0.12)
                    pressColor: Qt.rgba(themeColor.r, themeColor.g, themeColor.b, 0.25)
                    podBorderColor: Qt.rgba(255, 255, 255, 0.14)
                    hoverBorderColor: themeColor

                    onClicked: {
                        if (compactRoot.fsm) compactRoot.fsm.handleIntent("EXPAND", { tab: "media", source: "Click_MusicSlot" });
                    }
                    onRightClicked: {
                        if (typeof Bridge !== "undefined" && Bridge.sendMediaCmd) Bridge.sendMediaCmd("MEDIA_PLAY_PAUSE");
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 2.2

                        Repeater {
                            model: 5
                            Rectangle {
                                width: 2.8; height: 14; radius: 1.4
                                color: musicSlot.themeColor
                                anchors.verticalCenter: parent.verticalCenter

                                transform: Scale {
                                    origin.y: 7
                                    yScale: {
                                        if (!compactRoot.isMusicPlaying) return 0.22;
                                        var s1 = (compactRoot.relay && compactRoot.relay.spec1 !== undefined) ? Number(compactRoot.relay.spec1) : 0.2;
                                        var s2 = (compactRoot.relay && compactRoot.relay.spec2 !== undefined) ? Number(compactRoot.relay.spec2) : 0.2;
                                        var s3 = (compactRoot.relay && compactRoot.relay.spec3 !== undefined) ? Number(compactRoot.relay.spec3) : 0.2;
                                        var s4 = (compactRoot.relay && compactRoot.relay.spec4 !== undefined) ? Number(compactRoot.relay.spec4) : 0.2;

                                        switch (index) {
                                            case 0: return Math.max(0.24, Math.min(0.80, s1 * 0.90));
                                            case 1: return Math.max(0.30, Math.min(0.95, s2 * 1.15));
                                            case 2: return Math.max(0.36, Math.min(1.00, (s2 + s3) * 0.70));
                                            case 3: return Math.max(0.30, Math.min(0.95, s3 * 1.15));
                                            case 4: return Math.max(0.24, Math.min(0.80, s4 * 0.90));
                                            default: return 0.24;
                                        }
                                    }
                                    Behavior on yScale { NumberAnimation { duration: 75; easing.type: Easing.OutQuad } }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

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
            wsName: (compactRoot.relay && compactRoot.relay.wsName !== undefined && compactRoot.relay.wsName !== null) ? String(compactRoot.relay.wsName) : ""
            wsTotal: (compactRoot.relay && compactRoot.relay.wsTotal !== undefined && compactRoot.relay.wsTotal !== null) ? Number(compactRoot.relay.wsTotal) : 4
            wsList: (compactRoot.relay && compactRoot.relay.wsList !== undefined && compactRoot.relay.wsList !== null) ? compactRoot.relay.wsList : []
            displayWsNumber: (compactRoot.relay && compactRoot.relay.wsCurrent !== undefined && compactRoot.relay.wsCurrent !== null) ? Number(compactRoot.relay.wsCurrent) : 1
        }
    }

    Component {
        id: compAlert
        CompactAlertView {
            chosenFont: compactRoot.effectiveFont
            isAlertActive: true
            alertTitle: (compactRoot.currentPayload && compactRoot.currentPayload.title !== undefined) ? String(compactRoot.currentPayload.title) : ""
            alertSubtitle: (compactRoot.currentPayload && compactRoot.currentPayload.subtitle !== undefined) ? String(compactRoot.currentPayload.subtitle) : ""
            alertAvatar: (compactRoot.currentPayload && compactRoot.currentPayload.avatar !== undefined) ? String(compactRoot.currentPayload.avatar) : ""
            alertThemeColor: (compactRoot.currentPayload && compactRoot.currentPayload.color !== undefined) ? compactRoot.currentPayload.color : Theme.notification
            implicitWidth: 300
        }
    }

    Component {
        id: compCall
        CompactCallView {
            chosenFont: compactRoot.effectiveFont
            isCalling: true
            callTitle: (compactRoot.currentPayload && compactRoot.currentPayload.title !== undefined) ? String(compactRoot.currentPayload.title) : ""
            callSubtitle: (compactRoot.currentPayload && compactRoot.currentPayload.subtitle !== undefined) ? String(compactRoot.currentPayload.subtitle) : ""
            callAvatar: (compactRoot.currentPayload && compactRoot.currentPayload.avatar !== undefined) ? String(compactRoot.currentPayload.avatar) : ""
            implicitWidth: 340
        }
    }

    Component {
        id: compVoice
        CompactVoiceView {
            chosenFont: compactRoot.effectiveFont
            isListening: true
            voiceLevel: (typeof Bridge !== "undefined" && Bridge.voiceInputLevel !== undefined) ? Number(Bridge.voiceInputLevel) : 0.2
            streamText: (typeof Bridge !== "undefined" && Bridge.voiceInputText !== undefined) ? String(Bridge.voiceInputText) : ""
            onStopRequested: if (typeof Bridge !== "undefined" && Bridge.stopVoiceInput) Bridge.stopVoiceInput()
            implicitWidth: 340
        }
    }

    Component {
        id: compSedentary
        CompactSedentaryView {
            chosenFont: compactRoot.effectiveFont
            continuousSitMinutes: (compactRoot.currentPayload && compactRoot.currentPayload.continuousMinutes !== undefined) ? Number(compactRoot.currentPayload.continuousMinutes) : 45
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
            payload: compactRoot.currentPayload || ({})
            effectiveFont: compactRoot.effectiveFont
            relay: compactRoot.relay
        }
    }
}