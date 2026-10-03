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

    onTargetWChanged: commit()
    onTargetHChanged: commit()
    onIsExpandedChanged: commit()
    onIsCollapsingChanged: commit()

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

        // 🚀 核心黑科技：四周各外扩 2px，彻底避开抗锯齿羽化边缘被 1-bit 遮罩切成狗牙
        var margin = 2

        if (isLargeCard) {
            var effH = Math.max(capsuleItem.height, targetH)
            var effW = Math.max(capsuleItem.width, targetW)
            var pX = Math.max(0, Math.round((rootItem.width - effW) / 2) + ((typeof Config !== "undefined") ? Config.offsetX : 0))
            var pY = Math.round(capsuleItem.y)
            var rList = [{
                x: pX - margin,
                y: pY - margin,
                w: Math.round(effW) + margin * 2,
                h: Math.round(effH) + margin * 2,
                r: Math.round(capsuleItem.radius) + margin
            }]
            Bridge.updateCompositeMask(rList)
            return
        }

        // 常态紧凑态：同样留出 2px 的安全外扩羽化区
        var rectList = []

        rectList.push({
            x: Math.round(capsuleItem.x) - margin,
            y: Math.round(capsuleItem.y) - margin,
            w: Math.round(capsuleItem.width) + margin * 2,
            h: Math.round(capsuleItem.height) + margin * 2,
            r: Math.round(capsuleItem.radius) + margin
        })

        function addBubble(bubble) {
            if (!bubble || !bubble.active || bubble.opacity <= 0.02) return
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
}