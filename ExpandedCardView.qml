import QtQuick
import QtQuick.Controls

Item {
    id: cardRoot

    property string chosenFont: ""
    property string expandedTab: "workspace"
    property var enabledTabs: []

    // 🚀 二级下钻状态："" 表示主面板，非空（如 "power", "clock", "timer" 等）表示进入全量详情页
    property string drillDownPage: ""

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
        cardRoot.drillDownPage = "" // 切换顶层 Tab 时自动退出下钻模式
        cardRoot.cancelCollapse()
        cardRoot.tabSelected(targetKey)
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

            readonly property int dynamicTabWidth: 44

            // 桌面滚轮支持（仅在处于桌面 Tab 且未通话时生效）
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

            // 左侧状态指示 / 下钻【‹ 返回控制台】按钮
            Item {
                anchors.left: parent.left
                anchors.right: powerQuickBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 24

                // 下钻返回按键
                Rectangle {
                    visible: cardRoot.drillDownPage !== "" && !cardRoot.isCalling
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
                        Text { text: "‹"; color: Theme.clock; font.pixelSize: 13; font.weight: Font.Black }
                        Text {
                            text: {
                                if (cardRoot.drillDownPage === "power") return "返回 · 电源会话"
                                if (cardRoot.drillDownPage === "clock") return "返回 · 日历时钟"
                                if (cardRoot.drillDownPage === "timer") return "返回 · 专注计时"
                                if (cardRoot.drillDownPage === "network") return "返回 · 网络监控"
                                if (cardRoot.drillDownPage === "bluetooth") return "返回 · 蓝牙外设"
                                if (cardRoot.drillDownPage === "notification") return "返回 · 消息中心"
                                return "返回控制台"
                            }
                            color: "white"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.family: cardRoot.chosenFont
                        }
                    }

                    HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: backTap
                        onTapped: {
                            cardRoot.drillDownPage = ""
                            cardRoot.expandedTab = "control"
                        }
                    }
                }

                // 常规状态标签
                Text {
                    visible: cardRoot.drillDownPage === "" || cardRoot.isCalling
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight

                    text: cardRoot.isCalling ? "● INCOMING CALL · TEAMS" :
                          (cardRoot.expandedTab === "workspace" ? ("● WORKSPACE · " + (cardRoot.wsName ? cardRoot.wsName : ("DESKTOP " + cardRoot.wsCurrent))) :
                          (cardRoot.expandedTab === "media" ? (cardRoot.status === "Playing" ? "● PLAYING" : "⏸ PAUSED") :
                          (cardRoot.expandedTab === "calendar" ? "● CALENDAR" : "● CONTROL CENTER · 控制中心")))

                    color: cardRoot.isCalling ? Theme.media :
                           (cardRoot.expandedTab === "workspace" ? Theme.workspace :
                           (cardRoot.expandedTab === "media" ? (cardRoot.status === "Playing" ? Theme.media : Theme.textMuted) :
                           (cardRoot.expandedTab === "calendar" ? Theme.calendar : Theme.clock)))
                    font.family: cardRoot.chosenFont
                    font.pixelSize: 10
                    font.weight: Font.Black
                    font.letterSpacing: 0.8
                }
            }

            // 🚀 独立电源中心快捷按钮（高质感呼吸红微光）
            Rectangle {
                id: powerQuickBtn
                anchors.right: tabSliderContainer.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                radius: 12
                color: powerBtnHover.hovered ? Qt.rgba(239, 68, 68, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                border.color: powerBtnHover.hovered ? "#ef4444" : Theme.borderSubtle
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
                    color: powerBtnHover.hovered ? "#ef4444" : Qt.rgba(1, 1, 1, 0.75)
                }

                HoverHandler { id: powerBtnHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: powerBtnTap
                    onTapped: {
                        cardRoot.expandedTab = "control"
                        cardRoot.drillDownPage = "power"
                    }
                }
            }

            // 右侧紧凑 Tab 滑块容器（3个核心 Tab + 1个纵向三点 ⋮）
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
                                anchors.fill: parent; anchors.margins: 2; radius: 10
                                color: tabMouseArea.containsMouse && !isCurrent ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }

                            // 🚀 针对纵向三点 ⋮ 进行专用字号与居中微调
                            Text {
                                anchors.centerIn: parent
                                text: modelData.name || ""
                                color: isCurrent ? (modelData.key === "media" ? Theme.textPrimary : modelData.color) :
                                       (tabMouseArea.containsMouse ? Theme.textPrimary : Theme.textMuted)
                                font.pixelSize: modelData.name === "⋮" ? 15 : 11
                                font.family: cardRoot.chosenFont
                                font.weight: Font.Black
                                anchors.verticalCenterOffset: modelData.name === "⋮" ? -1 : 0
                            }

                            MouseArea {
                                id: tabMouseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: cardRoot.selectTabByIndex(index)
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2. 页面容器（核心页面 + Bento 控制中心 + 全量下钻页面）
        // =====================================================================
        Item {
            width: parent.width
            height: parent.height - 38

            // -------------------------------------------------------------
            // 通话全屏呼叫面板
            // -------------------------------------------------------------
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

            // -------------------------------------------------------------
            // 常规核心页面
            // -------------------------------------------------------------
            WorkspacePage {
                anchors.fill: parent; chosenFont: cardRoot.chosenFont
                currentWs: cardRoot.wsCurrent; totalWs: cardRoot.wsTotal; currentWsName: cardRoot.wsName; wsList: cardRoot.wsList
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "workspace")
            }

            MediaPage {
                anchors.fill: parent; chosenFont: cardRoot.chosenFont; isCalling: false
                title: cardRoot.title; artist: cardRoot.artist; status: cardRoot.status; artUrl: cardRoot.artUrl
                position: cardRoot.position; duration: cardRoot.duration
                onCancelCollapse: cardRoot.cancelCollapse(); onRequestCollapse: cardRoot.requestCollapse(); onStartCollapse: cardRoot.startCollapse()
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "media")
            }

            CalendarPage {
                anchors.fill: parent; chosenFont: cardRoot.chosenFont
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "calendar")
            }

            // -------------------------------------------------------------
            // 控制中心 Bento 主页面
            // -------------------------------------------------------------
            ControlCenterPage {
                id: controlCenterView
                anchors.fill: parent; chosenFont: cardRoot.chosenFont
                timerPageRef: persistentTimerPage
                downSpeedStr: cardRoot.downSpeedStr; upSpeedStr: cardRoot.upSpeedStr; localIp: cardRoot.localIp
                visible: !cardRoot.isCalling && (cardRoot.expandedTab === "control") && (cardRoot.drillDownPage === "")
                onOpenDetail: (key) => cardRoot.drillDownPage = key
            }

            // -------------------------------------------------------------
            // 全量下钻页面集合
            // -------------------------------------------------------------
            TimerPage {
                id: persistentTimerPage; anchors.fill: parent; chosenFont: cardRoot.chosenFont
                visible: !cardRoot.isCalling && ((cardRoot.expandedTab === "control" && cardRoot.drillDownPage === "timer") || cardRoot.expandedTab === "timer")
                onTimerCompleted: (t, msg) => cardRoot.timerCompleted(t, msg)
            }

            Loader {
                id: clockLoader; anchors.fill: parent
                active: !cardRoot.isCalling && ((cardRoot.expandedTab === "control" && cardRoot.drillDownPage === "clock") || cardRoot.expandedTab === "clock")
                visible: active
                sourceComponent: Component {
                    WorldClockPage {
                        chosenFont: cardRoot.chosenFont
                        is24h: (typeof Config !== "undefined") ? (Config.timeFormat === "24h") : true
                    }
                }
            }

            Loader {
                id: networkLoader; anchors.fill: parent
                active: !cardRoot.isCalling && ((cardRoot.expandedTab === "control" && cardRoot.drillDownPage === "network") || cardRoot.expandedTab === "network")
                visible: active
                sourceComponent: Component {
                    NetworkPage {
                        chosenFont: cardRoot.chosenFont
                        downSpeed: cardRoot.downSpeedStr; upSpeed: cardRoot.upSpeedStr; localIp: cardRoot.localIp
                    }
                }
            }

            Loader {
                id: bluetoothLoader; anchors.fill: parent
                active: !cardRoot.isCalling && ((cardRoot.expandedTab === "control" && cardRoot.drillDownPage === "bluetooth") || cardRoot.expandedTab === "bluetooth")
                visible: active
                sourceComponent: Component {
                    BluetoothPage { chosenFont: cardRoot.chosenFont }
                }
            }

            Loader {
                id: notifLoader; anchors.fill: parent
                active: !cardRoot.isCalling && ((cardRoot.expandedTab === "control" && cardRoot.drillDownPage === "notification") || cardRoot.expandedTab === "notification")
                visible: active
                sourceComponent: Component {
                    NotificationPage { chosenFont: cardRoot.chosenFont }
                }
            }

            // 🚀 全新系统电源与会话管理下钻界面
            Loader {
                id: powerLoader; anchors.fill: parent
                active: !cardRoot.isCalling && (cardRoot.expandedTab === "control" && cardRoot.drillDownPage === "power")
                visible: active
                sourceComponent: Component {
                    PowerPage { chosenFont: cardRoot.chosenFont }
                }
            }
        }
    }
}