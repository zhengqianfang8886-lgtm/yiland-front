// ==========================================
// 📄 File: capsule/CapsuleSensorArea.qml
// 🌟 修复松手误触展开Bug · 全局事件隔离防误收缩完整版
// ==========================================
import QtQuick

Item {
    id: sensorRoot
    anchors.fill: parent

    // 🚀 核心状态：接收来自最外层的全局悬停守卫状态
    property bool isGlobalHovered: false

    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isCalling: false
    property bool isNoticeActive: false
    property string activeTransient: ""
    property bool subBubbleInteracting: false

    property bool isScrubbing: false
    property bool isScrubCanceling: false

    // 🚀 核心修复：融合全局守卫状态，哪怕内部子按钮抢走 MouseArea 的 hover，这里依然为 true
    readonly property bool isPointerHovered: isGlobalHovered || capsuleHoverHandler.hovered || hitArea.containsMouse

    signal requestExpand(string tabName)
    signal requestCollapse()
    signal startCollapse()
    signal requestHideIsland()
    signal wheelScrolled(int deltaY)

    signal scrubStarted()
    signal scrubMoved(real mouseX, real mouseY)
    signal scrubCommitted()
    signal scrubCanceled()

    property bool isPointerPressed: false
    property real pressStartX: 0
    property real pressStartY: 0
    property bool scrollSessionLocked: false
    property bool morphBriefLocked: false

    property bool wasScrubbingJustNow: false

    Timer {
        id: resetWasScrubbingTimer
        interval: 100
        repeat: false
        onTriggered: sensorRoot.wasScrubbingJustNow = false
    }

    Timer {
        id: longPressTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (sensorRoot.isPointerPressed && !sensorRoot.isExpanded && !sensorRoot.isCalling) {
                sensorRoot.activateScrubbing()
            }
        }
    }

    Timer {
        id: hoverDwellTimer
        interval: (typeof Config !== "undefined" && Config.hoverDwellTime !== undefined) ? Config.hoverDwellTime : 240
        onTriggered: {
            if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return
            if (sensorRoot.isPointerPressed || sensorRoot.isScrubbing || sensorRoot.wasScrubbingJustNow) return

            if (!sensorRoot.scrollSessionLocked && !sensorRoot.subBubbleInteracting && !sensorRoot.isCollapsing && sensorRoot.isPointerHovered && !sensorRoot.isExpanded) {
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
            // 🚀 这里会检查 isPointerHovered，由于注入了全局的 isGlobalHovered，进入卡片内部按钮绝不会触发收缩
            if (sensorRoot.isExpanded && !sensorRoot.morphBriefLocked && !sensorRoot.isPointerHovered) {
                sensorRoot.startCollapse()
            }
        }
    }

    Timer {
        id: morphBriefTimer
        interval: 260
        repeat: false
        onTriggered: {
            sensorRoot.morphBriefLocked = false
            if (sensorRoot.isExpanded && !sensorRoot.isPointerHovered) {
                sensorRoot.requestCollapse()
            }
        }
    }

    function lockBriefMorph() {
        leaveGraceTimer.stop()
        sensorRoot.morphBriefLocked = true
        morphBriefTimer.restart()
    }

    function cancelCollapse() {
        leaveGraceTimer.stop()
    }

    function triggerRequestCollapse() {
        if (sensorRoot.isExpanded && !sensorRoot.morphBriefLocked) {
            leaveGraceTimer.restart()
        }
    }

    function triggerImmediateCollapse() {
        if (!sensorRoot.isExpanded) return
        sensorRoot.morphBriefLocked = false
        morphBriefTimer.stop()
        hoverDwellTimer.stop()
        leaveGraceTimer.stop()
        sensorRoot.startCollapse()
    }

    function activateScrubbing() {
        hoverDwellTimer.stop()
        leaveGraceTimer.stop()
        sensorRoot.isScrubbing = true
        sensorRoot.wasScrubbingJustNow = true
        sensorRoot.isScrubCanceling = false
        sensorRoot.scrubStarted()
    }

    HoverHandler {
        id: capsuleHoverHandler
        onHoveredChanged: {
            if (hovered) {
                sensorRoot.morphBriefLocked = false
                morphBriefTimer.stop()
                leaveGraceTimer.stop()
                if (!sensorRoot.isExpanded && !sensorRoot.isCollapsing && !sensorRoot.subBubbleInteracting && !sensorRoot.isScrubbing && !sensorRoot.isPointerPressed) {
                    if (typeof Config === "undefined" || Config.hoverExpandEnabled !== false) {
                        hoverDwellTimer.restart()
                    }
                }
            } else {
                hoverDwellTimer.stop()
                sensorRoot.scrollSessionLocked = false
                if (sensorRoot.isExpanded) {
                    sensorRoot.triggerRequestCollapse()
                }
            }
        }
    }

    MouseArea {
        id: hitArea
        anchors.fill: parent
        z: (sensorRoot.isExpanded || sensorRoot.isNoticeActive) ? -1 : 1
        hoverEnabled: true

        acceptedButtons: sensorRoot.isExpanded ? Qt.NoButton : (Qt.LeftButton | Qt.RightButton)
        cursorShape: sensorRoot.isScrubbing ? (sensorRoot.isScrubCanceling ? Qt.ForbiddenCursor : Qt.SplitHCursor) : (sensorRoot.isExpanded ? Qt.ArrowCursor : Qt.PointingHandCursor)

        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                hoverDwellTimer.stop()
                sensorRoot.isPointerPressed = true
                sensorRoot.pressStartX = mouse.x
                sensorRoot.pressStartY = mouse.y
                longPressTimer.restart()
            }
        }

        onPositionChanged: (mouse) => {
            if (!sensorRoot.isPointerPressed) return

            var dx = Math.abs(mouse.x - sensorRoot.pressStartX)
            var dy = mouse.y - sensorRoot.pressStartY

            if (!sensorRoot.isScrubbing) {
                if (dx >= 6 && Math.abs(dy) < 18) {
                    longPressTimer.stop()
                    sensorRoot.activateScrubbing()
                }
            }

            if (sensorRoot.isScrubbing) {
                if (dy > 30) {
                    sensorRoot.isScrubCanceling = true
                } else {
                    sensorRoot.isScrubCanceling = false
                    sensorRoot.scrubMoved(mouse.x, mouse.y)
                }
            }
        }

        onReleased: (mouse) => {
            sensorRoot.isPointerPressed = false
            longPressTimer.stop()
            hoverDwellTimer.stop()

            if (sensorRoot.isScrubbing) {
                sensorRoot.wasScrubbingJustNow = true
                resetWasScrubbingTimer.restart()

                if (sensorRoot.isScrubCanceling) {
                    sensorRoot.scrubCanceled()
                } else {
                    sensorRoot.scrubCommitted()
                }

                sensorRoot.isScrubbing = false
                sensorRoot.isScrubCanceling = false
            }
        }

        onCanceled: {
            sensorRoot.isPointerPressed = false
            longPressTimer.stop()
            hoverDwellTimer.stop()
            if (sensorRoot.isScrubbing) {
                sensorRoot.wasScrubbingJustNow = true
                resetWasScrubbingTimer.restart()
                sensorRoot.isScrubbing = false
                sensorRoot.isScrubCanceling = false
                sensorRoot.scrubCanceled()
            }
        }

        onEntered: {
            leaveGraceTimer.stop()
            sensorRoot.scrollSessionLocked = false
            if (!sensorRoot.isExpanded && !sensorRoot.isCollapsing && !sensorRoot.subBubbleInteracting && !sensorRoot.isScrubbing && !sensorRoot.isPointerPressed) {
                if (typeof Config === "undefined" || Config.hoverExpandEnabled !== false) {
                    hoverDwellTimer.restart()
                }
            }
        }

        onExited: {
            hoverDwellTimer.stop()
            sensorRoot.scrollSessionLocked = false
            sensorRoot.triggerRequestCollapse()
        }

        onWheel: (wheel) => {
            wheel.accepted = true
            if (sensorRoot.isScrubbing) return
            sensorRoot.wheelScrolled(wheel.angleDelta.y)
        }

        onClicked: (mouse) => {
            if (sensorRoot.wasScrubbingJustNow || sensorRoot.isScrubbing || sensorRoot.activeTransient === "SEDENTARY") {
                sensorRoot.wasScrubbingJustNow = false
                return
            }

            if (mouse.button === Qt.RightButton) {
                hoverDwellTimer.stop()
                leaveGraceTimer.stop()
                sensorRoot.requestHideIsland()
                return
            }

            if (sensorRoot.isExpanded) return

            hoverDwellTimer.stop()
            leaveGraceTimer.stop()
            sensorRoot.scrollSessionLocked = false

            if (sensorRoot.isCalling) { sensorRoot.requestExpand("media"); return }
            if (sensorRoot.activeTransient === "ALERT") { sensorRoot.requestExpand("notification"); return }
            sensorRoot.requestExpand("time")
        }
    }
}