// ==========================================
// 📄 File: IslandPluginBay.qml
// 🌟 副岛挂载槽 (主岛稳态联动 · 极速可中断版)
// ==========================================
import QtQuick
import "bubbles"

Item {
    id: bayRoot

    property string side: "left"
    property real capsuleX: 0
    property real capsuleWidth: 0
    property real capsuleY: 0
    property real capsuleHeight: 0
    property int splitGap: 8
    property bool isBlocked: false

    // 🚀 当阻塞解除/施加时，即刻重新计算布局与遮罩
    onIsBlockedChanged: {
        bayRoot.requestLayout()
    }

    property var relay: null
    property var capsule: null
    property bool hasMusicIsland: false

    property var activeKeys: []
    property int layoutRevision: 0

    Timer {
        id: delayedMaskCommitTimer
        interval: 160
        repeat: false
        onTriggered: bayRoot.maskUpdateRequested()
    }

    function requestLayout() {
        layoutRevision++
        maskUpdateRequested()
        delayedMaskCommitTimer.restart()
        updateHoverState()
    }

    signal requestExpand(string tabName)
    signal interacted()
    signal maskUpdateRequested()

    property bool isAnyHovered: false

    function updateHoverState() {
        for (var i = 0; i < repeater.count; i++) {
            var l = repeater.itemAt(i)
            if (l && l.active && l.isHovered) {
                bayRoot.isAnyHovered = true
                return
            }
        }
        bayRoot.isAnyHovered = false
    }

    function getPluginWidth(loader) {
        if (!loader) return 0
        if (loader.item && loader.item.width > 0) return loader.item.width
        if (loader.pluginKey === "music") return 52
        if (loader.pluginKey === "memory") return 78
        if (loader.pluginKey === "timer") return 88
        if (loader.pluginKey === "notification") return 42
        return 50
    }

    function getActiveItems() {
        var list = []
        for (var i = 0; i < repeater.count; i++) {
            var loader = repeater.itemAt(i)
            if (loader && loader.active) {
                list.push(loader)
            }
        }
        return list
    }

    function getItemX(idx) {
        if (idx < 0 || idx >= repeater.count) return 0
        var currentOffset = bayRoot.splitGap

        for (var i = 0; i < idx; i++) {
            var prevLoader = repeater.itemAt(i)
            if (prevLoader && prevLoader.active) {
                currentOffset += (bayRoot.getPluginWidth(prevLoader) + bayRoot.splitGap)
            }
        }

        var myLoader = repeater.itemAt(idx)
        var myW = bayRoot.getPluginWidth(myLoader)

        if (bayRoot.side === "left") {
            return Math.max(8, bayRoot.capsuleX - (currentOffset + myW))
        } else {
            return bayRoot.capsuleX + bayRoot.capsuleWidth + currentOffset
        }
    }

    Repeater {
        id: repeater
        model: bayRoot.activeKeys

        Loader {
            id: pluginLoader
            readonly property string pluginKey: modelData
            readonly property int itemIndex: index

            x: {
                var _ = bayRoot.layoutRevision
                return bayRoot.getItemX(index)
            }
            // 锚定于主胶囊常态垂直中心，杜绝负数
            y: Math.max(0, bayRoot.capsuleY) + Math.round((Math.max(34, bayRoot.capsuleHeight) - height) / 2)
            
            width: bayRoot.getPluginWidth(pluginLoader)
            height: (item && item.height > 0) ? item.height : 34
            z: 1

            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            onXChanged: bayRoot.maskUpdateRequested()
            onYChanged: bayRoot.maskUpdateRequested()

            readonly property real radius: (item && item.radius !== undefined) ? item.radius : (height / 2)
            readonly property bool active: item ? Boolean(item.active) : false
            readonly property bool isHovered: item ? Boolean(item.isHovered) : false

            sourceComponent: bayRoot.getComponentForKey(pluginKey)

            onLoaded: Qt.callLater(bayRoot.requestLayout)

            Connections {
                target: pluginLoader.item
                ignoreUnknownSignals: true
                function onActiveChanged() { bayRoot.requestLayout() }
                function onWidthChanged() { bayRoot.requestLayout() }
                function onIsHoveredChanged() { bayRoot.updateHoverState() }
            }
        }
    }

    function getComponentForKey(key) {
        if (key === "memory") return compMemory
        if (key === "music") return compMusic
        if (key === "timer") return compTimer
        if (key === "notification") return compNotif
        return null
    }

    // 1. 内存监控小岛
    Component {
        id: compMemory
        MemoryBubbleView {
            transformOrigin: bayRoot.side === "left" ? Item.Right : Item.Left
            readonly property bool meetsThreshold: {
                if (typeof Config === "undefined" || Config.memoryThreshold === undefined || Config.memoryThreshold <= 0) return true
                return (bayRoot.relay && bayRoot.relay.memoryPercent !== undefined ? bayRoot.relay.memoryPercent : 0) >= Config.memoryThreshold
            }
            active: Boolean(!bayRoot.isBlocked && (typeof Config === "undefined" || Config.showMemoryBubble !== false) && meetsThreshold)
            memoryPercent: (bayRoot.relay && bayRoot.relay.memoryPercent !== undefined) ? bayRoot.relay.memoryPercent : 0
            memoryUsedGb: (bayRoot.relay && bayRoot.relay.memoryUsedGb) ? bayRoot.relay.memoryUsedGb : "0G"
            memoryTotalGb: (bayRoot.relay && bayRoot.relay.memoryTotalGb) ? bayRoot.relay.memoryTotalGb : "0G"
            onClicked: if (typeof Bridge !== "undefined" && Bridge.openSystemMonitor) Bridge.openSystemMonitor()
        }
    }

    // 2. 音乐律动小岛
    Component {
        id: compMusic
        MusicBubbleView {
            transformOrigin: bayRoot.side === "left" ? Item.Right : Item.Left
            active: Boolean(!bayRoot.isBlocked && bayRoot.hasMusicIsland)
            dominantColor: (bayRoot.relay && bayRoot.relay.dominantColor) ? bayRoot.relay.dominantColor : "#22c55e"
            spec1: (bayRoot.relay && bayRoot.relay.spec1 !== undefined) ? bayRoot.relay.spec1 : 0.2
            spec2: (bayRoot.relay && bayRoot.relay.spec2 !== undefined) ? bayRoot.relay.spec2 : 0.2
            spec3: (bayRoot.relay && bayRoot.relay.spec3 !== undefined) ? bayRoot.relay.spec3 : 0.2
            spec4: (bayRoot.relay && bayRoot.relay.spec4 !== undefined) ? bayRoot.relay.spec4 : 0.2
            onClicked: bayRoot.requestExpand("media")
            onWheelInteracted: bayRoot.interacted()
        }
    }

    // 3. 专注计时小岛 (彻底修复消失问题)
    Component {
        id: compTimer
        TimerBubbleView {
            transformOrigin: bayRoot.side === "left" ? Item.Right : Item.Left
            active: Boolean(!bayRoot.isBlocked && bayRoot.capsule && bayRoot.capsule.timerActive)
            timerText: (bayRoot.capsule && bayRoot.capsule.timerFormattedText) ? bayRoot.capsule.timerFormattedText : "25:00"
            hasHours: Boolean(bayRoot.capsule && bayRoot.capsule.timerHasHours)
            isCountUp: Boolean(bayRoot.capsule && bayRoot.capsule.timerIsCountUp)
            progress: (bayRoot.capsule && bayRoot.capsule.timerProgress !== undefined) ? bayRoot.capsule.timerProgress : 0.0
            remainingSeconds: (bayRoot.capsule && bayRoot.capsule.timerRemaining !== undefined) ? bayRoot.capsule.timerRemaining : 0
            totalSeconds: (bayRoot.capsule && bayRoot.capsule.timerTotal !== undefined) ? bayRoot.capsule.timerTotal : 0
            isRunning: Boolean(bayRoot.capsule && bayRoot.capsule.timerRunning)
            isPaused: Boolean(bayRoot.capsule && bayRoot.capsule.timerIsPaused)
            isCompleted: Boolean(bayRoot.capsule && bayRoot.capsule.timerIsCompleted)
            onTogglePause: if (bayRoot.capsule) bayRoot.capsule.toggleTimerPause()
            onDismissTimer: if (bayRoot.capsule) bayRoot.capsule.dismissTimer()
        }
    }

    // 4. 消息通知小岛
    Component {
        id: compNotif
        NotificationBubbleView {
            transformOrigin: bayRoot.side === "left" ? Item.Right : Item.Left
            active: Boolean(!bayRoot.isBlocked && bayRoot.relay && bayRoot.relay.unreadCount > 0)
            unreadCount: (bayRoot.relay && bayRoot.relay.unreadCount !== undefined) ? bayRoot.relay.unreadCount : 0
            avatarUrl: (bayRoot.relay && bayRoot.relay.latestNotifAvatar) ? bayRoot.relay.latestNotifAvatar : ""
            onClicked: bayRoot.requestExpand("notification")
            onRightClicked: bayRoot.requestExpand("notification")
        }
    }
}