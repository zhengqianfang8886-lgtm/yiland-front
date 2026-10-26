// =========================================================================
// 📄 File: ui/shell/IslandCapsule.qml
// 🌟 灵动岛主壳体 (参数化响应式高度 · 终态单一主权版)
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
    // 🚀【动态高度】：从配置读取 (32 / 36 / 42)
    readonly property int currentConfigHeight: (typeof Config !== "undefined" && Config.capsuleHeight !== undefined) ? Config.capsuleHeight : 36
    property real islandOffsetX: 0

    readonly property bool isCurrentExpanded: fsm ? (fsm.currentState === IslandFsm.State.Expanded) : false
    readonly property bool isMoving: motionPod.isMoving

    HoverHandler {
        id: capsuleBodyHover
        blocking: false
        enabled: !capsuleRoot.isCurrentExpanded && !capsuleRoot.isMoving
    }

    readonly property bool isHovered: capsuleRoot.isCurrentExpanded || capsuleBodyHover.hovered || (sensorArea && sensorArea.isPointerHovered)

    signal requestSettings()

    PhysicsMotionPod {
        id: motionPod
        onMotionSettled: capsuleRoot.commitPrecisionMask()
    }

    Timer {
        id: maskSettleWatchdog
        interval: 140
        repeat: false
        onTriggered: capsuleRoot.executeActualMaskCommit()
    }

    width: Math.max(160, motionPod.currentWidth)
    height: Math.max(currentConfigHeight, motionPod.currentHeight)
    y: motionPod.currentY
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: islandOffsetX

    function resolveAndExpress() {
        if (!fsm) return;

        var tY = normalTopMargin;
        var tW = 210;
        var tH = currentConfigHeight;
        var tR = Math.round(tH / 2);

        switch (fsm.currentState) {
            case IslandFsm.State.Hidden:
                tW = 180; tH = currentConfigHeight; tR = Math.round(tH / 2);
                tY = -(tH - 5.0);
                break;

            case IslandFsm.State.Compact:
            case IslandFsm.State.Interacting:
            case IslandFsm.State.Overlay:
                tW = (compactView && compactView.naturalWidth > 0) ? compactView.naturalWidth : 210;
                tH = (fsm.activeTransientKey === "SEDENTARY") ? 116 : 
                     (fsm.activeTransientKey === "CALL" ? 50 : 
                     (fsm.activeTransientKey === "ALERT" ? 56 : currentConfigHeight));
                tR = Math.min(26, Math.round(tH / 2));
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
            maskSettleWatchdog.stop();
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

    // 监听高度设置变更
    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onCapsuleHeightChanged(h) {
            capsuleRoot.resolveAndExpress();
        }
    }

    function commitPrecisionMask() {
        maskSettleWatchdog.restart();
    }

    function executeActualMaskCommit() {
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
        enabled: visible && !capsuleRoot.isMoving
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