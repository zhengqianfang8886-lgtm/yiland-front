// ==========================================
// 📄 File: IslandMaskController.qml
// 🌟 物理遮罩动态包络引擎 (支持 Peek 偷瞄无裁切穿透)
// ==========================================
import QtQuick

Item {
    id: maskCtrl

    property var rootItem: null
    property var capsuleItem: null

    property var leftBay: null
    property var rightBay: null

    property bool maskActive: false
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isMorphing: false
    property int targetW: 150
    property int targetH: 36

    function getDiscoveredIslands() {
        var list = []
        // 仅在真实静止隐藏吸顶时（非 Peek 偷瞄中），副岛才不进入遮罩
        if (capsuleItem && capsuleItem.isActuallyTucked && !capsuleItem.isMorphing) {
            return list
        }
        if (leftBay && leftBay.getActiveItems) {
            var lItems = leftBay.getActiveItems()
            for (var i = 0; i < lItems.length; i++) list.push(lItems[i])
        }
        if (rightBay && rightBay.getActiveItems) {
            var rItems = rightBay.getActiveItems()
            for (var j = 0; j < rItems.length; j++) list.push(rItems[j])
        }
        return list
    }

    function computeSafeMaskGeometry(item, isCapsule) {
        if (!item) return null

        // -------------------------------------------------------------
        // 副岛小岛
        // -------------------------------------------------------------
        if (!isCapsule) {
            var ix = Math.round(item.x)
            var iy = Math.max(0, Math.round(item.y))
            var iw = Math.round(item.width)
            var ih = Math.round(item.height)

            if (iw <= 0 || ih <= 0) return null

            var padX = 18
            var padY = 6
            var maskX = Math.max(0, ix - padX)
            var maskY = 0
            var targetBottom = Math.max(iy + ih + padY, 48)
            var maskW = iw + (ix - maskX) + padX
            var maskH = targetBottom - maskY
            var rVal = (item.radius !== undefined && item.radius > 0) ? Math.round(item.radius) : Math.round(ih / 2)

            return {
                x: maskX,
                y: maskY,
                w: maskW,
                h: maskH,
                r: rVal
            }
        }

        // -------------------------------------------------------------
        // 主胶囊
        // -------------------------------------------------------------
        // 1. 真实静止吸顶隐藏态
        if (capsuleItem.isActuallyTucked && !capsuleItem.isMorphing) {
            var tw = capsuleItem.targetWidth || 140
            var tx = Math.round((rootItem.width - tw) / 2 + (typeof Config !== "undefined" ? Config.offsetX : 0))
            return {
                x: Math.max(0, tx - 2),
                y: 0,
                w: tw + 4,
                h: 6.0,
                r: 3
            }
        }

        // 2. 展开卡片态
        if (capsuleItem.isExpanded) {
            var expW = Math.max(item.width, capsuleItem.targetWidth)
            var expH = Math.max(item.height, capsuleItem.targetHeight)
            var expX = Math.round((rootItem.width - expW) / 2 + (typeof Config !== "undefined" ? Config.offsetX : 0))
            var expPad = 10
            return {
                x: Math.max(0, expX - expPad),
                y: 0,
                w: expW + expPad * 2,
                h: expH + expPad,
                r: 28
            }
        }

        // 3. 常态、Peek 偷瞄中、以及下落过渡中 (舞台先行)
        var curW = Math.max(item.width, capsuleItem.targetWidth)
        var curH = Math.max(item.height, capsuleItem.targetHeight)
        var normalMargin = (typeof capsuleItem.normalTopMargin !== "undefined") ? capsuleItem.normalTopMargin : 8

        var capMaskH = normalMargin + curH + 14
        var capMaskW = curW + 16
        var capMaskX = Math.round((rootItem.width - capMaskW) / 2 + (typeof Config !== "undefined" ? Config.offsetX : 0))

        return {
            x: Math.max(0, capMaskX),
            y: 0,
            w: capMaskW,
            h: capMaskH,
            r: 17
        }
    }

    function commit() {
        if (!maskActive || typeof Bridge === "undefined" || !capsuleItem || !rootItem) return

        var rectList = []
        var capMask = computeSafeMaskGeometry(capsuleItem, true)
        if (capMask) rectList.push(capMask)

        var dynamicIslands = getDiscoveredIslands()
        for (var i = 0; i < dynamicIslands.length; i++) {
            var islandMask = computeSafeMaskGeometry(dynamicIslands[i], false)
            if (islandMask) rectList.push(islandMask)
        }

        Bridge.updateCompositeMask(rectList)
    }

    function requestMaskUpdate() {
        commit()
    }
}