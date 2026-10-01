import QtQuick
import QtQuick.Controls

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

    property int wsCurrent: 1
    property int wsTotal: 4
    property string wsName: ""
    property var wsList: []

    property string downSpeedStr: ""
    property string upSpeedStr: ""
    property string localIp: ""
    property string activeTransient: ""

    readonly property alias timerPageRef: persistentTimerPage

    signal tabSelected(string key)
    signal cancelCollapse()
    signal requestCollapse()
    signal startCollapse()
    signal timerCompleted(string title, string message)

    property real tabWheelAccum: 0
    Timer { id: tabWheelReset; interval: 260; onTriggered: cardRoot.tabWheelAccum = 0 }

    readonly property int activeTabIndex: {
        for (var i = 0; i < cardRoot.enabledTabs.length; i++) {
            if (cardRoot.enabledTabs[i].key === cardRoot.expandedTab) return i
        }
        return 0
    }

    onExpandedTabChanged: {
        if (expandedTab === "calendar" && calendarPage) calendarPage.resetToToday()
        if (expandedTab === "bluetooth" && bluetoothPage) bluetoothPage.refresh()
        if (expandedTab === "notification" && notifCenterPage) notifCenterPage.refresh()
    }

    function selectTabByIndex(idx) {
        if (!cardRoot.enabledTabs || cardRoot.enabledTabs.length === 0) return
        var safeIdx = (idx + cardRoot.enabledTabs.length) % cardRoot.enabledTabs.length
        var targetKey = cardRoot.enabledTabs[safeIdx].key
        cardRoot.cancelCollapse()
        cardRoot.tabSelected(targetKey)
    }

    function switchTabNext() { selectTabByIndex(cardRoot.activeTabIndex + 1) }
    function switchTabPrev() { selectTabByIndex(cardRoot.activeTabIndex - 1) }

    Column {
        anchors.fill: parent
        spacing: 12

        // 1. 顶部 Header 状态标签与自适应 Tab 栏
        Item {
            id: headerArea
            width: parent.width
            height: 26

            readonly property int dynamicTabWidth: cardRoot.enabledTabs.length > 5 ? 42 : 48

            // 🚀 左侧标题区域：独立滚轮检测区，边界在 Tab 栏左侧终止，绝不遮挡 Tab 点击！
            MouseArea {
                anchors.left: parent.left
                anchors.right: tabSliderContainer.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                hoverEnabled: true
                onWheel: (wheel) => {
                    wheel.accepted = true
                    tabWheelReset.restart()
                    cardRoot.tabWheelAccum += wheel.angleDelta.y
                    if (Math.abs(cardRoot.tabWheelAccum) >= 80) {
                        if (cardRoot.tabWheelAccum > 0) cardRoot.switchTabPrev()
                        else cardRoot.switchTabNext()
                        cardRoot.tabWheelAccum = 0
                    }
                }
            }

            // 🚀 右侧自适应 Tab 栏容器（保证完全可点击）
            Rectangle {
                id: tabSliderContainer
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: cardRoot.enabledTabs.length * headerArea.dynamicTabWidth
                height: 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: !cardRoot.isCalling && cardRoot.enabledTabs.length > 1
                z: 5

                // Tab 栏专属滚轮切换（使用 NoButton，允许鼠标点击毫无阻碍地穿透给 Tab 项）
                MouseArea {
                    anchors.fill: parent
                    z: 0
                    acceptedButtons: Qt.NoButton
                    onWheel: (wheel) => {
                        wheel.accepted = true
                        tabWheelReset.restart()
                        cardRoot.tabWheelAccum += wheel.angleDelta.y
                        if (Math.abs(cardRoot.tabWheelAccum) >= 80) {
                            if (cardRoot.tabWheelAccum > 0) cardRoot.switchTabPrev()
                            else cardRoot.switchTabNext()
                            cardRoot.tabWheelAccum = 0
                        }
                    }
                }

                // 滑块背景指示器
                Rectangle {
                    z: 1; y: 2
                    x: cardRoot.activeTabIndex * headerArea.dynamicTabWidth + 2
                    width: headerArea.dynamicTabWidth - 4
                    height: 20
                    radius: 10
                    color: {
                        var curr = cardRoot.enabledTabs[cardRoot.activeTabIndex]
                        return curr ? curr.activeColor : Qt.rgba(1, 1, 1, 0.18)
                    }
                    border.color: {
                        var curr = cardRoot.enabledTabs[cardRoot.activeTabIndex]
                        return curr ? curr.color : Qt.rgba(1, 1, 1, 0.3)
                    }
                    border.width: 1
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                // Tab 文字与点击热区（z: 2 置顶响应点击）
                Row {
                    z: 2
                    anchors.fill: parent

                    Repeater {
                        model: cardRoot.enabledTabs

                        Item {
                            width: headerArea.dynamicTabWidth
                            height: parent.height
                            readonly property bool isCurrent: cardRoot.expandedTab === modelData.key

                            // 悬停轻量高亮背景
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 10
                                color: tabMouseArea.containsMouse && !isCurrent ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: isCurrent ?
                                       (modelData.key === "media" ? "#ffffff" : modelData.color) :
                                       (tabMouseArea.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.45))
                                font.pixelSize: 11
                                font.family: cardRoot.chosenFont
                                font.weight: isCurrent ? Font.Black : Font.Bold
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            // 🚀 核心点击 MouseArea
                            MouseArea {
                                id: tabMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton

                                onEntered: cardRoot.cancelCollapse()
                                onClicked: (mouse) => {
                                    mouse.accepted = true
                                    cardRoot.cancelCollapse()
                                    cardRoot.selectTabByIndex(index)
                                }
                            }
                        }
                    }
                }
            }

            // 左侧状态指示标签
            Text {
                anchors.left: parent.left
                anchors.right: tabSliderContainer.visible ? tabSliderContainer.left : parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight

                text: cardRoot.isCalling ? "● INCOMING CALL" :
                      (cardRoot.expandedTab === "notification" ? "● NOTIFICATION" :
                      (cardRoot.expandedTab === "calendar" ? "● CALENDAR" :
                      (cardRoot.expandedTab === "workspace" ? "● WORKSPACE" :
                      (cardRoot.expandedTab === "timer" ? (persistentTimerPage.isCountUp ? "● STOPWATCH" : "● TIMER") :
                      (cardRoot.expandedTab === "bluetooth" ? "● BLUETOOTH" :
                      (cardRoot.expandedTab === "network" ? "● NETWORK" :
                      (cardRoot.expandedTab === "clock" ? "● WORLD CLOCK" :
                      (cardRoot.status === "Playing" ? "● PLAYING" : "⏸ PAUSED"))))))))

                color: cardRoot.isCalling ? "#22c55e" :
                       (cardRoot.expandedTab === "notification" ? "#818cf8" :
                       (cardRoot.expandedTab === "calendar" ? "#38bdf8" :
                       (cardRoot.expandedTab === "workspace" ? "#a855f7" :
                       (cardRoot.expandedTab === "timer" ? persistentTimerPage.accentColor :
                       (cardRoot.expandedTab === "bluetooth" ? "#60a5fa" :
                       (cardRoot.expandedTab === "network" ? "#34d399" :
                       (cardRoot.expandedTab === "clock" ? "#f59e0b" :
                       (cardRoot.status === "Playing" ? Qt.rgba(0.2, 0.85, 0.5, 0.9) : Qt.rgba(1, 1, 1, 0.4)))))))))
                font.family: cardRoot.chosenFont
                font.pixelSize: 10
                font.weight: Font.Black
                font.letterSpacing: 0.8
            }
        }

        // 2. 页面容器
        Item {
            width: parent.width
            height: parent.height - 38

            WorkspacePage {
                id: workspacePage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                currentWs: cardRoot.wsCurrent; totalWs: cardRoot.wsTotal; currentWsName: cardRoot.wsName; wsList: cardRoot.wsList
                opacity: (cardRoot.expandedTab === "workspace" && !cardRoot.isCalling) ? 1.0 : 0.0
                visible: opacity > 0.01
            }

            MediaPage {
                id: mediaPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                isCalling: cardRoot.isCalling; callTitle: cardRoot.callTitle; callSubtitle: cardRoot.callSubtitle; callAvatar: cardRoot.callAvatar
                title: cardRoot.title; artist: cardRoot.artist; status: cardRoot.status; artUrl: cardRoot.artUrl
                position: cardRoot.position; duration: cardRoot.duration
                onCancelCollapse: cardRoot.cancelCollapse(); onRequestCollapse: cardRoot.requestCollapse(); onStartCollapse: cardRoot.startCollapse()
                opacity: (cardRoot.expandedTab === "media" || cardRoot.isCalling) ? 1.0 : 0.0
                visible: opacity > 0.01
            }

            CalendarPage {
                id: calendarPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                opacity: ((typeof Config !== "undefined" && Config.showCalendarTab) && cardRoot.expandedTab === "calendar" && !cardRoot.isCalling) ? 1.0 : 0.0
                visible: opacity > 0.01
            }

            TimerPage {
                id: persistentTimerPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                opacity: (cardRoot.expandedTab === "timer" && !cardRoot.isCalling) ? 1.0 : 0.0
                visible: opacity > 0.01
                onTimerCompleted: (t, msg) => cardRoot.timerCompleted(t, msg)
            }

            NotificationPage {
                id: notifCenterPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                opacity: (cardRoot.expandedTab === "notification" && !cardRoot.isCalling) ? 1.0 : 0.0
                visible: opacity > 0.01
            }

            BluetoothPage {
                id: bluetoothPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                opacity: ((typeof Config !== "undefined" && Config.showBluetoothTab) && cardRoot.expandedTab === "bluetooth" && !cardRoot.isCalling) ? 1.0 : 0.0
                visible: opacity > 0.01
            }

            NetworkPage {
                id: networkPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                downSpeed: cardRoot.downSpeedStr; upSpeed: cardRoot.upSpeedStr; localIp: cardRoot.localIp
                opacity: ((typeof Config !== "undefined" && Config.showNetworkTab) && cardRoot.expandedTab === "network" && !cardRoot.isCalling) ? 1.0 : 0.0
                visible: opacity > 0.01
            }

            WorldClockPage {
                id: worldClockPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                is24h: (typeof Config !== "undefined") ? (Config.timeFormat === "24h") : true
                opacity: ((typeof Config !== "undefined" && Config.showClockTab) && cardRoot.expandedTab === "clock" && !cardRoot.isCalling) ? 1.0 : 0.0
                visible: opacity > 0.01
            }
        }
    }
}