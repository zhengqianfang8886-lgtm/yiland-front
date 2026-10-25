// ==========================================
// 📄 File: ui/components/capsule/CapsuleSensorArea.qml
// 🌟 纯声明式状态机手势中枢 (修复拖拽松手误触发展开 Bug 版)
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

    // 🚀【核心加固】：拖拽消费锁，防止松手瞬间误触发 onClicked 展开
    property bool wasScrubbingJustNow: false

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

    // 250ms 冷却定时器：确保松手后的点击余震彻底过去
    Timer {
        id: scrubLockCooldown
        interval: 250
        repeat: false
        onTriggered: sensorRoot.wasScrubbingJustNow = false
    }

    HoverHandler {
        id: globalCapsuleHover
        blocking: false
        enabled: !sensorRoot.isTucked && !sensorRoot.isExpanded

        onHoveredChanged: {
            if (hovered) {
                sensorRoot.pointerEnteredCapsule();
                // 如果刚刚结束拖拽，禁止立即进入 HOVERING 导致自动展开
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
            // 🚀 如果刚刚松手，坚决不响应悬停展开
            if (sensorRoot.wasScrubbingJustNow) return;
            if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return;
            if (sensorRoot.isTucked || sensorRoot.isPeeking || sensorRoot.isPassive5S) return;

            if (!sensorRoot.isExpanded) {
                if (sensorRoot.isCalling) sensorRoot.requestExpand("media");
                else if (sensorRoot.activeTransient === "ALERT") sensorRoot.requestExpand("notification");
                else if (sensorRoot.activeTransient === "SEDENTARY" || sensorRoot.activeTransient === "VOICE_INPUT") return;
                else sensorRoot.requestExpand("workspace");
            }
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
            if (mouse.button === Qt.RightButton) {
                mouse.accepted = true;
                return;
            }

            sensorRoot.pressStartX = mouse.x;
            sensorRoot.pressStartY = mouse.y;
            sensorRoot.lastDragX = mouse.x;
            sensorRoot.dragVelocityX = 0;

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
            var ady = mouse.y - sensorRoot.pressStartY;

            // 🚀 水平移动超过 6px，正式锁定为拖拽状态
            if (sensorRoot.state === "PRESSED" && adx >= 6 && Math.abs(ady) < 18) {
                sensorRoot.state = "SCRUBBING";
                sensorRoot.wasScrubbingJustNow = true;
                sensorRoot.scrubStarted();
            }

            if (sensorRoot.state === "SCRUBBING") {
                if (ady > 30) {
                    sensorRoot.isScrubCanceling = true;
                } else {
                    sensorRoot.isScrubCanceling = false;
                    sensorRoot.scrubMoved(mouse.x, mouse.y);
                }
            }
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) return;

            if (sensorRoot.state === "MOVING") {
                sensorRoot.state = "IDLE";
                sensorRoot.dragFinished(sensorRoot.dragVelocityX);
                return;
            }

            if (sensorRoot.state === "SCRUBBING") {
                // 标记刚刚完成了拖拽，并启动冷却倒计时
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

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                sensorRoot.goHomeRequested();
            }
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                mouse.accepted = true;
                sensorRoot.requestTuckToggle();
                return;
            }

            // 🚀【核心拦截】：如果是拖拽松手引发的伴生点击，物理硬阻断，绝不展开！
            if (sensorRoot.wasScrubbingJustNow) {
                sensorRoot.wasScrubbingJustNow = false;
                scrubLockCooldown.stop();
                return;
            }

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

            sensorRoot.requestExpand("hardware");
        }
    }
}