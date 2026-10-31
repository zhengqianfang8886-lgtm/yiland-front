// =========================================================================
// 📄 File: ui/shell/IslandCapsule.qml
// 🌟 灵动岛主壳体 (遮罩穿透精准裁切 · 彻底消灭下方阻挡 · 终极收敛版)
// =========================================================================
import QtQuick
import QtQml
import "../core"
import "../views"
import "../components/capsule"
import "../core/IslandLogger.js" as Logger

Item {
    id: capsuleRoot

    // =========================================================================
    // 1. 外部依赖与属性
    // =========================================================================
    property var fsm: null
    property var relay: null
    property var timeService: null
    property var sedentaryService: null

    property real normalTopMargin: (typeof Config !== "undefined" && Config.capsuleTopMargin !== undefined) ? Config.capsuleTopMargin : 8
    readonly property int currentConfigHeight: (typeof Config !== "undefined" && Config.capsuleHeight !== undefined) ? Config.capsuleHeight : 36
    property real islandOffsetX: 0

    readonly property bool isCurrentExpanded: fsm ? (fsm.currentState === IslandFsm.State.Expanded) : false
    readonly property bool isMoving: motionPod.isMoving

    readonly property bool isAnyMenuOpen: compactView ? (compactView.isAnyMenuOpen || compactView.isImeMenuOpen) : false

    readonly property bool isHovered: capsuleRoot.isCurrentExpanded ||
                                     capsuleRootHover.hovered ||
                                     (sensorArea && sensorArea.isPointerHovered) ||
                                     capsuleRoot.isAnyMenuOpen

    readonly property bool isRightPressing: sensorArea ? sensorArea.isRightPressing : false

    signal requestSettings()

    // 🚀 菜单关闭或大卡片收拢时，立即下发收拢遮罩，严禁残留 520px 玻璃罩
    onIsAnyMenuOpenChanged: {
        if (!isAnyMenuOpen && !isCurrentExpanded) {
            executeActualMaskCommit();
        } else if (isAnyMenuOpen) {
            if (typeof Bridge !== "undefined") Bridge.openFullCorridorForMotion();
        }
    }

    onIsCurrentExpandedChanged: {
        if (!isCurrentExpanded) {
            maskSettleTimer.restart();
        } else {
            if (typeof Bridge !== "undefined") Bridge.openFullCorridorForMotion();
        }
    }

    Timer {
        id: maskSettleTimer
        interval: motionPod.motionDuration + 20
        repeat: false
        onTriggered: capsuleRoot.executeActualMaskCommit()
    }

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
            Logger.geom("MOTION_POD", "运动管道定格", motionPod.targetWidth, Math.round(capsuleRoot.width), 
                        "H:" + Math.round(capsuleRoot.height) + " Y:" + Math.round(capsuleRoot.y));
        }
    }

    // =========================================================================
    // 2. 目标几何决策
    // =========================================================================
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

    readonly property real liquidPillMinWidth: 140.0
    readonly property real targetExpandedWidth: 420.0

    readonly property real targetCompactWidth: {
        if (!fsm) return 220.0;
        if (fsm.currentState === IslandFsm.State.Hidden) {
            return 140.0;
        }
        var anticipatedW = (compactView && compactView.naturalWidth > 0) ? compactView.naturalWidth : 220.0;
        return Math.max(220.0, Math.ceil(anticipatedW / 2) * 2);
    }

    readonly property real contractionFactor: smoothStep(0.0, 1.0, pullRatio) * 0.12
    readonly property real targetStaticWidth: capsuleRoot.isCurrentExpanded ? targetExpandedWidth : targetCompactWidth
    readonly property real dynamicTargetWidth: targetStaticWidth - ((targetStaticWidth - liquidPillMinWidth) * contractionFactor)

    width: Math.max(liquidPillMinWidth, Math.ceil(dynamicTargetWidth / 2) * 2)

    Behavior on width {
        id: widthAnimBehavior
        enabled: !capsuleRoot.isActivelyPulling
        NumberAnimation {
            duration: motionPod.motionDuration
            easing.type: motionPod.fluidCurve
            onRunningChanged: {
                if (running) {
                    Logger.geom("WIDTH_PHASE", "起跑对齐", Math.round(capsuleRoot.dynamicTargetWidth), Math.round(capsuleRoot.width));
                } else {
                    Logger.geom("WIDTH_PHASE", "稳态定格", Math.round(capsuleRoot.width), Math.round(capsuleRoot.width));
                }
            }
        }
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: islandOffsetX

    scale: (capsuleRoot.isRightPressing) ? 0.95 : ((sensorArea && sensorArea.isTriggerPrimed) ? 1.02 : 1.0)
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

    // =========================================================================
    // 3. 几何路由分发
    // =========================================================================
    function resolveAndExpress() {
        if (!fsm) return;
        var tY = normalTopMargin;
        var tW = 220;
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
                tW = targetCompactWidth;
                tH = (fsm.activeTransientKey === "SEDENTARY") ? 116 : 
                     (fsm.activeTransientKey === "CALL" ? 50 : 
                     (fsm.activeTransientKey === "ALERT" ? 56 : currentConfigHeight));
                tR = Math.min(26, Math.round(tH / 2));
                tY = normalTopMargin;
                route = "TWEAK";
                break;
            case IslandFsm.State.Expanded:
                tW = targetExpandedWidth; 
                tH = 240; 
                tR = 24;
                tY = normalTopMargin;
                route = isSubmerged ? "EMERGE_AND_EXPAND" : "TWEAK";
                break;
        }

        motionPod.expressGeometry(tY, tW, tH, tR, route);
    }

    Component.onCompleted: {
        resolveAndExpress();
        executeActualMaskCommit();
        Logger.info("CAPSULE_INIT", "灵动岛主壳体就绪");
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

    // =========================================================================
    // 🚀【核心修复】：精准遮罩裁切算法（绝对杜绝悬挂 520px 巨幕）
    // =========================================================================
    function executeActualMaskCommit() {
        if (typeof Bridge === "undefined") return;

        // 仅在真实展开大卡片、打开右键多级菜单、或正在物理大行程下拉时，才放行 780x520
        if (capsuleRoot.isCurrentExpanded || capsuleRoot.isAnyMenuOpen || capsuleRoot.isActivelyPulling) {
            Bridge.openFullCorridorForMotion();
            Logger.geom("MASK_COMMIT", "大卡片/多级菜单展开 -> 放行 780x520", 780, 520);
            return;
        }

        var safePadH = 8;
        
        // 1. 深潜隐藏模式：只保留顶部 14px 细缝
        if (fsm && fsm.currentState === IslandFsm.State.Hidden) {
            var tuckW = 140;
            var tuckX = Math.round((parent.width - tuckW) / 2 + islandOffsetX);
            Bridge.applySettledMask(Math.max(0, tuckX - safePadH), 0, tuckW + safePadH * 2, 14);
            Logger.geom("MASK_COMMIT", "深潜模式 -> 仅保留顶端 14px 缝隙", tuckW, 14);
            return;
        }

        // 2. 常态或覆盖态（无论鼠标是否悬停在胶囊上）：
        // 🚀 严格锁定在胶囊的真实高度 actualBottomY 范围！下方 470px 永远 100% 穿透点击！
        var capW = Math.round(capsuleRoot.width);
        var capX = Math.round((parent.width - capW) / 2 + islandOffsetX);
        var actualBottomY = Math.round(capsuleRoot.y + capsuleRoot.height + 4);

        Bridge.applySettledMask(Math.max(0, capX - safePadH), 0, capW + safePadH * 2, actualBottomY);
        Logger.geom("MASK_COMMIT", "常态精准裁切 -> 下方全部归还屏幕", capW, actualBottomY);
    }

    CapsuleBackground {
        id: bg
        isTucked: fsm ? (fsm.currentState === IslandFsm.State.Hidden) : false
        capsuleRadius: motionPod.currentRadius
        pullY: capsuleRoot.pullOffset
        pullRatio: capsuleRoot.pullRatio
        isTriggerPrimed: sensorArea ? sensorArea.isTriggerPrimed : false
    }

    readonly property real clockFadeout: smoothStep(0.55, 0.95, pullRatio) * 0.4
    readonly property real glyphFadein: smoothStep(0.35, 0.85, pullRatio)
    readonly property real dotSpread: smoothStep(0.40, 0.95, pullRatio)

    CapsuleSensorArea {
        id: sensorArea
        actionBus: actionBus
        width: capsuleRoot.width
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
        width: capsuleRoot.width
        height: capsuleRoot.currentConfigHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        clip: false
        z: 10
        visible: opacity > 0.001

        enabled: !capsuleRoot.isCurrentExpanded && !capsuleRoot.isActivelyPulling && (fsm && fsm.currentState !== IslandFsm.State.Hidden)
        readonly property bool shouldDisplay: !capsuleRoot.isCurrentExpanded && (fsm && fsm.currentState !== IslandFsm.State.Hidden)

        opacity: shouldDisplay ? 1.0 : 0.0
        scale: shouldDisplay ? 1.0 : 0.92

        Behavior on opacity {
            NumberAnimation {
                duration: compactContainer.shouldDisplay ? 200 : 240
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation { duration: 240; easing.type: Easing.OutQuad }
        }

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
        scale: capsuleRoot.isCurrentExpanded ? 1.0 : 0.90

        Behavior on opacity {
            NumberAnimation {
                duration: capsuleRoot.isCurrentExpanded ? Theme.animNormal : 240
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: motionPod.motionDuration
                easing.type: motionPod.fluidCurve
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