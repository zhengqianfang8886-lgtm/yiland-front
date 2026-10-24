// ==========================================
// 📄 File: ui/shell/IslandBridgeRelay.qml
// 🌟 统一事件清洗与中继总线 (音量 OSD 日志埋点版)
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

    readonly property var notifModel: (typeof Bridge !== "undefined") ? Bridge.notificationModel : null
    property int unreadCount: (typeof Bridge !== "undefined" && Bridge.unreadCount !== undefined) ? Bridge.unreadCount : 0
    property string latestNotifAvatar: (typeof Bridge !== "undefined" && Bridge.latestNotificationAvatar !== undefined) ? Bridge.latestNotificationAvatar : ""

    property string downSpeedStr: "0.0 B/s"
    property string upSpeedStr: "0.0 B/s"
    property string localIp: "127.0.0.1"

    property int memoryPercent: 0

    signal triggerAlert(var payload, int durationMs)
    signal triggerOsd(string icon, string label, int val)
    signal triggerWorkspace(int curr, int tot, string name)
    signal callEnded()

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        ignoreUnknownSignals: true

        function onUnreadCountChanged(cnt) { relay.unreadCount = cnt }

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

        function onOsdTriggered(icon, label, val) {
            // 🔊【音量日志触发点 9】：QML 中继层拦截到底层发来的 OSD 信号
            if (label === "Volume") {
                console.log("[IslandBridgeRelay] 收到底层音量 OSD 信号 -> icon: " + icon + ", label: " + label + ", val: " + val)
            }
            relay.triggerOsd(icon, label, val)
        }

        function onClipboardTriggered(icon, title, detail, ms) {
            relay.triggerAlert({
                icon: icon,
                title: title,
                subtitle: detail,
                avatar: "",
                color: "#38bdf8"
            }, ms)
        }

        function onWorkspaceTriggered(curr, tot, name) {
            relay.wsCurrent = curr; relay.wsTotal = tot; relay.wsName = name
            relay.triggerWorkspace(curr, tot, name)
        }
        function onWorkspaceListUpdated(list) { relay.wsList = list }

        function onAlertTriggered(icon, t, sub, ms, avatar) {
            relay.triggerAlert({
                icon: icon || "🔔",
                title: t || "提醒",
                subtitle: sub || "",
                avatar: avatar || "",
                color: (icon === "⏰") ? "#f97316" : "#818cf8"
            }, ms > 0 ? ms : 3500)
        }

        function onCallIncomingTriggered(title, sub, avatar) {
            relay.isCalling = true
            relay.callTitle = title || "Teams 来电"
            relay.callSubtitle = sub || "正在呼叫..."
            relay.callAvatar = avatar || ""
            relay.triggerAlert({
                icon: "📞",
                title: relay.callTitle,
                subtitle: relay.callSubtitle,
                avatar: relay.callAvatar,
                color: "#22c55e"
            }, 0)
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