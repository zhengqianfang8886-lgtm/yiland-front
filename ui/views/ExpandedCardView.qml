// =========================================================================
// 📄 File: ui/views/ExpandedCardView.qml
// 🌟 展开态卡片中枢 (移除硬件控制页纯净版)
// =========================================================================
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

    property string activeTabId: "workspace"
    property var sensorCoordinator: null

    readonly property var enabledPlugins: {
        var order = (typeof Config !== "undefined" && Config.tabOrder && Config.tabOrder.length > 0) ? 
                    Config.tabOrder : 
                    ["workspace", "media", "calendar", "timer", "clock", "notification"];

        var allMeta = {
            "workspace":    { id: "workspace",    title: "WORKSPACE",      sub: (cardRoot.relay && cardRoot.relay.wsName) ? cardRoot.relay.wsName : "工作空间", color: Theme.workspace },
            "media":        { id: "media",        title: "MEDIA",          sub: (cardRoot.relay && cardRoot.relay.status === "Playing") ? cardRoot.relay.title : "媒体播控", color: (cardRoot.relay && cardRoot.relay.status === "Playing") ? cardRoot.relay.dominantColor : "#22c55e" },
            "calendar":     { id: "calendar",     title: "CALENDAR",       sub: "系统日历", color: "#38bdf8" },
            "timer":        { id: "timer",        title: "TIMER",          sub: "专注时钟", color: Theme.timer },
            "clock":        { id: "clock",        title: "WORLD CLOCK",    sub: "世界时区", color: Theme.clock },
            "notification": { id: "notification", title: "NOTIFICATIONS",  sub: "通知归档", color: Theme.notification }
        };

        var list = [];
        for (var i = 0; i < order.length; i++) {
            var k = order[i];
            var isEnabled = true;
            if (typeof Config !== "undefined") {
                if (k === "workspace") isEnabled = Config.showWorkspaceTab !== false;
                else if (k === "media") isEnabled = Config.showMediaTab !== false;
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
        return { title: "WORKSPACE", sub: "工作空间", color: Theme.workspace };
    }

    function getPluginIndex(tabId) {
        for (var i = 0; i < enabledPlugins.length; i++) {
            if (enabledPlugins[i].id === tabId) return i;
        }
        return 0;
    }

    function switchTab(targetId, explicitDir) {
        if (activeTabId === targetId) return;

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
                "workspace": compWorkspace,
                "media": compMedia,
                "calendar": compCalendar,
                "timer": compTimer,
                "clock": compClock,
                "notification": compNotification
            })
        }
    }

    Component { id: compWorkspace; WorkspacePage { chosenFont: cardRoot.chosenFont; currentWs: cardRoot.relay ? cardRoot.relay.wsCurrent : 1; totalWs: cardRoot.relay ? cardRoot.relay.wsTotal : 4; currentWsName: cardRoot.relay ? cardRoot.relay.wsName : ""; wsList: cardRoot.relay ? cardRoot.relay.wsList : [] } }
    Component { id: compMedia; MediaPage { chosenFont: cardRoot.chosenFont; title: cardRoot.relay ? cardRoot.relay.title : ""; artist: cardRoot.relay ? cardRoot.relay.artist : ""; status: cardRoot.relay ? cardRoot.relay.status : "Paused"; artUrl: cardRoot.relay ? cardRoot.relay.artUrl : ""; position: cardRoot.relay ? cardRoot.relay.position : 0; duration: cardRoot.relay ? cardRoot.relay.duration : 0; dominantColor: cardRoot.relay ? cardRoot.relay.dominantColor : "#22c55e"; onStartCollapse: if (cardRoot.fsm) cardRoot.fsm.handleIntent("COLLAPSE", { source: "MediaPage_Collapse" }) } }
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