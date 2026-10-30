// =========================================================================
// 📄 File: ui/components/capsule/CapsuleSensorArea.qml
// 🌟 纯正声明式交互中枢 (极度敏感下拉 · 7px极速落锁 · 100ms高速感知版)
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
    property bool isPeeking: false
    property bool isPassive5S: false

    property bool isMovingIsland: false
    property bool isRightPressing: false

    // =========================================================================
    // 🚀【极度敏感下拉动力学参数】
    // =========================================================================
    property bool isPullingDown: false
    property real rawPullDistance: 0.0
    property real visualPullY: 0.0
    property bool isTriggerPrimed: false

    // 🌟 极致敏感落锁阈值：从 14.0 降至 7.0 (真实拖拽约 7~8px 即瞬间激活动作)
    readonly property real triggerThreshold: 7.0
    readonly property bool isPointerHovered: globalCapsuleHover.hovered || hitArea.containsMouse

    // =========================================================================
    // 🛡️【桌面切回冷却锁 (压缩至 200ms 快速解锁)】
    // =========================================================================
    property bool isReturnCooldown: false

    Timer {
        id: returnCooldownTimer
        interval: 200 // 🌟 从 800ms 压缩至 200ms，切回后光速恢复响应
        repeat: false
        onTriggered: {
            sensorRoot.isReturnCooldown = false;
        }
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onGridActiveChanged(isActive) {
            if (!isActive) {
                sensorRoot.isReturnCooldown = true;
                hoverDwellTimer.stop();
                returnCooldownTimer.restart();
            }
        }
    }

    signal requestExpand(string tabName)
    signal requestCollapse()
    signal startCollapse()
    signal wheelScrolled(int deltaY)

    signal moveOffsetRequested(real deltaX)
    signal dragFinished(real velocityX)
    signal goHomeRequested()

    signal requestTuckToggle()
    signal pointerExitedCapsule()
    signal pointerEnteredCapsule()
    signal requestSettingsWindow()

    property real pressStartX: 0
    property real pressStartY: 0
    property real lastDragX: 0
    property real dragVelocityX: 0

    state: "IDLE"

    states: [
        State { name: "IDLE"; PropertyChanges { target: sensorRoot; isMovingIsland: false } },
        State { name: "HOVERING" },
        State { name: "PRESSED" },
        State { name: "MOVING"; PropertyChanges { target: sensorRoot; isMovingIsland: true } }
    ]

    // 🌟 几乎 1:1 的直接跟手动力学：前 8px 零衰减，下拉手感极其轻快干脆
    function computeDampedPull(dy) {
        if (dy <= 0) return 0.0;
        if (dy < 8) return dy * 0.95; 
        return 7.6 + Math.pow(dy - 8, 0.65) * 1.2;
    }

    SequentialAnimation {
        id: snapBackAnimation

        NumberAnimation {
            target: sensorRoot
            property: "visualPullY"
            to: 0.0
            duration: 120
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }

        ScriptAction {
            script: {
                sensorRoot.visualPullY = 0.0;
                sensorRoot.isPullingDown = false;
                sensorRoot.isTriggerPrimed = false;
            }
        }
    }

    // 🌟 悬停自动展开高速感应：默认提速至 110ms
    Timer {
        id: hoverDwellTimer
        interval: (typeof Config !== "undefined" && Config.hoverDwellTime) ? Math.min(Config.hoverDwellTime, 120) : 110
        repeat: false
        onTriggered: {
            if (sensorRoot.isReturnCooldown) return;

            if (sensorRoot.isPointerHovered && !sensorRoot.isExpanded && !sensorRoot.isTucked && !sensorRoot.isPullingDown) {
                if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return;
                if (sensorRoot.isCalling) sensorRoot.requestExpand("media");
                else if (sensorRoot.activeTransient === "ALERT") sensorRoot.requestExpand("notification");
                else if (sensorRoot.activeTransient === "SEDENTARY" || sensorRoot.activeTransient === "VOICE_INPUT") return;
                else sensorRoot.requestExpand("workspace");
            }
        }
    }

    HoverHandler {
        id: globalCapsuleHover
        blocking: false
        enabled: !sensorRoot.isTucked && !sensorRoot.isExpanded
        onHoveredChanged: {
            if (hovered) {
                sensorRoot.pointerEnteredCapsule();
                if (sensorRoot.state === "IDLE" && !sensorRoot.isExpanded && !sensorRoot.isCollapsing) {
                    sensorRoot.state = "HOVERING";
                }
            } else {
                if (sensorRoot.state === "HOVERING") sensorRoot.state = "IDLE";
            }
        }
    }

    onStateChanged: {
        if (state === "HOVERING") {
            if (sensorRoot.isReturnCooldown) return;
            if (sensorRoot.isTucked || sensorRoot.isPeeking || sensorRoot.isPassive5S) return;
            if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return;
            hoverDwellTimer.restart();
        } else {
            hoverDwellTimer.stop();
        }
    }

    MouseArea {
        id: hitArea
        anchors.fill: parent
        enabled: !sensorRoot.isExpanded && !sensorRoot.isNoticeActive && !sensorRoot.isTucked &&
                 (sensorRoot.activeTransient !== "VOICE_INPUT") &&
                 (sensorRoot.activeTransient !== "CALL") &&
                 (sensorRoot.activeTransient !== "SEDENTARY")
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: sensorRoot.isMovingIsland ? Qt.SizeHorCursor : (sensorRoot.isPullingDown ? Qt.ClosedHandCursor : Qt.PointingHandCursor)

        onPressed: (mouse) => {
            snapBackAnimation.stop();
            hoverDwellTimer.stop();

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
            sensorRoot.rawPullDistance = 0;
            sensorRoot.visualPullY = 0;
            sensorRoot.isTriggerPrimed = false;

            var isModifierHeld = (mouse.modifiers & Qt.AltModifier) || (mouse.modifiers & Qt.MetaModifier);
            if (isModifierHeld || mouse.button === Qt.MiddleButton) {
                sensorRoot.state = "MOVING";
                return;
            }
            sensorRoot.state = "PRESSED";
        }

        onPositionChanged: (mouse) => {
            if (!hitArea.pressed || !(mouse.buttons & Qt.LeftButton)) {
                return;
            }

            if (sensorRoot.state === "MOVING") {
                var stepX = mouse.x - sensorRoot.lastDragX;
                sensorRoot.dragVelocityX = stepX;
                sensorRoot.lastDragX = mouse.x;
                sensorRoot.moveOffsetRequested(stepX);
                return;
            }

            var adx = Math.abs(mouse.x - sensorRoot.pressStartX);
            var dy = mouse.y - sensorRoot.pressStartY;

            // 🌟 极速起步识别：位移只需超过 2px 且放宽角度约束，轻轻一拉立刻进入下拉手势
            if (dy > 2 && dy > adx * 0.75) {
                sensorRoot.isPullingDown = true;
                sensorRoot.rawPullDistance = dy;
                
                var calculatedY = sensorRoot.computeDampedPull(dy);
                sensorRoot.visualPullY = calculatedY;
                sensorRoot.isTriggerPrimed = (calculatedY >= sensorRoot.triggerThreshold);
                return;
            } else if (dy <= 0 && sensorRoot.isPullingDown) {
                sensorRoot.visualPullY = 0;
                sensorRoot.isPullingDown = false;
                sensorRoot.isTriggerPrimed = false;
            }
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                sensorRoot.isRightPressing = false;
                sensorRoot.requestTuckToggle();
                return;
            }

            if (sensorRoot.isPullingDown) {
                if (sensorRoot.isTriggerPrimed) {
                    sensorRoot.isReturnCooldown = true;
                    hoverDwellTimer.stop();
                    returnCooldownTimer.restart();

                    if (typeof Bridge !== "undefined" && Bridge.toggleDesktopGrid) {
                        Bridge.toggleDesktopGrid();
                    }
                    sensorRoot.visualPullY = 0.0;
                    sensorRoot.isPullingDown = false;
                    sensorRoot.isTriggerPrimed = false;
                } else {
                    snapBackAnimation.restart();
                }

                sensorRoot.rawPullDistance = 0;
                sensorRoot.state = "IDLE";
                return;
            }

            if (sensorRoot.state === "MOVING") {
                sensorRoot.state = "IDLE";
                sensorRoot.dragFinished(sensorRoot.dragVelocityX);
                return;
            }

            sensorRoot.state = "IDLE";
        }

        onCanceled: {
            if (sensorRoot.isPullingDown) {
                snapBackAnimation.restart();
            } else {
                sensorRoot.visualPullY = 0.0;
            }
            sensorRoot.isRightPressing = false;
            sensorRoot.isPullingDown = false;
            sensorRoot.rawPullDistance = 0;
            sensorRoot.isTriggerPrimed = false;
            sensorRoot.state = "IDLE";
        }

        onWheel: (wheel) => {
            wheel.accepted = true;
            if (sensorRoot.isMovingIsland || sensorRoot.isPullingDown) return;
            sensorRoot.wheelScrolled(wheel.angleDelta.y);
        }

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                mouse.accepted = true;
                if (typeof Bridge !== "undefined" && Bridge.toggleDesktopGrid) {
                    Bridge.toggleDesktopGrid();
                }
            }
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) return;
            if (sensorRoot.isReturnCooldown) return;
            if (sensorRoot.isPullingDown || sensorRoot.visualPullY > 1.5) return;
            if (sensorRoot.isPeeking || sensorRoot.isPassive5S || sensorRoot.isExpanded) return;
            if (sensorRoot.activeTransient === "SEDENTARY" || sensorRoot.activeTransient === "VOICE_INPUT") return;

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
}