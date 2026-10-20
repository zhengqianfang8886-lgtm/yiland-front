// ==========================================
// 📄 File: ui/views/ExpandedCardView.qml
// 🌟 展开态卡片中枢 (消灭特权挂载 · 传送带统一接管全量视图)
// ==========================================
import QtQuick
import QtQuick.Controls
import "../components/expanded"
import "../components/pages"

Item {
    id: cardRoot

    property string chosenFont: ""
    property string expandedTab: "hardware"
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

    signal startCollapse()
    signal requestSettings()

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

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => mouse.accepted = true
        onClicked: (mouse) => mouse.accepted = true
    }

    readonly property var currentTabMeta: {
        if (cardRoot.isCalling) return { title: "TEAMS CALL", sub: "呼叫中", color: Theme.media }
        if (cardRoot.expandedTab === "hardware") return { title: "CONTROL CENTER", sub: "硬件与系统控制", color: "#f59e0b" }
        if (cardRoot.expandedTab === "workspace") return { title: "WORKSPACE", sub: cardRoot.wsName ? cardRoot.wsName : ("桌面 " + cardRoot.wsCurrent), color: Theme.workspace }
        if (cardRoot.expandedTab === "media") return { title: "MEDIA", sub: cardRoot.status === "Playing" ? (cardRoot.title || "正在播放") : "已暂停", color: cardRoot.status === "Playing" ? cardRoot.dominantColor : Theme.textMuted }
        if (cardRoot.expandedTab === "calendar") return { title: "CALENDAR", sub: "日历日程", color: Theme.calendar }
        if (cardRoot.expandedTab === "timer") return { title: "TIMER", sub: "专注计时", color: Theme.timer }
        if (cardRoot.expandedTab === "clock") return { title: "WORLD CLOCK", sub: "世界时钟", color: Theme.clock }
        if (cardRoot.expandedTab === "notification") return { title: "NOTIFICATIONS", sub: "消息归档", color: Theme.notification }
        return { title: "CONTROL CENTER", sub: "", color: Theme.textSecondary }
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

            // 🚀【彻底统一】：Timer 重新回归传送带标准调度，消除所有外部特权贴纸
            InterruptibleConveyor {
                id: conveyor
                anchors.fill: parent
                currentKey: cardRoot.expandedTab

                keyToComponentMap: ({
                    "hardware": compHardware,
                    "workspace": compWorkspace,
                    "media": compMedia,
                    "calendar": compCalendar,
                    "timer": compTimer,
                    "clock": compClock,
                    "notification": compNotification
                })
            }
        }
    }

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
    Component { id: compTimer; TimerPage { chosenFont: cardRoot.chosenFont } }
    Component { id: compClock; WorldClockPage { chosenFont: cardRoot.chosenFont } }
    Component { id: compNotification; NotificationPage { chosenFont: cardRoot.chosenFont } }
}