import QtQuick

Item {
    id: maskCtrl

    property var rootItem: null
    property var capsuleItem: null
    property var leftBubble: null
    property var rightBubble: null
    property var notifBubble: null

    // 🚀 重命名为 maskActive，彻底消除与 Item 内建 enabled 属性的冲突
    property bool maskActive: false
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isMorphing: false
    property int targetW: 150
    property int targetH: 36

    Timer {
        id: retractTimer
        interval: 240
        onTriggered: maskCtrl.commit()
    }

    function requestRetract() { retractTimer.restart() }

    function commit() {
        if (!maskActive || typeof Bridge === "undefined" || !capsuleItem || !rootItem) return

        if (isExpanded || isCollapsing || isMorphing || targetW > 300 || targetH > 100) {
            var fullW = 430 + 100, fullH = 240 + 40
            var pX = Math.max(0, Math.round((rootItem.width - fullW) / 2) + ((typeof Config !== "undefined") ? Config.offsetX : 0))
            Bridge.updateMask(pX, 0, Math.min(rootItem.width, Math.round(fullW)), Math.round(fullH))
            return
        }

        var rectList = []
        var padX = 18, padY = 6

        var effectiveW = Math.max(capsuleItem.width, targetW)
        var effectiveH = Math.max(capsuleItem.height, targetH)
        var effectiveX = Math.round((rootItem.width - effectiveW) / 2) + ((typeof Config !== "undefined") ? Config.offsetX : 0)

        rectList.push({
            x: Math.max(0, effectiveX - padX),
            y: Math.max(0, Math.round(capsuleItem.y) - padY),
            w: Math.round(effectiveW) + padX * 2,
            h: Math.round(effectiveH) + padY * 2
        })

        if (leftBubble && leftBubble.active) {
            rectList.push({
                x: Math.max(0, Math.round(leftBubble.x) - padX),
                y: Math.max(0, Math.round(leftBubble.y) - padY),
                w: Math.round(leftBubble.width) + padX * 2,
                h: Math.round(leftBubble.height) + padY * 2
            })
        }

        if (rightBubble && rightBubble.active) {
            rectList.push({
                x: Math.max(0, Math.round(rightBubble.x) - padX),
                y: Math.max(0, Math.round(rightBubble.y) - padY),
                w: Math.round(rightBubble.width) + padX * 2,
                h: Math.round(rightBubble.height) + padY * 2
            })
        }

        if (notifBubble && notifBubble.active) {
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