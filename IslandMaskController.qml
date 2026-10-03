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

    // 保留属性以兼容 Island.qml 的绑定调用
    property int targetW: 150
    property int targetH: 36

    // 🚀【核心机制】：只要动效一开始，立刻完全释放系统遮罩！
    onIsExpandedChanged: handleMotionChange()
    onIsCollapsingChanged: handleMotionChange()
    onIsMorphingChanged: handleMotionChange()

    function handleMotionChange() {
        if (!maskActive || typeof Bridge === "undefined") return

        var inMotion = isExpanded || isCollapsing || isMorphing

        if (inMotion) {
            // 动效期间彻底清除剪刀！让 GPU 进行 100% 完整流畅的物理绘制
            settleTimer.stop()
            if (Bridge.clearMask) {
                Bridge.clearMask()
            }
        } else {
            // 动画完全停稳后，等待 80ms 确保 GPU 双缓冲彻底静止，再执行唯一一次精细镂空
            settleTimer.restart()
        }
    }

    Timer {
        id: settleTimer
        interval: 80
        repeat: false
        onTriggered: maskCtrl.commitPreciseMask()
    }

    // 🚀【静止态唯一收束口】：此时所有岛屿都在绝对静止位置，绝不撕裂
    function commitPreciseMask() {
        if (!maskActive || typeof Bridge === "undefined" || !capsuleItem || !rootItem) return
        if (isExpanded || isCollapsing || isMorphing) return

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

        // 2. 所有静止的在场副岛（自动兼容满编与自定义）
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