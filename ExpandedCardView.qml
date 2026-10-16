// ==========================================
// 📄 File: ExpandedCardView.qml
// ==========================================
import QtQuick
import QtQuick.Controls
import "expanded"
import "pages"

Item {
    id: cardRoot

    property string chosenFont: ""
    property string expandedTab: "workspace"
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
    signal requestSettings()

    readonly property int viewportWidth: width
    readonly property int viewportHeight: height - 36
    readonly property int slotGap: 16
    readonly property int slotPitch: viewportWidth + slotGap

    property string currentKey: "time"
    property string departingKey: ""
    property int slideDir: 1
    property real transitionProgress: 1.0
    property bool isFastWheeling: false

    function getRingSlotIndex(key) {
        if (!cardRoot.enabledTabs) return -1
        for (var i = 0; i < cardRoot.enabledTabs.length; i++) {
            if (cardRoot.enabledTabs[i] && cardRoot.enabledTabs[i].key === key) return i
        }
        return -1
    }

    function getPanelX(key) {
        var S = cardRoot.slotPitch
        if (key === cardRoot.currentKey) {
            if (cardRoot.departingKey === "" || !conveyorAnim.running) return 0
            return cardRoot.slideDir > 0 ? (S * (1.0 - cardRoot.transitionProgress)) : (-S * (1.0 - cardRoot.transitionProgress))
        }

        if (key === cardRoot.departingKey && conveyorAnim.running) {
            return cardRoot.slideDir > 0 ? (-S * cardRoot.transitionProgress) : (S * cardRoot.transitionProgress)
        }
        return S
    }

    function isPanelVisible(key) {
        if (key === cardRoot.currentKey) return true
        if (key === cardRoot.departingKey && conveyorAnim.running) return true
        return false
    }

    function triggerConveyorTransition(newKey, forcedDir) {
        if (newKey === cardRoot.currentKey && cardRoot.departingKey === "") return

        if (forcedDir !== undefined && forcedDir !== 0) {
            cardRoot.slideDir = forcedDir
        } else {
            var oldIdx = getRingSlotIndex(cardRoot.currentKey)
            var newIdx = getRingSlotIndex(newKey)
            var N = cardRoot.enabledTabs ? cardRoot.enabledTabs.length : 1

            if (oldIdx >= 0 && newIdx >= 0 && N > 1) {
                var diff = newIdx - oldIdx
                if (diff > (N / 2)) diff -= N
                else if (diff < -(N / 2)) diff += N
                cardRoot.slideDir = (diff >= 0) ? 1 : -1
            } else {
                cardRoot.slideDir = 1
            }
        }

        var startProgress = 0.0
        if (conveyorAnim.running) {
            conveyorAnim.stop()
            startProgress = 0.0
        }

        cardRoot.departingKey = cardRoot.currentKey
        cardRoot.currentKey = newKey

        conveyorAnim.duration = cardRoot.isFastWheeling ? Theme.animFast : Theme.animSlow
        conveyorAnim.easing.type = cardRoot.isFastWheeling ? Theme.curveDecel : Theme.curveSpring
        conveyorAnim.easing.overshoot = cardRoot.isFastWheeling ? 1.0 : Theme.springOvershootSubtle
        cardRoot.transitionProgress = startProgress
        conveyorAnim.start()
    }

    NumberAnimation {
        id: conveyorAnim
        target: cardRoot
        property: "transitionProgress"
        from: 0.0; to: 1.0
        onFinished: { cardRoot.departingKey = "" }
    }

    property bool timeLoaded: true
    property bool hardwareLoaded: false
    property bool workspaceLoaded: false
    property bool mediaLoaded: false
    property bool calendarLoaded: false
    property bool clockLoaded: false
    property bool networkLoaded: false
    property bool bluetoothLoaded: false
    property bool notificationLoaded: false

    onExpandedTabChanged: {
        if (expandedTab === "time") timeLoaded = true
        else if (expandedTab === "hardware") hardwareLoaded = true
        else if (expandedTab === "workspace") workspaceLoaded = true
        else if (expandedTab === "media") mediaLoaded = true
        else if (expandedTab === "calendar") calendarLoaded = true
        else if (expandedTab === "clock") clockLoaded = true
        else if (expandedTab === "network") networkLoaded = true
        else if (expandedTab === "bluetooth") bluetoothLoaded = true
        else if (expandedTab === "notification") notificationLoaded = true

        if (expandedTab !== currentKey) triggerConveyorTransition(expandedTab, 0)
    }

    function switchRoute(targetTab, explicitDir) {
        cardRoot.cancelCollapse()
        triggerConveyorTransition(targetTab, explicitDir)
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

    property real tabWheelAccum: 0
    Timer { id: tabWheelResetTimer; interval: Theme.animSlow; onTriggered: cardRoot.tabWheelAccum = 0 }
    Timer { id: fastWheelResetTimer; interval: Theme.animSlow; onTriggered: cardRoot.isFastWheeling = false }

    function handleTabWheel(wheel) {
        wheel.accepted = true
        tabWheelResetTimer.restart()
        var delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y
        cardRoot.tabWheelAccum += delta

        if (Math.abs(cardRoot.tabWheelAccum) >= 48) {
            if (!cardRoot.enabledTabs || cardRoot.enabledTabs.length <= 1) return
            var dir = cardRoot.tabWheelAccum > 0 ? -1 : 1
            var nextIndex = (cardRoot.activeTabIndex + dir + cardRoot.enabledTabs.length) % cardRoot.enabledTabs.length

            cardRoot.isFastWheeling = true
            fastWheelResetTimer.restart()
            cardRoot.switchRoute(cardRoot.enabledTabs[nextIndex].key, dir)
            cardRoot.tabWheelAccum = 0
        }
    }

    MouseArea {
        anchors.fill: parent; z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => mouse.accepted = true
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
            // 🚀 连接顶栏齿轮到全局偏好设置信号
            onRequestSettings: cardRoot.requestSettings()
        }

        Item {
            id: conveyorViewport
            width: cardRoot.viewportWidth
            height: cardRoot.viewportHeight
            clip: true

            ExpandedCallCard {
                z: 100
                chosenFont: cardRoot.chosenFont
                callTitle: cardRoot.callTitle
                callSubtitle: cardRoot.callSubtitle
                callAvatar: cardRoot.callAvatar
                isCalling: cardRoot.isCalling
                visible: cardRoot.isCalling
                onCollapseRequested: cardRoot.startCollapse()
            }

            Item {
                id: conveyorBeltCanvas
                anchors.fill: parent

                // 1. 本地时间页
                Item {
                    id: panelTime
                    x: cardRoot.getPanelX("time")
                    width: cardRoot.viewportWidth; height: cardRoot.viewportHeight
                    visible: cardRoot.isPanelVisible("time")
                    Loader {
                        anchors.fill: parent; active: cardRoot.timeLoaded
                        sourceComponent: Component { TimeDetailPage { chosenFont: cardRoot.chosenFont } }
                    }
                }

                // 2. 硬件控制页
                Item {
                    id: panelHardware
                    x: cardRoot.getPanelX("hardware")
                    width: cardRoot.viewportWidth; height: cardRoot.viewportHeight
                    visible: cardRoot.isPanelVisible("hardware")
                    Loader {
                        anchors.fill: parent; active: cardRoot.hardwareLoaded
                        sourceComponent: Component {
                            HardwarePage {
                                chosenFont: cardRoot.chosenFont
                                onRequestSettings: cardRoot.requestSettings()
                            }
                        }
                    }
                }

                // 3. 工作区页面
                Item {
                    id: panelWorkspace
                    x: cardRoot.getPanelX("workspace")
                    width: cardRoot.viewportWidth; height: cardRoot.viewportHeight
                    visible: cardRoot.isPanelVisible("workspace")
                    Loader {
                        anchors.fill: parent; active: cardRoot.workspaceLoaded
                        sourceComponent: Component {
                            WorkspacePage {
                                chosenFont: cardRoot.chosenFont
                                currentWs: cardRoot.wsCurrent; totalWs: cardRoot.wsTotal
                                currentWsName: cardRoot.wsName; wsList: cardRoot.wsList
                            }
                        }
                    }
                }

                // 4. 媒体控制页
                Item {
                    id: panelMedia
                    x: cardRoot.getPanelX("media")
                    width: cardRoot.viewportWidth; height: cardRoot.viewportHeight
                    visible: cardRoot.isPanelVisible("media")
                    Loader {
                        anchors.fill: parent; active: cardRoot.mediaLoaded
                        sourceComponent: Component {
                            MediaPage {
                                chosenFont: cardRoot.chosenFont
                                title: cardRoot.title; artist: cardRoot.artist
                                status: cardRoot.status; artUrl: cardRoot.artUrl
                                position: cardRoot.position; duration: cardRoot.duration
                                dominantColor: cardRoot.dominantColor
                                onCancelCollapse: cardRoot.cancelCollapse()
                                onRequestCollapse: cardRoot.requestCollapse()
                                onStartCollapse: cardRoot.startCollapse()
                            }
                        }
                    }
                }

                // 5. 日历与日程页
                Item {
                    id: panelCalendar
                    x: cardRoot.getPanelX("calendar")
                    width: cardRoot.viewportWidth; height: cardRoot.viewportHeight
                    visible: cardRoot.isPanelVisible("calendar")
                    Loader {
                        anchors.fill: parent; active: cardRoot.calendarLoaded
                        sourceComponent: Component { CalendarPage { chosenFont: cardRoot.chosenFont } }
                    }
                }

                // 6. 专注计时器页
                Item {
                    id: panelTimer
                    x: cardRoot.getPanelX("timer")
                    width: cardRoot.viewportWidth; height: cardRoot.viewportHeight
                    visible: cardRoot.isPanelVisible("timer")
                    TimerPage {
                        id: persistentTimerPage
                        anchors.fill: parent; chosenFont: cardRoot.chosenFont
                        onTimerCompleted: (t, msg) => cardRoot.timerCompleted(t, msg)
                    }
                }

                // 7. 世界时钟页
                Item {
                    id: panelClock
                    x: cardRoot.getPanelX("clock")
                    width: cardRoot.viewportWidth; height: cardRoot.viewportHeight
                    visible: cardRoot.isPanelVisible("clock")
                    Loader {
                        anchors.fill: parent; active: cardRoot.clockLoaded
                        sourceComponent: Component {
                            WorldClockPage {
                                chosenFont: cardRoot.chosenFont
                                is24h: (typeof Config !== "undefined") ? (Config.timeFormat === "24h") : true
                            }
                        }
                    }
                }

                // 8. 网络监控页
                Item {
                    id: panelNetwork
                    x: cardRoot.getPanelX("network")
                    width: cardRoot.viewportWidth; height: cardRoot.viewportHeight
                    visible: cardRoot.isPanelVisible("network")
                    Loader {
                        anchors.fill: parent; active: cardRoot.networkLoaded
                        sourceComponent: Component {
                            NetworkPage {
                                chosenFont: cardRoot.chosenFont
                                downSpeed: cardRoot.downSpeedStr; upSpeed: cardRoot.upSpeedStr
                                localIp: cardRoot.localIp
                            }
                        }
                    }
                }

                // 9. 蓝牙外设页
                Item {
                    id: panelBluetooth
                    x: cardRoot.getPanelX("bluetooth")
                    width: cardRoot.viewportWidth; height: cardRoot.viewportHeight
                    visible: cardRoot.isPanelVisible("bluetooth")
                    Loader {
                        anchors.fill: parent; active: cardRoot.bluetoothLoaded
                        sourceComponent: Component { BluetoothPage { chosenFont: cardRoot.chosenFont } }
                    }
                }

                // 10. 历史通知流页
                Item {
                    id: panelNotification
                    x: cardRoot.getPanelX("notification")
                    width: cardRoot.viewportWidth; height: cardRoot.viewportHeight
                    visible: cardRoot.isPanelVisible("notification")
                    Loader {
                        id: notifLoader
                        anchors.fill: parent; active: cardRoot.notificationLoaded
                        sourceComponent: Component { NotificationPage { chosenFont: cardRoot.chosenFont } }
                        Connections {
                            target: notifLoader.item
                            ignoreUnknownSignals: true
                            function onStartCollapse() { cardRoot.startCollapse() }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        cardRoot.currentKey = (cardRoot.expandedTab && cardRoot.expandedTab !== "") ? cardRoot.expandedTab : "time"
        cardRoot.departingKey = ""
        cardRoot.transitionProgress = 1.0
    }
}