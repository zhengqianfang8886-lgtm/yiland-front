import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: cardRoot

    property string chosenFont: ""
    property string expandedTab: "calendar"
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

    readonly property alias timerPageRef: timerPage

    // 🚀 标准 Qt 信号定义
    signal tabSelected(string key)
    signal cancelCollapse()
    signal requestCollapse()
    signal startCollapse()
    signal timerCompleted(string title, string message)

    Column {
        anchors.fill: parent
        spacing: 12

        // 1. 顶部 Header 状态标签与自适应 Tab 栏
        Item {
            width: parent.width
            height: 26

            readonly property int dynamicTabWidth: cardRoot.enabledTabs.length > 5 ? 41 : 46

            Rectangle {
                id: tabSliderContainer
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: cardRoot.enabledTabs.length * parent.dynamicTabWidth
                height: 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: !cardRoot.isCalling && cardRoot.activeTransient !== "ALERT" && cardRoot.enabledTabs.length > 1

                readonly property int activeTabIndex: {
                    for (var i = 0; i < cardRoot.enabledTabs.length; i++) {
                        if (cardRoot.enabledTabs[i].key === cardRoot.expandedTab) return i
                    }
                    return 0
                }

                Rectangle {
                    z: 0; y: 2
                    x: tabSliderContainer.activeTabIndex * parent.dynamicTabWidth + 2
                    width: parent.dynamicTabWidth - 4
                    height: 20
                    radius: 10
                    color: {
                        var curr = cardRoot.enabledTabs[tabSliderContainer.activeTabIndex]
                        return curr ? curr.activeColor : Qt.rgba(1, 1, 1, 0.18)
                    }
                    border.color: {
                        var curr = cardRoot.enabledTabs[tabSliderContainer.activeTabIndex]
                        return curr ? curr.color : Qt.rgba(1, 1, 1, 0.3)
                    }
                    border.width: 1
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }

                Row {
                    z: 1; anchors.fill: parent
                    Repeater {
                        model: cardRoot.enabledTabs
                        Item {
                            width: tabSliderContainer.parent.dynamicTabWidth
                            height: parent.height
                            readonly property bool isCurrent: cardRoot.expandedTab === modelData.key
                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                color: isCurrent ? (modelData.key === "media" ? "#ffffff" : modelData.color) : Qt.rgba(1, 1, 1, 0.45)
                                font.pixelSize: 11; font.family: cardRoot.chosenFont; font.weight: isCurrent ? Font.Black : Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    cardRoot.expandedTab = modelData.key
                                    cardRoot.tabSelected(modelData.key) // 向外发射标准信号
                                    if (modelData.key === "calendar") calendarPage.resetToToday()
                                    if (modelData.key === "bluetooth") bluetoothPage.refresh()
                                    if (modelData.key === "notification") notifCenterPage.refresh()
                                }
                            }
                        }
                    }
                }
            }

            // 左侧状态标题
            Text {
                anchors.left: parent.left
                anchors.right: tabSliderContainer.visible ? tabSliderContainer.left : parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight

                text: cardRoot.isCalling ? "● INCOMING CALL" : 
                      (cardRoot.activeTransient === "ALERT" ? "● NOTIFICATION" : 
                      (cardRoot.expandedTab === "notification" ? "● NOTIFICATION" :
                      (cardRoot.expandedTab === "calendar" ? "● CALENDAR" : 
                      (cardRoot.expandedTab === "workspace" ? "● WORKSPACE" : 
                      (cardRoot.expandedTab === "timer" ? (timerPage.isCountUp ? "● STOPWATCH" : "● TIMER") : 
                      (cardRoot.expandedTab === "bluetooth" ? "● BLUETOOTH" :
                      (cardRoot.expandedTab === "network" ? "● NETWORK" : 
                      (cardRoot.expandedTab === "clock" ? "● WORLD CLOCK" : 
                      (cardRoot.status === "Playing" ? "● PLAYING" : "⏸ PAUSED")))))))))

                color: cardRoot.isCalling ? "#22c55e" : 
                       (cardRoot.activeTransient === "ALERT" ? "#818cf8" : 
                       (cardRoot.expandedTab === "notification" ? "#818cf8" :
                       (cardRoot.expandedTab === "calendar" ? "#38bdf8" : 
                       (cardRoot.expandedTab === "workspace" ? "#a855f7" :
                       (cardRoot.expandedTab === "timer" ? timerPage.accentColor : 
                       (cardRoot.expandedTab === "bluetooth" ? "#60a5fa" :
                       (cardRoot.expandedTab === "network" ? "#34d399" :
                       (cardRoot.expandedTab === "clock" ? "#f59e0b" : 
                       (cardRoot.status === "Playing" ? Qt.rgba(0.2, 0.85, 0.5, 0.9) : Qt.rgba(1, 1, 1, 0.4))))))))))
                font.family: cardRoot.chosenFont
                font.pixelSize: 10
                font.weight: Font.Black
                font.letterSpacing: 0.8
            }
        }

        // 2. 8大业务子页面装配栈
        Item {
            width: parent.width
            height: parent.height - 38

            CalendarPage {
                id: calendarPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                opacity: (Config.showCalendarTab && cardRoot.expandedTab === "calendar" && !cardRoot.isCalling && cardRoot.activeTransient !== "ALERT") ? 1.0 : 0.0
                visible: opacity > 0.01
            }

            MediaPage {
                id: mediaPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                isCalling: cardRoot.isCalling; callTitle: cardRoot.callTitle; callSubtitle: cardRoot.callSubtitle; callAvatar: cardRoot.callAvatar
                title: cardRoot.title; artist: cardRoot.artist; status: cardRoot.status; artUrl: cardRoot.artUrl
                position: cardRoot.position; duration: cardRoot.duration
                onCancelCollapse: cardRoot.cancelCollapse(); onRequestCollapse: cardRoot.requestCollapse(); onStartCollapse: cardRoot.startCollapse()
                opacity: (Config.showMediaTab && (cardRoot.expandedTab === "media" || cardRoot.isCalling) && cardRoot.activeTransient !== "ALERT") ? 1.0 : 0.0
                visible: opacity > 0.01
            }

            WorkspacePage {
                id: workspacePage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                currentWs: cardRoot.wsCurrent; totalWs: cardRoot.wsTotal; currentWsName: cardRoot.wsName; wsList: cardRoot.wsList
                opacity: (typeof Config !== "undefined" && Config.showWorkspaceTab && cardRoot.expandedTab === "workspace" && !cardRoot.isCalling && cardRoot.activeTransient !== "ALERT") ? 1.0 : 0.0
                visible: opacity > 0.01
            }

            TimerPage {
                id: timerPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                opacity: (cardRoot.expandedTab === "timer" && !cardRoot.isCalling && cardRoot.activeTransient !== "ALERT") ? 1.0 : 0.0
                visible: opacity > 0.01
                onTimerCompleted: (t, msg) => cardRoot.timerCompleted(t, msg)
            }

            NotificationPage {
                id: notifCenterPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                opacity: (cardRoot.expandedTab === "notification" && !cardRoot.isCalling && cardRoot.activeTransient !== "ALERT") ? 1.0 : 0.0
                visible: opacity > 0.01
            }

            BluetoothPage {
                id: bluetoothPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                opacity: (typeof Config !== "undefined" && Config.showBluetoothTab && cardRoot.expandedTab === "bluetooth" && !cardRoot.isCalling && cardRoot.activeTransient !== "ALERT") ? 1.0 : 0.0
                visible: opacity > 0.01
            }

            NetworkPage {
                id: networkPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                downSpeed: cardRoot.downSpeedStr; upSpeed: cardRoot.upSpeedStr; localIp: cardRoot.localIp
                opacity: (Config.showNetworkTab && cardRoot.expandedTab === "network" && !cardRoot.isCalling && cardRoot.activeTransient !== "ALERT") ? 1.0 : 0.0
                visible: opacity > 0.01
            }

            WorldClockPage {
                id: worldClockPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont; is24h: Config.timeFormat === "24h"
                opacity: (Config.showClockTab && cardRoot.expandedTab === "clock" && !cardRoot.isCalling && cardRoot.activeTransient !== "ALERT") ? 1.0 : 0.0
                visible: opacity > 0.01
            }
        }
    }
}