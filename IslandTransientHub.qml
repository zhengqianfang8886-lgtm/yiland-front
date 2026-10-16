// ==========================================
// 📄 File: IslandTransientHub.qml (自适应弹性尺寸中枢)
// ==========================================
import QtQuick

Item {
    id: hubRoot

    property string activeKey: ""
    property int activePriority: 0
    property var activePayload: ({})
    readonly property bool hasActiveTransient: activeKey !== ""

    signal transientActivated(string key, var meta, var payload)
    signal transientDismissed(string key)
    signal geometryInvalidated()

    property var registry: ({
        "CALL": {
            prio: 100, defaultDuration: 0,
            widthMode: "fixed", w: 320, h: 44, r: 22
        },
        "SEDENTARY": {
            prio: 50, defaultDuration: 0,
            widthMode: "fixed", w: 420, h: 108, r: 26
        },
        "ALERT": {
            prio: 40, defaultDuration: 3500,
            widthMode: "custom", w: -1, h: 48, r: 24,
            calcWidth: function(contentW) { return Math.min(420, Math.max(160, contentW + 28)) },
            calcHeight: function(isLong) { return isLong ? 64 : 48 }
        },
        "OSD": {
            prio: 30, defaultDuration: 1500,
            widthMode: "content", w: 0, h: 34, r: 17
        },
        "WORKSPACE": {
            prio: 20, defaultDuration: 800,
            widthMode: "custom", w: -1, h: 34, r: 17,
            calcWidth: function(contentW) { return Math.max(170, Math.min(260, contentW + 28)) }
        },
        // 🚀【核心修复】：MEDIA_PEEK 绝对不再粗暴锁死窄宽，而是跟随实际内容自动留足富余
        "MEDIA_PEEK": {
            prio: 10, defaultDuration: 3500,
            widthMode: "custom", w: -1, h: 34, r: 17,
            calcWidth: function(contentW) { return Math.max(210, contentW) }
        }
    })

    function registerTransient(key, descriptor) {
        var copy = Object.assign({}, registry)
        copy[key] = Object.assign({ prio: 10, defaultDuration: 2000, widthMode: "content", w: 0, h: 34, r: 17 }, descriptor)
        registry = copy
    }

    function getMeta(key) {
        return registry[key] || { prio: 0, defaultDuration: 1500, widthMode: "content", w: 0, h: 34, r: 17 }
    }

    function push(key, customDurationMs, payload) {
        var meta = getMeta(key)
        if (!meta) return false

        if (hasActiveTransient && meta.prio < activePriority) {
            return false
        }

        activeKey = key
        activePriority = meta.prio
        activePayload = payload || {}

        var dur = (customDurationMs !== undefined && customDurationMs >= 0) ? customDurationMs : meta.defaultDuration

        if (dur > 0) {
            leaseTimer.interval = dur
            leaseTimer.restart()
        } else {
            leaseTimer.stop()
        }

        transientActivated(key, meta, activePayload)
        geometryInvalidated()
        return true
    }

    function dismiss(key) {
        if (key && activeKey !== key) return
        leaseTimer.stop()
        var oldKey = activeKey
        activeKey = ""
        activePriority = 0
        activePayload = ({})

        if (oldKey !== "") {
            transientDismissed(oldKey)
        }
        geometryInvalidated()
    }

    Timer {
        id: leaseTimer
        repeat: false
        onTriggered: hubRoot.dismiss()
    }

    function resolveGeometry(normalW, dynamicArgs) {
        if (!hasActiveTransient) {
            return { w: normalW, h: 34, r: 17 }
        }

        var meta = getMeta(activeKey)
        var targetW = normalW
        var targetH = meta.h
        var targetR = meta.r

        if (meta.widthMode === "fixed") {
            targetW = meta.w
        } else if (meta.widthMode === "custom" && typeof meta.calcWidth === "function") {
            var contentW = (dynamicArgs && dynamicArgs.contentWidth !== undefined) ? dynamicArgs.contentWidth : normalW
            targetW = meta.calcWidth(contentW)
        } else {
            targetW = normalW
        }

        if (typeof meta.calcHeight === "function") {
            targetH = meta.calcHeight(dynamicArgs ? dynamicArgs.isLongAlert : false)
        }

        return { w: Math.round(targetW), h: targetH, r: targetR }
    }
}