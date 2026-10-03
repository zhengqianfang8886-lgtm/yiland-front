import QtQuick

Item {
    id: maskCtrl

    property var rootItem: null
    property var capsuleItem: null
    property var leftMemoryBubble: null
    property var leftBubble: null
    property var rightBubble: null
    property var notifBubble: null

    property bool maskActive: false
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isMorphing: false
    property int targetW: 150
    property int targetH: 36

    onTargetWChanged: commit()
    onTargetHChanged: commit()
    onIsExpandedChanged: commit()
    onIsCollapsingChanged: commit()

    // 🚀【核心修复】：在物理形变期间以 60fps 实时刷新输入遮罩，确保点击穿透绝无滞后
    onIsMorphingChanged: {
        if (isMorphing) {
            morphFrameTracker.start()
        } else {
            morphFrameTracker.stop()
            commit()
        }
    }

    Timer {
        id: morphFrameTracker
        interval: 16
        repeat: true
        running: false
        onTriggered: maskCtrl.commit()
    }

    Timer {
        id: retractTimer
        interval: 120
        onTriggered: maskCtrl.commit()
    }

    function requestRetract() { retractTimer.restart() }

    function commit() {
        if (!maskActive || typeof Bridge === "undefined" || !capsuleItem || !rootItem) return

        var isLargeCard = isExpanded || isCollapsing || (capsuleItem.height > 60) || (targetH > 60)

        if (isLargeCard) {
            // 大卡片展开或久坐大弹窗时，按实际几何体生成圆角遮罩
            var effH = Math.max(capsuleItem.height, targetH)
            var effW = Math.max(capsuleItem.width, targetW)
            var pX = Math.max(0, Math.round((rootItem.width - effW) / 2) + ((typeof Config !== "undefined") ? Config.offsetX : 0))
            var pY = Math.round(capsuleItem.y)
            var rList = [{
                x: pX,
                y: pY,
                w: Math.round(effW),
                h: Math.round(effH),
                r: Math.round(capsuleItem.radius)
            }]
            Bridge.updateCompositeMask(rList)
            return
        }

        // 常态紧凑态：1:1 严格贴合真实几何曲率，零多余外扩
        var rectList = []

        rectList.push({
            x: Math.round(capsuleItem.x),
            y: Math.round(capsuleItem.y),
            w: Math.round(capsuleItem.width),
            h: Math.round(capsuleItem.height),
            r: Math.round(capsuleItem.radius)
        })

        function addBubble(bubble) {
            if (!bubble || !bubble.active || bubble.opacity <= 0.02) return
            rectList.push({
                x: Math.round(bubble.x),
                y: Math.round(bubble.y),
                w: Math.round(bubble.width),
                h: Math.round(bubble.height),
                r: Math.round(bubble.radius)
            })
        }

        addBubble(leftMemoryBubble)
        addBubble(leftBubble)
        addBubble(rightBubble)
        addBubble(notifBubble)

        Bridge.updateCompositeMask(rectList)
    }
}