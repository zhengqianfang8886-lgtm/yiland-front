// ==========================================
// 📄 File: IslandBridgeRelay.qml (集成击键物理脉冲中继)
// ==========================================
import QtQuick

Item {
    id: relay

    // 媒体数据
    property string title: "等待播放..."
    property string artist: "未知歌手"
    property string status: "Paused"
    property string artUrl: ""
    property real position: 0
    property real duration: 0

    property string dominantColor: "#22c55e"
    property real spec1: 0.2
    property real spec2: 0.2
    property real spec3: 0.2
    property real spec4: 0.2

    // 🚀 打字心流数据与击键物理脉冲版本号
    property bool typingActive: false
    property color typingColor: "#38bdf8"
    property real typingSpec1: 0.2
    property real typingSpec2: 0.2
    property real typingSpec3: 0.2
    property real typingSpec4: 0.2
    property real typingKps: 0.0
    property string typingMod: ""
    property string typingKey: ""
    property int strokeRevision: 0 // 🚀 每次击键递增的物理版本号

    // 通话数据
    property bool isCalling: false
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""

    // 虚拟桌面
    property int wsCurrent: 1
    property int wsTotal: 4
    property string wsName: "Desktop 1"
    property var wsList: []

    // 瞬态与 OSD
    property string osdIcon: "🔊"
    property int osdValue: 50
    property string alertIcon: "🔔"
    property string alertTitle: ""
    property string alertSubtitle: ""
    property string alertAvatar: ""

    readonly property var notifModel: (typeof Bridge !== "undefined") ? Bridge.notificationModel : null
    property int unreadCount: notifModel ? notifModel.unreadCount : 0
    property string latestNotifAvatar: notifModel ? notifModel.latestAvatar : ""

    property string downSpeedStr: "0.0 B/s"
    property string upSpeedStr: "0.0 B/s"
    property string downSpeedCompact: "0K"
    property string upSpeedCompact: "0K"
    property string localIp: "127.0.0.1"

    property int memoryPercent: 0
    property string memoryUsedGb: "0G"
    property string memoryTotalGb: "0G"

    signal triggerAlert(string icon, string title, string sub, int ms, string avatar)
    signal triggerClipboard(string icon, string title, string detail, int ms)
    signal triggerOsd(string icon, string label, int val)
    signal triggerWorkspace(int curr, int tot, string name)
    signal callEnded()

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null

        function onMediaUpdated(t, a, s, u, pos, dur) {
            relay.title = t; relay.artist = a; relay.status = s; relay.artUrl = u
            if (dur !== undefined && !isNaN(dur) && Number(dur) > 0) relay.duration = Number(dur)
            if (pos !== undefined && !isNaN(pos) && Number(pos) >= 0) relay.position = Number(pos)
        }
        function onProgressUpdated(pos, dur) {
            if (dur !== undefined && !isNaN(dur) && Number(dur) > 0) relay.duration = Number(dur)
            if (pos !== undefined && !isNaN(pos) && Number(pos) >= 0) relay.position = Number(pos)
        }
        function onDominantColorUpdated(hex) { relay.dominantColor = hex }
        function onAudioSpectrumUpdated(s1, s2, s3, s4) {
            relay.spec1 = s1; relay.spec2 = s2; relay.spec3 = s3; relay.spec4 = s4
        }

        function onTypingSpectrumUpdated(active, color, s1, s2, s3, s4, kps, modLabel, keyLabel) {
            relay.typingActive = active
            relay.typingColor = color
            relay.typingSpec1 = s1
            relay.typingSpec2 = s2
            relay.typingSpec3 = s3
            relay.typingSpec4 = s4
            relay.typingKps = kps
            relay.typingMod = modLabel || ""
            relay.typingKey = keyLabel || ""
        }

        // 🚀 响应底层击键脉冲：无论字符是否改变，strokeRevision 都会改变
        function onKeyStrokeTriggered(modLabel, keyLabel, counter) {
            relay.typingMod = modLabel || ""
            relay.typingKey = keyLabel || ""
            relay.strokeRevision = counter
        }

        function onClipboardTriggered(icon, title, detail, ms) { relay.triggerClipboard(icon, title, detail, ms) }
        function onOsdTriggered(icon, label, val) {
            relay.osdIcon = icon; relay.osdValue = val
            relay.triggerOsd(icon, label, val)
        }
        function onWorkspaceTriggered(curr, tot, name) {
            relay.wsCurrent = curr; relay.wsTotal = tot; relay.wsName = name
            relay.triggerWorkspace(curr, tot, name)
        }
        function onWorkspaceListUpdated(list) { relay.wsList = list }
        function onAlertTriggered(icon, t, sub, ms, avatar) { relay.triggerAlert(icon, t, sub, ms, avatar) }

        function onCallIncomingTriggered(title, sub, avatar) {
            relay.isCalling = true
            relay.callTitle = title || "Teams 来电"
            relay.callSubtitle = sub || "正在呼叫..."
            relay.callAvatar = avatar || ""
            relay.triggerAlert("📞", relay.callTitle, relay.callSubtitle, 0, relay.callAvatar)
        }

        function onCallEndedTriggered() {
            relay.isCalling = false
            relay.callTitle = ""
            relay.callSubtitle = ""
            relay.callAvatar = ""
            relay.callEnded()
        }

        function onNetSpeedUpdated(down, up, downComp, upComp, ip) {
            relay.downSpeedStr = down; relay.upSpeedStr = up
            relay.downSpeedCompact = downComp; relay.upSpeedCompact = upComp
            if (ip) relay.localIp = ip
        }
        function onMemoryUpdated(pct, used, total) {
            relay.memoryPercent = pct
            relay.memoryUsedGb = used
            relay.memoryTotalGb = total
        }
    }
}