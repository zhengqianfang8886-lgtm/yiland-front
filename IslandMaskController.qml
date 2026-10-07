// ==========================================
// 📄 File: IslandMaskController.qml
// 🌟 60帧节流原子掩模引擎 · 补齐属性声明防崩溃版
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

    // 🚀 恢复属性声明，兼容外部 Island.qml 的绑定赋值，防止编译崩溃
    property bool maskActive: false
    property bool isIslandHidden: false
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isMorphing: false
    property int targetW: 150
    property int targetH: 36
    
    // 状态记录锁
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

    // 只要 active 就是有效岛屿，绝不用 opacity 过滤，防止入场动画被截断！
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

    // 防饿死节流引擎 (Throttle)，确保连续动画时每 16ms 稳稳输出一帧掩模
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
        interval: 16  // 锁定 ~60fps 的掩模刷新率
        repeat: false
        onTriggered: {
            if (_updatePending) {
                _updatePending = false
                commitPreciseMask()
                throttleTimer.start()
            }
        }
    }

    // 统一暴露给外部调用的入口
    function notifyIslandMoving() { requestMaskUpdate() }
    function commit() { requestMaskUpdate() }

    // 为副岛提供超级宽容度，彻底吸收 IPC 延迟带来的残影
    function computeSafeMaskGeometry(item, isCapsule) {
        if (!item) return null

        var ix = Math.round(item.x)
        var iy = Math.round(item.y)
        var iw = Math.round(item.width)
        var ih = Math.round(item.height)
        if (iw <= 0 || ih <= 0) return null

        // 主胶囊给 14px 边距，副岛滑动时给予更充裕的 32px 安全冗余
        var marginX = isCapsule ? 14 : 32
        var marginY = 14

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