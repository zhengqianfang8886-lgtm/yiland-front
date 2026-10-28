// ==========================================
// 📄 File: ui/views/ExpandedCardView.qml
// 🌟 展开态卡片中枢 (彻底移除 Workspace 与 Hardware 展开卡片版)
// ==========================================
import QtQuick
import QtQuick.Controls
import "../components/expanded"
import "../components/pages"

Item {
    id: cardRoot
    anchors.fill: parent

    property var fsm: null
    property var relay: null
    property string chosenFont: ""

    // 默认展开落在日历页
    property string activeTabId: "calendar"
    property var sensorCoordinator: null

    readonly property var enabledPlugins: {
        var order = (typeof Config !== "undefined" && Config.tabOrder && Config.tabOrder.length > 0) ? 
                    Config.tabOrder : 
                    ["media", "calendar", "timer", "clock", "notification"];

        // 🚀 仅保留纯粹需要展开的页面元数据 (已剔除 hardware 与 workspace)
        var allMeta = {
            "media":        { id: "media",        title: "MEDIA",          sub: (cardRoot.relay && cardRoot.relay.status === "Playing") ? cardRoot.relay.title : "媒体播控", color: (cardRoot.relay && cardRoot.relay.status === "Playing") ? cardRoot.relay.dominantColor : "#22c55e" },
            "calendar":     { id: "calendar",     title: "CALENDAR",       sub: "系统日历", color: "#38bdf8" },
            "timer":        { id: "timer",        title: "TIMER",          sub: "专注时钟", color: Theme.timer },
            "clock":        { id: "clock",        title: "WORLD CLOCK",    sub: "世界时区", color: Theme.clock },
            "notification": { id: "notification", title: "NOTIFICATIONS",  sub: "通知归档", color: Theme.notification }
        };

        var list = [];
        for (var i = 0; i < order.length; i++) {
            var k = order[i];
            if (k === "workspace" || k === "hardware") continue; // 绝对不进展开态

            var isEnabled = true;
            if (typeof Config !== "undefined") {
                if (k === "media") isEnabled = Config.showMediaTab !== false;
                else if (k === "calendar") isEnabled = Config.showCalendarTab !== false;
                else if (k === "timer") isEnabled = Config.showTimerTab !== false;
                else if (k === "clock") isEnabled = Config.showClockTab !== false;
                else if (k === "notification") isEnabled = Config.showNotificationTab !== false;
            }
            if (isEnabled && allMeta[k]) {
                list.push(allMeta[k]);
            }
        }
        return list;
    }

    signal requestSettings()

    readonly property var currentTabMeta: {
        for (var i = 0; i < enabledPlugins.length; i++) {
            if (enabledPlugins[i].id === activeTabId) {
                return enabledPlugins[i];
            }
        }
        if (enabledPlugins.length > 0) return enabledPlugins[0];
        return { title: "CALENDAR", sub: "系统日历", color: "#38bdf8" };
    }

    function getPluginIndex(tabId) {
        for (var i = 0; i < enabledPlugins.length; i++) {
            if (enabledPlugins[i].id === tabId) return i;
        }
        return 0;
    }

    function switchTab(targetId, explicitDir) {
        if (!targetId || activeTabId === targetId) return;

        var curIdx = getPluginIndex(activeTabId);
        var targetIdx = getPluginIndex(targetId);
        var calculatedDir = (explicitDir !== undefined) ? explicitDir : (targetIdx >= curIdx ? 1 : -1);

        activeTabId = targetId;
        pageConveyor.switchTo(targetId, calculatedDir);
    }

    property real tabWheelAccum: 0
    property bool isTabWheelCooldown: false

    Timer { id: tabWheelResetTimer; interval: 260; onTriggered: cardRoot.tabWheelAccum = 0 }
    Timer { id: tabWheelCooldownTimer; interval: 140; onTriggered: cardRoot.isTabWheelCooldown = false }

    function handleHeaderWheel(wheel) {
        if (cardRoot.isTabWheelCooldown) return;
        tabWheelResetTimer.restart();

        var delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y;
        cardRoot.tabWheelAccum += delta;

        if (Math.abs(cardRoot.tabWheelAccum) >= 100) {
            if (!cardRoot.enabledPlugins || cardRoot.enabledPlugins.length <= 1) return;
            var dir = cardRoot.tabWheelAccum > 0 ? -1 : 1;
            var currIdx = getPluginIndex(cardRoot.activeTabId);
            var nextIndex = (currIdx + dir + cardRoot.enabledPlugins.length) % cardRoot.enabledPlugins.length;
            
            cardRoot.switchTab(cardRoot.enabledPlugins[nextIndex].id, dir);
            cardRoot.tabWheelAccum = 0;
            cardRoot.isTabWheelCooldown = true;
            tabWheelCooldownTimer.restart();
        }
    }

    // 1. 顶栏
    ExpandedHeaderBar {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 26
        z: 10

        chosenFont: cardRoot.chosenFont
        expandedTab: cardRoot.activeTabId
        enabledTabs: cardRoot.enabledPlugins
        tabMeta: cardRoot.currentTabMeta
        onSwitchRoute: (targetTab) => cardRoot.switchTab(targetTab)
        onRequestSettings: cardRoot.requestSettings()
        onTabWheel: (wheel) => cardRoot.handleHeaderWheel(wheel)
    }

    // 2. 传送带
    Item {
        id: contentContainer
        anchors.top: headerBar.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true

        InterruptibleConveyor {
            id: pageConveyor
            anchors.fill: parent
            currentKey: cardRoot.activeTabId
            keyToComponentMap: ({
                "media": compMedia,
                "calendar": compCalendar,
                "timer": compTimer,
                "clock": compClock,
                "notification": compNotification
            })
        }
    }

    // 🚀 已彻底删除 compWorkspace (以及 compHardware)
    Component { 
        id: compMedia
        MediaPage { 
            chosenFont: cardRoot.chosenFont
            title: cardRoot.relay ? cardRoot.relay.title : ""
            artist: cardRoot.relay ? cardRoot.relay.artist : ""
            status: cardRoot.relay ? cardRoot.relay.status : "Paused"
            artUrl: cardRoot.relay ? cardRoot.relay.artUrl : ""
            position: cardRoot.relay ? cardRoot.relay.position : 0
            duration: cardRoot.relay ? cardRoot.relay.duration : 0
            dominantColor: cardRoot.relay ? cardRoot.relay.dominantColor : "#22c55e"
            onStartCollapse: if (cardRoot.fsm) cardRoot.fsm.handleIntent("COLLAPSE", { source: "MediaPage_Collapse" })
        } 
    }
    Component { id: compCalendar; CalendarPage { chosenFont: cardRoot.chosenFont } }
    Component { id: compTimer; TimerPage { chosenFont: cardRoot.chosenFont } }
    Component { id: compClock; WorldClockPage { chosenFont: cardRoot.chosenFont } }
    Component { id: compNotification; NotificationPage { chosenFont: cardRoot.chosenFont } }

    Component.onCompleted: {
        if (enabledPlugins.length > 0) {
            activeTabId = enabledPlugins[0].id;
        }
    }
}