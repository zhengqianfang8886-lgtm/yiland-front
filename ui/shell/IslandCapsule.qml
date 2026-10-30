// =========================================================================
// 📄 File: ui/shell/IslandCapsule.qml
// 🌟 灵动岛主壳体 (内容定宽冷冻隔离 · 零重排风暴 · 满帧流体版)
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
    readonly property bool isHovered: capsuleRoot.isCurrentExpanded || (sensorArea && sensorArea.isPointerHovered)
    readonly property bool isRightPressing: sensorArea ? sensorArea.isRightPressing : false

    signal requestSettings()

    PhysicsMotionPod {
        id: motionPod
        onMotionSettled: {
            capsuleRoot.executeActualMaskCommit();
        }
    }

    // =========================================================================
    // 🌊【物理骨骼参数体系】
    // =========================================================================
    // 稳态基准宽度：绝不随手势动态拉动而改变，作为内容视口的永久定宽锚
    readonly property real baseRestingWidth: motionPod.targetWidth

    readonly property real pullOffset: (!sensorArea || capsuleRoot.isCurrentExpanded) ? 0.0 : sensorArea.visualPullY
    readonly property real pullRatio: (!sensorArea || capsuleRoot.isCurrentExpanded) ? 0.0 : sensorArea.pullRatio
    readonly property bool isActivelyPulling: sensorArea ? sensorArea.isPullingDown : false

    function smoothStep(edge0, edge1, val) {
        var t = Math.max(0.0, Math.min(1.0, (val - edge0) / Math.max(0.0001, edge1 - edge0)));
        return t * t * (3.0 - 2.0 * t);
    }

    y: motionPod.currentY

    // 纵向物理拉伸
    readonly property real liquidExtraHeight: pullOffset * 0.85
    height: Math.max(currentConfigHeight, Math.round(motionPod.currentHeight + liquidExtraHeight))

    // 横向向心收缩
    readonly property real liquidPillMinWidth: 124.0
    readonly property real contractionFactor: smoothStep(0.0, 1.0, pullRatio)
    readonly property real dynamicTargetWidth: baseRestingWidth - ((baseRestingWidth - liquidPillMinWidth) * contractionFactor)

    // 外壳几何宽度 (由手势实时 1:1 无阻碍驱动)
    width: Math.max(liquidPillMinWidth, Math.round(dynamicTargetWidth))
    Behavior on width {
        enabled: !capsuleRoot.isActivelyPulling
        NumberAnimation {
            duration: Theme.animFast
            easing.type: Easing.OutQuad
        }
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: islandOffsetX

    scale: (capsuleRoot.isRightPressing) ? 0.95 : ((sensorArea && sensorArea.isTriggerPrimed) ? 1.02 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
    }

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

        if (capsuleRoot.isCurrentExpanded || (compactView && compactView.isImeMenuOpen) || capsuleRoot.isActivelyPulling) {
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

    // 黑曜石背景材质 (仅由几何外壳驱动拉伸，零子布局开销)
    CapsuleBackground {
        id: bg
        isTucked: fsm ? (fsm.currentState === IslandFsm.State.Hidden) : false
        capsuleRadius: motionPod.currentRadius
        pullY: capsuleRoot.pullOffset
        pullRatio: capsuleRoot.pullRatio
        isTriggerPrimed: sensorArea ? sensorArea.isTriggerPrimed : false
    }

    readonly property real clockFadeout: smoothStep(0.04, 0.40, pullRatio)
    readonly property real glyphFadein: smoothStep(0.12, 0.55, pullRatio)
    readonly property real dotSpread: smoothStep(0.18, 0.82, pullRatio)

    // =========================================================================
    // 🚀【核心架构重构 1】：内容视口定宽冷冻隔离
    // 容器宽度绝对绑定至 baseRestingWidth，在拖拽期间绝对不发生尺寸缩放！
    // 彻底切断任何 Text/Row 级联重排重算，实现极其丝滑的 GPU 级淡出！
    // =========================================================================
    Item {
        id: compactContainer
        width: capsuleRoot.baseRestingWidth
        height: capsuleRoot.currentConfigHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        clip: false
        z: 10
        visible: opacity > 0.001
        
        // 拖拽激活时物理断开交互，杜绝任何子药丸事件抢占
        enabled: !capsuleRoot.isCurrentExpanded && !capsuleRoot.isActivelyPulling && (fsm && fsm.currentState !== IslandFsm.State.Hidden)

        opacity: (!capsuleRoot.isCurrentExpanded && (fsm && fsm.currentState !== IslandFsm.State.Hidden)) ? (1.0 - capsuleRoot.clockFadeout) : 0.0
        scale: 1.0 - capsuleRoot.clockFadeout * 0.06
        transform: Translate { y: capsuleRoot.clockFadeout * 1.5 }

        CompactCapsuleView {
            id: compactView
            anchors.fill: parent
            fsm: capsuleRoot.fsm
            relay: capsuleRoot.relay
            timeService: capsuleRoot.timeService
            sedentaryService: capsuleRoot.sedentaryService
        }
    }

    // 4 点微标无跳跃显现
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

    // =========================================================================
    // 🚀【核心架构重构 2】：传感器空间静止绑定
    // 传感器的宽度同样绝对锁定 baseRestingWidth，绝不随水滴收缩而变窄位移！
    // 坐标系在触控全程保持绝对欧几里得恒定，彻底根除自激漂移泥潭感！
    // =========================================================================
    CapsuleSensorArea {
        id: sensorArea
        width: capsuleRoot.baseRestingWidth
        height: Math.max(capsuleRoot.currentConfigHeight, capsuleRoot.height)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        z: 20
        visible: !capsuleRoot.isCurrentExpanded && (fsm && fsm.currentState !== IslandFsm.State.Hidden)
        enabled: visible
        isExpanded: capsuleRoot.isCurrentExpanded
        isTucked: fsm ? (fsm.currentState === IslandFsm.State.Hidden) : false

        onRequestExpand: (tab) => {
            if (fsm) fsm.handleIntent("EXPAND", { tab: tab, source: "SensorArea_Expand" });
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