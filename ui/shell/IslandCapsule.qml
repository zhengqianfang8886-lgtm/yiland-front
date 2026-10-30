// =========================================================================
// 📄 File: ui/shell/IslandCapsule.qml
// 🌟 灵动岛主壳体 (通用全组件防抢占 · 根级非侵入式几何悬停 · 菜单互锁版)
// =========================================================================
import QtQuick
import QtQml
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

    // 🚀【通用菜单互锁】：支持 IME、OBS 以及未来任意新增托盘菜单
    readonly property bool isAnyMenuOpen: compactView ? (compactView.isAnyMenuOpen || compactView.isImeMenuOpen) : false

    // 🚀【核心设计：通用根级悬停判定】：
    // 采用根级 HoverHandler，免疫任何内部子组件（OBS、IME、时钟、网速、未来新插件）MouseArea 的事件劫持！
    readonly property bool isHovered: capsuleRoot.isCurrentExpanded ||
                                     capsuleRootHover.hovered ||
                                     (sensorArea && sensorArea.isPointerHovered) ||
                                     capsuleRoot.isAnyMenuOpen

    readonly property bool isRightPressing: sensorArea ? sensorArea.isRightPressing : false

    signal requestSettings()

    // 根级无阻断悬停探针（不受任何子组件遮挡）
    HoverHandler {
        id: capsuleRootHover
        enabled: fsm && (fsm.currentState !== IslandFsm.State.Hidden)
    }

    IslandActionBus {
        id: actionBus
        bridge: (typeof Bridge !== "undefined") ? Bridge : null
        fsm: capsuleRoot.fsm
    }

    PhysicsMotionPod {
        id: motionPod
        onMotionSettled: {
            capsuleRoot.executeActualMaskCommit();
        }
    }

    readonly property real baseRestingWidth: motionPod.targetWidth
    readonly property real pullOffset: (!sensorArea || capsuleRoot.isCurrentExpanded) ? 0.0 : sensorArea.visualPullY
    readonly property real pullRatio: (!sensorArea || capsuleRoot.isCurrentExpanded) ? 0.0 : sensorArea.pullRatio
    readonly property bool isActivelyPulling: sensorArea ? sensorArea.isPullingDown : false

    function smoothStep(edge0, edge1, val) {
        var t = Math.max(0.0, Math.min(1.0, (val - edge0) / Math.max(0.0001, edge1 - edge0)));
        return t * t * (3.0 - 2.0 * t);
    }

    y: motionPod.currentY

    readonly property real liquidExtraHeight: pullOffset * 0.95
    height: Math.max(currentConfigHeight, Math.round(motionPod.currentHeight + liquidExtraHeight))

    readonly property real liquidPillMinWidth: 136.0
    readonly property real contractionFactor: smoothStep(0.0, 1.0, pullRatio) * 0.22
    readonly property real dynamicTargetWidth: baseRestingWidth - ((baseRestingWidth - liquidPillMinWidth) * contractionFactor)

    width: Math.max(liquidPillMinWidth, Math.round(dynamicTargetWidth))
    Behavior on width {
        enabled: !capsuleRoot.isActivelyPulling
        NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutQuint }
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: islandOffsetX

    scale: (capsuleRoot.isRightPressing) ? 0.95 : ((sensorArea && sensorArea.isTriggerPrimed) ? 1.02 : 1.0)
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

    function resolveAndExpress() {
        if (!fsm) return;

        var tY = normalTopMargin;
        var tW = 210;
        var tH = currentConfigHeight;
        var tR = Math.round(tH / 2);
        var route = "TWEAK";

        var isSubmerged = (motionPod.y < -5);

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
                route = isSubmerged ? "EMERGE_AND_EXPAND" : "TWEAK";
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
            capsuleRoot.resolveAndExpress();
            if (newState === IslandFsm.State.Expanded && ctx && ctx.tab) {
                expandedView.switchTab(ctx.tab);
            }
        }
    }

    Connections {
        target: compactView
        function onNaturalWidthChanged() {
            if (capsuleRoot.fsm && !capsuleRoot.isCurrentExpanded && !capsuleRoot.isActivelyPulling) {
                capsuleRoot.resolveAndExpress();
            }
        }
    }

    function executeActualMaskCommit() {
        if (typeof Bridge === "undefined") return;

        // 只要处在展开态、手势拉拽中、或者任意菜单处于打开状态，保持全窗口通透，绝不裁切菜单
        if (capsuleRoot.isCurrentExpanded || capsuleRoot.isAnyMenuOpen || capsuleRoot.isActivelyPulling) {
            Bridge.openFullCorridorForMotion();
            return;
        }

        var safePadH = 8;
        if (fsm && fsm.currentState === IslandFsm.State.Hidden) {
            var tuckW = 280;
            var tuckX = Math.round((parent.width - tuckW) / 2 + islandOffsetX);
            Bridge.applySettledMask(Math.max(0, tuckX - safePadH), 0, tuckW + safePadH * 2, 14);
            return;
        }

        var capW = Math.round(capsuleRoot.width);
        var capX = Math.round((parent.width - capW) / 2 + islandOffsetX);
        var actualBottomY = Math.round(capsuleRoot.y + capsuleRoot.height + 4);

        Bridge.applySettledMask(Math.max(0, capX - safePadH), 0, capW + safePadH * 2, actualBottomY);
    }

    CapsuleBackground {
        id: bg
        isTucked: fsm ? (fsm.currentState === IslandFsm.State.Hidden) : false
        capsuleRadius: motionPod.currentRadius
        pullY: capsuleRoot.pullOffset
        pullRatio: capsuleRoot.pullRatio
        isTriggerPrimed: sensorArea ? sensorArea.isTriggerPrimed : false
    }

    readonly property real clockFadeout: smoothStep(0.06, 0.45, pullRatio)
    readonly property real glyphFadein: smoothStep(0.12, 0.60, pullRatio)
    readonly property real dotSpread: smoothStep(0.18, 0.85, pullRatio)

    CapsuleSensorArea {
        id: sensorArea
        actionBus: actionBus
        width: capsuleRoot.baseRestingWidth
        height: Math.max(capsuleRoot.currentConfigHeight, capsuleRoot.height)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        z: 1
        visible: !capsuleRoot.isCurrentExpanded && (fsm && fsm.currentState !== IslandFsm.State.Hidden)
        enabled: visible
        isExpanded: capsuleRoot.isCurrentExpanded
        isTucked: fsm ? (fsm.currentState === IslandFsm.State.Hidden) : false

        onRequestSettingsWindow: capsuleRoot.requestSettings()
    }

    Item {
        id: compactContainer
        width: capsuleRoot.baseRestingWidth
        height: capsuleRoot.currentConfigHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        clip: false
        z: 10
        visible: opacity > 0.001
        
        enabled: !capsuleRoot.isCurrentExpanded && !capsuleRoot.isActivelyPulling && (fsm && fsm.currentState !== IslandFsm.State.Hidden)

        opacity: (!capsuleRoot.isCurrentExpanded && (fsm && fsm.currentState !== IslandFsm.State.Hidden)) ? (1.0 - capsuleRoot.clockFadeout) : 0.0
        scale: 1.0 - capsuleRoot.clockFadeout * 0.06
        transform: Translate { y: capsuleRoot.pullOffset * 0.3 }

        CompactCapsuleView {
            id: compactView
            anchors.fill: parent
            fsm: capsuleRoot.fsm
            relay: capsuleRoot.relay
            timeService: capsuleRoot.timeService
            sedentaryService: capsuleRoot.sedentaryService
        }
    }

    Item {
        id: morphicGlyphContainer
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round((capsuleRoot.height - height) / 2)
        width: 26; height: 26
        z: 15

        opacity: capsuleRoot.glyphFadein
        visible: opacity > 0.001

        scale: (sensorArea && sensorArea.isTriggerPrimed) ? 1.10 : (0.85 + capsuleRoot.glyphFadein * 0.20)
        Behavior on scale { NumberAnimation { duration: 80 } }

        readonly property color glyphColor: (sensorArea && sensorArea.isTriggerPrimed) ? "#c084fc" : "#ffffff"

        Item {
            anchors.centerIn: parent
            width: 22; height: 22

            readonly property real gap: 1.0 + capsuleRoot.dotSpread * 2.6
            readonly property real dotSize: 5.4 + capsuleRoot.dotSpread * 1.4
            readonly property real dotRadius: 1.6 + capsuleRoot.dotSpread * 0.4

            Rectangle {
                x: parent.width / 2 - width - parent.gap / 2
                y: parent.height / 2 - height - parent.gap / 2
                width: parent.dotSize; height: parent.dotSize; radius: parent.dotRadius
                color: morphicGlyphContainer.glyphColor
            }
            Rectangle {
                x: parent.width / 2 + parent.gap / 2
                y: parent.height / 2 - height - parent.gap / 2
                width: parent.dotSize; height: parent.dotSize; radius: parent.dotRadius
                color: morphicGlyphContainer.glyphColor
            }
            Rectangle {
                x: parent.width / 2 - width - parent.gap / 2
                y: parent.height / 2 + parent.gap / 2
                width: parent.dotSize; height: parent.dotSize; radius: parent.dotRadius
                color: morphicGlyphContainer.glyphColor
            }
            Rectangle {
                x: parent.width / 2 + parent.gap / 2
                y: parent.height / 2 + parent.gap / 2
                width: parent.dotSize; height: parent.dotSize; radius: parent.dotRadius
                color: morphicGlyphContainer.glyphColor
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

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutQuint } }

        ExpandedCardView {
            id: expandedView
            anchors.fill: parent
            fsm: capsuleRoot.fsm
            relay: capsuleRoot.relay
            onRequestSettings: capsuleRoot.requestSettings()
        }
    }
}