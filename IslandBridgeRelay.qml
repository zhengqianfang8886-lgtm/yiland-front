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

    // 网络与通知
    property int unreadCount: 0
    property string latestNotifAvatar: ""
    property string downSpeedStr: "0.0 B/s"
    property string upSpeedStr: "0.0 B/s"
    property string downSpeedCompact: "0K"
    property string upSpeedCompact: "0K"
    property string localIp: "127.0.0.1"

    signal triggerAlert(string icon, string title, string sub, int ms, string avatar)
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
        function onOsdTriggered(icon, label, val) {
            relay.osdIcon = icon; relay.osdValue = val
            relay.triggerOsd(icon, label, val)
        }
        function onWorkspaceTriggered(curr, tot, name) {
            relay.wsCurrent = curr; relay.wsTotal = tot; relay.wsName = name
            relay.triggerWorkspace(curr, tot, name)
        }
        function onWorkspaceListUpdated(list) { relay.wsList = list }
        function onAlertTriggered(icon, t, sub, ms, avatar) {
            if (icon === "📞" || ms <= 0) {
                relay.isCalling = true; relay.callTitle = t; relay.callSubtitle = sub || "正在通话..."
                relay.callAvatar = avatar || ""
            }
            relay.triggerAlert(icon, t, sub, ms, avatar)
        }
        function onCallEndedTriggered() {
            relay.isCalling = false
            relay.callEnded()
        }
        function onNetSpeedUpdated(down, up, downComp, upComp, ip) {
            relay.downSpeedStr = down; relay.upSpeedStr = up
            relay.downSpeedCompact = downComp; relay.upSpeedCompact = upComp
            if (ip) relay.localIp = ip
        }
        function onUnreadCountChanged(cnt) {
            relay.unreadCount = cnt
            if (typeof Bridge !== "undefined" && Bridge.getLatestNotificationAvatar) {
                relay.latestNotifAvatar = Bridge.getLatestNotificationAvatar()
            }
        }
    }
}