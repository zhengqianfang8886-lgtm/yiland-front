// ==========================================
// 📄 File: IslandMaskController.qml (全面防切与绝对穿透终极版)
// ==========================================
import QtQuick

Item {
    id: maskCtrl

    property var rootItem: null
    property var capsuleItem: null
    property var leftMemoryBubble: null
    property var leftBubble: null
    property var hwBubble: null
    property var rightBubble: null
    property var notifBubble: null

    property bool maskActive: false
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isMorphing: false

    // 🚀 响应全岛隐藏状态
    property bool isIslandHidden: false
    onIsIslandHiddenChanged: handleHideState()

    property int targetW: 150
    property int targetH: 36

    onIsExpandedChanged: handleMotionChange()
    onIsCollapsingChanged: handleMotionChange()
    onIsMorphingChanged: handleMotionChange()

    function handleHideState() {
        if (!maskActive || typeof Bridge === "undefined") return
        if (isIslandHidden) {
            settleTimer.stop()
            islandSlideTimer.stop()
            // 🚀 隐藏的一瞬间：立刻通知底层设置离屏穿透遮罩，零延迟放行鼠标点击
            if (Bridge.setPassthrough) {
                Bridge.setPassthrough()
            } else if (Bridge.updateCompositeMask) {
                Bridge.updateCompositeMask([])
            }
        } else {
            settleTimer.restart()
        }
    }

    function handleMotionChange() {
        if (!maskActive || typeof Bridge === "undefined") return
        if (isIslandHidden || (rootItem && rootItem.isIslandHidden)) {
            if (Bridge.setPassthrough) Bridge.setPassthrough()
            return
        }

        var inMotion = isExpanded || isCollapsing || isMorphing

        if (inMotion) {
            settleTimer.stop()
            if (Bridge.clearMask) Bridge.clearMask()
        } else {
            settleTimer.restart()
        }
    }

    function notifyIslandMoving() {
        if (!maskActive || typeof Bridge === "undefined") return
        if (isIslandHidden || (rootItem && rootItem.isIslandHidden)) {
            if (Bridge.setPassthrough) Bridge.setPassthrough()
            return
        }

        if (Bridge.clearMask) Bridge.clearMask()
        islandSlideTimer.restart()
    }

    Timer {
        id: islandSlideTimer
        interval: 180
        repeat: false
        onTriggered: maskCtrl.commitPreciseMask()
    }

    Timer {
        id: settleTimer
        interval: 80
        repeat: false
        onTriggered: maskCtrl.commitPreciseMask()
    }

    // 绝对静止态精准镂空
    function commitPreciseMask() {
        if (!maskActive || typeof Bridge === "undefined" || !capsuleItem || !rootItem) return
        
        // 🚀 处于隐藏状态时，永远保持 100% 绝对穿透
        if (isIslandHidden || (rootItem && rootItem.isIslandHidden)) {
            if (Bridge.setPassthrough) Bridge.setPassthrough()
            else Bridge.updateCompositeMask([])
            return
        }

        if (isExpanded || isCollapsing || isMorphing || islandSlideTimer.running) return

        var margin = 2
        var rectList = []

        // 1. 中间主胶囊
        rectList.push({
            x: Math.round(capsuleItem.x) - margin,
            y: Math.round(capsuleItem.y) - margin,
            w: Math.round(capsuleItem.width) + margin * 2,
            h: Math.round(capsuleItem.height) + margin * 2,
            r: Math.round(capsuleItem.radius) + margin
        })

        // 2. 所有处于静止状态的副岛
        function addBubble(bubble) {
            if (!bubble || !bubble.active || bubble.opacity < 0.2) return
            rectList.push({
                x: Math.round(bubble.x) - margin,
                y: Math.round(bubble.y) - margin,
                w: Math.round(bubble.width) + margin * 2,
                h: Math.round(bubble.height) + margin * 2,
                r: Math.round(bubble.radius) + margin
            })
        }

        addBubble(leftMemoryBubble)
        addBubble(leftBubble)
        addBubble(hwBubble)
        addBubble(rightBubble)
        addBubble(notifBubble)

        Bridge.updateCompositeMask(rectList)
    }

    function commit() {
        if (isIslandHidden || (rootItem && rootItem.isIslandHidden)) {
            handleHideState()
        } else {
            handleMotionChange()
        }
    }
}