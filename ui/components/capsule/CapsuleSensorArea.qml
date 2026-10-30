// =========================================================================
// 📄 File: ui/components/capsule/CapsuleSensorArea.qml
// 🌟 纯正流体动力学传感器 (静态欧几里得空间 · C1连续流体力学 · 零漂移版)
// =========================================================================
import QtQuick

Item {
    id: sensorRoot
    anchors.fill: parent

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

    // 触发平铺网格的黄金阈值 (像素)
    readonly property real triggerThreshold: 15.5
    
    // 连续张力比例 (0.0 起跑 ~ 1.0 锁定 ~ 1.5 超幅)
    readonly property real pullRatio: Math.min(1.5, visualPullY / triggerThreshold)
    readonly property bool isPointerHovered: globalCapsuleHover.hovered || hitArea.containsMouse

    // 手势裁决锁与冷却盾
    property bool gestureEverExceededSlop: false
    property bool isInteractionCooldown: false
    property bool isReturnCooldown: false

    property real pressStartX: 0
    property real pressStartY: 0
    property real lastDragX: 0
    property real dragVelocityX: 0

    readonly property real dragSlop: 3.5

    signal requestExpand(string tabName)
    signal requestTuckToggle()
    signal wheelScrolled(int deltaY)
    signal moveOffsetRequested(real deltaX)
    signal dragFinished(real velocityX)
    signal pointerEnteredCapsule()
    signal pointerExitedCapsule()
    signal requestSettingsWindow()

    // 🚀【核心力学方程】：在 dy = 6px 处一阶导数严格连续为 1.0，前段零延迟直连，后段渐近双曲张力
    function computeFluidPull(dy) {
        if (dy <= 0) return 0.0;
        if (dy <= 6.0) return dy; // 0~6px: 100% 绝对 1:1 跟手，极速即时响应，零死区
        
        var excess = dy - 6.0;
        var maxStretch = 18.0;
        return 6.0 + (excess * maxStretch) / (maxStretch + excess * 0.85);
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

    Timer {
        id: hoverDwellTimer
        interval: (typeof Config !== "undefined" && Config.hoverDwellTime) ? Math.max(160, Config.hoverDwellTime) : 240
        repeat: false
        onTriggered: {
            if (sensorRoot.isInteractionCooldown || sensorRoot.isReturnCooldown) return;
            if (hitArea.pressed || sensorRoot.isPullingDown || sensorRoot.visualPullY > 0.1) return;
            if (sensorRoot.isExpanded || sensorRoot.isTucked) return;
            if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return;

            if (sensorRoot.isPointerHovered) {
                if (sensorRoot.isCalling) sensorRoot.requestExpand("media");
                else if (sensorRoot.activeTransient === "ALERT") sensorRoot.requestExpand("notification");
                else if (sensorRoot.activeTransient === "SEDENTARY" || sensorRoot.activeTransient === "VOICE_INPUT") return;
                else sensorRoot.requestExpand("workspace");
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

            // 在静态坐标系内打点记下绝对原点
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

            // 由于宿主容器定宽，此处 dy, dx 是绝对线性的，毫无坐标自激漂移！
            var dy = mouse.y - sensorRoot.pressStartY;
            var dx = Math.abs(mouse.x - sensorRoot.pressStartX);

            if (!sensorRoot.gestureEverExceededSlop) {
                if (dy > sensorRoot.dragSlop && dy > dx * 0.5) {
                    sensorRoot.gestureEverExceededSlop = true;
                    sensorRoot.isPullingDown = true;
                } else if (dx > sensorRoot.dragSlop) {
                    sensorRoot.gestureEverExceededSlop = true;
                }
            }

            if (sensorRoot.gestureEverExceededSlop && !sensorRoot.isMovingIsland) {
                if (dy > 0) {
                    sensorRoot.isPullingDown = true;
                    var calculatedY = sensorRoot.computeFluidPull(dy);
                    sensorRoot.visualPullY = calculatedY;
                    sensorRoot.isTriggerPrimed = (calculatedY >= sensorRoot.triggerThreshold);
                } else {
                    // 向上推回取消手势
                    sensorRoot.visualPullY = 0.0;
                    sensorRoot.isTriggerPrimed = false;
                }
            }
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                sensorRoot.isRightPressing = false;
                sensorRoot.requestTuckToggle();
                return;
            }

            if (sensorRoot.isMovingIsland) {
                sensorRoot.isMovingIsland = false;
                sensorRoot.dragFinished(sensorRoot.dragVelocityX);
                return;
            }

            // 经历过下拉，严格结算为手势（触发或取消），永不降级为点击
            if (sensorRoot.gestureEverExceededSlop) {
                if (sensorRoot.isTriggerPrimed) {
                    sensorRoot.isReturnCooldown = true;
                    hoverDwellTimer.stop();
                    returnCooldownTimer.restart();

                    if (typeof Bridge !== "undefined" && Bridge.toggleDesktopGrid) {
                        Bridge.toggleDesktopGrid();
                    }
                }

                sensorRoot.executeSnapBack();
                sensorRoot.armInteractionCooldown(420);
                return;
            }

            // 纯原地轻击判定
            var totalDx = Math.abs(mouse.x - sensorRoot.pressStartX);
            var totalDy = Math.abs(mouse.y - sensorRoot.pressStartY);

            if (totalDx < sensorRoot.dragSlop && totalDy < sensorRoot.dragSlop) {
                if (sensorRoot.isInteractionCooldown || sensorRoot.isReturnCooldown) return;
                if (sensorRoot.isPullingDown || sensorRoot.visualPullY > 1.0) return;

                if (sensorRoot.isCalling) {
                    sensorRoot.requestExpand("media");
                    return;
                }
                if (sensorRoot.activeTransient === "ALERT") {
                    sensorRoot.requestExpand("notification");
                    return;
                }
                sensorRoot.requestExpand("calendar");
            }
        }

        onCanceled: {
            sensorRoot.isRightPressing = false;
            sensorRoot.isMovingIsland = false;
            sensorRoot.executeSnapBack();
            sensorRoot.armInteractionCooldown(300);
        }

        onClicked: (mouse) => {
            mouse.accepted = true;
        }

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                mouse.accepted = true;
                if (typeof Bridge !== "undefined" && Bridge.toggleDesktopGrid) {
                    Bridge.toggleDesktopGrid();
                }
            }
        }

        onWheel: (wheel) => {
            wheel.accepted = true;
            if (!sensorRoot.isPullingDown) sensorRoot.wheelScrolled(wheel.angleDelta.y);
        }
    }
}