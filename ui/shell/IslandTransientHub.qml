// ==========================================
// 📄 File: ui/shell/IslandTransientHub.qml
// 🌟 统一瞬态载荷中枢 (单一事实源 Payload 中心 · 扩充语音输入规格)
// ==========================================
import QtQuick

Item {
    id: hubRoot

    property string activeKey: ""
    property int activePriority: 0
    property var activePayload: ({
        title: "",
        subtitle: "",
        icon: "🔔",
        avatar: "",
        value: 50,
        color: "#818cf8"
    })
    readonly property bool hasActiveTransient: activeKey !== ""

    signal transientActivated(string key, var meta, var payload)
    signal transientDismissed(string key)
    signal geometryInvalidated()

    property var registry: ({
        "CALL": {
            prio: 100, defaultDuration: 0,
            w: 320, h: 46, r: 23
        },
        "VOICE_INPUT": {
            prio: 80, defaultDuration: 0,
            w: 320, h: 42, r: 21
        },
        "SEDENTARY": {
            prio: 50, defaultDuration: 0,
            w: 420, h: 112, r: 26
        },
        "ALERT": {
            prio: 40, defaultDuration: 3500,
            w: -1, h: 50, r: 25,
            calcWidth: function(contentW) { return Math.min(420, Math.max(196, contentW + 36)) },
            calcHeight: function(isLong) { return isLong ? 66 : 50 }
        },
        "OSD": {
            prio: 30, defaultDuration: 1500,
            w: -1, h: 38, r: 19
        },
        "WORKSPACE": {
            prio: 20, defaultDuration: 800,
            w: 210, h: 38, r: 19
        },
        "MEDIA_PEEK": {
            prio: 10, defaultDuration: 3500,
            w: -1, h: 38, r: 19
        }
    })

    function getMeta(key) {
        return registry[key] || { prio: 0, defaultDuration: 1500, w: -1, h: 38, r: 19 }
    }

    function push(key, customDurationMs, payload) {
        var meta = getMeta(key)
        if (!meta) return false

        // 高优先级打断低优先级
        if (hasActiveTransient && meta.prio < activePriority) {
            return false
        }

        activeKey = key
        activePriority = meta.prio

        var p = payload || {}
        activePayload = {
            title: p.title || "",
            subtitle: p.subtitle || "",
            icon: p.icon || "🔔",
            avatar: p.avatar || "",
            value: (p.value !== undefined) ? p.value : 50,
            color: p.color || "#818cf8"
        }

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
        activePayload = { title: "", subtitle: "", icon: "🔔", avatar: "", value: 50, color: "#818cf8" }

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
}