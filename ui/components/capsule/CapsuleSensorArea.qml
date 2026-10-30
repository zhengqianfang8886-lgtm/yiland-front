// =========================================================================
// 📄 File: ui/components/capsule/CapsuleSensorArea.qml
// 🌟 纯正流体动力学手势裁决中枢 (补齐设置信号 · ActionBus 驱动 · 桌面网格精准触发版)
// =========================================================================
import QtQuick
import QtQml
import "../../core/IslandLogger.js" as Logger

Item {
    id: sensorRoot
    anchors.fill: parent

    // 动作总线注入引用
    property var actionBus: null

    // 状态机与暂态
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isCalling: false
    property bool isNoticeActive: false
    property string activeTransient: ""
    property bool isTucked: false

    property bool isMovingIsland: false
    property bool isRightPressing: false

    // 连续拉伸物理量
    property bool isPullingDown: false
    property real visualPullY: 0.0
    property bool isTriggerPrimed: false

    // 触发桌面平铺网格的标定黄金行程 (像素)
    readonly property real triggerThreshold: 16.0
    
    // 张力比与指针悬停
    readonly property real pullRatio: Math.min(1.5, visualPullY / triggerThreshold)
    readonly property bool isPointerHovered: globalCapsuleHover.hovered || hitArea.containsMouse

    // 意图锁定与冷却保护盾
    property bool gestureEverExceededSlop: false
    property bool isInteractionCooldown: false
    property bool isReturnCooldown: false

    property real pressStartX: 0
    property real pressStartY: 0
    property real lastDragX: 0
    property real dragVelocityX: 0

    readonly property real dragSlop: 3.5

    // =========================================================================
    // 🚀【完整信号契约声明】：彻底消灭编译阶段的 non-existent property 报错
    // =========================================================================
    signal pointerEnteredCapsule()
    signal pointerExitedCapsule()
    signal moveOffsetRequested(real deltaX)
    signal dragFinished(real velocityX)
    signal requestSettingsWindow()

    // C1 连续流体力学阻尼样条 (前 8px 绝对 1:1 跟手，后段双曲渐近张力)
    function computeFluidPull(dy) {
        if (dy <= 0) return 0.0;
        if (dy <= 8.0) return dy;
        
        var excess = dy - 8.0;
        var maxStretch = 20.0;
        return 8.0 + (excess * maxStretch) / (maxStretch + excess * 0.75);
    }

    function armInteractionCooldown(durationMs) {
        hoverDwellTimer.stop();
        sensorRoot.isInteractionCooldown = true;
        cooldownTimer.interval = durationMs || 420;
        cooldownTimer.restart();
    }

    function executeSnapBack() {
        if (visualPullY <= 0.001) {
            visualPullY = 0.0;
            isPullingDown = false;
            isTriggerPrimed = false;
            return;
        }
        snapBackAnimation.restart();
    }

    ParallelAnimation {
        id: snapBackAnimation

        NumberAnimation {
            target: sensorRoot
            property: "visualPullY"
            to: 0.0
            duration: Theme.animNormal
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        onFinished: {
            sensorRoot.visualPullY = 0.0;
            sensorRoot.isPullingDown = false;
            sensorRoot.isTriggerPrimed = false;
        }
    }

    Timer {
        id: cooldownTimer
        repeat: false
        onTriggered: sensorRoot.isInteractionCooldown = false
    }

    Timer {
        id: returnCooldownTimer
        interval: 220
        repeat: false
        onTriggered: sensorRoot.isReturnCooldown = false
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onGridActiveChanged(isActive) {
            if (!isActive) {
                sensorRoot.isReturnCooldown = true;
                hoverDwellTimer.stop();
                returnCooldownTimer.restart();
                sensorRoot.executeSnapBack();
            }
        }
    }

    // 悬停自动展开定时器
    Timer {
        id: hoverDwellTimer
        interval: (typeof Config !== "undefined" && Config.hoverDwellTime) ? Math.max(160, Config.hoverDwellTime) : 240
        repeat: false
        onTriggered: {
            if (sensorRoot.isInteractionCooldown || sensorRoot.isReturnCooldown) return;
            if (hitArea.pressed || sensorRoot.isPullingDown || sensorRoot.visualPullY > 0.1) return;
            if (sensorRoot.isExpanded || sensorRoot.isTucked) return;
            if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return;

            if (sensorRoot.isPointerHovered && sensorRoot.actionBus) {
                var targetTab = "workspace";
                if (sensorRoot.isCalling) targetTab = "media";
                else if (sensorRoot.activeTransient === "ALERT") targetTab = "notification";
                else if (sensorRoot.activeTransient === "SEDENTARY" || sensorRoot.activeTransient === "VOICE_INPUT") return;

                sensorRoot.actionBus.triggerAction("EXPAND_CARD", { tab: targetTab, source: "HoverDwell" });
            }
        }
    }

    HoverHandler {
        id: globalCapsuleHover
        enabled: !sensorRoot.isTucked && !sensorRoot.isExpanded
        onHoveredChanged: {
            if (hovered) {
                sensorRoot.pointerEnteredCapsule();
                if (!sensorRoot.isInteractionCooldown && !sensorRoot.isReturnCooldown && !hitArea.pressed) {
                    if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return;
                    hoverDwellTimer.restart();
                }
            } else {
                sensorRoot.pointerExitedCapsule();
                hoverDwellTimer.stop();
            }
        }
    }

    MouseArea {
        id: hitArea
        anchors.fill: parent
        enabled: !sensorRoot.isExpanded && !sensorRoot.isTucked &&
                 (sensorRoot.activeTransient !== "VOICE_INPUT") &&
                 (sensorRoot.activeTransient !== "CALL") &&
                 (sensorRoot.activeTransient !== "SEDENTARY")
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: sensorRoot.isMovingIsland ? Qt.SizeHorCursor : (sensorRoot.isPullingDown ? Qt.ClosedHandCursor : Qt.PointingHandCursor)

        onPressed: (mouse) => {
            snapBackAnimation.stop();
            hoverDwellTimer.stop();
            cooldownTimer.stop();
            sensorRoot.isInteractionCooldown = false;

            if (mouse.button === Qt.RightButton) {
                sensorRoot.isRightPressing = true;
                mouse.accepted = true;
                return;
            }

            sensorRoot.pressStartX = mouse.x;
            sensorRoot.pressStartY = mouse.y;
            sensorRoot.lastDragX = mouse.x;
            sensorRoot.dragVelocityX = 0;
            sensorRoot.isPullingDown = false;
            sensorRoot.visualPullY = 0;
            sensorRoot.isTriggerPrimed = false;
            sensorRoot.gestureEverExceededSlop = false;

            var isMod = (mouse.modifiers & Qt.AltModifier) || (mouse.modifiers & Qt.MetaModifier);
            if (isMod || mouse.button === Qt.MiddleButton) {
                sensorRoot.isMovingIsland = true;
                return;
            }
        }

        onPositionChanged: (mouse) => {
            if (!hitArea.pressed || !(mouse.buttons & Qt.LeftButton)) return;

            if (sensorRoot.isMovingIsland) {
                var stepX = mouse.x - sensorRoot.lastDragX;
                sensorRoot.dragVelocityX = stepX;
                sensorRoot.lastDragX = mouse.x;
                sensorRoot.moveOffsetRequested(stepX);
                return;
            }

            var dy = mouse.y - sensorRoot.pressStartY;
            var dx = Math.abs(mouse.x - sensorRoot.pressStartX);

            if (!sensorRoot.gestureEverExceededSlop) {
                if (dy > sensorRoot.dragSlop && dy > dx * 0.5) {
                    sensorRoot.gestureEverExceededSlop = true;
                    sensorRoot.isPullingDown = true;
                    Logger.gesture("lock", "越过死区门限 (dy=" + Math.round(dy) + "px) -> 锁定为下拉手势");
                } else if (dx > sensorRoot.dragSlop) {
                    sensorRoot.gestureEverExceededSlop = true;
                }
            }

            if (sensorRoot.gestureEverExceededSlop && !sensorRoot.isMovingIsland) {
                if (dy > 0) {
                    sensorRoot.isPullingDown = true;
                    var calculatedY = sensorRoot.computeFluidPull(dy);
                    sensorRoot.visualPullY = calculatedY;
                    var primed = (calculatedY >= sensorRoot.triggerThreshold);
                    if (primed !== sensorRoot.isTriggerPrimed) {
                        sensorRoot.isTriggerPrimed = primed;
                        Logger.gesture("prime", primed ? "🔥 达到行程阈值 (Primed) -> 桌面网格落锁" : "💧 行程缩回阈值内");
                    }
                } else {
                    sensorRoot.visualPullY = 0.0;
                    sensorRoot.isTriggerPrimed = false;
                }
            }
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                sensorRoot.isRightPressing = false;
                if (sensorRoot.actionBus) {
                    sensorRoot.actionBus.triggerAction("TOGGLE_TUCK", { source: "RightClick" });
                }
                return;
            }

            if (sensorRoot.isMovingIsland) {
                sensorRoot.isMovingIsland = false;
                sensorRoot.dragFinished(sensorRoot.dragVelocityX);
                return;
            }

            // 🚀 下拉手势结算：满行程 100% 呼出 KWin 平铺网格
            if (sensorRoot.gestureEverExceededSlop) {
                if (sensorRoot.isTriggerPrimed) {
                    Logger.gesture("trigger", "🎉 满行程释放 -> 触发 KWin 桌面平铺网格！");
                    sensorRoot.isReturnCooldown = true;
                    hoverDwellTimer.stop();
                    returnCooldownTimer.restart();

                    if (sensorRoot.actionBus) {
                        sensorRoot.actionBus.triggerAction("TRIGGER_DESKTOP_GRID", { source: "PullDownSettled" });
                    }
                } else {
                    Logger.gesture("abort", "💧 未满行程取消 -> 平滑回弹，拒绝打开卡片");
                }

                sensorRoot.executeSnapBack();
                sensorRoot.armInteractionCooldown(380);
                return;
            }

            // 纯原地轻击 (Tap)
            var totalDx = Math.abs(mouse.x - sensorRoot.pressStartX);
            var totalDy = Math.abs(mouse.y - sensorRoot.pressStartY);

            if (totalDx < sensorRoot.dragSlop && totalDy < sensorRoot.dragSlop) {
                if (sensorRoot.isInteractionCooldown || sensorRoot.isReturnCooldown) return;
                if (sensorRoot.isPullingDown || sensorRoot.visualPullY > 1.0) return;

                if (sensorRoot.actionBus) {
                    var tab = "calendar";
                    if (sensorRoot.isCalling) tab = "media";
                    else if (sensorRoot.activeTransient === "ALERT") tab = "notification";

                    sensorRoot.actionBus.triggerAction("EXPAND_CARD", { tab: tab, source: "CleanTap" });
                }
            }
        }

        onCanceled: {
            sensorRoot.isRightPressing = false;
            sensorRoot.isMovingIsland = false;
            sensorRoot.executeSnapBack();
            sensorRoot.armInteractionCooldown(300);
        }

        onClicked: (mouse) => { mouse.accepted = true; }

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton && sensorRoot.actionBus) {
                mouse.accepted = true;
                sensorRoot.actionBus.triggerAction("TRIGGER_DESKTOP_GRID", { source: "DoubleClick" });
            }
        }

        onWheel: (wheel) => {
            wheel.accepted = true;
            if (!sensorRoot.isPullingDown && sensorRoot.actionBus) {
                if (wheel.angleDelta.y > 0) {
                    sensorRoot.actionBus.triggerAction("WORKSPACE_PREV", { source: "SensorArea_Wheel" });
                } else {
                    sensorRoot.actionBus.triggerAction("WORKSPACE_NEXT", { source: "SensorArea_Wheel" });
                }
            }
        }
    }
}