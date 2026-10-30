// =========================================================================
// 📄 File: ui/components/capsule/CapsuleSensorArea.qml
// 🌟 纯正流体动力学手势中枢 (恢复下拉呼出桌面网格 · 彻底杜绝误触卡片版)
// =========================================================================
import QtQuick
import QtQml

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

    property bool isPullingDown: false
    property real visualPullY: 0.0
    property bool isTriggerPrimed: false

    // 触发桌面平铺网格的标定黄金行程 (像素)
    readonly property real triggerThreshold: 16.0
    
    readonly property real pullRatio: Math.min(1.5, visualPullY / triggerThreshold)
    readonly property bool isPointerHovered: globalCapsuleHover.hovered || hitArea.containsMouse

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

    // 渐近双曲力学样条：前 8px 绝对 1:1 跟手，随后渐进带起阻尼感
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

            // 🚀【核心功能恢复】：只要经历过下拉拖拽，严格根据是否越过行程判定
            if (sensorRoot.gestureEverExceededSlop) {
                if (sensorRoot.isTriggerPrimed) {
                    // 🎉 满行程释放：100% 触发系统的平铺网格（Desktop Grid / Overview）！
                    sensorRoot.isReturnCooldown = true;
                    hoverDwellTimer.stop();
                    returnCooldownTimer.restart();

                    if (typeof Bridge !== "undefined" && Bridge.toggleDesktopGrid) {
                        Bridge.toggleDesktopGrid();
                    }
                }

                // 无论是成功触发还是半途放弃，回弹时都严格阻断误开卡片
                sensorRoot.executeSnapBack();
                sensorRoot.armInteractionCooldown(380);
                return;
            }

            // 纯轻触原地点击 (Tap) 展开日历/通知
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
            if (!sensorRoot.isPullingDown) {
                sensorRoot.wheelScrolled(wheel.angleDelta.y);
            }
        }
    }
}