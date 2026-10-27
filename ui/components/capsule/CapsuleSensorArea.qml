// ==========================================
// 📄 File: ui/components/capsule/CapsuleSensorArea.qml
// 🌟 声明式胶囊交互中枢 (暴露右键物理蓄力信号版)
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

    property bool isScrubbing: false
    property bool isScrubCanceling: false
    property bool isMovingIsland: false

    property bool wasScrubbingJustNow: false
    property bool isPullingDown: false
    property real pullDownDistance: 0

    // 🚀【新增】：暴露给 IslandCapsule 用于渲染层 Squash 缩放
    property bool isRightPressing: false

    readonly property bool isPointerHovered: globalCapsuleHover.hovered || hitArea.containsMouse

    signal requestExpand(string tabName)
    signal requestCollapse()
    signal startCollapse()
    signal wheelScrolled(int deltaY)

    signal scrubStarted()
    signal scrubMoved(real mouseX, real mouseY)
    signal scrubCommitted()
    signal scrubCanceled()

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
        State { name: "IDLE"; PropertyChanges { target: sensorRoot; isScrubbing: false; isScrubCanceling: false; isMovingIsland: false } },
        State { name: "HOVERING" },
        State { name: "PRESSED" },
        State { name: "SCRUBBING"; PropertyChanges { target: sensorRoot; isScrubbing: true } },
        State { name: "MOVING"; PropertyChanges { target: sensorRoot; isMovingIsland: true } }
    ]

    Timer { id: scrubLockCooldown; interval: 250; repeat: false; onTriggered: sensorRoot.wasScrubbingJustNow = false }

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

    Timer {
        id: singleClickDelayTimer
        interval: 180
        repeat: false
        property var pendingExpandAction: null
        onTriggered: {
            if (pendingExpandAction) {
                pendingExpandAction();
                pendingExpandAction = null;
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
                if (sensorRoot.wasScrubbingJustNow) return;
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
            if (sensorRoot.wasScrubbingJustNow || sensorRoot.isTucked || sensorRoot.isPeeking || sensorRoot.isPassive5S) return;
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
        cursorShape: sensorRoot.isMovingIsland ? Qt.SizeHorCursor : (sensorRoot.isScrubbing ? (sensorRoot.isScrubCanceling ? Qt.ForbiddenCursor : Qt.SplitHCursor) : Qt.PointingHandCursor)

        onPressed: (mouse) => {
            hoverDwellTimer.stop();
            if (mouse.button === Qt.RightButton) {
                sensorRoot.isRightPressing = true; // 🚀【蓄力触发】：右键按下瞬间产生物理压扁
                mouse.accepted = true;
                return;
            }

            sensorRoot.pressStartX = mouse.x; sensorRoot.pressStartY = mouse.y;
            sensorRoot.lastDragX = mouse.x; sensorRoot.dragVelocityX = 0;
            sensorRoot.isPullingDown = false; sensorRoot.pullDownDistance = 0;

            var isModifierHeld = (mouse.modifiers & Qt.AltModifier) || (mouse.modifiers & Qt.MetaModifier);
            if (isModifierHeld || mouse.button === Qt.MiddleButton) { sensorRoot.state = "MOVING"; return; }
            sensorRoot.state = "PRESSED";
        }

        onPositionChanged: (mouse) => {
            if (sensorRoot.state === "MOVING") {
                var stepX = mouse.x - sensorRoot.lastDragX;
                sensorRoot.dragVelocityX = stepX; sensorRoot.lastDragX = mouse.x;
                sensorRoot.moveOffsetRequested(stepX); return;
            }

            var adx = Math.abs(mouse.x - sensorRoot.pressStartX);
            var dy = mouse.y - sensorRoot.pressStartY;

            if (dy > 14 && dy > adx * 1.2 && !sensorRoot.isScrubbing) {
                sensorRoot.isPullingDown = true; sensorRoot.pullDownDistance = dy; return;
            }

            if (sensorRoot.state === "PRESSED" && adx >= 8 && Math.abs(dy) < 16) {
                sensorRoot.state = "SCRUBBING"; sensorRoot.wasScrubbingJustNow = true; sensorRoot.scrubStarted();
            }

            if (sensorRoot.state === "SCRUBBING") {
                if (dy > 30) sensorRoot.isScrubCanceling = true;
                else { sensorRoot.isScrubCanceling = false; sensorRoot.scrubMoved(mouse.x, mouse.y); }
            }
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                sensorRoot.isRightPressing = false; // 🚀【弹射触发】：右键松开，弹射隐藏
                sensorRoot.requestTuckToggle();
                return;
            }

            if (sensorRoot.isPullingDown) {
                if (sensorRoot.pullDownDistance >= 20 || (mouse.y - sensorRoot.pressStartY) >= 20) {
                    if (typeof Bridge !== "undefined" && Bridge.toggleDesktopGrid) Bridge.toggleDesktopGrid();
                }
                sensorRoot.isPullingDown = false; sensorRoot.pullDownDistance = 0; sensorRoot.state = "IDLE"; return;
            }

            if (sensorRoot.state === "MOVING") { sensorRoot.state = "IDLE"; sensorRoot.dragFinished(sensorRoot.dragVelocityX); return; }
            if (sensorRoot.state === "SCRUBBING") {
                sensorRoot.wasScrubbingJustNow = true; scrubLockCooldown.restart();
                if (sensorRoot.isScrubCanceling) sensorRoot.scrubCanceled(); else sensorRoot.scrubCommitted();
                sensorRoot.state = "IDLE"; return;
            }
            sensorRoot.state = "IDLE";
        }

        onCanceled: {
            sensorRoot.isRightPressing = false; // 异常脱离时释放蓄力
            sensorRoot.isPullingDown = false; sensorRoot.pullDownDistance = 0;
            if (sensorRoot.state === "SCRUBBING") {
                sensorRoot.wasScrubbingJustNow = true; scrubLockCooldown.restart(); sensorRoot.scrubCanceled();
            }
            sensorRoot.state = "IDLE";
        }

        onWheel: (wheel) => {
            wheel.accepted = true;
            if (sensorRoot.isScrubbing || sensorRoot.isMovingIsland) return;
            sensorRoot.wheelScrolled(wheel.angleDelta.y);
        }

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                mouse.accepted = true; singleClickDelayTimer.stop(); singleClickDelayTimer.pendingExpandAction = null;
                if (typeof Bridge !== "undefined" && Bridge.toggleDesktopGrid) Bridge.toggleDesktopGrid();
            }
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) return; // 已经在 Released 中处理了
            if (sensorRoot.wasScrubbingJustNow) { sensorRoot.wasScrubbingJustNow = false; scrubLockCooldown.stop(); return; }
            if (sensorRoot.isPeeking || sensorRoot.isPassive5S || sensorRoot.isExpanded) return;
            if (sensorRoot.activeTransient === "SEDENTARY" || sensorRoot.activeTransient === "VOICE_INPUT") return;

            singleClickDelayTimer.pendingExpandAction = function() {
                if (sensorRoot.isCalling) { sensorRoot.requestExpand("media"); return; }
                if (sensorRoot.activeTransient === "ALERT") { sensorRoot.requestExpand("notification"); return; }
                sensorRoot.requestExpand("hardware");
            };
            singleClickDelayTimer.restart();
        }
    }
}