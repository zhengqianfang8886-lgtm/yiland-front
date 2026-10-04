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

    property bool isIslandHidden: false
    onIsIslandHiddenChanged: handleHideState()

    property int targetW: 150
    property int targetH: 36

    // 🚀 核心修复：副岛（如硬件控制岛）展开悬浮时，立即清除二进制遮罩，呈现抗锯齿平滑边缘
    readonly property bool isAnySubExpanded: (hwBubble && hwBubble.isExpanded)

    onIsExpandedChanged: handleMotionChange()
    onIsCollapsingChanged: handleMotionChange()
    onIsMorphingChanged: handleMotionChange()
    onIsAnySubExpandedChanged: handleMotionChange()

    function handleHideState() {
        if (!maskActive || typeof Bridge === "undefined") return
        if (isIslandHidden) {
            settleTimer.stop()
            islandSlideTimer.stop()
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

        // 🚀 当主岛或控制中心副岛处于展开状态时，完全放开遮罩
        var inMotion = isExpanded || isCollapsing || isMorphing || isAnySubExpanded

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

    function commitPreciseMask() {
        if (!maskActive || typeof Bridge === "undefined" || !capsuleItem || !rootItem) return
        
        if (isIslandHidden || (rootItem && rootItem.isIslandHidden)) {
            if (Bridge.setPassthrough) Bridge.setPassthrough()
            else Bridge.updateCompositeMask([])
            return
        }

        if (isExpanded || isCollapsing || isMorphing || isAnySubExpanded || islandSlideTimer.running) return

        var margin = 2
        var rectList = []

        rectList.push({
            x: Math.round(capsuleItem.x) - margin,
            y: Math.round(capsuleItem.y) - margin,
            w: Math.round(capsuleItem.width) + margin * 2,
            h: Math.round(capsuleItem.height) + margin * 2,
            r: Math.round(capsuleItem.radius) + margin
        })

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