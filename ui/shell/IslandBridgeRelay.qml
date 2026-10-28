// =========================================================================
// 📄 File: ui/shell/IslandBridgeRelay.qml
// 🌟 统一事件中继总线 (已剔除 OSD 弹窗处理)
// =========================================================================
import QtQuick

Item {
    id: relay

    property var fsm: null

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

    property bool visualPlaying: false

    Timer {
        id: pauseDebounceTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (relay.status !== "Playing") {
                relay.visualPlaying = false;
            }
        }
    }

    // 通话状态
    property bool isCalling: false
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""

    // 工作区与通知
    property int wsCurrent: 1
    property int wsTotal: 4
    property string wsName: "1"
    property var wsList: []

    property int unreadCount: (typeof Bridge !== "undefined" && Bridge.unreadCount !== undefined) ? Bridge.unreadCount : 0
    property string latestNotifAvatar: (typeof Bridge !== "undefined" && Bridge.latestNotificationAvatar !== undefined) ? Bridge.latestNotificationAvatar : ""

    property string netDownVal: "0"
    property string netDownUnit: "B/s"
    property string netUpVal: "0"
    property string netUpUnit: "B/s"
    property string downCompact: "0B"
    property string upCompact: "0B"
    property string localIp: "127.0.0.1"
    property int memoryPercent: 0

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        ignoreUnknownSignals: true

        function onUnreadCountChanged(cnt) { relay.unreadCount = cnt; }

        function onNetSpeedUpdated(d_val, d_unit, u_val, u_unit, d_compact, u_compact) {
            relay.netDownVal = d_val;
            relay.netDownUnit = d_unit;
            relay.netUpVal = u_val;
            relay.netUpUnit = u_unit;
            relay.downCompact = d_compact;
            relay.upCompact = u_compact;
        }

        function onMediaUpdated(t, a, s, u, pos, dur) {
            var isTrackChanged = (relay.title !== t && t !== "" && t !== "等待播放...");
            relay.title = t; relay.artist = a; relay.status = s; relay.artUrl = u;
            if (dur !== undefined && !isNaN(dur) && Number(dur) > 0) relay.duration = Number(dur);
            if (pos !== undefined && !isNaN(pos) && Number(pos) >= 0) relay.position = Number(pos);

            var wasPlaying = relay.visualPlaying;
            if (s === "Playing") {
                pauseDebounceTimer.stop();
                relay.visualPlaying = true;
            } else {
                pauseDebounceTimer.restart();
            }

            if (s === "Playing" && relay.fsm && relay.fsm.currentState === 0) {
                if (!wasPlaying || isTrackChanged) {
                    relay.fsm.postTransient("MEDIA_PEEK", { 
                        title: t, 
                        subtitle: a || "未知艺术家", 
                        color: relay.dominantColor 
                    }, 3500);
                }
            }
        }

        function onDominantColorUpdated(hex) { relay.dominantColor = hex; }

        function onAudioSpectrumUpdated(s1, s2, s3, s4) {
            if (!relay.visualPlaying && relay.status !== "Playing") return;
            relay.spec1 = s1; relay.spec2 = s2; relay.spec3 = s3; relay.spec4 = s4;
        }

        // 🚀 已彻底剔除 onOsdTriggered

        function onWorkspaceTriggered(curr, tot, name) {
            relay.wsCurrent = curr; relay.wsTotal = tot; relay.wsName = name;
            if (relay.fsm) {
                relay.fsm.postTransient("WORKSPACE", {
                    title: name || ("桌面 " + curr),
                    subtitle: curr + "/" + tot,
                    color: Theme.workspace
                }, 800);
            }
        }

        function onWorkspaceListUpdated(list) { relay.wsList = list; }

        function onAlertTriggered(icon, t, sub, ms, avatar) {
            var isDnd = (typeof Config !== "undefined" && Config.dndEnabled !== undefined) ? Config.dndEnabled : false;
            if (isDnd && icon !== "⏰") return;

            if (relay.fsm) {
                relay.fsm.postTransient("ALERT", {
                    icon: icon || "🔔",
                    title: t || "提醒",
                    subtitle: sub || "",
                    avatar: avatar || "",
                    color: (icon === "⏰") ? "#f97316" : "#818cf8"
                }, ms > 0 ? ms : 3500);
            }
        }

        function onCallIncomingTriggered(title, sub, avatar) {
            var isDnd = (typeof Config !== "undefined" && Config.dndEnabled !== undefined) ? Config.dndEnabled : false;
            var allowCalls = (typeof Config !== "undefined" && Config.dndAllowCalls !== undefined) ? Config.dndAllowCalls : true;
            if (isDnd && !allowCalls) return;

            relay.isCalling = true;
            relay.callTitle = title || "Teams 来电";
            relay.callSubtitle = sub || "正在呼叫...";
            relay.callAvatar = avatar || "";
            if (relay.fsm) {
                relay.fsm.postTransient("CALL", {
                    title: relay.callTitle,
                    subtitle: relay.callSubtitle,
                    avatar: relay.callAvatar
                }, 0);
            }
        }

        function onCallEndedTriggered() {
            relay.isCalling = false;
            if (relay.fsm) {
                relay.fsm.dismissTransient("CALL");
            }
        }

        // 🚀【核心补全】：接收底层进度更新，每秒推送至各页面
        function onProgressUpdated(pos, dur, prog) {
            if (pos !== undefined && !isNaN(pos) && Number(pos) >= 0) {
                relay.position = Number(pos);
            }
            if (dur !== undefined && !isNaN(dur) && Number(dur) > 0) {
                relay.duration = Number(dur);
            }
        }
    }
}