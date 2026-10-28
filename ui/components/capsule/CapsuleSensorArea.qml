// ==========================================
// 📄 File: ui/components/capsule/CapsuleSensorArea.qml
// 🌟 纯正声明式交互中枢 (移除鱼眼洗牌 · 零点击延迟响应版)
// ==========================================
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
    property bool isPullingDown: false
    property real pullDownDistance: 0

    // 暴露给外壳用于右键蓄力压扁物理动效
    property bool isRightPressing: false

    readonly property bool isPointerHovered: globalCapsuleHover.hovered || hitArea.containsMouse

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

    Timer {
        id: hoverDwellTimer
        interval: (typeof Config !== "undefined" && Config.hoverDwellTime) ? Config.hoverDwellTime : 240
        repeat: false
        onTriggered: {
            if (sensorRoot.isPointerHovered && !sensorRoot.isExpanded && !sensorRoot.isTucked) {
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
        cursorShape: sensorRoot.isMovingIsland ? Qt.SizeHorCursor : Qt.PointingHandCursor

        onPressed: (mouse) => {
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
            sensorRoot.pullDownDistance = 0;

            var isModifierHeld = (mouse.modifiers & Qt.AltModifier) || (mouse.modifiers & Qt.MetaModifier);
            if (isModifierHeld || mouse.button === Qt.MiddleButton) {
                sensorRoot.state = "MOVING";
                return;
            }
            sensorRoot.state = "PRESSED";
        }

        onPositionChanged: (mouse) => {
            if (sensorRoot.state === "MOVING") {
                var stepX = mouse.x - sensorRoot.lastDragX;
                sensorRoot.dragVelocityX = stepX;
                sensorRoot.lastDragX = mouse.x;
                sensorRoot.moveOffsetRequested(stepX);
                return;
            }

            var adx = Math.abs(mouse.x - sensorRoot.pressStartX);
            var dy = mouse.y - sensorRoot.pressStartY;

            // 识别向下拉出平铺网格意图
            if (dy > 14 && dy > adx * 1.2) {
                sensorRoot.isPullingDown = true;
                sensorRoot.pullDownDistance = dy;
                return;
            }
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                sensorRoot.isRightPressing = false;
                sensorRoot.requestTuckToggle();
                return;
            }

            if (sensorRoot.isPullingDown) {
                if (sensorRoot.pullDownDistance >= 20 || (mouse.y - sensorRoot.pressStartY) >= 20) {
                    if (typeof Bridge !== "undefined" && Bridge.toggleDesktopGrid) Bridge.toggleDesktopGrid();
                }
                sensorRoot.isPullingDown = false;
                sensorRoot.pullDownDistance = 0;
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
            sensorRoot.isRightPressing = false;
            sensorRoot.isPullingDown = false;
            sensorRoot.pullDownDistance = 0;
            sensorRoot.state = "IDLE";
        }

        onWheel: (wheel) => {
            wheel.accepted = true;
            if (sensorRoot.isMovingIsland) return;
            sensorRoot.wheelScrolled(wheel.angleDelta.y);
        }

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                mouse.accepted = true;
                if (typeof Bridge !== "undefined" && Bridge.toggleDesktopGrid) Bridge.toggleDesktopGrid();
            }
        }

        // 🚀【核心优化】：无需等待 180ms 定时器防抖，点击瞬间立刻响应展开！
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) return;
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