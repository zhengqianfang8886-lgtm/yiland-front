// ==========================================
// 📄 File: IslandMaskController.qml (全自动探测·通用几何防咬边引擎)
// ==========================================
import QtQuick

Item {
    id: maskCtrl

    // 核心宿主容器与主胶囊注入
    property var rootItem: null
    property var capsuleItem: null

    // 兼容历史命名接口（保留以兼容外部直接传参）
    property var leftMemoryBubble: null
    property var leftBubble: null
    property var hwBubble: null
    property var rightBubble: null
    property var notifBubble: null

    // 外部显式数组插槽（可选：亦可外部直接传入岛屿数组）
    property var customIslands: []

    property bool maskActive: false
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isMorphing: false

    property bool isIslandHidden: false
    onIsIslandHiddenChanged: handleHideState()

    property int targetW: 150
    property int targetH: 36

    // =========================================================================
    // 1. 全自动小岛动态探测与展开状态汇聚
    // =========================================================================

    // 动态探测当前存在的所有有效副岛实例（无需硬编码指定）
    function getDiscoveredIslands() {
        var list = []
        var seen = ({})

        function registerItem(item) {
            if (!item) return
            // 排除自身、主胶囊、根容器和不可见/纯逻辑项
            if (item === maskCtrl || item === capsuleItem || item === rootItem) return
            if (typeof item.x === "undefined" || typeof item.width === "undefined") return
            if (item.width <= 0 || item.height <= 0) return

            // 过滤未激活或几乎完全透明项
            if (item.active !== undefined && !item.active) return
            if (item.opacity !== undefined && item.opacity < 0.1) return

            var key = item.toString()
            if (seen[key]) return
            seen[key] = true
            list.push(item)
        }

        // 1. 自动合并兼容历史属性
        registerItem(leftMemoryBubble)
        registerItem(leftBubble)
        registerItem(hwBubble)
        registerItem(rightBubble)
        registerItem(notifBubble)

        // 2. 自动合并自定义数组
        if (customIslands && customIslands.length > 0) {
            for (var c = 0; c < customIslands.length; c++) {
                registerItem(customIslands[c])
            }
        }

        // 3. 🌟 核心机制：自动扫描 rootItem.children 发现未来任意新增小岛
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

    // 动态判断当前是否有任意副岛处于展开交互态
    function checkAnySubExpanded() {
        var islands = getDiscoveredIslands()
        for (var i = 0; i < islands.length; i++) {
            if (islands[i] && islands[i].isExpanded) {
                return true
            }
        }
        return false
    }

    readonly property bool isAnySubExpanded: checkAnySubExpanded()

    // 状态机监听
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
            if (Bridge.clearMask) Bridge.clearMask()
            islandSlideTimer.interval = 350
            islandSlideTimer.restart()
        }
    }

    function handleMotionChange() {
        if (!maskActive || typeof Bridge === "undefined") return
        if (isIslandHidden || (rootItem && rootItem.isIslandHidden)) return

        var inMotion = isExpanded || isCollapsing || isMorphing || checkAnySubExpanded()

        if (inMotion) {
            settleTimer.stop()
            if (Bridge.clearMask) Bridge.clearMask()
        } else {
            settleTimer.restart()
        }
    }

    function notifyIslandMoving() {
        if (!maskActive || typeof Bridge === "undefined") return
        if (isIslandHidden || (rootItem && rootItem.isIslandHidden)) return

        if (Bridge.clearMask) Bridge.clearMask()
        islandSlideTimer.interval = 180
        islandSlideTimer.restart()
    }

    Timer {
        id: islandSlideTimer
        interval: 180
        repeat: false
        onTriggered: maskCtrl.commitPreciseMask()
    }

    Timer {
        id: settleTimer
        interval: 80
        repeat: false
        onTriggered: maskCtrl.commitPreciseMask()
    }

    // =========================================================================
    // 2. 通用几何防咬边数学通式 (适用于主胶囊及任意现有/未来副岛)
    // =========================================================================
    function computeSafeMaskGeometry(item, isCapsule) {
        if (!item) return null

        var ix = Math.round(item.x)
        var iy = Math.round(item.y)
        var iw = Math.round(item.width)
        var ih = Math.round(item.height)
        if (iw <= 0 || ih <= 0) return null

        // 🌟 1. 全局充裕外围纯透明安全边距 (12px)
        var margin = 12

        // 🌟 2. 顶部统一通往屏幕极顶 (y = 0)，彻底切除顶隙狭缝
        var maskX = ix - margin
        var maskY = 0
        var maskW = iw + margin * 2
        var maskH = iy + ih + margin

        // 🌟 3. 数学自适应安全圆角通式：
        // 杜绝盲目使用 (radius + margin)。将圆角内敛约束在 [8, 14] 之间，
        // 在贴顶 y = iy (约 6px) 处，圆弧内凹位移恒 <= 1.35px，
        // 无论岛屿多窄（如 40px），四周恒有 >= 10.65px 纯透明缓冲，物理上绝对不咬边！
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

    // =========================================================================
    // 3. 聚合提交流程
    // =========================================================================
    function commitPreciseMask() {
        if (!maskActive || typeof Bridge === "undefined" || !capsuleItem || !rootItem) return
        if (isIslandHidden || (rootItem && rootItem.isIslandHidden)) return
        if (isExpanded || isCollapsing || isMorphing || checkAnySubExpanded() || islandSlideTimer.running) return

        var rectList = []

        // 1. 处理主胶囊
        var capMask = computeSafeMaskGeometry(capsuleItem, true)
        if (capMask) {
            rectList.push(capMask)
        }

        // 2. 自动遍历并处理所有被动态发现的副岛
        var dynamicIslands = getDiscoveredIslands()
        for (var i = 0; i < dynamicIslands.length; i++) {
            var islandMask = computeSafeMaskGeometry(dynamicIslands[i], false)
            if (islandMask) {
                rectList.push(islandMask)
            }
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