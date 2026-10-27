// ==========================================
// 📄 File: ui/shell/IslandCapsule.qml
// 🌟 灵动岛主壳体 (彻底修复动画中连击穿透展开 Bug 版)
// ==========================================
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
        var route = "TWEAK";

        var isActuallySubmerged = (motionPod.y < -5);

        switch (fsm.currentState) {
            case IslandFsm.State.Hidden:
                tW = 180; 
                tH = currentConfigHeight; 
                tR = Math.round(tH / 2);
                tY = -(tH - 6.0);
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

                if (isActuallySubmerged) {
                    route = "EMERGE_AND_EXPAND";
                } else {
                    route = "TWEAK";
                }
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

    function executeActualMaskCommit() {
        if (typeof Bridge === "undefined") return;

        if (capsuleRoot.isCurrentExpanded || (compactView && compactView.isImeMenuOpen)) {
            Bridge.openFullCorridorForMotion();
            return;
        }

        var safePadH = 6;
        if (fsm && fsm.currentState === IslandFsm.State.Hidden) {
            var tuckW = 180;
            var tuckX = Math.round((parent.width - tuckW) / 2 + islandOffsetX);
            Bridge.applySettledMask(Math.max(0, tuckX - safePadH), 0, tuckW + safePadH * 2, 14);
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

    HoverHandler {
        id: capsuleGlobalHover
        blocking: false
        enabled: (fsm && fsm.currentState !== IslandFsm.State.Hidden)
    }

    CapsuleBackground {
        id: bg
        isTucked: fsm ? (fsm.currentState === IslandFsm.State.Hidden) : false
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

    // =========================================================================
    // 🚀【核心修复】：移除 !capsuleRoot.isMoving，任何微动画期间严禁禁用子控件！
    // =========================================================================
    Item {
        id: compactContainer
        anchors.fill: parent
        clip: true
        z: 10
        visible: opacity > 0.001
        enabled: !capsuleRoot.isCurrentExpanded && (fsm && fsm.currentState !== IslandFsm.State.Hidden)

        opacity: (!capsuleRoot.isCurrentExpanded && (fsm && fsm.currentState !== IslandFsm.State.Hidden)) ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: capsuleRoot.isCurrentExpanded ? 40 : 140
                easing.type: Easing.OutQuad
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
        scale: capsuleRoot.isCurrentExpanded ? 1.0 : 0.96

        Behavior on opacity {
            NumberAnimation {
                duration: capsuleRoot.isCurrentExpanded ? 140 : 40
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: capsuleRoot.isCurrentExpanded ? 180 : 40
                easing.type: Easing.OutBack
                easing.overshoot: 1.05
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