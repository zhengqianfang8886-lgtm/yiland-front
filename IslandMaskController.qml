// ==========================================
// 📄 File: IslandMaskController.qml
// 🌟 终极稳妥：全状态物理遮罩 · 彻底消除漏切与小岛消失
// ==========================================
import QtQuick

Item {
    id: maskCtrl

    property var rootItem: null
    property var capsuleItem: null

    property var lofiBubble: null
    property var appsBubble: null
    property var leftMemoryBubble: null
    property var leftBubble: null
    property var hwBubble: null
    property var rightBubble: null
    property var notifBubble: null
    property var customIslands: []

    property bool maskActive: false
    property bool isIslandHidden: false
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isMorphing: false
    property int targetW: 150
    property int targetH: 36

    onIsIslandHiddenChanged: {
        if (!maskActive || typeof Bridge === "undefined") return
        if (isIslandHidden) {
            if (Bridge.setPassthrough) Bridge.setPassthrough()
        } else {
            commit()
        }
    }

    // 🚀【核心修复】：只要小岛是 active 状态，哪怕 opacity 在淡入中，也 100% 加入保护，绝不漏切！
    function getDiscoveredIslands() {
        var list = []
        var seen = ({})

        function registerItem(item) {
            if (!item) return
            if (item === maskCtrl || item === capsuleItem || item === rootItem) return
            if (typeof item.x === "undefined" || typeof item.width === "undefined") return
            if (item.width <= 0 || item.height <= 0) return
            
            // 只要小岛配置是激活的，必须纳入遮罩！只有明确 active===false 才能剔除
            if (item.active !== undefined && !item.active) return

            var key = item.toString()
            if (seen[key]) return
            seen[key] = true
            list.push(item)
        }

        registerItem(lofiBubble)
        registerItem(appsBubble)
        registerItem(leftMemoryBubble)
        registerItem(leftBubble)
        registerItem(hwBubble)
        registerItem(rightBubble)
        registerItem(notifBubble)

        if (customIslands && customIslands.length > 0) {
            for (var c = 0; c < customIslands.length; c++) registerItem(customIslands[c])
        }

        if (rootItem && rootItem.children) {
            for (var i = 0; i < rootItem.children.length; i++) {
                var child = rootItem.children[i]
                if (child && (child.active !== undefined || child.isExpanded !== undefined || child.isSubBubble !== undefined)) {
                    registerItem(child)
                }
            }
        }
        return list
    }

    function computeSafeMaskGeometry(item, isCapsule) {
        if (!item) return null

        var ix = Math.round(item.x)
        var iy = Math.round(item.y)
        var iw = Math.round(item.width)
        var ih = Math.round(item.height)

        // 胶囊展开时赋予目标宽度，防止边缘漏空
        if (isCapsule && capsuleItem.isExpanded) {
            iw = Math.max(iw, capsuleItem.targetWidth)
            ih = Math.max(ih, capsuleItem.targetHeight)
            ix = Math.round((rootItem.width - iw) / 2 + (typeof Config !== "undefined" ? Config.offsetX : 0))
        }

        if (iw <= 0 || ih <= 0) return null

        var padX = isCapsule && capsuleItem.isExpanded ? 10 : 5
        var padY = isCapsule && capsuleItem.isExpanded ? 10 : 4

        var rVal = 17
        if (item.radius !== undefined && item.radius > 0) {
            rVal = Math.round(item.radius)
        } else if (isCapsule) {
            rVal = capsuleItem.isExpanded ? 28 : 17
        } else {
            rVal = Math.round(ih / 2)
        }

        var maskX = Math.max(0, ix - padX)
        var maskY = (iy <= (padY + 2)) ? 0 : Math.max(0, iy - padY)
        var maskW = iw + (ix - maskX) + padX
        var maskH = (iy - maskY) + ih + padY

        return {
            x: maskX,
            y: maskY,
            w: maskW,
            h: maskH,
            r: rVal
        }
    }

    function commit() {
        if (!maskActive || typeof Bridge === "undefined" || !capsuleItem || !rootItem || isIslandHidden) return

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