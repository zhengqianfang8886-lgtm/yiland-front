// ==========================================
// 📄 File: ui/shell/IslandCapsule.qml
// 🌟 灵动岛主壳体 (物理实时感知路由 · 消除二次收缩版)
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
    // 🚀【核心链路】：暴露按压信号给外层用于渲染层防抖缩放
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

    // =========================================================================
    // 🚀【物理实时状态路由】：杜绝历史状态残留导致的二次缩水
    // =========================================================================
    function resolveAndExpress() {
        if (!fsm) return;

        var tY = normalTopMargin;
        var tW = 210;
        var tH = currentConfigHeight;
        var tR = Math.round(tH / 2);
        var route = "TWEAK";

        // 纯物理判定：外壳当前是否真的被埋在屏幕上方天花板里
        var isActuallySubmerged = (motionPod.y < -5);

        switch (fsm.currentState) {
            case IslandFsm.State.Hidden:
                tW = 180; 
                tH = currentConfigHeight; 
                tR = Math.round(tH / 2);
                tY = -(tH - 6.0); // 潜入屏幕上方，仅留 6px 细缝
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

                // 只有物理坐标确实在负值区，才需要降落；否则直接从当前大小一气呵成单调膨胀！
                if (isActuallySubmerged) {
                    route = "EMERGE_AND_EXPAND";
                } else {
                    route = "TWEAK";
                }
                break;
        }

        // 第 0ms 瞬间打通物理鼠标穿透全走廊
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
            // 🚀【瞬间材质闪烁】：进入深潜态瞬间触发确认闪光
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

    // 🚀【掩码契约加固】：只要处于大卡片展开 OR 输入法下拉菜单弹出中，保持全域放行！
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
        var actualBottomY = Math.round(capsuleRoot.y + capsuleRoot.height + 6);

        Bridge.applySettledMask(Math.max(0, capX - safePadH), 0, capW + safePadH * 2, actualBottomY);
    }

    // 🚀【核心监听】：菜单开闭状态突变时，即时重塑窗口物理掩码！
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
        // 🚀 同步隐藏状态给底层，启动呼吸灯
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

    Item {
        id: compactContainer
        anchors.fill: parent
        clip: true
        z: 10
        visible: opacity > 0.001
        enabled: !capsuleRoot.isCurrentExpanded && !capsuleRoot.isMoving && (fsm && fsm.currentState !== IslandFsm.State.Hidden)

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

        onScrubStarted: {
            if (fsm) fsm.handleIntent("LOCK_SCRUBBING");
            if (compactView) compactView.isScrubbing = true;
        }
        onScrubMoved: (mx, my) => {
            if (compactView) {
                compactView.isScrubCanceling = sensorArea.isScrubCanceling;
                compactView.handleScrubMove(mx, my);
            }
        }
        onScrubCommitted: {
            if (fsm) fsm.handleIntent("UNLOCK_SCRUBBING");
            if (compactView) {
                compactView.isScrubbing = false;
                var targetIdx = compactView.getScrubTargetIndex();
                if (typeof Bridge !== "undefined") Bridge.switchWorkspace(targetIdx);
            }
        }
        onScrubCanceled: {
            if (fsm) fsm.handleIntent("UNLOCK_SCRUBBING");
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