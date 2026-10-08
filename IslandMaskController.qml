// ==========================================
// 📄 File: IslandMaskController.qml
// 🌟 60帧节流原子掩模引擎 · 物理隔离边距 · 彻底消除边缘穿模残影完整版
// ==========================================
import QtQuick

Item {
    id: maskCtrl

    property var rootItem: null
    property var capsuleItem: null

    property var lofiBubble: null
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
    
    property bool _updatePending: false

    onIsIslandHiddenChanged: {
        if (!maskActive || typeof Bridge === "undefined") return
        if (isIslandHidden) {
            throttleTimer.stop()
            if (Bridge.setPassthrough) Bridge.setPassthrough()
        } else {
            requestMaskUpdate()
        }
    }

    function getDiscoveredIslands() {
        var list = []
        var seen = ({})

        function registerItem(item) {
            if (!item) return
            if (item === maskCtrl || item === capsuleItem || item === rootItem) return
            if (typeof item.x === "undefined" || typeof item.width === "undefined") return
            if (item.width <= 0 || item.height <= 0) return
            if (item.active !== undefined && !item.active) return
            if (item.visible !== undefined && !item.visible) return

            var key = item.toString()
            if (seen[key]) return
            seen[key] = true
            list.push(item)
        }

        registerItem(lofiBubble)
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

    function requestMaskUpdate() {
        if (!maskActive || typeof Bridge === "undefined" || isIslandHidden) return

        if (!throttleTimer.running) {
            commitPreciseMask()
            throttleTimer.start()
        } else {
            _updatePending = true
        }
    }

    Timer {
        id: throttleTimer
        interval: 16
        repeat: false
        onTriggered: {
            if (_updatePending) {
                _updatePending = false
                commitPreciseMask()
                throttleTimer.start()
            }
        }
    }

    function notifyIslandMoving() { requestMaskUpdate() }
    function commit() { requestMaskUpdate() }

    // 🚀【核心修复】：主胶囊 marginX 从过大的 14px 纠正为安全的 4px，彻底杜绝掩模侵入副岛领地 6px 的月牙穿模！
    function computeSafeMaskGeometry(item, isCapsule) {
        if (!item) return null

        var ix = Math.round(item.x)
        var iy = Math.round(item.y)
        var iw = Math.round(item.width)
        var ih = Math.round(item.height)
        if (iw <= 0 || ih <= 0) return null

        var marginX = isCapsule ? 4 : 8
        var marginY = 4

        return {
            x: ix - marginX,
            y: 0,
            w: iw + marginX * 2,
            h: iy + ih + marginY,
            r: isCapsule ? Math.round(item.radius + marginY) : Math.max(8, Math.round(ih * 0.38))
        }
    }

    function commitPreciseMask() {
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
}