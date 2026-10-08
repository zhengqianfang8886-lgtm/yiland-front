// ==========================================
// 📄 File: capsule/CapsuleSensorArea.qml
// 🌟 顶层穿透单向闭环感知 · 移入常驻 · 移出准时收回
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
    property bool subBubbleInteracting: false

    property bool isScrubbing: false
    property bool isScrubCanceling: false

    // 🚀【唯一真理源】：处于 z: 20 的 HoverHandler 直接判定，无任何多余中间变量干扰
    readonly property bool isPointerHovered: globalCapsuleHover.hovered

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
    property bool wasScrubbingJustNow: false

    function logT(tag, msg) {
        if (typeof Bridge !== "undefined" && Bridge.traceLog) {
            Bridge.traceLog(tag, msg)
        }
    }

    // 1. 悬停展开定时器（未展开时 240ms 触发）
    Timer {
        id: hoverDwellTimer
        interval: (typeof Config !== "undefined" && Config.hoverDwellTime !== undefined) ? Config.hoverDwellTime : 240
        repeat: false
        onTriggered: {
            if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return
            if (sensorRoot.isPointerPressed || sensorRoot.isScrubbing || sensorRoot.wasScrubbingJustNow) return

            if (!sensorRoot.scrollSessionLocked && !sensorRoot.subBubbleInteracting && 
                !sensorRoot.isCollapsing && sensorRoot.isPointerHovered && !sensorRoot.isExpanded) {
                sensorRoot.logT("TRACE-EXPAND", "⏱️ hoverDwellTimer 到期，触发主胶囊展开")
                if (sensorRoot.isCalling) sensorRoot.requestExpand("media")
                else if (sensorRoot.activeTransient === "ALERT") sensorRoot.requestExpand("notification")
                else if (sensorRoot.activeTransient === "SEDENTARY") return
                else sensorRoot.requestExpand("workspace")
            }
        }
    }

    // 🚀【跟手修复】：由 380ms 降至 160ms，鼠标刚滑出卡片边缘便立即无感触发收拢
    Timer {
        id: leaveGraceTimer
        interval: 160
        repeat: false
        onTriggered: {
            if (!sensorRoot.isExpanded) return

            if (sensorRoot.isPointerHovered) {
                return
            }

            sensorRoot.startCollapse()
        }
    }

    Timer { id: resetWasScrubbingTimer; interval: 100; onTriggered: sensorRoot.wasScrubbingJustNow = false }
    Timer {
        id: longPressTimer; interval: 180; onTriggered: {
            if (sensorRoot.isPointerPressed && !sensorRoot.isExpanded && !sensorRoot.isCalling) sensorRoot.activateScrubbing()
        }
    }

    function lockBriefMorph() {
        leaveGraceTimer.stop()
    }

    function cancelCollapse() {
        leaveGraceTimer.stop()
    }

    function triggerRequestCollapse() {
        if (sensorRoot.isExpanded && !sensorRoot.isPointerHovered) {
            leaveGraceTimer.restart()
        }
    }

    function triggerImmediateCollapse() {
        if (!sensorRoot.isExpanded) return
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

    // 🚀【核心机制】：最高层级 (z: 20) 纯观察指针处理器，不拦截点击，精准感应进出
    HoverHandler {
        id: globalCapsuleHover
        blocking: false
        onHoveredChanged: {
            sensorRoot.logT("TRACE-HOVER", "Capsule Hover 变化 -> hovered: " + hovered + " (isExpanded=" + sensorRoot.isExpanded + ")")
            if (hovered) {
                // 鼠标移入：立即终止任何收缩企图！
                leaveGraceTimer.stop()

                if (!sensorRoot.isExpanded && !sensorRoot.isCollapsing && 
                    !sensorRoot.subBubbleInteracting && !sensorRoot.isScrubbing && !sensorRoot.isPointerPressed) {
                    if (typeof Config === "undefined" || Config.hoverExpandEnabled !== false) {
                        hoverDwellTimer.restart()
                    }
                }
            } else {
                // 鼠标移出：停止展开计时，启动离开收回倒计时！
                hoverDwellTimer.stop()
                sensorRoot.scrollSessionLocked = false

                if (sensorRoot.isExpanded) {
                    sensorRoot.logT("TRACE-COLLAPSE", "🚪 鼠标移出胶囊外框，启动 380ms 收缩倒计时！")
                    leaveGraceTimer.restart()
                }
            }
        }
    }

    // 常态专用手势区（展开后完全禁用，绝不阻挡卡片内任何按钮或输入框）
    MouseArea {
        id: hitArea
        anchors.fill: parent
        enabled: !sensorRoot.isExpanded && !sensorRoot.isNoticeActive
        hoverEnabled: false
        cursorShape: sensorRoot.isScrubbing ? (sensorRoot.isScrubCanceling ? Qt.ForbiddenCursor : Qt.SplitHCursor) : Qt.PointingHandCursor

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
            if (!sensorRoot.isScrubbing && (dx >= 6 && Math.abs(dy) < 18)) {
                longPressTimer.stop()
                sensorRoot.activateScrubbing()
            }
            if (sensorRoot.isScrubbing) {
                if (dy > 30) sensorRoot.isScrubCanceling = true
                else { sensorRoot.isScrubCanceling = false; sensorRoot.scrubMoved(mouse.x, mouse.y) }
            }
        }

        onReleased: (mouse) => {
            sensorRoot.isPointerPressed = false
            longPressTimer.stop()
            hoverDwellTimer.stop()
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