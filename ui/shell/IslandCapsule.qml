// =========================================================================
// 📄 File: ui/shell/IslandCapsule.qml
// 🌟 灵动岛主壳体 (280px宽域感应 · 深度下探唤醒 · 极度敏感版)
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
    property var sedentaryService: null

    property real normalTopMargin: (typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined) ? Config.capsuleTopMargin : 8
    readonly property int currentConfigHeight: (typeof Config !== "undefined" && Config.capsuleHeight !== undefined) ? Config.capsuleHeight : 36
    property real islandOffsetX: 0

    readonly property bool isCurrentExpanded: fsm ? (fsm.currentState === IslandFsm.State.Expanded) : false
    readonly property bool isMoving: motionPod.isMoving

    readonly property bool isHovered: capsuleRoot.isCurrentExpanded || 
                                      capsuleGlobalHover.hovered || 
                                      (sensorArea && sensorArea.isPointerHovered)

    signal requestSettings()
    readonly property bool isRightPressing: sensorArea ? sensorArea.isRightPressing : false

    PhysicsMotionPod {
        id: motionPod
        onMotionSettled: {
            capsuleRoot.executeActualMaskCommit();
        }
    }

    readonly property real pullOffset: {
        if (!sensorArea || capsuleRoot.isCurrentExpanded) return 0.0;
        return (sensorArea.isPullingDown || sensorArea.visualPullY > 0.1) ? Math.max(0.0, sensorArea.visualPullY) : 0.0;
    }

    width: Math.max(140, motionPod.currentWidth)
    height: Math.max(currentConfigHeight, motionPod.currentHeight)

    y: motionPod.currentY + capsuleRoot.pullOffset

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: islandOffsetX

    scale: (capsuleRoot.isRightPressing) ? 0.95 : 1.0
    Behavior on scale { NumberAnimation { duration: 100 } }

    function resolveAndExpress() {
        if (!fsm) return;

        var tY = normalTopMargin;
        var tW = 210;
        var tH = currentConfigHeight;
        var tR = Math.round(tH / 2);
        var route = "TWEAK";

        var isActuallySubmerged = (motionPod.y < -5);

        switch (fsm.currentState) {
            case IslandFsm.State.Hidden:
                var isStealth = (typeof Config !== "undefined" && Config.stealthTuckEnabled);
                tW = 140; 
                tH = currentConfigHeight; 
                tR = Math.round(tH / 2);
                tY = isStealth ? -(tH + 2) : -(tH - 2.5);
                route = "TWEAK";
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
                route = "TWEAK";
                break;

            case IslandFsm.State.Expanded:
                tW = 420; 
                tH = 240; 
                tR = 24;
                tY = normalTopMargin;
                route = isActuallySubmerged ? "EMERGE_AND_EXPAND" : "TWEAK";
                break;
        }

        if (fsm.currentState !== IslandFsm.State.Hidden) {
            if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) {
                Bridge.openFullCorridorForMotion();
            }
        }

        motionPod.expressGeometry(tY, tW, tH, tR, route);
    }

    Component.onCompleted: {
        resolveAndExpress();
        executeActualMaskCommit();
    }

    Connections {
        target: capsuleRoot.fsm
        function onStateChanged(oldState, newState, ctx) {
            if (newState === IslandFsm.State.Hidden && oldState !== IslandFsm.State.Hidden) {
                bg.triggerTuckFlash();
            }
            
            capsuleRoot.resolveAndExpress();
            if (newState === IslandFsm.State.Expanded && ctx && ctx.tab) {
                expandedView.switchTab(ctx.tab);
            }
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

    // 🌟【核心修复】：将隐藏时的物理感应宽域由 140px 大幅扩至 280px，深度增至 14px，光标一甩立即下来
    function executeActualMaskCommit() {
        if (typeof Bridge === "undefined") return;

        if (capsuleRoot.isCurrentExpanded || (compactView && compactView.isImeMenuOpen) || (sensorArea && sensorArea.isPullingDown)) {
            Bridge.openFullCorridorForMotion();
            return;
        }

        var safePadH = 8;
        if (fsm && fsm.currentState === IslandFsm.State.Hidden) {
            var tuckW = 280; // 宽域感应，即使鼠标略微偏航也能被灵敏接住
            var tuckX = Math.round((parent.width - tuckW) / 2 + islandOffsetX);
            Bridge.applySettledMask(Math.max(0, tuckX - safePadH), 0, tuckW + safePadH * 2, 7);
            return;
        }

        var capW = Math.round(capsuleRoot.width);
        var capX = Math.round((parent.width - capW) / 2 + islandOffsetX);
        var actualBottomY = Math.round(capsuleRoot.y + capsuleRoot.height + 4);

        Bridge.applySettledMask(Math.max(0, capX - safePadH), 0, capW + safePadH * 2, actualBottomY);
    }

    Connections {
        target: compactView
        function onIsImeMenuOpenChanged() {
            capsuleRoot.executeActualMaskCommit();
        }
    }

    Connections {
        target: sensorArea
        function onIsPullingDownChanged() {
            if (sensorArea.isPullingDown && typeof Bridge !== "undefined") {
                Bridge.openFullCorridorForMotion();
            } else {
                capsuleRoot.executeActualMaskCommit();
            }
        }
    }

    HoverHandler {
        id: capsuleGlobalHover
        blocking: false
        enabled: (fsm && fsm.currentState !== IslandFsm.State.Hidden)
    }

    CapsuleBackground {
        id: bg
        isTucked: fsm ? (fsm.currentState === IslandFsm.State.Hidden) : false
        capsuleRadius: motionPod.currentRadius
        pullY: capsuleRoot.pullOffset
        isTriggerPrimed: sensorArea ? sensorArea.isTriggerPrimed : false

        opacity: (isTucked && (typeof Config !== "undefined" && Config.stealthTuckEnabled)) ? 0.0 : 1.0
        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

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
        id: compactContainer
        anchors.fill: parent
        clip: true
        z: 10
        visible: opacity > 0.001
        enabled: !capsuleRoot.isCurrentExpanded && (fsm && fsm.currentState !== IslandFsm.State.Hidden)

        readonly property bool shouldDisplayContent: (!capsuleRoot.isCurrentExpanded && (fsm && fsm.currentState !== IslandFsm.State.Hidden))

        opacity: shouldDisplayContent ? 1.0 : 0.0
        scale: shouldDisplayContent ? 1.0 : 0.88

        Behavior on opacity {
            NumberAnimation {
                duration: capsuleRoot.isCurrentExpanded ? 60 : 150
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: capsuleRoot.isCurrentExpanded ? 70 : 180
                easing.type: Easing.OutBack
                easing.overshoot: 1.05
            }
        }

        CompactCapsuleView {
            id: compactView
            fsm: capsuleRoot.fsm
            relay: capsuleRoot.relay
            timeService: capsuleRoot.timeService
            sedentaryService: capsuleRoot.sedentaryService
        }
    }

    CapsuleSensorArea {
        id: sensorArea
        anchors.fill: parent
        z: 1
        visible: !capsuleRoot.isCurrentExpanded && (fsm && fsm.currentState !== IslandFsm.State.Hidden)
        enabled: visible
        isExpanded: capsuleRoot.isCurrentExpanded
        isTucked: fsm ? (fsm.currentState === IslandFsm.State.Hidden) : false

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
        id: expandedContainer
        anchors.fill: parent
        anchors.margins: 12
        clip: true
        z: 50
        visible: opacity > 0.001
        enabled: capsuleRoot.isCurrentExpanded && !capsuleRoot.isMoving

        opacity: capsuleRoot.isCurrentExpanded ? 1.0 : 0.0
        scale: capsuleRoot.isCurrentExpanded ? 1.0 : 0.88

        Behavior on opacity {
            NumberAnimation {
                duration: capsuleRoot.isCurrentExpanded ? 220 : 50 
                easing.type: Easing.InOutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: capsuleRoot.isCurrentExpanded ? 340 : 60
                easing.type: Easing.OutQuint
            }
        }

        ExpandedCardView {
            id: expandedView
            anchors.fill: parent
            fsm: capsuleRoot.fsm
            relay: capsuleRoot.relay
            onRequestSettings: capsuleRoot.requestSettings()
        }
    }
}