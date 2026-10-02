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
        if (!cardRoot.enabledTabs || !cardRoot.enabledTabs.length) return 0
        for (var i = 0; i < cardRoot.enabledTabs.length; i++) {
            if (cardRoot.enabledTabs[i] && cardRoot.enabledTabs[i].key === cardRoot.expandedTab) return i
        }
        return 0
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

        // 1. 顶部 Header
        Item {
            id: headerArea
            width: parent.width
            height: 26

            readonly property int dynamicTabWidth: (cardRoot.enabledTabs && cardRoot.enabledTabs.length > 5) ? 42 : 48

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

            Rectangle {
                id: tabSliderContainer
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: (cardRoot.enabledTabs ? cardRoot.enabledTabs.length : 0) * headerArea.dynamicTabWidth
                height: 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.08)
                visible: !cardRoot.isCalling && cardRoot.enabledTabs && cardRoot.enabledTabs.length > 1
                z: 5

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

                Rectangle {
                    z: 1; y: 2
                    x: cardRoot.activeTabIndex * headerArea.dynamicTabWidth + 2
                    width: headerArea.dynamicTabWidth - 4
                    height: 20
                    radius: 10
                    color: {
                        if (!cardRoot.enabledTabs || !cardRoot.enabledTabs.length) return Qt.rgba(1, 1, 1, 0.18)
                        var curr = cardRoot.enabledTabs[cardRoot.activeTabIndex]
                        return curr && curr.activeColor ? curr.activeColor : Qt.rgba(1, 1, 1, 0.18)
                    }
                    border.color: {
                        if (!cardRoot.enabledTabs || !cardRoot.enabledTabs.length) return Theme.borderFocus
                        var curr = cardRoot.enabledTabs[cardRoot.activeTabIndex]
                        return curr && curr.color ? curr.color : Theme.borderFocus
                    }
                    border.width: 1
                    Behavior on x { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
                }

                Row {
                    z: 2
                    anchors.fill: parent

                    Repeater {
                        model: cardRoot.enabledTabs || []

                        Item {
                            width: headerArea.dynamicTabWidth
                            height: parent.height
                            readonly property bool isCurrent: cardRoot.expandedTab === modelData.key

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 10
                                color: tabMouseArea.containsMouse && !isCurrent ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name || ""
                                color: isCurrent ? (modelData.key === "media" ? Theme.textPrimary : modelData.color) :
                                       (tabMouseArea.containsMouse ? Theme.textPrimary : Theme.textMuted)
                                font.pixelSize: 11
                                font.family: cardRoot.chosenFont
                                font.weight: isCurrent ? Font.Black : Font.Bold
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }

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

                color: cardRoot.isCalling ? Theme.media :
                       (cardRoot.expandedTab === "notification" ? Theme.notification :
                       (cardRoot.expandedTab === "calendar" ? Theme.calendar :
                       (cardRoot.expandedTab === "workspace" ? Theme.workspace :
                       (cardRoot.expandedTab === "timer" ? persistentTimerPage.accentColor :
                       (cardRoot.expandedTab === "bluetooth" ? Theme.bluetooth :
                       (cardRoot.expandedTab === "network" ? Theme.network :
                       (cardRoot.expandedTab === "clock" ? Theme.clock :
                       (cardRoot.status === "Playing" ? Theme.media : Theme.textMuted))))))))
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

            TimerPage {
                id: persistentTimerPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                opacity: (cardRoot.expandedTab === "timer" && !cardRoot.isCalling) ? 1.0 : 0.0
                visible: opacity > 0.01
                onTimerCompleted: (t, msg) => cardRoot.timerCompleted(t, msg)
            }

            Loader {
                id: calendarLoader
                anchors.fill: parent
                active: cardRoot.expandedTab === "calendar"
                visible: active
                sourceComponent: Component {
                    CalendarPage { chosenFont: cardRoot.chosenFont }
                }
            }

            Loader {
                id: notifLoader
                anchors.fill: parent
                active: cardRoot.expandedTab === "notification"
                visible: active
                sourceComponent: Component {
                    NotificationPage { chosenFont: cardRoot.chosenFont }
                }
            }

            Loader {
                id: bluetoothLoader
                anchors.fill: parent
                active: cardRoot.expandedTab === "bluetooth"
                visible: active
                sourceComponent: Component {
                    BluetoothPage { chosenFont: cardRoot.chosenFont }
                }
            }

            Loader {
                id: networkLoader
                anchors.fill: parent
                active: cardRoot.expandedTab === "network"
                visible: active
                sourceComponent: Component {
                    NetworkPage {
                        chosenFont: cardRoot.chosenFont
                        downSpeed: cardRoot.downSpeedStr; upSpeed: cardRoot.upSpeedStr; localIp: cardRoot.localIp
                    }
                }
            }

            Loader {
                id: clockLoader
                anchors.fill: parent
                active: cardRoot.expandedTab === "clock"
                visible: active
                sourceComponent: Component {
                    WorldClockPage {
                        chosenFont: cardRoot.chosenFont
                        is24h: (typeof Config !== "undefined") ? (Config.timeFormat === "24h") : true
                    }
                }
            }
        }
    }
}