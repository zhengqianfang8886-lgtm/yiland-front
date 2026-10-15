// ==========================================
// 📄 File: IslandBridgeRelay.qml
// ==========================================
import QtQuick

Item {
    id: relay

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

    property bool isCalling: false
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""

    property int wsCurrent: 1
    property int wsTotal: 5
    property string wsName: "1"
    property var wsList: []

    property string osdIcon: "🔊"
    property int osdValue: 50
    property string alertIcon: "🔔"
    property string alertTitle: ""
    property string alertSubtitle: ""
    property string alertAvatar: ""

    // 🚀【核心修复】：直通绑定 Bridge 原生属性
    readonly property var notifModel: (typeof Bridge !== "undefined") ? Bridge.notificationModel : null
    property int unreadCount: (typeof Bridge !== "undefined" && Bridge.unreadCount !== undefined) ? Bridge.unreadCount : 0
    property string latestNotifAvatar: (typeof Bridge !== "undefined" && Bridge.latestNotificationAvatar !== undefined) ? Bridge.latestNotificationAvatar : ""

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
        ignoreUnknownSignals: true

        // 🚀【核心修复】：实时响应未读数变动
        function onUnreadCountChanged(cnt) {
            relay.unreadCount = cnt
        }

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
    }
}