// ==========================================
// 📄 File: Island.qml (已移除 time/network/bluetooth 纯净版)
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 460
    height: 280

    readonly property string chosenFont: Theme.activeFont

    // 🚀【核心修复】：仅保留现有模块的元数据
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

    // 1. 久坐服务
    IslandSedentaryService {
        id: sedentaryService
        onRequestAlert: (mins) => {
            capsule.stageEngine.pushTransient("SEDENTARY", 0)
        }
        onDismissAlert: {
            capsule.stageEngine.popTransient("SEDENTARY")
        }
    }

    // 2. 桥接事件监听
    IslandBridgeRelay {
        id: relay

        onTriggerOsd: (icon, label, val) => {
            capsule.stageEngine.pushTransient("OSD", 1500)
        }

        onTriggerWorkspace: (c, t, n) => {
            if (capsule.islandOffsetX !== 0) capsule.goHome()
            capsule.stageEngine.pushTransient("WORKSPACE", 800)
            if (typeof Bridge !== "undefined") Bridge.forceRaise()
        }

        onTriggerAlert: (icon, t, sub, ms, avatar) => {
            var isDnd = (typeof Config !== "undefined" && Config.dndEnabled)
            var isCall = (icon === "📞" || relay.isCalling)
            if (isDnd && !isCall) return

            if (capsule.islandOffsetX !== 0) capsule.goHome()
            capsule.stageEngine.pushTransient("ALERT", ms > 0 ? ms : 3500)
        }

        onCallEnded: {
            capsule.stageEngine.popTransient("CALL")
            capsule.stageEngine.pushTransient("ALERT", 3000)
        }
    }

    // 3. 媒体被动出水监听
    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        ignoreUnknownSignals: true
        function onMediaUpdated(t, a, s, u, pos, dur) {
            if (s === "Playing") {
                if (capsule.stageEngine.currentBaseTier === capsule.stageEngine.tierTUCKED) {
                    capsule.stageEngine.pushTransient("MEDIA_PEEK", 3500)
                }
            }
        }
    }

    // 4. 偏好设置窗口 Loader
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

    // 5. 核心胶囊
    IslandCapsule {
        id: capsule
        anchors.horizontalCenter: parent.horizontalCenter
        chosenFont: root.chosenFont
        relay: relay
        timeService: timeService
        enabledTabs: root.enabledTabs

        onTimerAlert: (t, msg) => {
            capsule.stageEngine.pushTransient("ALERT", 5000)
            if (typeof Bridge !== "undefined") Bridge.forceRaise()
        }
        onSedentaryRested: sedentaryService.markRested()
        onSedentarySnooze: sedentaryService.snooze()
        onRequestSettings: root.openSettingsWindow()
    }

    // 6. 天花板全域鼠标感应网
    MouseArea {
        id: ceilingHoverNet
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Math.max(160, capsule.width + 24)
        z: 99

        readonly property bool isTuckedMode: capsule.stageEngine.currentBaseTier === capsule.stageEngine.tierTUCKED

        height: isTuckedMode ? 
                (capsule.stageEngine.submergedSubTier === capsule.stageEngine.subTierUSER ? Math.max(48, capsule.y + capsule.height + 8) : 14) : 0

        enabled: isTuckedMode
        hoverEnabled: true
        cursorShape: isTuckedMode ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.RightButton

        property real lastMoveY: 0

        onEntered: {
            if (isTuckedMode) {
                capsule.stageEngine.userHoverEnter()
            }
        }

        onPositionChanged: (mouse) => {
            if (isTuckedMode && !capsule.stageEngine.tuckArmed) {
                if (Math.abs(mouse.y - lastMoveY) > 8) {
                    capsule.stageEngine.tuckArmed = true
                }
            }
            lastMoveY = mouse.y
        }

        onExited: {
            if (isTuckedMode) {
                capsule.stageEngine.userHoverLeave()
            }
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                lastMoveY = mouse.y
                capsule.stageEngine.toggleTuck()
            }
        }
    }
}