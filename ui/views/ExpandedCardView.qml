// =========================================================================
// 📄 File: ui/views/ExpandedCardView.qml
// 🌟 展开态卡片中枢 (滚轮切页主动刹车 · 免疫收缩干扰版)
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

    property string activeTabId: "hardware"

    // 关联外部协调器进行交互制动
    property var sensorCoordinator: null

    readonly property var enabledPlugins: {
        var order = (typeof Config !== "undefined" && Config.tabOrder && Config.tabOrder.length > 0) ? 
                    Config.tabOrder : 
                    ["hardware", "workspace", "media", "calendar", "timer", "clock", "notification"];

        var allMeta = {
            "hardware":     { id: "hardware",     title: "CONTROL CENTER", sub: "硬件与系统控制", color: "#f59e0b" },
            "workspace":    { id: "workspace",    title: "WORKSPACE",      sub: (cardRoot.relay && cardRoot.relay.wsName) ? cardRoot.relay.wsName : "工作空间", color: Theme.workspace },
            "media":        { id: "media",        title: "MEDIA",          sub: (cardRoot.relay && cardRoot.relay.status === "Playing") ? cardRoot.relay.title : "媒体播控", color: (cardRoot.relay && cardRoot.relay.status === "Playing") ? cardRoot.relay.dominantColor : "#22c55e" },
            "calendar":     { id: "calendar",     title: "CALENDAR",       sub: "日程打卡", color: Theme.calendar },
            "timer":        { id: "timer",        title: "TIMER",          sub: "专注时钟", color: Theme.timer },
            "clock":        { id: "clock",        title: "WORLD CLOCK",    sub: "世界时区", color: Theme.clock },
            "notification": { id: "notification", title: "NOTIFICATIONS",  sub: "通知归档", color: Theme.notification }
        };

        var list = [];
        for (var i = 0; i < order.length; i++) {
            var k = order[i];
            var isEnabled = true;
            if (typeof Config !== "undefined") {
                if (k === "hardware") isEnabled = Config.showHardwareTab !== false;
                else if (k === "workspace") isEnabled = Config.showWorkspaceTab !== false;
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
        return { title: "CONTROL CENTER", sub: "硬件与系统控制", color: "#f59e0b" };
    }

    function switchTab(targetId) {
        if (activeTabId === targetId) return;
        activeTabId = targetId;
    }

    // 顶栏专用滚轮切页计算器
    property real tabWheelAccum: 0
    Timer { id: tabWheelResetTimer; interval: 260; onTriggered: cardRoot.tabWheelAccum = 0 }

    function handleHeaderWheel(wheel) {
        tabWheelResetTimer.restart();
        
        // 🚀【主动制动】：滚轮滚动期间，立刻刹停收起倒计时
        if (cardRoot.sensorCoordinator && cardRoot.sensorCoordinator.brakeTimerOnWheel) {
            cardRoot.sensorCoordinator.brakeTimerOnWheel();
        }

        var delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y;
        cardRoot.tabWheelAccum += delta;

        if (Math.abs(cardRoot.tabWheelAccum) >= 40) {
            if (!cardRoot.enabledPlugins || cardRoot.enabledPlugins.length <= 1) return;
            var dir = cardRoot.tabWheelAccum > 0 ? -1 : 1;
            var currIdx = 0;
            for (var i = 0; i < cardRoot.enabledPlugins.length; i++) {
                if (cardRoot.enabledPlugins[i].id === cardRoot.activeTabId) {
                    currIdx = i;
                    break;
                }
            }
            var nextIndex = (currIdx + dir + cardRoot.enabledPlugins.length) % cardRoot.enabledPlugins.length;
            cardRoot.switchTab(cardRoot.enabledPlugins[nextIndex].id);
            cardRoot.tabWheelAccum = 0;
        }
    }

    Column {
        anchors.fill: parent
        spacing: 10

        // 1. 顶栏导航与状态条 (唯一允许滚轮切页的区域)
        ExpandedHeaderBar {
            chosenFont: cardRoot.chosenFont
            expandedTab: cardRoot.activeTabId
            enabledTabs: cardRoot.enabledPlugins
            tabMeta: cardRoot.currentTabMeta
            onSwitchRoute: (targetTab) => cardRoot.switchTab(targetTab)
            onRequestSettings: cardRoot.requestSettings()
            onTabWheel: (wheel) => cardRoot.handleHeaderWheel(wheel)
        }

        // 2. 核心动态内容视口 (常驻懒加载池，滚轮属于页面内部滚动，绝不切页)
        Item {
            id: contentContainer
            width: parent.width
            height: parent.height - 36
            clip: true

            Loader {
                id: loaderHardware
                anchors.fill: parent
                active: cardRoot.activeTabId === "hardware" || (item !== null)
                visible: cardRoot.activeTabId === "hardware"
                sourceComponent: compHardware
            }

            Loader {
                id: loaderWorkspace
                anchors.fill: parent
                active: cardRoot.activeTabId === "workspace" || (item !== null)
                visible: cardRoot.activeTabId === "workspace"
                sourceComponent: compWorkspace
            }

            Loader {
                id: loaderMedia
                anchors.fill: parent
                active: cardRoot.activeTabId === "media" || (item !== null)
                visible: cardRoot.activeTabId === "media"
                sourceComponent: compMedia
            }

            Loader {
                id: loaderCalendar
                anchors.fill: parent
                active: cardRoot.activeTabId === "calendar" || (item !== null)
                visible: cardRoot.activeTabId === "calendar"
                sourceComponent: compCalendar
            }

            Loader {
                id: loaderTimer
                anchors.fill: parent
                active: cardRoot.activeTabId === "timer" || (item !== null)
                visible: cardRoot.activeTabId === "timer"
                sourceComponent: compTimer
            }

            Loader {
                id: loaderClock
                anchors.fill: parent
                active: cardRoot.activeTabId === "clock" || (item !== null)
                visible: cardRoot.activeTabId === "clock"
                sourceComponent: compClock
            }

            Loader {
                id: loaderNotification
                anchors.fill: parent
                active: cardRoot.activeTabId === "notification" || (item !== null)
                visible: cardRoot.activeTabId === "notification"
                sourceComponent: compNotification
            }
        }
    }

    Component {
        id: compHardware
        HardwarePage {
            chosenFont: cardRoot.chosenFont
            onRequestSettings: cardRoot.requestSettings()
        }
    }

    Component {
        id: compWorkspace
        WorkspacePage {
            chosenFont: cardRoot.chosenFont
            currentWs: cardRoot.relay ? cardRoot.relay.wsCurrent : 1
            totalWs: cardRoot.relay ? cardRoot.relay.wsTotal : 4
            currentWsName: cardRoot.relay ? cardRoot.relay.wsName : ""
            wsList: cardRoot.relay ? cardRoot.relay.wsList : []
        }
    }

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

    Component {
        id: compCalendar
        CalendarPage {
            chosenFont: cardRoot.chosenFont
        }
    }

    Component {
        id: compTimer
        TimerPage {
            chosenFont: cardRoot.chosenFont
        }
    }

    Component {
        id: compClock
        WorldClockPage {
            chosenFont: cardRoot.chosenFont
        }
    }

    Component {
        id: compNotification
        NotificationPage {
            chosenFont: cardRoot.chosenFont
        }
    }

    Component.onCompleted: {
        if (enabledPlugins.length > 0) {
            activeTabId = enabledPlugins[0].id;
        }
    }
}