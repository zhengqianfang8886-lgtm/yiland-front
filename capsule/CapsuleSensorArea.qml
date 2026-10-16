// ==========================================
// 📄 File: capsule/CapsuleSensorArea.qml
// 🌟 毫秒级输入层 (新增常态双击右键直达设置中心)
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

    property bool isScrubbing: false
    property bool isScrubCanceling: false

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

    signal requestTuck()             // 单击右键隐藏
    signal pinnedRestoreRequested()  // 固定恢复常态
    signal pointerExitedCapsule()
    signal pointerEnteredCapsule()
    signal requestSettingsWindow()   // 🚀 呼叫偏好设置窗口

    property bool isPointerPressed: false
    property real pressStartX: 0
    property real pressStartY: 0
    property real lastDragX: 0
    property real dragVelocityX: 0
    property bool isMovingIsland: false
    property bool scrollSessionLocked: false
    property bool wasScrubbingJustNow: false

    // 🚀 右键双击检测定时器
    property int rightClickCount: 0
    Timer {
        id: rightClickTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (sensorRoot.rightClickCount === 1) {
                // 单击右键：如果未在探头态，则执行吸顶隐藏
                if (!sensorRoot.isPeeking) sensorRoot.requestTuck()
            }
            sensorRoot.rightClickCount = 0
        }
    }

    Timer {
        id: hoverDwellTimer
        interval: (typeof Config !== "undefined" && Config.hoverDwellTime !== undefined) ? Config.hoverDwellTime : 240
        repeat: false
        onTriggered: {
            if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return
            if (sensorRoot.isPointerPressed || sensorRoot.isScrubbing || sensorRoot.wasScrubbingJustNow || sensorRoot.isMovingIsland || sensorRoot.isTucked) return

            if (!sensorRoot.scrollSessionLocked && !sensorRoot.isCollapsing && sensorRoot.isPointerHovered && !sensorRoot.isExpanded) {
                if (sensorRoot.isCalling) sensorRoot.requestExpand("media")
                else if (sensorRoot.activeTransient === "ALERT") sensorRoot.requestExpand("notification")
                else if (sensorRoot.activeTransient === "SEDENTARY") return
                else sensorRoot.requestExpand("workspace")
            }
        }
    }

    Timer {
        id: leaveGraceTimer
        interval: 160
        repeat: false
        onTriggered: {
            if (!sensorRoot.isExpanded) return
            if (sensorRoot.isPointerHovered) return
            sensorRoot.startCollapse()
        }
    }

    Timer { id: resetWasScrubbingTimer; interval: 100; onTriggered: sensorRoot.wasScrubbingJustNow = false }
    Timer {
        id: longPressTimer; interval: 180; onTriggered: {
            if (sensorRoot.isPointerPressed && !sensorRoot.isExpanded && !sensorRoot.isCalling && !sensorRoot.isMovingIsland && !sensorRoot.isTucked) {
                sensorRoot.activateScrubbing()
            }
        }
    }

    function lockBriefMorph() { leaveGraceTimer.stop() }
    function cancelCollapse() { leaveGraceTimer.stop() }
    function triggerRequestCollapse() {
        if (sensorRoot.isExpanded && !sensorRoot.isPointerHovered) leaveGraceTimer.restart()
    }
    function triggerImmediateCollapse() {
        if (!sensorRoot.isExpanded) return
        hoverDwellTimer.stop(); leaveGraceTimer.stop()
        sensorRoot.startCollapse()
    }

    function activateScrubbing() {
        hoverDwellTimer.stop(); leaveGraceTimer.stop()
        sensorRoot.isScrubbing = true
        sensorRoot.wasScrubbingJustNow = true
        sensorRoot.isScrubCanceling = false
        sensorRoot.scrubStarted()
    }

    HoverHandler {
        id: globalCapsuleHover
        blocking: false
        enabled: !sensorRoot.isTucked
        onHoveredChanged: {
            if (hovered) {
                leaveGraceTimer.stop()
                sensorRoot.pointerEnteredCapsule()
                if (!sensorRoot.isExpanded && !sensorRoot.isCollapsing && 
                    !sensorRoot.isScrubbing && !sensorRoot.isPointerPressed && !sensorRoot.isTucked) {
                    if (typeof Config === "undefined" || Config.hoverExpandEnabled !== false) {
                        hoverDwellTimer.restart()
                    }
                }
            } else {
                hoverDwellTimer.stop()
                sensorRoot.scrollSessionLocked = false
                sensorRoot.pointerExitedCapsule()
                if (sensorRoot.isExpanded) leaveGraceTimer.restart()
            }
        }
    }

    MouseArea {
        id: hitArea
        anchors.fill: parent
        enabled: !sensorRoot.isExpanded && !sensorRoot.isNoticeActive && !sensorRoot.isTucked
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: sensorRoot.isMovingIsland ? Qt.SizeHorCursor :
                     (sensorRoot.isScrubbing ? (sensorRoot.isScrubCanceling ? Qt.ForbiddenCursor : Qt.SplitHCursor) : Qt.PointingHandCursor)

        onEntered: sensorRoot.pointerEnteredCapsule()
        onExited: sensorRoot.pointerExitedCapsule()

        onPressed: (mouse) => {
            // 🚀【右键多击与还原判定】
            if (mouse.button === Qt.RightButton) {
                mouse.accepted = true
                hoverDwellTimer.stop()
                leaveGraceTimer.stop()

                if (sensorRoot.isPeeking) {
                    sensorRoot.pinnedRestoreRequested()
                    return
                }

                sensorRoot.rightClickCount++
                if (sensorRoot.rightClickCount === 1) {
                    rightClickTimer.restart()
                } else if (sensorRoot.rightClickCount >= 2) {
                    rightClickTimer.stop()
                    sensorRoot.rightClickCount = 0
                    // 🚀 双击右键直接打开设置窗口！
                    sensorRoot.requestSettingsWindow()
                }
                return
            }

            hoverDwellTimer.stop()
            sensorRoot.isPointerPressed = true
            sensorRoot.pressStartX = mouse.x
            sensorRoot.pressStartY = mouse.y
            sensorRoot.lastDragX = mouse.x
            dragVelocityX = 0

            var isModifierHeld = (mouse.modifiers & Qt.AltModifier) || (mouse.modifiers & Qt.MetaModifier)
            if (isModifierHeld || mouse.button === Qt.MiddleButton) {
                sensorRoot.isMovingIsland = true
                return
            }

            if (mouse.button === Qt.LeftButton) {
                longPressTimer.restart()
            }
        }

        onPositionChanged: (mouse) => {
            if (!sensorRoot.isPointerPressed) return

            if (sensorRoot.isMovingIsland) {
                var stepX = mouse.x - sensorRoot.lastDragX
                sensorRoot.dragVelocityX = stepX
                sensorRoot.lastDragX = mouse.x
                sensorRoot.moveOffsetRequested(stepX)
                return
            }

            var adx = Math.abs(mouse.x - sensorRoot.pressStartX)
            var ady = mouse.y - sensorRoot.pressStartY
            if (!sensorRoot.isScrubbing && (adx >= 6 && Math.abs(ady) < 18)) {
                longPressTimer.stop()
                sensorRoot.activateScrubbing()
            }
            if (sensorRoot.isScrubbing) {
                if (ady > 30) sensorRoot.isScrubCanceling = true
                else { sensorRoot.isScrubCanceling = false; sensorRoot.scrubMoved(mouse.x, mouse.y) }
            }
        }

        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) return

            sensorRoot.isPointerPressed = false
            longPressTimer.stop()
            hoverDwellTimer.stop()

            if (sensorRoot.isMovingIsland) {
                sensorRoot.isMovingIsland = false
                sensorRoot.dragFinished(sensorRoot.dragVelocityX)
                return
            }

            if (sensorRoot.isScrubbing) {
                sensorRoot.wasScrubbingJustNow = true
                resetWasScrubbingTimer.restart()
                if (sensorRoot.isScrubCanceling) sensorRoot.scrubCanceled()
                else sensorRoot.scrubCommitted()
                sensorRoot.isScrubbing = false
                sensorRoot.isScrubCanceling = false
            }
        }

        onCanceled: {
            sensorRoot.isPointerPressed = false
            sensorRoot.isMovingIsland = false
            longPressTimer.stop(); hoverDwellTimer.stop()
            if (sensorRoot.isScrubbing) {
                sensorRoot.wasScrubbingJustNow = true
                resetWasScrubbingTimer.restart()
                sensorRoot.isScrubbing = false
                sensorRoot.isScrubCanceling = false
                sensorRoot.scrubCanceled()
            }
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
            if (mouse.button === Qt.RightButton) return

            sensorRoot.pinnedRestoreRequested()

            if (sensorRoot.wasScrubbingJustNow || sensorRoot.isScrubbing || sensorRoot.isMovingIsland || sensorRoot.activeTransient === "SEDENTARY") {
                sensorRoot.wasScrubbingJustNow = false
                return
            }

            if (sensorRoot.isExpanded) return

            hoverDwellTimer.stop(); leaveGraceTimer.stop()
            sensorRoot.scrollSessionLocked = false
            if (sensorRoot.isCalling) { sensorRoot.requestExpand("media"); return }
            if (sensorRoot.activeTransient === "ALERT") { sensorRoot.requestExpand("notification"); return }
            sensorRoot.requestExpand("time")
        }
    }
}