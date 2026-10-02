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
        interval: 320 // 确保长于副岛淡出动画（280ms）
        onTriggered: maskCtrl.commit()
    }

    function requestRetract() { retractTimer.restart() }

    function commit() {
        if (!maskActive || typeof Bridge === "undefined" || !capsuleItem || !rootItem) return

        // 展开状态直接给予全尺寸充裕包围盒
        if (isExpanded || isCollapsing || isMorphing || targetW > 300 || targetH > 100) {
            var fullW = 430 + 120, fullH = 240 + 50
            var pX = Math.max(0, Math.round((rootItem.width - fullW) / 2) + ((typeof Config !== "undefined") ? Config.offsetX : 0))
            Bridge.updateMask(pX, 0, Math.min(rootItem.width, Math.round(fullW)), Math.round(fullH))
            return
        }

        var rectList = []
        // 🚀 安全冗余垫片：padX 设为 36px，容纳果冻 Overshoot 弹性回弹，杜绝切边！
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

        // 只要副岛仍在屏幕上有渲染痕迹（opacity > 0.02），就必须保留遮罩，不提前截断
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