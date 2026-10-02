import QtQuick
import QtQuick.Controls

Item {
    id: cardRoot

    property string chosenFont: ""

    // =========================================================================
    // 🚀 全局唯一单真理源路由状态
    // =========================================================================
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

    property int wsCurrent: 1
    property int wsTotal: 4
    property string wsName: ""
    property var wsList: []

    property string downSpeedStr: ""
    property string upSpeedStr: ""
    property string localIp: ""
    property string activeTransient: ""

    // 暴露计时器常驻引用给外部副岛（确保倒计时在后台切页时不中断）
    readonly property alias timerPageRef: persistentTimerPage

    signal cancelCollapse()
    signal requestCollapse()
    signal startCollapse()
    signal timerCompleted(string title, string message)

    // =========================================================================
    // 🚀 全局直达路由：直接切换到独立页面，无需中转
    // =========================================================================
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

    // =========================================================================
    // 🚀 滚轮防抖切页引擎（双轴自适应）
    // =========================================================================
    property real tabWheelAccum: 0
    Timer {
        id: tabWheelResetTimer
        interval: 260
        onTriggered: cardRoot.tabWheelAccum = 0
    }

    function handleTabWheel(wheel) {
        wheel.accepted = true
        tabWheelResetTimer.restart()

        var delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y
        cardRoot.tabWheelAccum += delta

        if (Math.abs(cardRoot.tabWheelAccum) >= 70) {
            if (!cardRoot.enabledTabs || cardRoot.enabledTabs.length <= 1) return
            var dir = cardRoot.tabWheelAccum > 0 ? -1 : 1
            var nextIndex = (cardRoot.activeTabIndex + dir + cardRoot.enabledTabs.length) % cardRoot.enabledTabs.length
            var targetKey = cardRoot.enabledTabs[nextIndex].key
            cardRoot.switchRoute(targetKey, "")
            cardRoot.tabWheelAccum = 0
        }
    }

    // 底层遮罩吸收未捕获点击，杜绝事件击穿
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => mouse.accepted = true
    }

    Column {
        anchors.fill: parent
        spacing: 12

        // =====================================================================
        // 1. 顶部 Header 交互栏
        // =====================================================================
        Item {
            id: headerArea
            width: parent.width
            height: 26

            // 左侧桌面滚轮支持
            MouseArea {
                anchors.left: parent.left
                anchors.right: powerQuickBtn.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                hoverEnabled: true
                onWheel: (wheel) => {
                    wheel.accepted = true
                    if (!cardRoot.isCalling && cardRoot.expandedTab === "workspace" && typeof Bridge !== "undefined") {
                        if (wheel.angleDelta.y > 0) Bridge.switchWorkspacePrev()
                        else if (wheel.angleDelta.y < 0) Bridge.switchWorkspaceNext()
                    }
                }
            }

            // 左侧状态指示与独立模块面包屑标题
            Item {
                anchors.left: parent.left
                anchors.right: powerQuickBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 24

                // 电源状态下的快捷返回键
                Rectangle {
                    visible: cardRoot.expandedTab === "power" && !cardRoot.isCalling
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: backRow.implicitWidth + 14
                    height: 22
                    radius: 11
                    color: backTap.pressed ? Qt.rgba(1, 1, 1, 0.22) : (backHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                    border.color: Theme.borderSubtle
                    border.width: 1

                    Row {
                        id: backRow
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "‹"; color: "#ef4444"; font.pixelSize: 13; font.weight: Font.Black }
                        Text {
                            text: "返回工作台"
                            color: "white"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.family: cardRoot.chosenFont
                        }
                    }

                    HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: backTap
                        onTapped: cardRoot.switchRoute(cardRoot.previousTab || "workspace", "")
                    }
                }

                // 各独立页面专属面包屑标题
                Text {
                    visible: cardRoot.expandedTab !== "power" || cardRoot.isCalling
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight

                    text: {
                        if (cardRoot.isCalling) return "● INCOMING CALL · TEAMS"
                        if (cardRoot.expandedTab === "workspace") return "● WORKSPACE · " + (cardRoot.wsName ? cardRoot.wsName : ("DESKTOP " + cardRoot.wsCurrent))
                        if (cardRoot.expandedTab === "media") return cardRoot.status === "Playing" ? "● PLAYING" : "⏸ PAUSED"
                        if (cardRoot.expandedTab === "calendar") return "● CALENDAR · 日历"
                        if (cardRoot.expandedTab === "timer") return "● TIMER · 专注计时"
                        if (cardRoot.expandedTab === "clock") return "● WORLD CLOCK · 世界时钟"
                        if (cardRoot.expandedTab === "network") return "● NETWORK · 网络监控"
                        if (cardRoot.expandedTab === "bluetooth") return "● BLUETOOTH · 蓝牙外设"
                        if (cardRoot.expandedTab === "notification") return "● NOTIFICATIONS · 消息归档"
                        return "● ALCOVE ISLAND"
                    }

                    color: {
                        if (cardRoot.isCalling) return Theme.media
                        if (cardRoot.expandedTab === "workspace") return Theme.workspace
                        if (cardRoot.expandedTab === "media") return cardRoot.status === "Playing" ? Theme.media : Theme.textMuted
                        if (cardRoot.expandedTab === "calendar") return Theme.calendar
                        if (cardRoot.expandedTab === "timer") return Theme.timer
                        if (cardRoot.expandedTab === "clock") return Theme.clock
                        if (cardRoot.expandedTab === "network") return Theme.network
                        if (cardRoot.expandedTab === "bluetooth") return Theme.bluetooth
                        if (cardRoot.expandedTab === "notification") return Theme.notification
                        return Theme.textSecondary
                    }

                    font.family: cardRoot.chosenFont
                    font.pixelSize: 10
                    font.weight: Font.Black
                    font.letterSpacing: 0.8
                }
            }

            // 独立电源快捷键
            Rectangle {
                id: powerQuickBtn
                anchors.right: tabTrackContainer.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                radius: 12
                readonly property bool isPowerActive: (cardRoot.expandedTab === "power")
                color: isPowerActive ? Qt.rgba(239, 68, 68, 0.35) : (powerBtnHover.hovered ? Qt.rgba(239, 68, 68, 0.22) : Qt.rgba(1, 1, 1, 0.08))
                border.color: isPowerActive || powerBtnHover.hovered ? "#ef4444" : Theme.borderSubtle
                border.width: 1
                scale: powerBtnTap.pressed ? 0.92 : (powerBtnHover.hovered ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "⏻"
                    font.pixelSize: 11
                    font.weight: Font.Black
                    color: parent.isPowerActive || powerBtnHover.hovered ? "#ef4444" : Qt.rgba(1, 1, 1, 0.75)
                }

                HoverHandler { id: powerBtnHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: powerBtnTap
                    onTapped: {
                        if (cardRoot.expandedTab === "power") {
                            cardRoot.switchRoute(cardRoot.previousTab || "workspace", "")
                        } else {
                            cardRoot.switchRoute("power", "")
                        }
                    }
                }
            }

            // =================================================================
            // 🚀 图 2 风格流体点条指示轨（Dots & Pill Track）
            // 消除汉字，选中项拉伸为专属色药丸，未选中项为微圆点
            // =================================================================
            Rectangle {
                id: tabTrackContainer
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: dotsLayoutRow.implicitWidth + 14
                height: 18
                radius: 9
                color: Qt.rgba(1, 1, 1, 0.08)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                visible: !cardRoot.isCalling && cardRoot.enabledTabs && cardRoot.enabledTabs.length > 1
                z: 5

                MouseArea {
                    anchors.fill: parent
                    z: 0
                    acceptedButtons: Qt.NoButton
                    onWheel: (wheel) => cardRoot.handleTabWheel(wheel)
                }

                Row {
                    id: dotsLayoutRow
                    anchors.centerIn: parent
                    spacing: 5
                    z: 1

                    Repeater {
                        model: cardRoot.enabledTabs || []

                        Item {
                            id: tabSlotItem
                            readonly property bool isCurrent: (cardRoot.expandedTab === modelData.key)
                            width: isCurrent ? 18 : 5
                            height: 18

                            Behavior on width {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.15
                                }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 5
                                radius: 2.5
                                color: tabSlotItem.isCurrent ?
                                       (modelData.color ? modelData.color : Theme.workspace) :
                                       (tabMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.35))

                                scale: tabSlotItem.isCurrent ? 1.0 : (tabMouseArea.containsMouse ? 1.35 : 1.0)

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                            }

                            MouseArea {
                                id: tabMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cardRoot.switchRoute(modelData.key, "")
                                onWheel: (wheel) => cardRoot.handleTabWheel(wheel)
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2. 独立业务页面展示区（全量一等公民直达页面）
        // =====================================================================
        Item {
            width: parent.width
            height: parent.height - 38

            // 1. 来电特权级呼叫面板
            Item {
                id: incomingCallCard
                anchors.fill: parent
                visible: cardRoot.isCalling

                Column {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 14

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16

                        Item {
                            width: 60; height: 60
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: cardPulse
                                anchors.centerIn: parent
                                width: 60; height: 60; radius: 30
                                color: "transparent"
                                border.color: Theme.media
                                border.width: 1.5

                                SequentialAnimation {
                                    running: cardRoot.isCalling
                                    loops: Animation.Infinite
                                    ParallelAnimation {
                                        NumberAnimation { target: cardPulse; property: "scale"; from: 0.9; to: 1.35; duration: 1200; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: cardPulse; property: "opacity"; from: 0.8; to: 0.0; duration: 1200; easing.type: Easing.OutQuad }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 30
                                color: cardAvatarImg.visible ? "transparent" : "#4F46E5"
                                border.color: Qt.rgba(255, 255, 255, 0.15)
                                border.width: 1.5
                                clip: true

                                Image {
                                    id: cardAvatarImg
                                    anchors.fill: parent
                                    source: cardRoot.callAvatar
                                    fillMode: Image.PreserveAspectCrop
                                    visible: cardRoot.callAvatar !== "" && status === Image.Ready
                                    sourceSize.width: 120; sourceSize.height: 120
                                    asynchronous: true; cache: true
                                    smooth: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (cardAvatarImg.visible) return ""
                                        if (cardRoot.callTitle && cardRoot.callTitle.length > 0) {
                                            var parts = cardRoot.callTitle.trim().split(" ")
                                            return (parts.length >= 2) ? (parts[0][0] + parts[1][0]).toUpperCase() : cardRoot.callTitle.trim().charAt(0).toUpperCase()
                                        }
                                        return "📞"
                                    }
                                    color: "white"
                                    font.family: cardRoot.chosenFont
                                    font.pixelSize: 22
                                    font.weight: Font.Black
                                    visible: !cardAvatarImg.visible
                                }
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            width: 280

                            Text {
                                text: cardRoot.callTitle || "Teams 来电"
                                color: "white"
                                font.family: cardRoot.chosenFont
                                font.pixelSize: 19
                                font.weight: Font.Black
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: (cardRoot.callSubtitle || "正在呼叫...") + " · Microsoft Teams 语音通话"
                                color: Theme.media
                                font.family: cardRoot.chosenFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 12

                        Rectangle {
                            width: 110; height: 40; radius: 20
                            color: rejectArea.pressed ? Qt.rgba(239, 68, 68, 0.45) : (rejectArea.containsMouse ? Qt.rgba(239, 68, 68, 0.3) : Qt.rgba(239, 68, 68, 0.16))
                            border.color: Theme.danger; border.width: 1
                            scale: rejectArea.pressed ? 0.96 : 1.0

                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Text { text: "✕"; color: Theme.danger; font.pixelSize: 14; font.weight: Font.Black }
                                Text { text: "拒接"; color: "white"; font.family: cardRoot.chosenFont; font.pixelSize: 12; font.weight: Font.Bold }
                            }

                            MouseArea {
                                id: rejectArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof Bridge !== "undefined") {
                                        Bridge.rejectTeamsCall()
                                        cardRoot.startCollapse()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 240; height: 40; radius: 20
                            color: answerArea.pressed ? "#15803d" : (answerArea.containsMouse ? "#16a34a" : Theme.media)
                            scale: answerArea.pressed ? 0.98 : 1.0

                            Row {
                                anchors.centerIn: parent; spacing: 8
                                Text { text: "📞"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "直接接听呼叫"; color: "white"; font.family: cardRoot.chosenFont; font.pixelSize: 13; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "✓"; color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 13; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            }

                            MouseArea {
                                id: answerArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof Bridge !== "undefined") {
                                        Bridge.answerTeamsCall()
                                        cardRoot.startCollapse()
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "💡 点击一键接通电话并自动聚焦 Teams 窗口"
                        color: Theme.textMuted; font.family: cardRoot.chosenFont; font.pixelSize: 10; font.weight: Font.Bold
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // 2. 桌面工作区独立页
            WorkspacePage {
                anchors.fill: parent; chosenFont: cardRoot.chosenFont
                currentWs: cardRoot.wsCurrent; totalWs: cardRoot.wsTotal; currentWsName: cardRoot.wsName; wsList: cardRoot.wsList
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "workspace")
            }

            // 3. 媒体控制独立页
            MediaPage {
                anchors.fill: parent; chosenFont: cardRoot.chosenFont; isCalling: false
                title: cardRoot.title; artist: cardRoot.artist; status: cardRoot.status; artUrl: cardRoot.artUrl
                position: cardRoot.position; duration: cardRoot.duration
                onCancelCollapse: cardRoot.cancelCollapse(); onRequestCollapse: cardRoot.requestCollapse(); onStartCollapse: cardRoot.startCollapse()
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "media")
            }

            // 4. 日历独立页
            CalendarPage {
                anchors.fill: parent; chosenFont: cardRoot.chosenFont
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "calendar")
            }

            // 5. 专注倒计时/秒表独立页（状态常驻，防止切页中断）
            TimerPage {
                id: persistentTimerPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "timer")
                onTimerCompleted: (t, msg) => cardRoot.timerCompleted(t, msg)
            }

            // 6. 世界时钟独立页
            Loader {
                id: clockLoader; anchors.fill: parent
                active: !cardRoot.isCalling && (cardRoot.expandedTab === "clock")
                visible: active
                sourceComponent: Component {
                    WorldClockPage {
                        chosenFont: cardRoot.chosenFont
                        is24h: (typeof Config !== "undefined") ? (Config.timeFormat === "24h") : true
                    }
                }
            }

            // 7. 实时网络监控独立页
            Loader {
                id: networkLoader; anchors.fill: parent
                active: !cardRoot.isCalling && (cardRoot.expandedTab === "network")
                visible: active
                sourceComponent: Component {
                    NetworkPage {
                        chosenFont: cardRoot.chosenFont
                        downSpeed: cardRoot.downSpeedStr; upSpeed: cardRoot.upSpeedStr; localIp: cardRoot.localIp
                    }
                }
            }

            // 8. 蓝牙外设管理独立页
            Loader {
                id: bluetoothLoader; anchors.fill: parent
                active: !cardRoot.isCalling && (cardRoot.expandedTab === "bluetooth")
                visible: active
                sourceComponent: Component {
                    BluetoothPage { chosenFont: cardRoot.chosenFont }
                }
            }

            // 9. 消息归档中心独立页
            Loader {
                id: notifLoader; anchors.fill: parent
                active: !cardRoot.isCalling && (cardRoot.expandedTab === "notification")
                visible: active
                sourceComponent: Component {
                    NotificationPage { chosenFont: cardRoot.chosenFont }
                }
            }

            // 10. 系统电源会话独立页
            Loader {
                id: powerLoader; anchors.fill: parent
                active: !cardRoot.isCalling && (cardRoot.expandedTab === "power")
                visible: active
                sourceComponent: Component {
                    PowerPage { chosenFont: cardRoot.chosenFont }
                }
            }
        }
    }
}