import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Item {
    id: root
    width: 460
    height: 270

    property bool isExpanded: false
    property bool animationReady: false
    property bool isCollapsing: false

    readonly property bool isMouseOverCapsule: (typeof capsuleHover !== "undefined" && capsuleHover.hovered) || (typeof capsuleMouseArea !== "undefined" && capsuleMouseArea.containsMouse)

    function handleCapsuleHoverEnter() {
        root.cancelCollapse()
        if (!root.isExpanded && !root.isCollapsing) {
            hoverDwellTimer.restart()
        }
    }

    function handleCapsuleHoverLeave() {
        hoverDwellTimer.stop()
        root.requestCollapse()
    }

    readonly property string chosenFont: {
        if (!Config.fontFamily || Config.fontFamily.indexOf("系统默认") !== -1) return ""
        return Config.fontFamily
    }

    // 媒体属性
    property string title: "等待播放..."
    property string artist: "未知歌手"
    property string status: "Paused"
    property string artUrl: ""
    property real position: 0
    property real duration: 0

    // 通话持续状态
    property bool isCalling: false
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""

    // 瞬态冲激事件
    property string activeTransient: ""   // "", "WORKSPACE", "OSD", "ALERT"
    property string osdIcon: "🔊"
    property int osdValue: 50
    property int wsCurrent: 1
    property int wsTotal: 4
    property string wsName: "Desktop 1"
    property string alertIcon: "🔔"
    property string alertTitle: ""
    property string alertSubtitle: ""
    property string alertAvatar: ""

    readonly property bool isSplit: (root.activeTransient !== "" || root.isCalling) && !root.isExpanded
    readonly property int splitGap: 8
    readonly property int subBubbleWidth: (root.status === "Playing") ? 74 : 60

    onIsSplitChanged: root.commitEnvelopeMask(Math.max(root.targetWidth, capsule.width), Math.max(root.targetHeight, capsule.height))

    function formatMediaTime(sec, forceHours) {
        if (!sec || isNaN(sec) || sec <= 0) return forceHours ? "0:00:00" : "0:00"
        var totalSec = Math.floor(sec)
        var h = Math.floor(totalSec / 3600)
        var m = Math.floor((totalSec % 3600) / 60)
        var s = totalSec % 60
        if (h > 0 || forceHours) {
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
        }
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    property string displayDate: ""
    property string displayTime: "04:53"
    property string displayPeriod: "pm"
    property string displaySeconds: ""

    // 展开 Tab 控制：media | calendar | clock
    property string expandedTab: "calendar"

    SettingsWindow { id: settingsDialog }

    Timer {
        id: raiseTimer
        interval: 160
        onTriggered: Bridge.forceRaise()
    }

    Timer {
        interval: 1000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: updateDateTime()
    }

    Connections {
        target: Config
        function onTimeFormatChanged() { root.updateDateTime() }
        function onShowSecondsChanged() { root.updateDateTime() }
        function onShowDateChanged() { root.updateDateTime() }
        function onFontFamilyChanged() { }
        function onTopMarginChanged() { root.commitEnvelopeMask(capsule.width, capsule.height) }
        function onOffsetXChanged() { root.commitEnvelopeMask(capsule.width, capsule.height) }
    }

    function updateDateTime() {
        var d = new Date()
        var h = d.getHours()
        var m = d.getMinutes()
        var s = d.getSeconds()
        
        if (Config.showDate) {
            var days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            var mStr = (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1)
            var dStr = (d.getDate() < 10 ? "0" : "") + d.getDate()
            root.displayDate = mStr + "/" + dStr + " " + days[d.getDay()]
        } else {
            root.displayDate = ""
        }

        root.displaySeconds = Config.showSeconds ? (":" + (s < 10 ? "0" : "") + s) : ""

        if (Config.timeFormat === "24h") {
            root.displayTime = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
            root.displayPeriod = ""
        } else {
            root.displayPeriod = h >= 12 ? "pm" : "am"
            h = h % 12
            h = h ? h : 12
            root.displayTime = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
        }
    }

    Timer {
        id: transientTimer
        onTriggered: root.activeTransient = ""
    }

    function triggerTransient(mode, ms) {
        if (root.isExpanded) return
        root.activeTransient = mode
        transientTimer.interval = ms
        transientTimer.restart()
    }

    onIsExpandedChanged: {
        if (isExpanded && activeTransient === "ALERT") {
            transientTimer.stop()
        }
    }

    Connections {
        target: Bridge
        function onMediaUpdated(t, a, s, u, pos, dur) {
            var wasPlaying = (root.status === "Playing")
            root.title = t; root.artist = a; root.status = s; root.artUrl = u
            var p = (pos !== undefined && !isNaN(pos)) ? Number(pos) : 0
            var d = (dur !== undefined && !isNaN(dur)) ? Number(dur) : 0
            root.duration = d
            root.position = p

            if (!wasPlaying && s === "Playing") {
                root.expandedTab = "media"
            }
        }
        function onProgressUpdated(pos, dur, prog) {
            var p = (pos !== undefined && !isNaN(pos)) ? Number(pos) : 0
            var d = (dur !== undefined && !isNaN(dur)) ? Number(dur) : root.duration
            if (d > 0) root.duration = d

            if (d > 0 && p >= d && root.status === "Playing" && root.position > 0 && (d - root.position > 5)) {
                return
            }
            root.position = p
        }
        function onOsdTriggered(icon, label, val) {
            root.osdIcon = icon; root.osdValue = val
            root.triggerTransient("OSD", 1500)
        }
        function onWorkspaceTriggered(curr, tot, name) {
            root.wsCurrent = curr; root.wsTotal = tot; root.wsName = name
            root.triggerTransient("WORKSPACE", 1800)
            Bridge.forceRaise()
            raiseTimer.restart()
        }
        function onAlertTriggered(icon, t, sub, ms, avatar) {
            if (icon === "📞" || ms <= 0) {
                root.isCalling = true
                root.expandedTab = "media"
                root.callTitle = t
                root.callSubtitle = sub || "正在通话..."
                root.callAvatar = (avatar !== undefined && avatar !== null) ? avatar : ""
            } else {
                root.alertIcon = icon; root.alertTitle = t; root.alertSubtitle = sub
                root.alertAvatar = (avatar !== undefined && avatar !== null) ? avatar : ""
                root.triggerTransient("ALERT", ms > 0 ? ms : 5000)
            }
        }
        function onCallEndedTriggered() {
            root.isCalling = false
            if (root.isExpanded) {
                root.startCollapse()
            }
            root.alertIcon = "📞"
            root.alertTitle = root.callTitle || "Teams 通话"
            root.alertSubtitle = "呼叫已完成"
            root.alertAvatar = ""
            root.triggerTransient("ALERT", 1500)
        }
    }

    Timer {
        id: hoverDwellTimer
        interval: 180
        onTriggered: {
            if (!root.isCollapsing && root.isMouseOverCapsule && !root.isExpanded) {
                root.isExpanded = true
            }
        }
    }

    Timer {
        id: leaveGraceTimer
        interval: 350
        onTriggered: {
            if (root.isCalling) return
            if ((typeof capsuleHover !== "undefined" && capsuleHover.hovered) || capsuleMouseArea.containsMouse) {
                return
            }
            root.startCollapse()
        }
    }

    Timer {
        id: cooldownTimer
        interval: 150
        onTriggered: {
            root.isCollapsing = false
            if (root.isMouseOverCapsule && !root.isExpanded) {
                hoverDwellTimer.restart()
            }
        }
    }

    function cancelCollapse() {
        leaveGraceTimer.stop()
    }

    function requestCollapse() {
        if (root.isCalling) return
        if (root.isExpanded) {
            leaveGraceTimer.restart()
        }
    }

    function startCollapse() {
        if (!root.isExpanded) return
        root.isCollapsing = true
        hoverDwellTimer.stop()
        leaveGraceTimer.stop()
        root.isExpanded = false
        if (root.activeTransient === "ALERT") {
            root.activeTransient = ""
        }
    }

    readonly property int targetWidth: {
        if (root.isExpanded) return 430
        if (root.isCalling) return 250
        if (root.activeTransient === "ALERT") {
            var rawLen = (root.alertTitle.length + root.alertSubtitle.length)
            var alertW = (rawLen > 18) ? 310 : Math.max(210, rawLen * 10 + 64)
            return alertW
        }
        if (root.activeTransient === "WORKSPACE") {
            var wsW = wsLayoutRow.implicitWidth
            return root.isSplit ? Math.max(165, wsW + 40) : ((root.status === "Playing") ? Math.max(225, wsW + 60) : Math.max(170, wsW + 40))
        }
        if (root.activeTransient === "OSD") {
            return root.isSplit ? 148 : ((root.status === "Playing") ? 236 : 205)
        }
        var textW = compactTimeRow.implicitWidth
        return (root.status === "Playing") ? (textW + 74) : (textW + 36)
    }

    readonly property int targetHeight: {
        if (root.isExpanded) return 240
        if (root.activeTransient === "ALERT") {
            return (root.alertSubtitle.length > 15) ? 48 : 40
        }
        if (root.isCalling) return 38
        return 36
    }

    onTargetWidthChanged: handleGeometryWillChange()
    onTargetHeightChanged: handleGeometryWillChange()

    function handleGeometryWillChange() {
        if (!root.animationReady) return
        if (root.targetWidth > capsule.width || root.targetHeight > capsule.height) {
            commitEnvelopeMask(Math.max(root.targetWidth, capsule.width), Math.max(root.targetHeight, capsule.height))
        }
    }

    function commitEnvelopeMask(w, h) {
        var padX = 20
        var padY = 10
        var totalW = root.isSplit ? (w + root.splitGap + root.subBubbleWidth) : w
        var safeW = totalW + padX * 2
        var safeH = h + padY
        var pX = Math.max(0, Math.round((root.width - safeW) / 2) + Config.offsetX)
        var pY = Math.max(0, Math.round(capsule.y))
        Bridge.updateMask(pX, pY, Math.round(safeW), Math.round(safeH))
    }

    Rectangle {
        id: capsule
        anchors.top: parent.top
        anchors.topMargin: Config.topMargin
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Config.offsetX - (root.isSplit ? Math.round((root.subBubbleWidth + root.splitGap) / 2) : 0)
        Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        width: root.targetWidth
        height: root.targetHeight
        radius: root.isExpanded ? 28 : Math.min(height / 2, 20)
        clip: true

        color: Qt.rgba(0.08, 0.08, 0.1, 0.96)
        border.color: (capsuleMouseArea.containsMouse || root.isExpanded) ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.14)
        border.width: 1

        scale: (!root.isExpanded && capsuleMouseArea.containsMouse && !root.isCollapsing) ? 1.02 : 1.0
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

        Behavior on width {
            enabled: root.animationReady
            NumberAnimation {
                duration: root.isExpanded ? 340 : 260
                easing.type: root.isExpanded ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.06
                onRunningChanged: {
                    if (!running) {
                        root.commitEnvelopeMask(capsule.width, capsule.height)
                        if (!root.isExpanded) cooldownTimer.restart()
                    }
                }
            }
        }
        Behavior on height {
            enabled: root.animationReady
            NumberAnimation {
                duration: root.isExpanded ? 340 : 260
                easing.type: Easing.OutCubic
                onRunningChanged: {
                    if (!running) {
                        root.commitEnvelopeMask(capsule.width, capsule.height)
                        if (!root.isExpanded) cooldownTimer.restart()
                    }
                }
            }
        }
        Behavior on radius {
            enabled: root.animationReady
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        HoverHandler {
            id: capsuleHover
            onHoveredChanged: {
                if (hovered) {
                    root.cancelCollapse()
                } else {
                    root.requestCollapse()
                }
            }
        }
        MouseArea {
            id: capsuleMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: (root.isCalling || root.activeTransient === "ALERT") ? Qt.PointingHandCursor : Qt.ArrowCursor

            onEntered: {
                root.cancelCollapse()
                if (!root.isExpanded && !root.isCollapsing) {
                    hoverDwellTimer.restart()
                }
            }
            onExited: {
                hoverDwellTimer.stop()
                root.requestCollapse()
            }
            onClicked: (mouse) => {
                hoverDwellTimer.stop(); leaveGraceTimer.stop()
                if (mouse.button === Qt.RightButton) {
                    settingsDialog.show(); settingsDialog.raise(); settingsDialog.requestActivate()
                } else {
                    if (root.isCalling) {
                        Bridge.focusTeamsWindow()
                        return
                    }
                    if (root.activeTransient === "ALERT" && !root.isExpanded) {
                        Bridge.focusTeamsWindow()
                        root.activeTransient = ""
                        return
                    }
                    if (root.isExpanded) {
                        root.startCollapse()
                    } else {
                        root.isExpanded = true
                    }
                }
            }
        }

        Item {
            id: compactContainer
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            opacity: root.isExpanded ? 0 : 1
            visible: opacity > 0.01

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.isExpanded ? 0 : 50 }
                    NumberAnimation {
                        duration: root.isExpanded ? 60 : 160
                        easing.type: Easing.OutQuad
                    }
                }
            }

            // 1. 瞬态：工作区切换
            Row {
                id: wsLayoutRow
                anchors.centerIn: parent
                spacing: 8
                opacity: root.activeTransient === "WORKSPACE" ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                Text {
                    text: "🖥️ " + (root.wsName ? root.wsName : ("桌面 " + root.wsCurrent))
                    color: "white"
                    font.family: root.chosenFont
                    font.pixelSize: 12
                    font.weight: Font.Black
                    anchors.verticalCenter: parent.verticalCenter
                }
                Row {
                    spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: Math.min(10, Math.max(1, root.wsTotal))
                        Rectangle {
                            width: (index + 1) === root.wsCurrent ? 14 : 4
                            height: 4; radius: 99
                            color: (index + 1) === root.wsCurrent ? "white" : Qt.rgba(1, 1, 1, 0.3)
                            Behavior on width { NumberAnimation { duration: 200 } }
                        }
                    }
                }
            }

            // 2. 瞬态：音量/亮度 OSD
            Row {
                anchors.centerIn: parent
                spacing: 7
                opacity: root.activeTransient === "OSD" ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

                Text { text: root.osdIcon; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: (root.status === "Playing") ? 80 : 96
                    height: 4; radius: 99; color: Qt.rgba(1, 1, 1, 0.2)
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: parent.width * Math.min(1.0, Math.max(0.0, root.osdValue / 100.0))
                        height: parent.height; radius: 99; color: "white"
                    }
                }
                Text { text: root.osdValue + "%"; color: "white"; font.family: (root.chosenFont !== "") ? root.chosenFont : "Monospace"; font.pixelSize: 11; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
            }

            // 3. 瞬态：通知提醒 (ALERT 紧凑条态)
            Row {
                anchors.fill: parent
                spacing: 10
                visible: root.activeTransient === "ALERT"

                Rectangle {
                    width: (capsule.height >= 46) ? 30 : 25
                    height: width
                    radius: width / 2
                    color: avatarImg.visible ? "transparent" : "#4F6BED"
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true

                    Image {
                        id: avatarImg
                        anchors.fill: parent
                        source: root.alertAvatar
                        fillMode: Image.PreserveAspectCrop
                        visible: root.alertAvatar !== "" && status === Image.Ready
                        cache: false
                    }
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (avatarImg.visible) return ""
                            if (root.alertTitle && root.alertTitle.length > 0) {
                                var parts = root.alertTitle.trim().split(" ")
                                return (parts.length >= 2) ? (parts[0][0] + parts[1][0]).toUpperCase() : root.alertTitle.trim().charAt(0).toUpperCase()
                            }
                            return root.alertIcon
                        }
                        color: "white"
                        font.family: root.chosenFont
                        font.pixelSize: (capsule.height >= 46) ? 12 : 11
                        font.weight: Font.Black
                        visible: !avatarImg.visible
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    width: parent.width - ((capsule.height >= 46) ? 40 : 35)

                    Row {
                        width: parent.width
                        spacing: 5
                        Text {
                            id: alertTitleText
                            text: root.alertTitle
                            color: "white"
                            font.family: root.chosenFont
                            font.pixelSize: 12
                            font.weight: Font.Black
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Text {
                            text: "• Teams"
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.family: root.chosenFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        id: alertSubText
                        text: root.alertSubtitle
                        color: Qt.rgba(1, 1, 1, 0.9)
                        font.family: root.chosenFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                        maximumLineCount: (capsule.height >= 46) ? 2 : 1
                        lineHeight: 1.1
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            // 4. 持续态：正在通话中
            Row {
                anchors.fill: parent
                spacing: 10
                visible: root.isCalling && root.activeTransient === ""

                Rectangle {
                    width: 26; height: 26; radius: 13
                    color: callAvatarImg.visible ? "transparent" : "#22c55e"
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    Image {
                        id: callAvatarImg; anchors.fill: parent; source: root.callAvatar
                        fillMode: Image.PreserveAspectCrop; visible: root.callAvatar !== "" && status === Image.Ready; cache: false
                    }
                    Text {
                        anchors.centerIn: parent
                        text: (root.callTitle && root.callTitle.length > 0) ? root.callTitle.trim().charAt(0).toUpperCase() : "📞"
                        color: "white"; font.family: root.chosenFont; font.pixelSize: 12; font.weight: Font.Black; visible: !callAvatarImg.visible
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 1; width: parent.width - 36
                    Text { text: root.callTitle; color: "white"; font.family: root.chosenFont; font.pixelSize: 12; font.weight: Font.Black; elide: Text.ElideRight; width: parent.width }
                    Text { text: root.callSubtitle + "  ➔ 点击直达"; color: "#22c55e"; font.family: root.chosenFont; font.pixelSize: 10; font.weight: Font.Bold; elide: Text.ElideRight; width: parent.width }
                }
            }

            // 5. 常态时钟 (扁平饱满排版、加黑加粗)
            Row {
                id: compactTimeRow
                opacity: (root.activeTransient === "" && !root.isCalling) ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                anchors.verticalCenter: parent.verticalCenter
                x: (root.status === "Playing") ? 0 : Math.max(0, Math.round((parent.width - width) / 2))
                Behavior on x { enabled: !root.isExpanded && !root.isCollapsing; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                spacing: 7

                Text {
                    id: dateText
                    text: root.displayDate
                    color: Qt.rgba(1, 1, 1, 0.82)
                    font.family: root.chosenFont
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    visible: Config.showDate && root.displayDate !== ""
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: timeText
                        text: root.displayTime
                        color: "white"
                        font.family: (root.chosenFont !== "") ? root.chosenFont : "Monospace"
                        font.pixelSize: 22
                        font.weight: Font.Black
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: secText
                        text: root.displaySeconds
                        color: "#34d399"
                        font.family: (root.chosenFont !== "") ? root.chosenFont : "Monospace"
                        font.pixelSize: 14
                        font.weight: Font.ExtraBold
                        visible: Config.showSeconds && root.displaySeconds !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 1
                    }

                    Text {
                        id: periodText
                        text: root.displayPeriod
                        color: Qt.rgba(1, 1, 1, 0.65)
                        font.family: root.chosenFont
                        font.pixelSize: 10
                        font.weight: Font.Black
                        font.capitalization: Font.AllUppercase
                        visible: Config.timeFormat === "12h" && root.displayPeriod !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 2
                    }
                }
            }

            // 6. 媒体绿色律动波形
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3.0
                opacity: (root.status === "Playing" && !root.isCalling && root.activeTransient === "" && !root.isSplit) ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Repeater {
                    model: [13, 9, 14, 10]
                    Rectangle {
                        width: 2.2; radius: 99; color: "#22c55e"
                        height: 3
                        SequentialAnimation on height {
                            running: root.status === "Playing"
                            loops: Animation.Infinite
                            NumberAnimation { to: modelData; duration: 280 + index * 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 3; duration: 320 + index * 35; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }
        }

        // ==========================================================
        // 展开大卡片层
        // ==========================================================
        Item {
            id: expandedView
            anchors.fill: parent
            anchors.margins: 16
            opacity: root.isExpanded ? 1 : 0
            scale: root.isExpanded ? 1.0 : 0.92
            y: root.isExpanded ? 0 : 12
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: root.isExpanded ? 220 : 120
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.isExpanded ? 300 : 180
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: root.isExpanded ? 280 : 180
                    easing.type: Easing.OutCubic
                }
            }

            Column {
                anchors.fill: parent
                spacing: 12

                // 1. 顶部状态信息行与滑动控制器
                Item {
                    width: parent.width; height: 26

                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: root.isCalling ? "● INCOMING CALL" : 
                              (root.activeTransient === "ALERT" ? "● NOTIFICATION" : 
                              (root.expandedTab === "calendar" ? "● CALENDAR" : 
                              (root.expandedTab === "clock" ? "● WORLD CLOCK" : 
                              (root.status === "Playing" ? "● NOW PLAYING" : "⏸ PAUSED"))))

                        color: root.isCalling ? "#22c55e" : 
                               (root.activeTransient === "ALERT" ? "#818cf8" : 
                               (root.expandedTab === "calendar" ? "#38bdf8" : 
                               (root.expandedTab === "clock" ? "#f59e0b" : 
                               (root.status === "Playing" ? Qt.rgba(0.2, 0.85, 0.5, 0.9) : Qt.rgba(1, 1, 1, 0.4)))))
                        font.family: root.chosenFont
                        font.pixelSize: 10; font.weight: Font.Black; font.letterSpacing: 0.8
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 198; height: 24; radius: 12
                        color: Qt.rgba(1, 1, 1, 0.08)
                        visible: !root.isCalling && root.activeTransient !== "ALERT"

                        Rectangle {
                            y: 2
                            x: (root.expandedTab === "media") ? 2 : ((root.expandedTab === "calendar") ? 68 : 134)
                            width: 62; height: 20; radius: 10
                            color: (root.expandedTab === "calendar") ? Qt.rgba(56, 189, 248, 0.22) : ((root.expandedTab === "clock") ? Qt.rgba(245, 158, 11, 0.22) : Qt.rgba(1, 1, 1, 0.18))
                            border.color: (root.expandedTab === "calendar") ? "#38bdf8" : ((root.expandedTab === "clock") ? "#f59e0b" : Qt.rgba(1, 1, 1, 0.3))
                            border.width: 1
                            Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                        }

                        Row {
                            anchors.fill: parent
                            Item {
                                width: 66; height: parent.height
                                Row {
                                    anchors.centerIn: parent; spacing: 3
                                    Text { text: "🎵"; font.pixelSize: 10 }
                                    Text { text: "媒体"; color: root.expandedTab === "media" ? "white" : Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 11; font.family: root.chosenFont; font.weight: Font.Bold }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.expandedTab = "media"
                                }
                            }
                            Item {
                                width: 66; height: parent.height
                                Row {
                                    anchors.centerIn: parent; spacing: 3
                                    Text { text: "📅"; font.pixelSize: 10 }
                                    Text { text: "日历"; color: root.expandedTab === "calendar" ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 11; font.family: root.chosenFont; font.weight: Font.Bold }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.expandedTab = "calendar"
                                        calendarPage.resetToToday()
                                    }
                                }
                            }
                            Item {
                                width: 66; height: parent.height
                                Row {
                                    anchors.centerIn: parent; spacing: 3
                                    Text { text: "🌍"; font.pixelSize: 10 }
                                    Text { text: "时钟"; color: root.expandedTab === "clock" ? "#f59e0b" : Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 11; font.family: root.chosenFont; font.weight: Font.Bold }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.expandedTab = "clock"
                                        if (root.Window && root.Window.window) {
                                            root.Window.window.requestActivate()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 2. 页面内容展示区
                Item {
                    width: parent.width
                    height: parent.height - 38

                    // ==========================================
                    // 页面 A: 独立 Bento 日历面板
                    // ==========================================
                    CalendarPage {
                        id: calendarPage
                        anchors.fill: parent
                        chosenFont: root.chosenFont
                        opacity: (root.expandedTab === "calendar" && !root.isCalling && root.activeTransient !== "ALERT") ? 1.0 : 0.0
                        x: (root.expandedTab === "calendar") ? 0 : 26
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }
                        Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    }

                    // ==========================================
                    // 页面 B: 媒体播放与通话卡片
                    // ==========================================
                    Column {
                        id: mediaPage
                        anchors.fill: parent
                        spacing: 14
                        opacity: ((root.expandedTab === "media" || root.isCalling) && root.activeTransient !== "ALERT") ? 1.0 : 0.0
                        x: (root.expandedTab === "media" || root.isCalling) ? 0 : -26
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }
                        Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                        Item {
                            width: parent.width; height: 56
                            Row {
                                anchors.fill: parent
                                spacing: 16
                                Rectangle {
                                    width: 56; height: 56; radius: 14
                                    color: root.isCalling ? "#4F46E5" : "#27272a"
                                    border.color: (!root.isCalling && mediaPortalHover.containsMouse) ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.15)
                                    clip: true
                                    Image {
                                        id: coverImg; anchors.fill: parent
                                        source: root.isCalling ? root.callAvatar : (root.artUrl ? (root.artUrl.indexOf("://") !== -1 ? root.artUrl : "file://" + root.artUrl) : "")
                                        fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; visible: status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            if (coverImg.status === Image.Ready) return ""
                                            if (root.isCalling) {
                                                if (root.callTitle && root.callTitle.length > 0) {
                                                    var parts = root.callTitle.trim().split(" ")
                                                    return (parts.length >= 2) ? (parts[0][0] + parts[1][0]).toUpperCase() : root.callTitle.trim().charAt(0).toUpperCase()
                                                }
                                                return "📞"
                                            }
                                            return "🎵"
                                        }
                                        font.pixelSize: 20; font.family: root.chosenFont; font.weight: Font.Black; color: "white"
                                        visible: coverImg.status !== Image.Ready
                                    }
                                    Rectangle {
                                        anchors.fill: parent; radius: 14; color: Qt.rgba(0, 0, 0, 0.45)
                                        visible: !root.isCalling && mediaPortalHover.containsMouse
                                        Text { anchors.centerIn: parent; text: "↗"; color: "white"; font.pixelSize: 20; font.weight: Font.Bold }
                                    }
                                }
                                Column {
                                    width: parent.width - 72; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                                    Row {
                                        width: parent.width; spacing: 6
                                        Text {
                                            text: root.isCalling ? root.callTitle : (root.title ? root.title : "等待播放...")
                                            color: (!root.isCalling && mediaPortalHover.containsMouse) ? "#38bdf8" : "white"
                                            font.family: root.chosenFont; font.pixelSize: 15; font.weight: Font.Black; elide: Text.ElideRight
                                            width: (!root.isCalling) ? (parent.width - 20) : parent.width
                                        }
                                        Text {
                                            text: "↗"
                                            color: "#38bdf8"; font.pixelSize: 13; font.weight: Font.Bold
                                            visible: !root.isCalling && mediaPortalHover.containsMouse
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    Text {
                                        text: root.isCalling ? root.callSubtitle : ((root.artist ? root.artist : "未知歌手") + (mediaPortalHover.containsMouse ? " · 唤起客户端" : ""))
                                        color: root.isCalling ? "#22c55e" : Qt.rgba(1, 1, 1, 0.6)
                                        font.family: root.chosenFont; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width
                                    }
                                }
                            }
                            MouseArea {
                                id: mediaPortalHover
                                anchors.fill: parent
                                enabled: !root.isCalling
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.cancelCollapse()
                                onExited: root.requestCollapse()
                                onClicked: {
                                    Bridge.focusMediaWindow(root.title, root.artist)
                                    root.startCollapse()
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 8
                            visible: root.isCalling
                            Rectangle {
                                id: callPortalBtn
                                width: parent.width; height: 42; radius: 21
                                color: callPortalArea.pressed ? "#15803d" : (callPortalArea.containsMouse ? "#16a34a" : "#22c55e")
                                scale: callPortalArea.pressed ? 0.98 : (callPortalArea.containsMouse ? 1.01 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 120 } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Row {
                                    anchors.centerIn: parent; spacing: 8
                                    Text { text: "📞"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "唤起 Teams 窗口接听"; color: "white"; font.family: root.chosenFont; font.pixelSize: 14; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "↗"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 14; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea {
                                    id: callPortalArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onEntered: root.cancelCollapse(); onExited: root.requestCollapse()
                                    onClicked: (mouse) => { mouse.accepted = true; Bridge.focusTeamsWindow(); root.startCollapse() }
                                }
                            }
                            Text { text: "💡 跨桌面秒级聚焦 · 确认摄像头与麦克风状态"; color: Qt.rgba(1, 1, 1, 0.5); font.family: root.chosenFont; font.pixelSize: 11; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                        }

                        Item {
                            width: parent.width; height: 18
                            visible: !root.isCalling
                            Text { id: posText; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: root.formatMediaTime(root.position, root.duration >= 3600); color: Qt.rgba(1, 1, 1, 0.6); font.family: (root.chosenFont !== "") ? root.chosenFont : "Monospace"; font.pixelSize: 10; font.weight: Font.Bold }
                            Rectangle {
                                id: progressTrack
                                anchors.left: posText.right; anchors.right: durText.left; anchors.leftMargin: 10; anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter; height: 4; radius: 99; color: Qt.rgba(1, 1, 1, 0.15)
                                Rectangle {
                                    width: root.duration > 0 ? (progressTrack.width * Math.min(1.0, Math.max(0.0, root.position / root.duration))) : 0
                                    height: parent.height; radius: 99; color: "white"
                                }
                            }
                            Text { id: durText; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.formatMediaTime(root.duration); color: Qt.rgba(1, 1, 1, 0.6); font.family: (root.chosenFont !== "") ? root.chosenFont : "Monospace"; font.pixelSize: 10; font.weight: Font.Bold }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 56
                            visible: !root.isCalling
                            Item {
                                width: 38; height: 38
                                Text { anchors.centerIn: parent; text: "⏮"; color: "white"; font.pixelSize: 18; opacity: prevArea.pressed ? 1.0 : (prevArea.containsMouse ? 0.9 : 0.6); scale: prevArea.pressed ? 0.85 : 1.0 }
                                MouseArea { id: prevArea; anchors.fill: parent; hoverEnabled: true; onEntered: root.cancelCollapse(); onExited: root.requestCollapse(); onClicked: (mouse) => { mouse.accepted = true; Bridge.sendMediaCmd("MEDIA_PREV") } }
                            }
                            Item {
                                width: 40; height: 38
                                Text { anchors.centerIn: parent; text: root.status === "Playing" ? "⏸" : "▶"; color: "white"; font.pixelSize: 22; opacity: playArea.pressed ? 1.0 : (playArea.containsMouse ? 1.0 : 0.8); scale: playArea.pressed ? 0.85 : 1.0 }
                                MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; onEntered: root.cancelCollapse(); onExited: root.requestCollapse(); onClicked: (mouse) => { mouse.accepted = true; Bridge.sendMediaCmd("MEDIA_PLAY_PAUSE") } }
                            }
                            Item {
                                width: 38; height: 38
                                Text { anchors.centerIn: parent; text: "⏭"; color: "white"; font.pixelSize: 18; opacity: nextArea.pressed ? 1.0 : (nextArea.containsMouse ? 0.9 : 0.6); scale: nextArea.pressed ? 0.85 : 1.0 }
                                MouseArea { id: nextArea; anchors.fill: parent; hoverEnabled: true; onEntered: root.cancelCollapse(); onExited: root.requestCollapse(); onClicked: (mouse) => { mouse.accepted = true; Bridge.sendMediaCmd("MEDIA_NEXT") } }
                            }
                        }
                    }

                    // ==========================================
                    // 页面 C: 独立世界时钟
                    // ==========================================
                    WorldClockPage {
                        id: worldClockPage
                        anchors.fill: parent
                        chosenFont: root.chosenFont
                        is24h: Config.timeFormat === "24h"
                        opacity: (root.expandedTab === "clock" && !root.isCalling && root.activeTransient !== "ALERT") ? 1.0 : 0.0
                        x: (root.expandedTab === "clock") ? 0 : 26
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutQuad } }
                        Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    }

                    // ==========================================
                    // 页面 D: 专属消息通知大卡片 (ALERT 详情展开)
                    // ==========================================
                    Item {
                        id: alertExpandedPage
                        anchors.fill: parent
                        opacity: (root.activeTransient === "ALERT" && !root.isCalling) ? 1.0 : 0.0
                        visible: opacity > 0.01

                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                        Column {
                            anchors.fill: parent
                            spacing: 12

                            Row {
                                width: parent.width
                                spacing: 14

                                Rectangle {
                                    width: 46; height: 46; radius: 14
                                    color: alertExpandedAvatar.visible ? "transparent" : "#4F6BED"
                                    clip: true
                                    anchors.verticalCenter: parent.verticalCenter

                                    Image {
                                        id: alertExpandedAvatar
                                        anchors.fill: parent
                                        source: root.alertAvatar
                                        fillMode: Image.PreserveAspectCrop
                                        visible: root.alertAvatar !== "" && status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            if (alertExpandedAvatar.visible) return ""
                                            if (root.alertTitle && root.alertTitle.length > 0) {
                                                var parts = root.alertTitle.trim().split(" ")
                                                return (parts.length >= 2) ? (parts[0][0] + parts[1][0]).toUpperCase() : root.alertTitle.trim().charAt(0).toUpperCase()
                                            }
                                            return "🔔"
                                        }
                                        color: "white"; font.family: root.chosenFont; font.pixelSize: 18; font.weight: Font.Black
                                        visible: !alertExpandedAvatar.visible
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3
                                    width: parent.width - 60

                                    Row {
                                        spacing: 6
                                        Text {
                                            text: root.alertTitle
                                            color: "white"; font.family: root.chosenFont; font.pixelSize: 15; font.weight: Font.Black
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: "• Microsoft Teams"
                                            color: "#818cf8"; font.family: root.chosenFont; font.pixelSize: 11; font.weight: Font.Bold
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        text: "刚刚收到新消息"
                                        color: Qt.rgba(1, 1, 1, 0.5); font.family: root.chosenFont; font.pixelSize: 11; font.weight: Font.DemiBold
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width; height: 52; radius: 10
                                color: Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.08)

                                Text {
                                    anchors.fill: parent; anchors.margins: 10
                                    text: root.alertSubtitle
                                    color: Qt.rgba(1, 1, 1, 0.95)
                                    font.family: root.chosenFont
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.Wrap
                                    lineHeight: 1.2
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                }
                            }

                            Rectangle {
                                width: parent.width; height: 36; radius: 18
                                color: alertActionArea.pressed ? "#4338ca" : (alertActionArea.containsMouse ? "#4f46e5" : "#6366f1")

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: "💬"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "唤起 Teams 立即查看回复"; color: "white"; font.family: root.chosenFont; font.pixelSize: 12; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "↗"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                }

                                MouseArea {
                                    id: alertActionArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Bridge.focusTeamsWindow()
                                        root.startCollapse()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: subBubble
        anchors.left: capsule.right
        anchors.leftMargin: root.splitGap
        anchors.verticalCenter: capsule.verticalCenter

        width: root.subBubbleWidth
        height: capsule.height
        radius: height / 2

        color: Qt.rgba(0.08, 0.08, 0.1, 0.96)
        border.color: subBubbleHover.hovered ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.15)
        border.width: 1

        opacity: root.isSplit ? 1.0 : 0.0
        scale: root.isSplit ? 1.0 : 0.4
        visible: opacity > 0.01

        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

        Row {
            anchors.centerIn: parent
            spacing: 3

            Text {
                text: root.displayTime
                color: "white"
                font.family: (root.chosenFont !== "") ? root.chosenFont : "Monospace"
                font.pixelSize: 11
                font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                spacing: 1.8
                anchors.verticalCenter: parent.verticalCenter
                visible: root.status === "Playing"

                Repeater {
                    model: [9, 5, 10]
                    Rectangle {
                        width: 1.6; radius: 99; color: "#22c55e"
                        height: 3
                        SequentialAnimation on height {
                            running: root.isSplit && root.status === "Playing"
                            loops: Animation.Infinite
                            NumberAnimation { to: modelData; duration: 260 + index * 45; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 3; duration: 300 + index * 40; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }
        }

        HoverHandler {
            id: subBubbleHover
            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            id: subBubbleArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.isExpanded = true
        }
    }

    Component.onCompleted: {
        root.animationReady = true
        root.updateDateTime()
        root.commitEnvelopeMask(capsule.width, capsule.height)

        if (root.status === "Playing" || root.isCalling) {
            root.expandedTab = "media"
        }
    }
}