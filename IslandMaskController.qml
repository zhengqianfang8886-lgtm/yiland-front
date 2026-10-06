// ==========================================
// 📄 File: IslandMaskController.qml
// 🌟 物理原子掩模替换 · 绝不闪黑框 · 毫秒级跟手无截断版
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

    property var customIslands: []

    property bool maskActive: false
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isMorphing: false

    property bool isIslandHidden: false
    onIsIslandHiddenChanged: handleHideState()

    property int targetW: 150
    property int targetH: 36

    function getDiscoveredIslands() {
        var list = []
        var seen = ({})

        function registerItem(item) {
            if (!item) return
            if (item === maskCtrl || item === capsuleItem || item === rootItem) return
            if (typeof item.x === "undefined" || typeof item.width === "undefined") return
            if (item.width <= 0 || item.height <= 0) return
            if (item.active !== undefined && !item.active) return
            if (item.opacity !== undefined && item.opacity < 0.1) return

            var key = item.toString()
            if (seen[key]) return
            seen[key] = true
            list.push(item)
        }

        registerItem(leftMemoryBubble)
        registerItem(leftBubble)
        registerItem(hwBubble)
        registerItem(rightBubble)
        registerItem(notifBubble)

        if (customIslands && customIslands.length > 0) {
            for (var c = 0; c < customIslands.length; c++) {
                registerItem(customIslands[c])
            }
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

    function checkAnySubExpanded() {
        var islands = getDiscoveredIslands()
        for (var i = 0; i < islands.length; i++) {
            if (islands[i] && islands[i].isExpanded) return true
        }
        return false
    }

    readonly property bool isAnySubExpanded: checkAnySubExpanded()

    onIsExpandedChanged: handleMotionChange()
    onIsCollapsingChanged: handleMotionChange()
    onIsMorphingChanged: handleMotionChange()
    onIsAnySubExpandedChanged: handleMotionChange()

    Timer {
        id: passthroughTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (isIslandHidden && typeof Bridge !== "undefined") {
                if (Bridge.setPassthrough) Bridge.setPassthrough()
                else Bridge.updateCompositeMask([])
            }
        }
    }

    function handleHideState() {
        if (!maskActive || typeof Bridge === "undefined") return
        if (isIslandHidden) {
            settleTimer.stop()
            islandSlideTimer.stop()
            if (Bridge.clearMask) Bridge.clearMask()
            passthroughTimer.restart()
        } else {
            passthroughTimer.stop()
            islandSlideTimer.interval = 35
            islandSlideTimer.restart()
        }
    }

    function handleMotionChange() {
        if (!maskActive || typeof Bridge === "undefined") return
        if (isIslandHidden || (rootItem && rootItem.isIslandHidden)) return

        var inMotion = isExpanded || isCollapsing || isMorphing || checkAnySubExpanded()

        if (inMotion) {
            settleTimer.stop()
            if (isExpanded || isCollapsing) {
                if (Bridge.clearMask) Bridge.clearMask()
            }
        } else {
            settleTimer.restart()
        }
    }

    // 🚀【核心重构】：副岛位移或宽度展开时，绝对禁止调用 clearMask() 闪现黑底！直接极速提交新遮罩
    function notifyIslandMoving() {
        if (!maskActive || typeof Bridge === "undefined") return
        if (isIslandHidden || (rootItem && rootItem.isIslandHidden)) return

        // 毫秒级防抖，直接无缝更新原子遮罩，杜绝被旧遮罩切角
        islandSlideTimer.interval = 25
        islandSlideTimer.restart()
    }

    Timer {
        id: islandSlideTimer
        interval: 25
        repeat: false
        onTriggered: maskCtrl.commitPreciseMask()
    }

    Timer {
        id: settleTimer
        interval: 60
        repeat: false
        onTriggered: maskCtrl.commitPreciseMask()
    }

    function computeSafeMaskGeometry(item, isCapsule) {
        if (!item) return null

        var ix = Math.round(item.x)
        var iy = Math.round(item.y)
        var iw = Math.round(item.width)
        var ih = Math.round(item.height)
        if (iw <= 0 || ih <= 0) return null

        // 留出 14px 充裕安全边距，两端圆角彻底包裹
        var margin = 14
        var maskX = ix - margin
        var maskY = 0
        var maskW = iw + margin * 2
        var maskH = iy + ih + margin

        var maskR = 14
        if (isCapsule && item.isExpanded) {
            maskR = Math.round(item.radius + margin)
        } else {
            maskR = Math.max(8, Math.min(14, Math.round(ih * 0.38)))
        }

        return {
            x: maskX,
            y: maskY,
            w: maskW,
            h: maskH,
            r: maskR
        }
    }

    function commitPreciseMask() {
        if (!maskActive || typeof Bridge === "undefined" || !capsuleItem || !rootItem) return
        if (isIslandHidden || (rootItem && rootItem.isIslandHidden)) return
        if (isExpanded || isCollapsing || isMorphing || checkAnySubExpanded()) return

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

    function commit() {
        if (isIslandHidden || (rootItem && rootItem.isIslandHidden)) {
            handleHideState()
        } else {
            handleMotionChange()
        }
    }
}