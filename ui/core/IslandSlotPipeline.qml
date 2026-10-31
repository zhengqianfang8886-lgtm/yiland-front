// =========================================================================
// 📄 File: ui/core/IslandSlotPipeline.qml
// 🌟 声明式槽位注册与仲裁管线引擎 (新增 3 秒驻留防抖 CPU 模型版)
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

    readonly property bool recActive: (bridge && bridge.isRecordingActive !== undefined) ? Boolean(bridge.isRecordingActive) : false
    readonly property bool hasObsIcon: (bridge && bridge.recordingIcon !== undefined && bridge.recordingIcon !== "")
    readonly property int recWidth: recActive ? (hasObsIcon ? 58 : 28) : 0

    readonly property bool imeActive: (bridge && bridge.isImeActive)
    readonly property int imeWidth: imeActive ? 28 : 0

    // =========================================================================
    // 🚀【CPU 控制流：3秒冷却防抖 (Cooldown Debounce)】
    // =========================================================================
    readonly property bool cpuBubbleEnabled: (config && config.showCpuBubble !== false)
    readonly property int cpuThreshold: (config && config.cpuThreshold !== undefined) ? config.cpuThreshold : 75
    readonly property int currentCpu: (bridge && bridge.cpuPercent !== undefined) ? bridge.cpuPercent : 0

    // 内部迟滞状态：为 true 时保持显示
    property bool _cpuActiveHeld: false

    onCurrentCpuChanged: {
        if (!cpuBubbleEnabled) {
            _cpuActiveHeld = false;
            cpuHideTimer.stop();
            return;
        }

        // 常驻显示模式
        if (cpuThreshold === 0) {
            _cpuActiveHeld = true;
            cpuHideTimer.stop();
            return;
        }

        // 核心防抖逻辑
        if (currentCpu >= cpuThreshold) {
            _cpuActiveHeld = true;    // 立刻显示
            cpuHideTimer.stop();      // 打断正在倒计时的隐藏定时器
        } else {
            // 当 CPU 回落，且当前仍在显示时，开启 3 秒冷却倒计时
            if (_cpuActiveHeld && !cpuHideTimer.running) {
                cpuHideTimer.start();
            }
        }
    }

    property Timer cpuHideTimer: Timer {
        interval: 3000 // 3 秒无高压后，平滑收缩隐藏
        repeat: false
        onTriggered: {
            pipeline._cpuActiveHeld = false;
        }
    }

    // 将最终渲染是否激活，绑定到迟滞持有的状态变量上
    readonly property bool cpuActive: cpuBubbleEnabled && (cpuThreshold === 0 || _cpuActiveHeld)
    readonly property int cpuWidth: cpuActive ? 58 : 0

    // =========================================================================

    readonly property int unreadCount: (relay && relay.unreadCount > 0) ? relay.unreadCount : 0
    readonly property int noticeWidth: unreadCount > 0 ? (unreadCount >= 10 ? 40 : 34) : 0

    readonly property bool musicPlaying: (relay && relay.visualPlaying)
    readonly property int musicWidth: musicPlaying ? 40 : 0

    readonly property var registeredSlots: [
        { id: "recording", name: "录制与OBS",   priority: 95, width: pipeline.recWidth, active: pipeline.recActive, gap: 4 },
        { id: "ime",       name: "输入法",       priority: 85, width: pipeline.imeWidth, active: pipeline.imeActive, gap: 4 },
        { id: "cpu",       name: "CPU负载告警",  priority: 82, width: pipeline.cpuWidth, active: pipeline.cpuActive, gap: 4 },
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