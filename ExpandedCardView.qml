// ==========================================
// 📄 File: ExpandedCardView.qml (类型安全与零报错加固版)
// ==========================================
import QtQuick
import QtQuick.Controls
import "expanded"
import "pages"

Item {
    id: cardRoot

    property string chosenFont: ""
    property string expandedTab: "time"
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

    // 专注计时器常驻数据代理接口
    readonly property bool timerActive: persistentTimerPage.isRunning || persistentTimerPage.isPaused || persistentTimerPage.isCompleted
    readonly property bool timerIsPaused: persistentTimerPage.isPaused
    readonly property bool timerIsCompleted: persistentTimerPage.isCompleted
    readonly property string timerFormattedText: persistentTimerPage.formattedTime
    readonly property real timerProgress: persistentTimerPage.progress

    function toggleTimerPause() { persistentTimerPage.togglePause() }

    signal startCollapse()
    signal timerCompleted(string title, string message)
    signal requestSettings()

    // =========================================================================
    // 卡片独立鼠标生命周期管理器（防穿透 + 从容折叠）
    // =========================================================================
    Timer {
        id: cardLeaveGraceTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (!cardHoverHandler.hovered) {
                cardRoot.startCollapse()
            }
        }
    }

    HoverHandler {
        id: cardHoverHandler
        onHoveredChanged: {
            if (hovered) {
                cardLeaveGraceTimer.stop()
            } else {
                cardLeaveGraceTimer.restart()
            }
        }
    }

    // 底层点击拦截盾牌：防止点击卡片内部空白区域穿透
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => mouse.accepted = true
        onClicked: (mouse) => mouse.accepted = true
    }

    // 顶栏元数据解析
    readonly property var currentTabMeta: {
        if (cardRoot.isCalling) return { title: "TEAMS CALL", sub: "呼叫中", color: Theme.media }
        if (cardRoot.expandedTab === "time") return { title: "LOCAL TIME", sub: "时间与节律", color: Theme.calendar }
        if (cardRoot.expandedTab === "hardware") return { title: "CONTROL CENTER", sub: "硬件与系统控制", color: "#f59e0b" }
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

    function getRingSlotIndex(key) {
        if (!cardRoot.enabledTabs) return -1
        for (var i = 0; i < cardRoot.enabledTabs.length; i++) {
            if (cardRoot.enabledTabs[i] && cardRoot.enabledTabs[i].key === key) return i
        }
        return -1
    }

    function switchRoute(targetTab, explicitDir) {
        var dir = explicitDir
        if (dir === undefined || dir === 0) {
            var oldIdx = getRingSlotIndex(cardRoot.expandedTab)
            var newIdx = getRingSlotIndex(targetTab)
            var N = cardRoot.enabledTabs ? cardRoot.enabledTabs.length : 1
            if (oldIdx >= 0 && newIdx >= 0 && N > 1) {
                var diff = newIdx - oldIdx
                if (diff > (N / 2)) diff -= N
                else if (diff < -(N / 2)) diff += N
                dir = (diff >= 0) ? 1 : -1
            } else {
                dir = 1
            }
        }
        cardRoot.expandedTab = targetTab
        conveyor.switchTo(targetTab, dir)
    }

    // 滚轮切页支持
    property real tabWheelAccum: 0
    Timer { id: tabWheelResetTimer; interval: Theme.animSlow; onTriggered: cardRoot.tabWheelAccum = 0 }

    function handleTabWheel(wheel) {
        wheel.accepted = true
        tabWheelResetTimer.restart()
        var delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y
        cardRoot.tabWheelAccum += delta

        if (Math.abs(cardRoot.tabWheelAccum) >= 48) {
            if (!cardRoot.enabledTabs || cardRoot.enabledTabs.length <= 1) return
            var dir = cardRoot.tabWheelAccum > 0 ? -1 : 1
            var currIdx = getRingSlotIndex(cardRoot.expandedTab)
            var nextIndex = (currIdx + dir + cardRoot.enabledTabs.length) % cardRoot.enabledTabs.length

            cardRoot.switchRoute(cardRoot.enabledTabs[nextIndex].key, dir)
            cardRoot.tabWheelAccum = 0
        }
    }

    Column {
        anchors.fill: parent
        spacing: 10

        ExpandedHeaderBar {
            chosenFont: cardRoot.chosenFont
            expandedTab: cardRoot.expandedTab
            isCalling: cardRoot.isCalling
            enabledTabs: cardRoot.enabledTabs
            tabMeta: cardRoot.currentTabMeta
            onTabWheel: (wheel) => cardRoot.handleTabWheel(wheel)
            onSwitchRoute: (targetTab) => cardRoot.switchRoute(targetTab)
            onRequestSettings: cardRoot.requestSettings()
        }

        Item {
            id: viewport
            width: parent.width
            height: parent.height - 36
            clip: true

            ExpandedCallCard {
                z: 100
                chosenFont: cardRoot.chosenFont
                callTitle: cardRoot.callTitle; callSubtitle: cardRoot.callSubtitle; callAvatar: cardRoot.callAvatar
                isCalling: cardRoot.isCalling
                visible: cardRoot.isCalling
                onCollapseRequested: cardRoot.startCollapse()
            }

            // 可打断主传送带
            InterruptibleConveyor {
                id: conveyor
                anchors.fill: parent
                currentKey: cardRoot.expandedTab

                keyToComponentMap: ({
                    "time": compTime,
                    "hardware": compHardware,
                    "workspace": compWorkspace,
                    "media": compMedia,
                    "calendar": compCalendar,
                    "timer": null,
                    "clock": compClock,
                    "network": compNetwork,
                    "bluetooth": compBluetooth,
                    "notification": compNotification
                })
            }

            // 常驻计时器视口联动
            TimerPage {
                id: persistentTimerPage
                width: parent.width
                height: parent.height
                chosenFont: cardRoot.chosenFont
                z: 10
                visible: conveyor.activeKey === "timer" || conveyor.departingKey === "timer"
                x: {
                    if (conveyor.activeKey === "timer") {
                        return conveyor.slideOffset
                    }
                    if (conveyor.departingKey === "timer") {
                        return conveyor.slideOffset - (conveyor.slideDir > 0 ? conveyor.width : -conveyor.width)
                    }
                    return conveyor.width
                }
                onTimerCompleted: (t, msg) => cardRoot.timerCompleted(t, msg)
            }
        }
    }

    Component { id: compTime; TimeDetailPage { chosenFont: cardRoot.chosenFont } }
    Component { id: compHardware; HardwarePage { chosenFont: cardRoot.chosenFont; onRequestSettings: cardRoot.requestSettings() } }
    Component {
        id: compWorkspace
        WorkspacePage {
            chosenFont: cardRoot.chosenFont
            currentWs: cardRoot.wsCurrent; totalWs: cardRoot.wsTotal
            currentWsName: cardRoot.wsName; wsList: cardRoot.wsList
        }
    }
    Component {
        id: compMedia
        MediaPage {
            chosenFont: cardRoot.chosenFont
            title: cardRoot.title; artist: cardRoot.artist
            status: cardRoot.status; artUrl: cardRoot.artUrl
            position: cardRoot.position; duration: cardRoot.duration
            dominantColor: cardRoot.dominantColor
            onStartCollapse: cardRoot.startCollapse()
        }
    }
    Component { id: compCalendar; CalendarPage { chosenFont: cardRoot.chosenFont } }
    Component { id: compClock; WorldClockPage { chosenFont: cardRoot.chosenFont } }
    Component { 
        id: compNetwork
        NetworkPage { 
            chosenFont: cardRoot.chosenFont
            downSpeed: cardRoot.downSpeedStr
            upSpeed: cardRoot.upSpeedStr
            localIp: cardRoot.localIp 
        } 
    }
    Component { id: compBluetooth; BluetoothPage { chosenFont: cardRoot.chosenFont } }
    Component {
        id: compNotification
        NotificationPage {
            chosenFont: cardRoot.chosenFont
        }
    }
}