// ==========================================
// 📄 File: ui/windows/Island.qml
// 🌟 顶级窗口视图与天花板感应网 (音量 OSD 状态压栈日志增强版)
// ==========================================
import QtQuick
import QtQuick.Controls
import "../shell"
import "../views"

Item {
    id: root
    width: 460
    height: 280

    readonly property string chosenFont: Theme.activeFont

    readonly property var allTabsMeta: ({
        "hardware": { key: "hardware", name: "控制", color: "#f59e0b" },
        "workspace": { key: "workspace", name: "桌面", color: Theme.workspace },
        "media": { key: "media", name: "媒体", color: Theme.textPrimary },
        "calendar": { key: "calendar", name: "日历", color: Theme.calendar },
        "timer": { key: "timer", name: "计时", color: Theme.timer },
        "clock": { key: "clock", name: "时钟", color: Theme.clock },
        "notification": { key: "notification", name: "通知", color: Theme.notification }
    })

    function isTabEnabled(key) {
        if (typeof Config === "undefined") return true
        if (key === "hardware") return Config.showHardwareTab !== false
        if (key === "workspace") return Config.showWorkspaceTab !== false
        if (key === "media") return Config.showMediaTab !== false
        if (key === "calendar") return Config.showCalendarTab !== false
        if (key === "timer") return Config.showTimerTab !== false
        if (key === "clock") return Config.showClockTab !== false
        if (key === "notification") return Config.showNotificationTab !== false
        return false
    }

    readonly property var enabledTabs: {
        var order = (typeof Config !== "undefined" && Config.tabOrder && Config.tabOrder.length > 0) ?
                    Config.tabOrder :
                    ["hardware", "workspace", "media", "calendar", "timer", "clock", "notification"]
        var list = []
        for (var i = 0; i < order.length; i++) {
            var k = order[i]
            if (isTabEnabled(k) && allTabsMeta[k]) list.push(allTabsMeta[k])
        }
        return list
    }

    IslandTimeService { id: timeService }

    IslandSedentaryService {
        id: sedentaryService
        onRequestAlert: (mins) => {
            capsule.stageEngine.pushTransient("SEDENTARY", 0, {
                title: "站立建议",
                subtitle: "已连续伏案 " + mins + " 分钟",
                icon: "🧘",
                color: "#34d399"
            })
        }
        onDismissAlert: {
            capsule.stageEngine.popTransient("SEDENTARY")
        }
    }

    IslandBridgeRelay {
        id: relay

        onTriggerOsd: (icon, label, val) => {
            // 🔊【音量日志触发点 10】：顶层接收并准备将 OSD 压入灵动岛动画瞬态栈
            if (label === "Volume") {
                console.log("[Island.qml] 准备呼出胶囊音量 OSD: " + icon + " " + val + "% (持续 1500ms)")
            }
            capsule.stageEngine.pushTransient("OSD", 1500, {
                icon: icon,
                title: label,
                subtitle: val + "%",
                value: val,
                color: (icon === "🔇") ? "#ef4444" : "#ffffff"
            })
        }

        onTriggerWorkspace: (c, t, n) => {
            if (capsule.islandOffsetX !== 0) capsule.goHome()
            capsule.stageEngine.pushTransient("WORKSPACE", 800, {
                icon: "⊞",
                title: n || ("桌面 " + c),
                subtitle: c + "/" + t,
                color: Theme.workspace
            })
        }

        onTriggerAlert: (payload, durationMs) => {
            var isDnd = (typeof Config !== "undefined" && Config.dndEnabled)
            var isCall = (payload.icon === "📞" || relay.isCalling)
            if (isDnd && !isCall) return

            if (capsule.islandOffsetX !== 0) capsule.goHome()
            capsule.stageEngine.pushTransient("ALERT", durationMs, payload)
        }

        onCallEnded: {
            capsule.stageEngine.popTransient("CALL")
            capsule.stageEngine.pushTransient("ALERT", 3000, {
                icon: "📞",
                title: "通话已结束",
                subtitle: "Teams 语音通话",
                avatar: "",
                color: "#818cf8"
            })
        }
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        ignoreUnknownSignals: true
        function onMediaUpdated(t, a, s, u, pos, dur) {
            if (s === "Playing") {
                if (capsule.stageEngine.baseMode === capsule.stageEngine.modeTUCKED &&
                    capsule.stageEngine.presentState === capsule.stageEngine.stateREST) {
                    capsule.stageEngine.pushTransient("MEDIA_PEEK", 3500, {
                        icon: "🎵",
                        title: t,
                        subtitle: a,
                        color: relay.dominantColor
                    })
                }
            }
        }
    }

    Loader {
        id: settingsLoader
        active: false; source: "SettingsWindow.qml"
        onLoaded: { item.show(); item.raise() }
    }

    function openSettingsWindow() {
        if (settingsLoader.status === Loader.Ready && settingsLoader.item) {
            settingsLoader.item.show(); settingsLoader.item.raise()
        } else {
            settingsLoader.active = true
        }
    }

    IslandCapsule {
        id: capsule
        anchors.horizontalCenter: parent.horizontalCenter
        chosenFont: root.chosenFont
        relay: relay
        timeService: timeService
        enabledTabs: root.enabledTabs

        onSedentaryRested: sedentaryService.markRested()
        onSedentarySnooze: sedentaryService.snooze()
        onRequestSettings: root.openSettingsWindow()
    }

    MouseArea {
        id: ceilingHoverNet
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Math.max(180, capsule.width + 32)
        z: 99

        readonly property bool isTuckedMode: capsule.stageEngine.baseMode === capsule.stageEngine.modeTUCKED
        readonly property bool isUserPeeking: capsule.stageEngine.presentState === capsule.stageEngine.statePEEK

        height: isTuckedMode ? (isUserPeeking ? Math.max(52, capsule.y + capsule.height + 12) : 14) : 0

        enabled: isTuckedMode
        hoverEnabled: true
        cursorShape: isTuckedMode ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.RightButton

        onEntered: {
            if (isTuckedMode) capsule.stageEngine.userHoverEnter()
        }

        onPositionChanged: (mouse) => {
            if (isTuckedMode) {
                capsule.stageEngine.userHoverEnter()
                capsule.stageEngine.userHoverKeep()
            }
        }

        onExited: {
            if (isTuckedMode) capsule.stageEngine.userHoverLeave()
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                capsule.stageEngine.toggleTuck()
            }
        }
    }
}