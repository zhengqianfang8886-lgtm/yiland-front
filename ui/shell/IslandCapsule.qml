// =========================================================================
// 📄 File: ui/shell/IslandCapsule.qml
// 🌟 灵动岛主壳体 · 44px 高度舒适触控版
// =========================================================================
import QtQuick
import "../core"
import "../views"
import "../components/capsule"

Item {
    id: capsuleRoot

    property var fsm: null
    property var relay: null
    property var timeService: null

    property real normalTopMargin: (typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined) ? Config.capsuleTopMargin : 8
    property real islandOffsetX: 0

    readonly property bool isCurrentExpanded: fsm ? (fsm.currentState === IslandFsm.State.Expanded) : false

    HoverHandler {
        id: capsuleBodyHover
        blocking: false
        enabled: !capsuleRoot.isCurrentExpanded
    }

    readonly property bool isHovered: capsuleRoot.isCurrentExpanded || capsuleBodyHover.hovered || (sensorArea && sensorArea.isPointerHovered)

    signal requestSettings()

    PhysicsMotionPod {
        id: motionPod
        onMotionSettled: capsuleRoot.commitPrecisionMask()
    }

    Timer {
        id: maskSettleWatchdog
        interval: 320
        repeat: false
        onTriggered: capsuleRoot.commitPrecisionMask()
    }

    // 🚀 基础高度由 38 提升至 44
    width: Math.max(200, motionPod.currentWidth)
    height: Math.max(44, motionPod.currentHeight)
    y: motionPod.currentY
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: islandOffsetX

    function resolveAndExpress() {
        if (!fsm) return;

        var tY = normalTopMargin;
        var tW = (compactView && compactView.naturalWidth > 0) ? compactView.naturalWidth : 210;
        var tH = 44;
        var tR = 22;

        switch (fsm.currentState) {
            case IslandFsm.State.Hidden:
                tW = 190; tH = 44; tR = 22;
                tY = -(tH - 5.0);
                break;

            case IslandFsm.State.Compact:
            case IslandFsm.State.Interacting:
            case IslandFsm.State.Overlay:
                tW = Math.max(200, compactView.naturalWidth);
                tH = (fsm.activeTransientKey === "SEDENTARY") ? 116 : 
                     (fsm.activeTransientKey === "CALL" ? 50 : 
                     (fsm.activeTransientKey === "ALERT" ? 56 : 44));
                tR = Math.min(26, tH / 2);
                tY = normalTopMargin;
                break;

            case IslandFsm.State.Expanded:
                tW = 420; tH = 240; tR = 24;
                tY = normalTopMargin;
                break;
        }

        var willMove = (Math.abs(motionPod.targetY - tY) > 0.5 ||
                        Math.abs(motionPod.targetWidth - tW) > 0.5 ||
                        Math.abs(motionPod.targetHeight - tH) > 0.5);

        if (willMove) {
            if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) {
                Bridge.openFullCorridorForMotion();
            }
            maskSettleWatchdog.restart();
        }

        motionPod.expressGeometry(tY, tW, tH, tR);
    }

    Component.onCompleted: resolveAndExpress()

    Connections {
        target: capsuleRoot.fsm
        function onStateChanged(oldState, newState, ctx) {
            capsuleRoot.resolveAndExpress();
        }
    }

    Connections {
        target: compactView
        function onNaturalWidthChanged() {
            if (capsuleRoot.fsm && !capsuleRoot.isCurrentExpanded) {
                capsuleRoot.resolveAndExpress();
            }
        }
    }

    function commitPrecisionMask() {
        maskSettleWatchdog.stop();
        if (typeof Bridge === "undefined") return;

        if (capsuleRoot.isCurrentExpanded) {
            Bridge.openFullCorridorForMotion();
            return;
        }

        var capW = Math.round(capsuleRoot.width);
        var capX = Math.round((parent.width - capW) / 2 + islandOffsetX);
        var safePadH = 4;

        if (fsm && fsm.currentState === IslandFsm.State.Hidden) {
            Bridge.applySettledMask(Math.max(0, capX - safePadH), 0, capW + safePadH * 2, 10);
            return;
        }

        var actualBottomY = Math.round(capsuleRoot.y + capsuleRoot.height + 2);
        Bridge.applySettledMask(Math.max(0, capX - safePadH), 0, capW + safePadH * 2, actualBottomY);
    }

    CapsuleBackground {
        id: bg
        capsuleRadius: motionPod.currentRadius
        accentColor: {
            if (fsm && fsm.activePayload && fsm.activePayload.color) {
                return fsm.activePayload.color;
            }
            if (relay && relay.status === "Playing" && !capsuleRoot.isCurrentExpanded) {
                return relay.dominantColor;
            }
            return "transparent";
        }
    }

    Item {
        anchors.fill: parent
        clip: true
        visible: !capsuleRoot.isCurrentExpanded && (fsm && fsm.currentState !== IslandFsm.State.Hidden)
        enabled: visible
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        CompactCapsuleView {
            id: compactView
            fsm: capsuleRoot.fsm
            relay: capsuleRoot.relay
            timeService: capsuleRoot.timeService
        }
    }

    CapsuleSensorArea {
        id: sensorArea
        anchors.fill: parent
        visible: !capsuleRoot.isCurrentExpanded && (fsm && fsm.currentState !== IslandFsm.State.Hidden)
        enabled: visible
        isExpanded: capsuleRoot.isCurrentExpanded
        isTucked: fsm ? (fsm.currentState === IslandFsm.State.Hidden) : false

        onScrubStarted: {
            if (compactView) compactView.isScrubbing = true;
        }
        onScrubMoved: (mx, my) => {
            if (compactView) {
                compactView.isScrubCanceling = sensorArea.isScrubCanceling;
                compactView.handleScrubMove(mx, my);
            }
        }
        onScrubCommitted: {
            if (compactView) {
                compactView.isScrubbing = false;
                var targetIdx = compactView.getScrubTargetIndex();
                if (typeof Bridge !== "undefined") Bridge.switchWorkspace(targetIdx);
            }
        }
        onScrubCanceled: {
            if (compactView) compactView.isScrubbing = false;
        }

        onRequestExpand: (tab) => {
            if (fsm) fsm.handleIntent("EXPAND", { tab: tab, source: "SensorArea_RequestExpand" });
        }
        onRequestTuckToggle: {
            if (fsm) fsm.handleIntent("TOGGLE_TUCK", { source: "SensorArea_Tuck" });
        }
        onRequestSettingsWindow: capsuleRoot.requestSettings()

        onWheelScrolled: (deltaY) => {
            if (typeof Bridge !== "undefined") {
                if (deltaY > 0) Bridge.switchWorkspacePrev();
                else Bridge.switchWorkspaceNext();
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12
        clip: true
        z: 50
        visible: capsuleRoot.isCurrentExpanded
        enabled: visible
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        ExpandedCardView {
            id: expandedView
            anchors.fill: parent
            fsm: capsuleRoot.fsm
            relay: capsuleRoot.relay
            onRequestSettings: capsuleRoot.requestSettings()
        }
    }
}