// ==========================================
// 📄 File: Island.qml (平滑单向迟滞天花板感应版)
// ==========================================
import QtQuick
import QtQuick.Controls

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
            capsule.stageEngine.pushTransient("SEDENTARY", 0)
        }
        onDismissAlert: {
            capsule.stageEngine.popTransient("SEDENTARY")
        }
    }

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

    // 核心胶囊
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

    // =========================================================================
    // 6. 🚀【全新】：零抽搐·单向迟滞天花板鼠标感应网
    // =========================================================================
    MouseArea {
        id: ceilingHoverNet
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Math.max(180, capsule.width + 32)
        z: 99

        readonly property bool isTuckedMode: capsule.stageEngine.currentBaseTier === capsule.stageEngine.tierTUCKED
        readonly property bool isUserPeeking: capsule.stageEngine.submergedSubTier === capsule.stageEngine.subTierUSER

        // 迟滞感应高度：常态深潜时只占顶端 14px，一旦用户探出，无缝覆盖至胶囊底部，杜绝脱靶
        height: isTuckedMode ? (isUserPeeking ? Math.max(52, capsule.y + capsule.height + 12) : 14) : 0

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
            if (isTuckedMode) {
                // 如果鼠标已经开始大范围移动（说明已经离开原位右键位置），强制充满武装
                if (!capsule.stageEngine.tuckArmed) {
                    if (Math.abs(mouse.y - lastMoveY) > 6) {
                        capsule.stageEngine.tuckArmed = true
                        capsule.stageEngine.userHoverEnter()
                    }
                }
                capsule.stageEngine.userHoverKeep()
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