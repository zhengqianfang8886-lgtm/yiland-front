import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    width: 420
    height: 240

    property bool isExpanded: false
    property bool animationReady: false
    property bool isCollapsing: false  // 核心：收拢冷却锁，杜绝回魂自弹

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
        function onFontFamilyChanged() { /* 实时触发字体刷新 */ }
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

    Connections {
        target: Bridge
        function onMediaUpdated(t, a, s, u, pos, dur) {
            root.title = t; root.artist = a; root.status = s; root.artUrl = u
            root.position = (pos !== undefined) ? pos : 0
            root.duration = (dur !== undefined) ? dur : 0
        }
        function onProgressUpdated(pos, dur, prog) {
            root.position = pos
            if (dur > 0) root.duration = dur
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
                root.callTitle = t
                root.callSubtitle = sub || "正在通话..."
                root.callAvatar = (avatar !== undefined && avatar !== null) ? avatar : ""
            } else {
                root.alertIcon = icon; root.alertTitle = t; root.alertSubtitle = sub
                root.alertAvatar = (avatar !== undefined && avatar !== null) ? avatar : ""
                root.triggerTransient("ALERT", ms > 0 ? ms : 4500)
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

    // ==============================================================
    // 悬停防抖与离手防误触发调度器
    // ==============================================================
    Timer {
        id: hoverDwellTimer
        interval: 220
        onTriggered: {
            if (!root.isCollapsing && capsuleMouseArea.containsMouse && !root.isExpanded) {
                root.isExpanded = true
            }
        }
    }

    Timer {
        id: leaveGraceTimer
        interval: 350
        onTriggered: {
            if (root.isCalling) return  // 来电高优先状态下严禁自动收拢，保持稳定就绪
            var inChildArea = prevArea.containsMouse || playArea.containsMouse || nextArea.containsMouse
            if (typeof callPortalArea !== "undefined" && callPortalArea && callPortalArea.containsMouse) {
                inChildArea = true
            }
            if (!capsuleMouseArea.containsMouse && !inChildArea) {
                root.startCollapse()
            }
        }
    }

    // 冷却计时器：收缩到位后 150ms 彻底解锁悬停
    Timer {
        id: cooldownTimer
        interval: 150
        onTriggered: root.isCollapsing = false
    }

    function cancelCollapse() {
        leaveGraceTimer.stop()
    }

    function requestCollapse() {
        if (root.isCalling) return  // 通话呼叫中拒绝响应离手超时
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
    }

    // ==============================================================
    // 动态几何预测计算 (波形贴近时钟，杜绝多余黑隙)
    // ==============================================================
    readonly property int targetWidth: {
        if (root.isExpanded) return 380
        if (root.isCalling) return 260
        if (root.activeTransient === "ALERT") {
            var rawLen = (root.alertTitle.length + root.alertSubtitle.length)
            return (rawLen > 18) ? 350 : Math.max(260, rawLen * 11 + 90)
        }
        if (root.activeTransient === "WORKSPACE") {
            var wsW = wsLayoutRow.implicitWidth
            return (root.status === "Playing") ? Math.max(235, wsW + 68) : Math.max(170, wsW + 40)
        }
        if (root.activeTransient === "OSD") {
            return (root.status === "Playing") ? 245 : 215
        }
        // 放歌时从 +72 收缩至 +54，使右侧波形与时间紧密衔接
        var textW = compactTimeRow.implicitWidth
        return (root.status === "Playing") ? (textW + 84) : (textW + 38)
    }

    readonly property int targetHeight: {
        if (root.isExpanded) return 196
        if (root.activeTransient === "ALERT") {
            return (root.alertSubtitle.length > 15) ? 64 : 54
        }
        if (root.isCalling) return 52
        return 42
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
        var padX = 6
        var padY = 6
        var safeW = w + padX * 2
        var safeH = h + padY
        var pX = Math.max(0, Math.round((root.width - safeW) / 2) + Config.offsetX)
        var pY = Math.max(0, Math.round(capsule.y))
        Bridge.updateMask(pX, pY, Math.round(safeW), Math.round(safeH))
    }

    // ==============================================================
    // 胶囊核心容器
    // ==============================================================
    Rectangle {
        id: capsule
        anchors.top: parent.top
        anchors.topMargin: Config.topMargin
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Config.offsetX

        width: root.targetWidth
        height: root.targetHeight
        radius: root.isExpanded ? 28 : Math.min(height / 2, 24)

        color: Qt.rgba(0.08, 0.08, 0.1, 0.96)
        border.color: (capsuleMouseArea.containsMouse || root.isExpanded) ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.14)
        border.width: 1

        scale: (!root.isExpanded && capsuleMouseArea.containsMouse && !root.isCollapsing) ? 1.02 : 1.0
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

        Behavior on width {
            enabled: root.animationReady
            NumberAnimation {
                duration: root.isExpanded ? 360 : 320
                easing.type: root.isExpanded ? Easing.OutCubic : Easing.OutBack
                easing.overshoot: 1.08
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
                duration: root.isExpanded ? 360 : 280
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
            NumberAnimation { duration: 280; easing.type: Easing.OutQuad }
        }

        MouseArea {
            id: capsuleMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: root.isCalling ? Qt.PointingHandCursor : Qt.ArrowCursor

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
                    if (root.isExpanded) {
                        root.startCollapse()
                    } else {
                        root.isExpanded = true
                    }
                }
            }
        }

        // ==========================================================
        // 紧凑态视口 (原位平滑淡入，杜绝跨边界位移穿帮)
        // ==========================================================
        Item {
            id: compactContainer
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18

            opacity: root.isExpanded ? 0 : 1
            visible: opacity > 0.01

            Behavior on opacity {
                SequentialAnimation {
                    // 收缩时等待外壳基本回缩到位 (140ms)，再原地优雅淡入；展开时 60ms 极速瞬隐
                    PauseAnimation { duration: root.isExpanded ? 0 : 140 }
                    NumberAnimation {
                        duration: root.isExpanded ? 60 : 140
                        easing.type: Easing.OutQuad
                    }
                }
            }

            // 1. 瞬态：工作区切换
            Row {
                id: wsLayoutRow
                anchors.verticalCenter: parent.verticalCenter
                x: (root.status === "Playing") ? 0 : Math.max(0, Math.round((parent.width - width) / 2))
                Behavior on x { enabled: !root.isExpanded && !root.isCollapsing; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                spacing: 8
                visible: root.activeTransient === "WORKSPACE"

                Text {
                    text: "🖥️ " + (root.wsName ? root.wsName : ("桌面 " + root.wsCurrent))
                    color: "white"
                    font.family: root.chosenFont
                    font.pixelSize: 13
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Row {
                    spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: Math.min(10, Math.max(1, root.wsTotal))
                        Rectangle {
                            width: (index + 1) === root.wsCurrent ? 14 : 4.5
                            height: 4.5; radius: 99
                            color: (index + 1) === root.wsCurrent ? "white" : Qt.rgba(1, 1, 1, 0.3)
                            Behavior on width { NumberAnimation { duration: 200 } }
                        }
                    }
                }
            }

            // 2. 瞬态：音量/亮度 OSD
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: (root.status === "Playing") ? 0 : Math.max(0, Math.round((parent.width - width) / 2))
                Behavior on x { enabled: !root.isExpanded && !root.isCollapsing; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                spacing: 8
                visible: root.activeTransient === "OSD"

                Text { text: root.osdIcon; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: (root.status === "Playing") ? 88 : 108
                    height: 4.5; radius: 99; color: Qt.rgba(1, 1, 1, 0.2)
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: parent.width * Math.min(1.0, Math.max(0.0, root.osdValue / 100.0))
                        height: parent.height; radius: 99; color: "white"
                    }
                }
                Text { text: root.osdValue + "%"; color: "white"; font.family: (root.chosenFont !== "") ? root.chosenFont : "Monospace"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }

            // 3. 瞬态：通知提醒 (ALERT)
            Row {
                anchors.fill: parent
                spacing: 12
                visible: root.activeTransient === "ALERT"

                Rectangle {
                    width: (capsule.height >= 58) ? 36 : 30
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
                        font.pixelSize: (capsule.height >= 58) ? 14 : 12
                        font.bold: true
                        visible: !avatarImg.visible
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    width: parent.width - ((capsule.height >= 58) ? 48 : 42)

                    Row {
                        width: parent.width
                        spacing: 6
                        Text {
                            id: alertTitleText
                            text: root.alertTitle
                            color: "white"
                            font.family: root.chosenFont
                            font.pixelSize: 13
                            font.bold: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Text {
                            text: "• Teams"
                            color: Qt.rgba(1, 1, 1, 0.4)
                            font.family: root.chosenFont
                            font.pixelSize: 10
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        id: alertSubText
                        text: root.alertSubtitle
                        color: Qt.rgba(1, 1, 1, 0.88)
                        font.family: root.chosenFont
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        maximumLineCount: (capsule.height >= 58) ? 2 : 1
                        lineHeight: 1.15
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            // 4. 持续态：正在通话中
            Row {
                anchors.fill: parent
                spacing: 12
                visible: root.isCalling && root.activeTransient === ""

                Rectangle {
                    width: 32; height: 32; radius: 16
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
                        color: "white"; font.family: root.chosenFont; font.pixelSize: 13; font.bold: true; visible: !callAvatarImg.visible
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 2; width: parent.width - 44
                    Text { text: root.callTitle; color: "white"; font.family: root.chosenFont; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; width: parent.width }
                    Text { text: root.callSubtitle + "  ➔ 点击直达"; color: "#22c55e"; font.family: root.chosenFont; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight; width: parent.width }
                }
            }

            // 5. 常态时钟
            Row {
                id: compactTimeRow
                visible: (root.activeTransient === "" && !root.isCalling)
                anchors.verticalCenter: parent.verticalCenter
                x: (root.status === "Playing") ? 0 : Math.max(0, Math.round((parent.width - width) / 2))
                Behavior on x { enabled: !root.isExpanded && !root.isCollapsing; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                spacing: 8

                Text {
                    id: dateText
                    text: root.displayDate
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.family: root.chosenFont
                    font.pixelSize: 13
                    font.bold: true
                    visible: Config.showDate && root.displayDate !== ""
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: timeText
                        text: root.displayTime
                        color: "white"
                        font.family: (root.chosenFont !== "") ? root.chosenFont : "Monospace"
                        font.pixelSize: 18
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: secText
                        text: root.displaySeconds
                        color: "#34d399"
                        font.family: (root.chosenFont !== "") ? root.chosenFont : "Monospace"
                        font.pixelSize: 13
                        font.bold: true
                        visible: Config.showSeconds && root.displaySeconds !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 1
                    }

                    Text {
                        id: periodText
                        text: root.displayPeriod
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.family: root.chosenFont
                        font.pixelSize: 10
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                        visible: Config.timeFormat === "12h" && root.displayPeriod !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 3
                    }
                }
            }

            // 6. 媒体绿色律动波形 (放歌结束平滑淡出)
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3.0
                opacity: (root.status === "Playing" && !root.isCalling && root.activeTransient === "") ? 1.0 : 0.0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Repeater {
                    model: [15, 11, 16, 12]
                    Rectangle {
                        width: 2.4; radius: 99; color: "#22c55e"
                        height: 4
                        SequentialAnimation on height {
                            running: root.status === "Playing"
                            loops: Animation.Infinite
                            NumberAnimation { to: modelData; duration: 300 + index * 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 4; duration: 340 + index * 35; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }
        }

        // ==========================================================
        // 展开大卡片层 (从下方 12px 浮现，彻底与时钟错开)
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
                    duration: root.isExpanded ? 240 : 90
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: root.isExpanded ? 340 : 160
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: root.isExpanded ? 300 : 140
                    easing.type: Easing.OutCubic
                }
            }

            Column {
                anchors.fill: parent
                spacing: 11

                // 1. 顶部状态信息
                Item {
                    width: parent.width; height: 16
                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: root.isCalling ? "● INCOMING CALL" : (root.status === "Playing" ? "● NOW PLAYING" : "⏸ PAUSED")
                        color: root.isCalling ? "#22c55e" : (root.status === "Playing" ? Qt.rgba(0.2, 0.85, 0.5, 0.9) : Qt.rgba(1, 1, 1, 0.4))
                        font.family: root.chosenFont
                        font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: (Config.showDate ? root.displayDate : "") + root.displayTime + (Config.timeFormat === "12h" ? (" " + root.displayPeriod) : "")
                        color: Qt.rgba(1, 1, 1, 0.5); font.family: (root.chosenFont !== "") ? root.chosenFont : "Monospace"; font.pixelSize: 11; font.bold: true
                    }
                }

                // 2. 来电人/媒体核心信息
                Row {
                    width: parent.width; height: 50; spacing: 14
                    Rectangle {
                        width: 50; height: 50; radius: 12
                        color: root.isCalling ? "#4F46E5" : "#27272a"
                        border.color: Qt.rgba(1, 1, 1, 0.15); clip: true
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
                            font.pixelSize: 18; font.family: root.chosenFont; font.bold: true; color: "white"
                            visible: coverImg.status !== Image.Ready
                        }
                    }
                    Column {
                        width: parent.width - 64; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Text { text: root.isCalling ? root.callTitle : (root.title ? root.title : "等待播放..."); color: "white"; font.family: root.chosenFont; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; width: parent.width }
                        Text { text: root.isCalling ? root.callSubtitle : (root.artist ? root.artist : "未知歌手"); color: root.isCalling ? "#22c55e" : Qt.rgba(1, 1, 1, 0.5); font.family: root.chosenFont; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width }
                    }
                }

                // 3. 通话专属：穿梭门接听面板 (呼叫中呈现)
                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.isCalling

                    Rectangle {
                        id: callPortalBtn
                        width: parent.width
                        height: 40
                        radius: 20
                        color: callPortalArea.pressed ? "#15803d" : (callPortalArea.containsMouse ? "#16a34a" : "#22c55e")
                        scale: callPortalArea.pressed ? 0.98 : (callPortalArea.containsMouse ? 1.01 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: "📞"; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                text: "唤起 Teams 窗口接听"
                                color: "white"
                                font.family: root.chosenFont
                                font.pixelSize: 13
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text { text: "↗"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 14; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }

                        MouseArea {
                            id: callPortalArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.cancelCollapse()
                            onExited: root.requestCollapse()
                            onClicked: (mouse) => {
                                mouse.accepted = true
                                Bridge.focusTeamsWindow()
                                root.startCollapse()
                            }
                        }
                    }

                    Text {
                        text: "💡 跨桌面秒级聚焦 · 确认摄像头与麦克风状态"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.family: root.chosenFont
                        font.pixelSize: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // 4. 媒体专属：进度条 (非通话时呈现)
                Item {
                    width: parent.width; height: 16
                    visible: !root.isCalling
                    Text { id: posText; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: root.formatMediaTime(root.position, root.duration >= 3600); color: Qt.rgba(1, 1, 1, 0.45); font.family: (root.chosenFont !== "") ? root.chosenFont : "Monospace"; font.pixelSize: 9 }
                    Rectangle {
                        id: progressTrack
                        anchors.left: posText.right; anchors.right: durText.left; anchors.leftMargin: 8; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter; height: 3.5; radius: 99; color: Qt.rgba(1, 1, 1, 0.15)
                        Rectangle {
                            width: root.duration > 0 ? (progressTrack.width * Math.min(1.0, Math.max(0.0, root.position / root.duration))) : 0
                            height: parent.height; radius: 99; color: "white"
                        }
                    }
                    Text { id: durText; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.formatMediaTime(root.duration); color: Qt.rgba(1, 1, 1, 0.45); font.family: (root.chosenFont !== "") ? root.chosenFont : "Monospace"; font.pixelSize: 9 }
                }

                // 5. 媒体专属：切歌控制按钮 (非通话时呈现)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 52
                    visible: !root.isCalling
                    Item {
                        width: 34; height: 34
                        Text { anchors.centerIn: parent; text: "⏮"; color: "white"; font.pixelSize: 16; opacity: prevArea.pressed ? 1.0 : (prevArea.containsMouse ? 0.9 : 0.6); scale: prevArea.pressed ? 0.85 : 1.0 }
                        MouseArea {
                            id: prevArea; anchors.fill: parent; hoverEnabled: true
                            onEntered: root.cancelCollapse()
                            onExited: root.requestCollapse()
                            onClicked: (mouse) => { mouse.accepted = true; Bridge.sendMediaCmd("MEDIA_PREV") }
                        }
                    }
                    Item {
                        width: 36; height: 34
                        Text { anchors.centerIn: parent; text: root.status === "Playing" ? "⏸" : "▶"; color: "white"; font.pixelSize: 20; opacity: playArea.pressed ? 1.0 : (playArea.containsMouse ? 1.0 : 0.8); scale: playArea.pressed ? 0.85 : 1.0 }
                        MouseArea {
                            id: playArea; anchors.fill: parent; hoverEnabled: true
                            onEntered: root.cancelCollapse()
                            onExited: root.requestCollapse()
                            onClicked: (mouse) => { mouse.accepted = true; Bridge.sendMediaCmd("MEDIA_PLAY_PAUSE") }
                        }
                    }
                    Item {
                        width: 34; height: 34
                        Text { anchors.centerIn: parent; text: "⏭"; color: "white"; font.pixelSize: 16; opacity: nextArea.pressed ? 1.0 : (nextArea.containsMouse ? 0.9 : 0.6); scale: nextArea.pressed ? 0.85 : 1.0 }
                        MouseArea {
                            id: nextArea; anchors.fill: parent; hoverEnabled: true
                            onEntered: root.cancelCollapse()
                            onExited: root.requestCollapse()
                            onClicked: (mouse) => { mouse.accepted = true; Bridge.sendMediaCmd("MEDIA_NEXT") }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root.animationReady = true
        root.updateDateTime()
        root.commitEnvelopeMask(capsule.width, capsule.height)
    }
}
