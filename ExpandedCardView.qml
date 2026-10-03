import QtQuick
import QtQuick.Controls
import "expanded"

Item {
    id: cardRoot

    property string chosenFont: ""
    property string expandedTab: "workspace"
    property string previousTab: "workspace"
    property string drillDownPage: ""
    property var enabledTabs: []

    property bool isCalling: false
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""
    property string title: ""
    property string artist: ""
    property string status: "Paused"
    property string artUrl: ""
    property real position: 0
    property real duration: 0
    property color dominantColor: "#22c55e"

    property int wsCurrent: 1
    property int wsTotal: 4
    property string wsName: ""
    property var wsList: []

    property string downSpeedStr: ""
    property string upSpeedStr: ""
    property string localIp: ""
    property string activeTransient: ""

    readonly property alias timerPageRef: persistentTimerPage

    signal cancelCollapse()
    signal requestCollapse()
    signal startCollapse()
    signal timerCompleted(string title, string message)

    function switchRoute(targetTab, targetSubPage) {
        cardRoot.cancelCollapse()
        if (targetTab !== "power" && cardRoot.expandedTab !== "power") {
            cardRoot.previousTab = cardRoot.expandedTab
        }
        cardRoot.drillDownPage = targetSubPage || ""
        cardRoot.expandedTab = targetTab
    }

    readonly property int activeTabIndex: {
        if (!cardRoot.enabledTabs || !cardRoot.enabledTabs.length) return 0
        for (var i = 0; i < cardRoot.enabledTabs.length; i++) {
            if (cardRoot.enabledTabs[i] && cardRoot.enabledTabs[i].key === cardRoot.expandedTab) return i
        }
        return 0
    }

    readonly property var currentTabMeta: {
        if (cardRoot.isCalling) return { title: "TEAMS CALL", sub: "呼叫中", color: Theme.media }
        if (cardRoot.expandedTab === "power") return { title: "SESSION", sub: "系统会话", color: "#ef4444" }
        if (cardRoot.expandedTab === "time") return { title: "LOCAL TIME", sub: "时间与节律", color: Theme.calendar }
        if (cardRoot.expandedTab === "workspace") return { title: "WORKSPACE", sub: cardRoot.wsName ? cardRoot.wsName : ("桌面 " + cardRoot.wsCurrent), color: Theme.workspace }
        if (cardRoot.expandedTab === "media") return { title: "MEDIA", sub: cardRoot.status === "Playing" ? (cardRoot.title || "正在播放") : "已暂停", color: cardRoot.status === "Playing" ? cardRoot.dominantColor : Theme.textMuted }
        if (cardRoot.expandedTab === "calendar") return { title: "CALENDAR", sub: "日历日程", color: Theme.calendar }
        if (cardRoot.expandedTab === "timer") return { title: "TIMER", sub: "专注计时", color: Theme.timer }
        if (cardRoot.expandedTab === "clock") return { title: "WORLD CLOCK", sub: "世界时钟", color: Theme.clock }
        if (cardRoot.expandedTab === "network") return { title: "NETWORK", sub: "网络监控", color: Theme.network }
        if (cardRoot.expandedTab === "bluetooth") return { title: "BLUETOOTH", sub: "蓝牙外设", color: Theme.bluetooth }
        if (cardRoot.expandedTab === "notification") return { title: "NOTIFICATIONS", sub: "消息归档", color: Theme.notification }
        return { title: "ALCOVE ISLAND", sub: "", color: Theme.textSecondary }
    }

    property real tabWheelAccum: 0
    Timer { id: tabWheelResetTimer; interval: 240; onTriggered: cardRoot.tabWheelAccum = 0 }

    function handleTabWheel(wheel) {
        wheel.accepted = true; tabWheelResetTimer.restart()
        var delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y
        cardRoot.tabWheelAccum += delta
        if (Math.abs(cardRoot.tabWheelAccum) >= 60) {
            if (!cardRoot.enabledTabs || cardRoot.enabledTabs.length <= 1) return
            var dir = cardRoot.tabWheelAccum > 0 ? -1 : 1
            var nextIndex = (cardRoot.activeTabIndex + dir + cardRoot.enabledTabs.length) % cardRoot.enabledTabs.length
            cardRoot.switchRoute(cardRoot.enabledTabs[nextIndex].key, "")
            cardRoot.tabWheelAccum = 0
        }
    }

    MouseArea {
        anchors.fill: parent; z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => mouse.accepted = true
    }

    Column {
        anchors.fill: parent; spacing: 12

        // 1. 顶部微胶囊导航中控条组件
        ExpandedHeaderBar {
            chosenFont: cardRoot.chosenFont; expandedTab: cardRoot.expandedTab; previousTab: cardRoot.previousTab
            isCalling: cardRoot.isCalling; enabledTabs: cardRoot.enabledTabs; tabMeta: cardRoot.currentTabMeta
            onTabWheel: (wheel) => cardRoot.handleTabWheel(wheel)
            onSwitchRoute: (targetTab, targetSubPage) => cardRoot.switchRoute(targetTab, targetSubPage)
        }

        // 2. 页面路由分发区
        Item {
            width: parent.width; height: parent.height - 38

            // 来电全屏专属卡片组件
            ExpandedCallCard {
                chosenFont: cardRoot.chosenFont; callTitle: cardRoot.callTitle; callSubtitle: cardRoot.callSubtitle; callAvatar: cardRoot.callAvatar
                isCalling: cardRoot.isCalling; visible: cardRoot.isCalling
                onCollapseRequested: cardRoot.startCollapse()
            }

            TimeDetailPage {
                anchors.fill: parent; chosenFont: cardRoot.chosenFont
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "time")
            }

            WorkspacePage {
                anchors.fill: parent; chosenFont: cardRoot.chosenFont
                currentWs: cardRoot.wsCurrent; totalWs: cardRoot.wsTotal; currentWsName: cardRoot.wsName; wsList: cardRoot.wsList
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "workspace")
            }

            MediaPage {
                anchors.fill: parent; chosenFont: cardRoot.chosenFont
                title: cardRoot.title; artist: cardRoot.artist; status: cardRoot.status; artUrl: cardRoot.artUrl
                position: cardRoot.position; duration: cardRoot.duration; dominantColor: cardRoot.dominantColor
                onCancelCollapse: cardRoot.cancelCollapse(); onRequestCollapse: cardRoot.requestCollapse(); onStartCollapse: cardRoot.startCollapse()
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "media")
            }

            CalendarPage {
                anchors.fill: parent; chosenFont: cardRoot.chosenFont
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "calendar")
            }

            TimerPage {
                id: persistentTimerPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "timer")
                onTimerCompleted: (t, msg) => cardRoot.timerCompleted(t, msg)
            }

            Loader {
                anchors.fill: parent; active: !cardRoot.isCalling && (cardRoot.expandedTab === "clock"); visible: active
                sourceComponent: Component { WorldClockPage { chosenFont: cardRoot.chosenFont; is24h: (typeof Config !== "undefined") ? (Config.timeFormat === "24h") : true } }
            }

            Loader {
                anchors.fill: parent; active: !cardRoot.isCalling && (cardRoot.expandedTab === "network"); visible: active
                sourceComponent: Component { NetworkPage { chosenFont: cardRoot.chosenFont; downSpeed: cardRoot.downSpeedStr; upSpeed: cardRoot.upSpeedStr; localIp: cardRoot.localIp } }
            }

            Loader {
                anchors.fill: parent; active: !cardRoot.isCalling && (cardRoot.expandedTab === "bluetooth"); visible: active
                sourceComponent: Component { BluetoothPage { chosenFont: cardRoot.chosenFont } }
            }

            Loader {
                id: notifLoader; anchors.fill: parent; active: !cardRoot.isCalling && (cardRoot.expandedTab === "notification"); visible: active
                sourceComponent: Component { NotificationPage { chosenFont: cardRoot.chosenFont } }
                Connections { target: notifLoader.item; ignoreUnknownSignals: true; function onStartCollapse() { cardRoot.startCollapse() } }
            }

            Loader {
                id: powerLoader; anchors.fill: parent; active: !cardRoot.isCalling && (cardRoot.expandedTab === "power"); visible: active
                sourceComponent: Component { PowerPage { chosenFont: cardRoot.chosenFont } }
                Connections { target: powerLoader.item; ignoreUnknownSignals: true; function onStartCollapse() { cardRoot.startCollapse() } }
            }
        }
    }
}