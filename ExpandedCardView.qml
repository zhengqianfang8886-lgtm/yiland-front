import QtQuick
import QtQuick.Controls

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

    // 🚀 当前 Tab 的元数据配置（主题色、标题、副标题）
    readonly property var currentTabMeta: {
        if (cardRoot.isCalling) {
            return { title: "TEAMS CALL", sub: "呼叫中", color: Theme.media }
        }
        if (cardRoot.expandedTab === "power") {
            return { title: "SESSION", sub: "系统会话", color: "#ef4444" }
        }
        if (cardRoot.expandedTab === "time") {
            return { title: "LOCAL TIME", sub: "时间与节律", color: Theme.calendar }
        }
        if (cardRoot.expandedTab === "workspace") {
            var name = cardRoot.wsName ? cardRoot.wsName : ("桌面 " + cardRoot.wsCurrent)
            return { title: "WORKSPACE", sub: name, color: Theme.workspace }
        }
        if (cardRoot.expandedTab === "media") {
            var mediaSub = cardRoot.status === "Playing" ? (cardRoot.title ? cardRoot.title : "正在播放") : "已暂停"
            return { title: "MEDIA", sub: mediaSub, color: cardRoot.status === "Playing" ? cardRoot.dominantColor : Theme.textMuted }
        }
        if (cardRoot.expandedTab === "calendar") {
            return { title: "CALENDAR", sub: "日历日程", color: Theme.calendar }
        }
        if (cardRoot.expandedTab === "timer") {
            return { title: "TIMER", sub: "专注计时", color: Theme.timer }
        }
        if (cardRoot.expandedTab === "clock") {
            return { title: "WORLD CLOCK", sub: "世界时钟", color: Theme.clock }
        }
        if (cardRoot.expandedTab === "network") {
            return { title: "NETWORK", sub: "网络监控", color: Theme.network }
        }
        if (cardRoot.expandedTab === "bluetooth") {
            return { title: "BLUETOOTH", sub: "蓝牙外设", color: Theme.bluetooth }
        }
        if (cardRoot.expandedTab === "notification") {
            return { title: "NOTIFICATIONS", sub: "消息归档", color: Theme.notification }
        }
        return { title: "ALCOVE ISLAND", sub: "", color: Theme.textSecondary }
    }

    // 滚轮平滑阻尼累加器
    property real tabWheelAccum: 0
    Timer {
        id: tabWheelResetTimer
        interval: 240
        onTriggered: cardRoot.tabWheelAccum = 0
    }

    // 🚀 全局 Tab 滚轮切换调度器
    function handleTabWheel(wheel) {
        wheel.accepted = true
        tabWheelResetTimer.restart()

        var delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y
        cardRoot.tabWheelAccum += delta

        if (Math.abs(cardRoot.tabWheelAccum) >= 60) {
            if (!cardRoot.enabledTabs || cardRoot.enabledTabs.length <= 1) return
            var dir = cardRoot.tabWheelAccum > 0 ? -1 : 1
            var nextIndex = (cardRoot.activeTabIndex + dir + cardRoot.enabledTabs.length) % cardRoot.enabledTabs.length
            var targetKey = cardRoot.enabledTabs[nextIndex].key
            cardRoot.switchRoute(targetKey, "")
            cardRoot.tabWheelAccum = 0
        }
    }

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
        // 🚀 一体化微胶囊顶栏（高度统一定制 26px，支持整行全域平滑切页）
        // =====================================================================
        Item {
            id: headerArea
            width: parent.width
            height: 26

            // 全行底层滚轮拦截器（点击穿透给子组件，任意区域滚动皆可切页）
            MouseArea {
                anchors.fill: parent
                z: 0
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => cardRoot.handleTabWheel(wheel)
            }

            // 1. 左侧：面包屑标题微胶囊
            Rectangle {
                id: titleBadge
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: 26
                radius: 13
                z: 1

                readonly property bool isPowerPage: (cardRoot.expandedTab === "power" && !cardRoot.isCalling)
                width: isPowerPage ? (backRow.implicitWidth + 20) : Math.min(220, titleRow.implicitWidth + 20)

                color: badgeHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                border.color: badgeHover.hovered ?
                              Qt.rgba(cardRoot.currentTabMeta.color.r, cardRoot.currentTabMeta.color.g, cardRoot.currentTabMeta.color.b, 0.45) :
                              Qt.rgba(1, 1, 1, 0.09)
                border.width: 1

                scale: badgeTap.pressed ? 0.96 : 1.0
                Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                Behavior on color { ColorAnimation { duration: Theme.animInstant } }
                Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                // 电源页下显示的“返回”形态
                Row {
                    id: backRow
                    anchors.centerIn: parent
                    spacing: 5
                    visible: titleBadge.isPowerPage

                    Text { text: "‹"; color: "#ef4444"; font.pixelSize: 14; font.weight: Font.Black }
                    Text {
                        text: "返回工作台"
                        color: "white"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: cardRoot.chosenFont
                    }
                }

                // 常态下的分类 + 上下文形态
                Row {
                    id: titleRow
                    anchors.centerIn: parent
                    spacing: 6
                    visible: !titleBadge.isPowerPage
                    width: parent.width - 20

                    // 呼吸发光圆点
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: cardRoot.currentTabMeta.color
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // 模块大写分类标题
                    Text {
                        text: cardRoot.currentTabMeta.title
                        color: cardRoot.currentTabMeta.color
                        font.pixelSize: 10
                        font.weight: Font.Black
                        font.letterSpacing: 0.6
                        font.family: cardRoot.chosenFont
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    // 极简分隔点
                    Text {
                        text: "·"
                        color: Qt.rgba(1, 1, 1, 0.3)
                        font.pixelSize: 10
                        font.weight: Font.Black
                        anchors.verticalCenter: parent.verticalCenter
                        visible: cardRoot.currentTabMeta.sub !== ""
                    }

                    // 模块细分上下文信息（如桌面名 Main）
                    Text {
                        text: cardRoot.currentTabMeta.sub
                        color: "white"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: cardRoot.chosenFont
                        elide: Text.ElideRight
                        width: Math.max(20, titleRow.width - 12 - parent.children[1].implicitWidth - (parent.children[2].visible ? parent.children[2].implicitWidth : 0))
                        anchors.verticalCenter: parent.verticalCenter
                        visible: cardRoot.currentTabMeta.sub !== ""
                    }
                }

                HoverHandler { id: badgeHover; cursorShape: titleBadge.isPowerPage ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler {
                    id: badgeTap
                    onTapped: {
                        if (titleBadge.isPowerPage) {
                            cardRoot.switchRoute(cardRoot.previousTab || "workspace", "")
                        }
                    }
                }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => cardRoot.handleTabWheel(event)
                }
            }

            // 2. 右侧：一体化中控舱（指示点轨道 + 电源快速入口，统一 26px 规格）
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                z: 1

                // 2.1 Tab 指示点一体舱
                Rectangle {
                    id: tabTrackContainer
                    height: 26
                    radius: 13
                    width: dotsLayoutRow.implicitWidth + 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: trackHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: trackHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09)
                    border.width: 1
                    visible: !cardRoot.isCalling && cardRoot.enabledTabs && cardRoot.enabledTabs.length > 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: trackHover }
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (event) => cardRoot.handleTabWheel(event)
                    }

                    Row {
                        id: dotsLayoutRow
                        anchors.centerIn: parent
                        spacing: 4

                        Repeater {
                            model: cardRoot.enabledTabs || []

                            Item {
                                id: tabSlotItem
                                readonly property bool isCurrent: (cardRoot.expandedTab === modelData.key)
                                width: isCurrent ? 18 : 6
                                height: 26

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 180
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
                                           (modelData.key === "media" ? cardRoot.dominantColor : (modelData.color ? modelData.color : Theme.workspace)) :
                                           (tabMouseArea.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.32))

                                    scale: tabSlotItem.isCurrent ? 1.0 : (tabMouseArea.containsMouse ? 1.3 : 1.0)

                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                }

                                MouseArea {
                                    id: tabMouseArea
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: cardRoot.switchRoute(modelData.key, "")
                                    onWheel: (wheel) => cardRoot.handleTabWheel(wheel)
                                }
                            }
                        }
                    }
                }

                // 2.2 电源快捷按键（高精度圆形胶囊）
                Rectangle {
                    id: powerQuickBtn
                    width: 26
                    height: 26
                    radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !cardRoot.isCalling

                    readonly property bool isPowerActive: (cardRoot.expandedTab === "power")
                    color: isPowerActive ? Qt.rgba(239, 68, 68, 0.30) : (powerBtnHover.hovered ? Qt.rgba(239, 68, 68, 0.16) : Qt.rgba(1, 1, 1, 0.04))
                    border.color: (isPowerActive || powerBtnHover.hovered) ? "#ef4444" : Qt.rgba(1, 1, 1, 0.09)
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
                        color: (powerQuickBtn.isPowerActive || powerBtnHover.hovered) ? "#ef4444" : Qt.rgba(1, 1, 1, 0.70)
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
                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (event) => cardRoot.handleTabWheel(event)
                    }
                }
            }
        }

        // =====================================================================
        // 内容子页面视图（保持原有路由完全不变）
        // =====================================================================
        Item {
            width: parent.width
            height: parent.height - 38

            // 1. 来电全屏专属卡片
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

                            Item {
                                anchors.fill: parent

                                Image {
                                    id: cardAvatarRawImg
                                    source: cardRoot.callAvatar
                                    visible: false
                                    cache: true
                                    asynchronous: true
                                    onStatusChanged: {
                                        if (status === Image.Ready) {
                                            cardAvatarCanvas.requestPaint()
                                        }
                                    }
                                }

                                Canvas {
                                    id: cardAvatarCanvas
                                    anchors.fill: parent
                                    renderTarget: Canvas.FramebufferObject
                                    renderStrategy: Canvas.Threaded
                                    visible: cardAvatarRawImg.status === Image.Ready

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.reset()
                                        ctx.clearRect(0, 0, width, height)
                                        if (cardAvatarRawImg.status !== Image.Ready) return

                                        ctx.save()
                                        ctx.beginPath()
                                        ctx.arc(width / 2.0, height / 2.0, width / 2.0 - 0.5, 0, 2 * Math.PI, false)
                                        ctx.closePath()
                                        ctx.clip()
                                        ctx.drawImage(cardAvatarRawImg, 0, 0, width, height)
                                        ctx.restore()
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "#4F46E5"
                                    visible: cardAvatarRawImg.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: {
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
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: Qt.rgba(255, 255, 255, 0.2)
                                    border.width: 1.5
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

            TimeDetailPage {
                anchors.fill: parent
                chosenFont: cardRoot.chosenFont
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
                position: cardRoot.position; duration: cardRoot.duration
                dominantColor: cardRoot.dominantColor
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

            Loader {
                id: bluetoothLoader; anchors.fill: parent
                active: !cardRoot.isCalling && (cardRoot.expandedTab === "bluetooth")
                visible: active
                sourceComponent: Component {
                    BluetoothPage { chosenFont: cardRoot.chosenFont }
                }
            }

            Loader {
                id: notifLoader; anchors.fill: parent
                active: !cardRoot.isCalling && (cardRoot.expandedTab === "notification")
                visible: active
                sourceComponent: Component {
                    NotificationPage {
                        chosenFont: cardRoot.chosenFont
                    }
                }
                Connections {
                    target: notifLoader.item
                    ignoreUnknownSignals: true
                    function onStartCollapse() { cardRoot.startCollapse() }
                }
            }

            Loader {
                id: powerLoader; anchors.fill: parent
                active: !cardRoot.isCalling && (cardRoot.expandedTab === "power")
                visible: active
                sourceComponent: Component {
                    PowerPage {
                        chosenFont: cardRoot.chosenFont
                    }
                }
                Connections {
                    target: powerLoader.item
                    ignoreUnknownSignals: true
                    function onStartCollapse() { cardRoot.startCollapse() }
                }
            }
        }
    }
}