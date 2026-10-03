// ==========================================
// 📄 File: IslandMaskController.qml (全面防切终极版)
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

    property int targetW: 150
    property int targetH: 36

    // 1. 主胶囊动效监听
    onIsExpandedChanged: handleMotionChange()
    onIsCollapsingChanged: handleMotionChange()
    onIsMorphingChanged: handleMotionChange()

    function handleMotionChange() {
        if (!maskActive || typeof Bridge === "undefined") return

        var inMotion = isExpanded || isCollapsing || isMorphing

        if (inMotion) {
            settleTimer.stop()
            if (Bridge.clearMask) Bridge.clearMask()
        } else {
            settleTimer.restart()
        }
    }

    // 🚀【核心新增】：副岛平移与退场防切中枢
    // 只要有任何副岛出现、消失或滑移，立即放开遮罩，等滑行彻底结束再收紧！
    function notifyIslandMoving() {
        if (!maskActive || typeof Bridge === "undefined") return

        // 立即清除遮罩，让副岛在无剪刀干扰的全透明 GPU 画布上平滑滑行
        if (Bridge.clearMask) Bridge.clearMask()
        // 180ms 刚好覆盖副岛 150ms 的滑动动画 + 30ms 缓冲区
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

    // 🚀【绝对静止态精准镂空】：此时主岛和所有副岛都停稳了，绝不产生切面
    function commitPreciseMask() {
        if (!maskActive || typeof Bridge === "undefined" || !capsuleItem || !rootItem) return
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
        handleMotionChange()
    }
}