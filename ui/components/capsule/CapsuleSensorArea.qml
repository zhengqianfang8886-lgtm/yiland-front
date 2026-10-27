// ==========================================
// 📄 File: ui/components/capsule/CapsuleSensorArea.qml
// 🌟 纯声明式状态机手势中枢 (集成全域双击 + 向下轻拉呼出网格版)
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

    // 🚀 下拉手势状态跟踪
    property bool isPullingDown: false
    property real pullDownDistance: 0

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
        State {
            name: "IDLE"
            PropertyChanges { target: sensorRoot; isScrubbing: false; isScrubCanceling: false; isMovingIsland: false }
        },
        State { name: "HOVERING" },
        State { name: "PRESSED" },
        State {
            name: "SCRUBBING"
            PropertyChanges { target: sensorRoot; isScrubbing: true }
        },
        State {
            name: "MOVING"
            PropertyChanges { target: sensorRoot; isMovingIsland: true }
        }
    ]

    Timer {
        id: scrubLockCooldown
        interval: 250
        repeat: false
        onTriggered: sensorRoot.wasScrubbingJustNow = false
    }

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

    // 🚀 单双击分离仲裁定时器 (180ms 内若未收到第二次点击则执行单击展开)
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
                sensorRoot.pointerExitedCapsule();
                if (sensorRoot.state === "HOVERING") {
                    sensorRoot.state = "IDLE";
                }
            }
        }
    }

    onStateChanged: {
        if (state === "HOVERING") {
            if (sensorRoot.wasScrubbingJustNow) return;
            if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return;
            if (sensorRoot.isTucked || sensorRoot.isPeeking || sensorRoot.isPassive5S) return;
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
        cursorShape: sensorRoot.isMovingIsland ? Qt.SizeHorCursor :
                     (sensorRoot.isScrubbing ? (sensorRoot.isScrubCanceling ? Qt.ForbiddenCursor : Qt.SplitHCursor) : Qt.PointingHandCursor)

        onEntered: sensorRoot.pointerEnteredCapsule()
        onExited: sensorRoot.pointerExitedCapsule()

        onPressed: (mouse) => {
            hoverDwellTimer.stop();
            if (mouse.button === Qt.RightButton) {
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

            // 🚀【手势 2 识别】：按住垂直向下拉动超过 14px，判定为下拉轻拉手势
            if (dy > 14 && dy > adx * 1.2 && !sensorRoot.isScrubbing) {
                sensorRoot.isPullingDown = true;
                sensorRoot.pullDownDistance = dy;
                return;
            }

            // 左右横拉进入切桌面洗发态 (Scrubbing)
            if (sensorRoot.state === "PRESSED" && adx >= 8 && Math.abs(dy) < 16) {
                sensorRoot.state = "SCRUBBING";
                sensorRoot.wasScrubbingJustNow = true;
                sensorRoot.scrubStarted();
            }

            if (sensorRoot.state === "SCRUBBING") {
                if (dy > 30) {
                    sensorRoot.isScrubCanceling = true;
                } else {
                    sensorRoot.isScrubCanceling = false;
                    sensorRoot.scrubMoved(mouse.x, mouse.y);
                }
            }
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) return;

            // 🚀【手势 2 释放执行】：向下拉动超过 20px 释放，直接触发全屏平铺网格
            if (sensorRoot.isPullingDown) {
                if (sensorRoot.pullDownDistance >= 20 || (mouse.y - sensorRoot.pressStartY) >= 20) {
                    if (typeof Bridge !== "undefined" && Bridge.toggleDesktopGrid) {
                        Bridge.toggleDesktopGrid();
                    }
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

            if (sensorRoot.state === "SCRUBBING") {
                sensorRoot.wasScrubbingJustNow = true;
                scrubLockCooldown.restart();

                if (sensorRoot.isScrubCanceling) {
                    sensorRoot.scrubCanceled();
                } else {
                    sensorRoot.scrubCommitted();
                }
                sensorRoot.state = "IDLE";
                return;
            }

            sensorRoot.state = "IDLE";
        }

        onCanceled: {
            sensorRoot.isPullingDown = false;
            sensorRoot.pullDownDistance = 0;
            if (sensorRoot.state === "SCRUBBING") {
                sensorRoot.wasScrubbingJustNow = true;
                scrubLockCooldown.restart();
                sensorRoot.scrubCanceled();
            }
            sensorRoot.state = "IDLE";
        }

        onWheel: (wheel) => {
            wheel.accepted = true;
            if (sensorRoot.isScrubbing || sensorRoot.isMovingIsland) return;
            sensorRoot.wheelScrolled(wheel.angleDelta.y);
        }

        // =====================================================================
        // 🚀【手势 1 核心】：全域双击（全胶囊 100% 盲点直接呼出平铺网格）
        // =====================================================================
        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                mouse.accepted = true;
                // 取消单击展开的延迟计时，避免误开大卡片
                singleClickDelayTimer.stop();
                singleClickDelayTimer.pendingExpandAction = null;

                if (typeof Bridge !== "undefined" && Bridge.toggleDesktopGrid) {
                    Bridge.toggleDesktopGrid();
                }
            }
        }

        // 单击：延迟 180ms 展开大卡片（若中途双击则被取消）
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                mouse.accepted = true;
                sensorRoot.requestTuckToggle();
                return;
            }

            if (sensorRoot.wasScrubbingJustNow) {
                sensorRoot.wasScrubbingJustNow = false;
                scrubLockCooldown.stop();
                return;
            }

            if (sensorRoot.isPeeking || sensorRoot.isPassive5S || sensorRoot.isExpanded) return;
            if (sensorRoot.activeTransient === "SEDENTARY" || sensorRoot.activeTransient === "VOICE_INPUT") return;

            // 存入延时动作，等待是否产生第二次点击
            singleClickDelayTimer.pendingExpandAction = function() {
                if (sensorRoot.isCalling) {
                    sensorRoot.requestExpand("media");
                    return;
                }
                if (sensorRoot.activeTransient === "ALERT") {
                    sensorRoot.requestExpand("notification");
                    return;
                }
                sensorRoot.requestExpand("hardware");
            };
            singleClickDelayTimer.restart();
        }
    }
}