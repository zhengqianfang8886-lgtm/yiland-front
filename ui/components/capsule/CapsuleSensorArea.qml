// ==========================================
// 📄 File: ui/components/capsule/CapsuleSensorArea.qml
// 🌟 纯声明式状态机手势中枢 (放行特态内部交互按钮)
// ==========================================
import QtQuick

Item {
    id: sensorRoot
    anchors.fill: parent

    // 核心外部约束状态
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isCalling: false
    property bool isNoticeActive: false
    property string activeTransient: ""
    property bool isTucked: false
    property bool isPeeking: false
    property bool isPassive5S: false

    // 内部手势动作事实源 (SSOT)
    property bool isScrubbing: false
    property bool isScrubCanceling: false
    property bool isMovingIsland: false

    readonly property bool isPointerHovered: globalCapsuleHover.hovered || hitArea.containsMouse

    // 业务向外信号
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

    HoverHandler {
        id: globalCapsuleHover
        blocking: false
        // 在深度隐藏或已展开时，本层不抢占悬停判断
        enabled: !sensorRoot.isTucked && !sensorRoot.isExpanded

        onHoveredChanged: {
            if (hovered) {
                sensorRoot.pointerEnteredCapsule()
                if (sensorRoot.state === "IDLE" && !sensorRoot.isExpanded && !sensorRoot.isCollapsing) {
                    sensorRoot.state = "HOVERING"
                }
            } else {
                sensorRoot.pointerExitedCapsule()
                if (sensorRoot.state === "HOVERING") {
                    sensorRoot.state = "IDLE"
                }
                // 🚨【核心修复】：严禁在此处调用 sensorRoot.startCollapse()！
                // 展开态的收起由 ExpandedCardView 自带的 cardLeaveGraceTimer（带防抖延时）专门接管，
                // 此处若调用，展开瞬间焦点转移就会被误判为退出胶囊，从而光速收缩并卡死为大黑块。
            }
        }
    }

    onStateChanged: {
        if (state === "HOVERING") {
            if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return
            if (sensorRoot.isTucked || sensorRoot.isPeeking || sensorRoot.isPassive5S) return

            if (!sensorRoot.isExpanded) {
                if (sensorRoot.isCalling) sensorRoot.requestExpand("media")
                else if (sensorRoot.activeTransient === "ALERT") sensorRoot.requestExpand("notification")
                else if (sensorRoot.activeTransient === "SEDENTARY" || sensorRoot.activeTransient === "VOICE_INPUT") return
                else sensorRoot.requestExpand("workspace")
            }
        }
    }

    MouseArea {
        id: hitArea
        anchors.fill: parent
        // 当展开、或处于特态时，禁用小胶囊的全局事件捕获，让下层具体按钮生效
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
                mouse.accepted = true
                return
            }

            sensorRoot.pressStartX = mouse.x
            sensorRoot.pressStartY = mouse.y
            sensorRoot.lastDragX = mouse.x
            sensorRoot.dragVelocityX = 0

            var isModifierHeld = (mouse.modifiers & Qt.AltModifier) || (mouse.modifiers & Qt.MetaModifier)
            if (isModifierHeld || mouse.button === Qt.MiddleButton) {
                sensorRoot.state = "MOVING"
                return
            }

            sensorRoot.state = "PRESSED"
        }

        onPositionChanged: (mouse) => {
            if (sensorRoot.state === "MOVING") {
                var stepX = mouse.x - sensorRoot.lastDragX
                sensorRoot.dragVelocityX = stepX
                sensorRoot.lastDragX = mouse.x
                sensorRoot.moveOffsetRequested(stepX)
                return
            }

            var adx = Math.abs(mouse.x - sensorRoot.pressStartX)
            var ady = mouse.y - sensorRoot.pressStartY

            if (sensorRoot.state === "PRESSED" && adx >= 6 && Math.abs(ady) < 18) {
                sensorRoot.state = "SCRUBBING"
                sensorRoot.scrubStarted()
            }

            if (sensorRoot.state === "SCRUBBING") {
                if (ady > 30) {
                    sensorRoot.isScrubCanceling = true
                } else {
                    sensorRoot.isScrubCanceling = false
                    sensorRoot.scrubMoved(mouse.x, mouse.y)
                }
            }
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) return

            if (sensorRoot.state === "MOVING") {
                sensorRoot.state = "IDLE"
                sensorRoot.dragFinished(sensorRoot.dragVelocityX)
                return
            }

            if (sensorRoot.state === "SCRUBBING") {
                if (sensorRoot.isScrubCanceling) sensorRoot.scrubCanceled()
                else sensorRoot.scrubCommitted()
                sensorRoot.state = "IDLE"
                return
            }

            sensorRoot.state = "IDLE"
        }

        onCanceled: {
            if (sensorRoot.state === "SCRUBBING") {
                sensorRoot.scrubCanceled()
            }
            sensorRoot.state = "IDLE"
        }

        onWheel: (wheel) => {
            wheel.accepted = true
            if (sensorRoot.isScrubbing || sensorRoot.isMovingIsland) return
            sensorRoot.wheelScrolled(wheel.angleDelta.y)
        }

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                sensorRoot.goHomeRequested()
            }
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                mouse.accepted = true
                sensorRoot.requestTuckToggle()
                return
            }

            if (sensorRoot.isPeeking || sensorRoot.isPassive5S || sensorRoot.isExpanded) return
            if (sensorRoot.activeTransient === "SEDENTARY" || sensorRoot.activeTransient === "VOICE_INPUT") return

            if (sensorRoot.isCalling) {
                sensorRoot.requestExpand("media")
                return
            }
            if (sensorRoot.activeTransient === "ALERT") {
                sensorRoot.requestExpand("notification")
                return
            }
            sensorRoot.requestExpand("hardware")
        }
    }
}