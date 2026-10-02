import QtQuick

Item {
    id: maskCtrl

    property var rootItem: null
    property var capsuleItem: null
    property var leftBubble: null
    property var rightBubble: null
    property var notifBubble: null

    property bool maskActive: false
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isMorphing: false
    property int targetW: 150
    property int targetH: 36

    Timer {
        id: retractTimer
        interval: 220
        onTriggered: maskCtrl.commit()
    }

    function requestRetract() { retractTimer.restart() }

    function commit() {
        if (!maskActive || typeof Bridge === "undefined" || !capsuleItem || !rootItem) return

        var isLargeSize = (capsuleItem.height > 48) || (targetH > 50) || (capsuleItem.width > 220) || (targetW > 220)
        if (isExpanded || isCollapsing || isMorphing || isLargeSize) {
            // 🚀 核心修复：限制在实际窗口高度内（270px），避免溢出导致窗口系统丢弃事件
            var fullW = Math.min(rootItem.width, 430 + 100)
            var fullH = Math.min(rootItem.height, 240 + 24)
            var pX = Math.max(0, Math.round((rootItem.width - fullW) / 2) + ((typeof Config !== "undefined") ? Config.offsetX : 0))
            Bridge.updateMask(pX, 0, Math.round(fullW), Math.round(fullH))
            return
        }

        var rectList = []
        var padX = 36, padY = 10

        var effectiveW = Math.max(capsuleItem.width, targetW)
        var effectiveH = Math.max(capsuleItem.height, targetH)
        var effectiveX = Math.round((rootItem.width - effectiveW) / 2) + ((typeof Config !== "undefined") ? Config.offsetX : 0)

        rectList.push({
            x: Math.max(0, effectiveX - padX),
            y: Math.max(0, Math.round(capsuleItem.y) - padY),
            w: Math.round(effectiveW) + padX * 2,
            h: Math.round(effectiveH) + padY * 2
        })

        if (leftBubble && (leftBubble.active || leftBubble.opacity > 0.02)) {
            rectList.push({
                x: Math.max(0, Math.round(leftBubble.x) - padX),
                y: Math.max(0, Math.round(leftBubble.y) - padY),
                w: Math.round(leftBubble.width) + padX * 2,
                h: Math.round(leftBubble.height) + padY * 2
            })
        }

        if (rightBubble && (rightBubble.active || rightBubble.opacity > 0.02)) {
            rectList.push({
                x: Math.max(0, Math.round(rightBubble.x) - padX),
                y: Math.max(0, Math.round(rightBubble.y) - padY),
                w: Math.round(rightBubble.width) + padX * 2,
                h: Math.round(rightBubble.height) + padY * 2
            })
        }

        if (notifBubble && (notifBubble.active || notifBubble.opacity > 0.02)) {
            rectList.push({
                x: Math.max(0, Math.round(notifBubble.x) - padX),
                y: Math.max(0, Math.round(notifBubble.y) - padY),
                w: Math.round(notifBubble.width) + padX * 2,
                h: Math.round(notifBubble.height) + padY * 2
            })
        }

        Bridge.updateCompositeMask(rectList)
    }
}