// =========================================================================
// 📄 File: ui/core/IslandSlotPipeline.qml
// 🌟 声明式槽位注册与仲裁管线引擎 (红点与OBS合体版)
// =========================================================================
import QtQuick
import "IslandLogger.js" as Logger

QtObject {
    id: pipeline

    property var bridge: null
    property var relay: null
    property var config: null

    property int clockWidth: 72
    readonly property int maxSlotBudget: 180

    readonly property bool wsEnabled: (config && config.showWorkspaceName !== false)
    readonly property int wsWidth: (wsEnabled && relay && relay.wsName) ? Math.max(38, (relay.wsName.length * 8) + 16) : (wsEnabled ? 38 : 0)

    readonly property bool cdActive: (bridge && bridge.cdActive)
    readonly property int cdWidth: {
        if (!cdActive) return 0;
        var isOt = bridge.cdIsOvertime;
        var s = isOt ? bridge.cdOvertimeSec : bridge.cdRemainingSec;
        return s >= 3600 ? (isOt ? 114 : 102) : (isOt ? 84 : 76);
    }

    readonly property bool swActive: (bridge && bridge.swActive)
    readonly property int swWidth: swActive ? (bridge.swElapsedSec >= 3600 ? 102 : 76) : 0

    readonly property bool netEnabled: (config && config.showNetSpeed !== false)
    readonly property int netWidth: netEnabled ? 56 : 0

    // 🚀【核心合体】：录制微囊，如果包含 OBS 则宽 42px，否则纯红点宽 24px
    readonly property bool recActive: (bridge && bridge.isRecordingActive !== undefined) ? Boolean(bridge.isRecordingActive) : false
    readonly property bool hasObsIcon: (bridge && bridge.recordingIcon !== undefined && bridge.recordingIcon !== "")
    readonly property int recWidth: recActive ? (hasObsIcon ? 54 : 28) : 0

    readonly property bool imeActive: (bridge && bridge.isImeActive)
    readonly property int imeWidth: imeActive ? 26 : 0

    readonly property int unreadCount: (relay && relay.unreadCount > 0) ? relay.unreadCount : 0
    readonly property int noticeWidth: unreadCount > 0 ? (unreadCount >= 10 ? 40 : 34) : 0

    readonly property bool musicPlaying: (relay && relay.visualPlaying)
    readonly property int musicWidth: musicPlaying ? 40 : 0

    // 声明式槽位排序表 (现在只有唯一的 recording 槽位)
    readonly property var registeredSlots: [
        { id: "recording", name: "录制与OBS",   priority: 95, width: pipeline.recWidth, active: pipeline.recActive, gap: 4 },
        { id: "ime",       name: "输入法",       priority: 85, width: pipeline.imeWidth, active: pipeline.imeActive, gap: 4 },
        { id: "countdown", name: "倒计时",       priority: 80, width: pipeline.cdWidth,  active: pipeline.cdActive,  gap: 4 },
        { id: "stopwatch", name: "秒表",         priority: 79, width: pipeline.swWidth,  active: pipeline.swActive,  gap: 4 },
        { id: "notice",    name: "通知角标",     priority: 75, width: pipeline.noticeWidth, active: pipeline.unreadCount > 0, gap: 4 },
        { id: "music",     name: "音乐声谱",     priority: 60, width: pipeline.musicWidth, active: pipeline.musicPlaying, gap: 4 },
        { id: "netspeed",  name: "实时网速",     priority: 40, width: pipeline.netWidth, active: pipeline.netEnabled, gap: 4 }
    ]

    readonly property int calculatedRightWidth: {
        var total = 0;
        for (var i = 0; i < registeredSlots.length; i++) {
            var s = registeredSlots[i];
            if (s.active && s.width > 0) {
                total += (s.width + s.gap);
            }
        }
        return total;
    }

    readonly property int naturalCapsuleWidth: {
        var baseTotal = 24 + clockWidth;
        if (wsWidth > 0) baseTotal += (wsWidth + 5);
        if (calculatedRightWidth > 0) baseTotal += (calculatedRightWidth + 4);
        return Math.ceil(baseTotal / 4.0) * 4;
    }
}