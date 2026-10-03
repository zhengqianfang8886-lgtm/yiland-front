import QtQuick

Item {
    id: compactRoot

    property string chosenFont: ""
    property string activeTransient: ""
    property string status: "Paused"
    property bool isCalling: false
    property bool isSplit: false
    property bool isExpanded: false
    property bool isCollapsing: false

    property bool showNetSpeed: true

    property string wsName: ""
    property int wsCurrent: 1
    property int wsTotal: 4
    property int previousWsCurrent: 1

    property string osdIcon: "🔊"
    property int osdValue: 50
    property string alertTitle: ""
    property string alertSubtitle: ""
    property string alertAvatar: ""
    property string alertIcon: "🔔"
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""

    property string displayDate: ""
    property string displayTime: "04:53"
    property string displaySeconds: ""
    property string displayPeriod: "pm"

    property string downCompact: "0K"
    property string upCompact: "0K"

    property int continuousSitMinutes: 45
    signal sedentaryRested()
    signal sedentarySnooze()

    readonly property bool isLongAlert: {
        if (compactRoot.activeTransient !== "ALERT") return false
        var tLen = (compactRoot.alertTitle || "").length
        var sLen = (compactRoot.alertSubtitle || "").length
        return (tLen + sLen > 24) || (compactRoot.alertSubtitle || "").indexOf("\n") !== -1
    }

    readonly property int textRowImplicitWidth: compactTimeRow.implicitWidth
    readonly property int wsRowImplicitWidth: wsLayoutRow.implicitWidth

    readonly property int alertContentImplicitWidth: 38 + 12 + Math.max(alertTitleText.implicitWidth, alertSubText.implicitWidth)
    readonly property bool isAlertActive: (compactRoot.activeTransient === "ALERT") && !compactRoot.isCalling

    readonly property bool isBluetoothAlert: ["bluetooth", "ᛒ", "🎧", "🖱️", "⌨️", "📱"].indexOf(compactRoot.alertIcon) !== -1

    readonly property string alertSourceTag: {
        if (compactRoot.alertIcon === "⏰") return "计时器"
        if (isBluetoothAlert) return "蓝牙"
        if (compactRoot.alertIcon === "🛡️") return "网络"
        if (compactRoot.alertIcon === "📞") return "通话"
        if (compactRoot.alertAvatar !== "") return "Teams"
        return "通知"
    }

    readonly property color alertThemeColor: {
        if (compactRoot.alertIcon === "⏰") return Theme.timer
        if (isBluetoothAlert) return Theme.bluetooth
        if (compactRoot.alertIcon === "🛡️") return Theme.network
        if (compactRoot.alertIcon === "📞") return Theme.media
        return Theme.notification
    }

    readonly property int displayWsNumber: {
        var n = Number(compactRoot.wsCurrent)
        if (isNaN(n)) return 0
        if (compactRoot.wsName) {
            var trimmedName = compactRoot.wsName.trim()
            if (/^\d+$/.test(trimmedName)) return Number(trimmedName)
            if (trimmedName.indexOf(String(n)) !== -1) return n
            if (n !== 0 && trimmedName.indexOf(String(n + 1)) !== -1) return n + 1
        }
        return n
    }

    readonly property bool hasZeroWs: (compactRoot.wsCurrent === 0 || compactRoot.displayWsNumber === 0)

    readonly property int activeSlotIndex: {
        var n = compactRoot.displayWsNumber
        var tot = Math.max(1, compactRoot.wsTotal)
        if (isNaN(n)) return 0
        if (hasZeroWs) return Math.max(0, Math.min(n, tot - 1))
        return Math.max(0, Math.min(n - 1, tot - 1))
    }

    // =========================================================================
    // 特大久坐健康打断专属弹窗 (520x108)
    // =========================================================================
    Item {
        id: sedentaryAlertContainer
        anchors.fill: parent
        anchors.margins: 12
        visible: compactRoot.activeTransient === "SEDENTARY" && !compactRoot.isCalling
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.88

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershoot } }

        Row {
            anchors.fill: parent
            spacing: 14

            Item {
                width: 52; height: 52
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: healthGlowRing
                    anchors.centerIn: parent
                    width: 52; height: 52; radius: 26
                    color: "transparent"
                    border.color: "#34d399"
                    border.width: 1.5

                    SequentialAnimation {
                        running: sedentaryAlertContainer.visible
                        loops: Animation.Infinite
                        ParallelAnimation {
                            NumberAnimation { target: healthGlowRing; property: "scale"; from: 0.85; to: 1.3; duration: 1400; easing.type: Easing.OutQuad }
                            NumberAnimation { target: healthGlowRing; property: "opacity"; from: 0.8; to: 0.0; duration: 1400; easing.type: Easing.OutQuad }
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 44; height: 44; radius: 22
                    color: Qt.rgba(52, 211, 153, 0.2)
                    border.color: "#34d399"
                    border.width: 1.5

                    Text {
                        anchors.centerIn: parent
                        text: "🧘"
                        font.pixelSize: 22
                    }
                }
            }

            Column {
                width: parent.width - 52 - 130 - 28
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Row {
                    spacing: 6
                    Rectangle { width: 6; height: 6; radius: 3; color: "#34d399"; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "HEALTH & RECOVERY · 站立建议"
                        color: "#34d399"
                        font.pixelSize: 9
                        font.weight: Font.Black
                        font.letterSpacing: 0.8
                        font.family: compactRoot.chosenFont
                    }
                }

                Text {
                    text: "该站起来活动一下了"
                    color: "white"
                    font.family: compactRoot.chosenFont
                    font.pixelSize: 15
                    font.weight: Font.Black
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    text: "已连续伏案 " + compactRoot.continuousSitMinutes + " 分钟 · 建议起身接水、舒展放松"
                    color: Qt.rgba(1, 1, 1, 0.85)
                    font.family: compactRoot.chosenFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            Column {
                width: 130
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: parent.width; height: 32; radius: 16
                    color: restTap.pressed ? "#15803d" : (restHover.hovered ? "#16a34a" : "#22c55e")
                    scale: restTap.pressed ? 0.94 : (restHover.hovered ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "✓"; color: "white"; font.pixelSize: 11; font.weight: Font.Black }
                        Text { text: "我已起身活动"; color: "white"; font.pixelSize: 11; font.weight: Font.Black; font.family: compactRoot.chosenFont }
                    }

                    HoverHandler { id: restHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: restTap
                        onTapped: compactRoot.sedentaryRested()
                    }
                }

                Rectangle {
                    width: parent.width; height: 26; radius: 13
                    color: snoozeTap.pressed ? Qt.rgba(1, 1, 1, 0.22) : (snoozeHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                    border.color: Theme.borderSubtle; border.width: 1
                    scale: snoozeTap.pressed ? 0.94 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "⏱"; font.pixelSize: 10 }
                        Text { text: "延后 5 分钟"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 10; font.weight: Font.Bold; font.family: compactRoot.chosenFont }
                    }

                    HoverHandler { id: snoozeHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: snoozeTap
                        onTapped: compactRoot.sedentarySnooze()
                    }
                }
            }
        }
    }

    // =========================================================================
    // 高级来电专属模式条 (320x44)
    // =========================================================================
    Item {
        id: callCapsuleItem
        anchors.fill: parent
        visible: compactRoot.isCalling

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            Item {
                id: callAvatarArea
                width: 32; height: 32
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: pulseRing
                    anchors.centerIn: parent
                    width: 32; height: 32; radius: 16
                    color: "transparent"
                    border.color: Theme.media
                    border.width: 1.5

                    SequentialAnimation {
                        running: compactRoot.isCalling
                        loops: Animation.Infinite
                        ParallelAnimation {
                            NumberAnimation { target: pulseRing; property: "scale"; from: 0.9; to: 1.35; duration: 1200; easing.type: Easing.OutQuad }
                            NumberAnimation { target: pulseRing; property: "opacity"; from: 0.85; to: 0.0; duration: 1200; easing.type: Easing.OutQuad }
                        }
                        PauseAnimation { duration: 120 }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: callAvatarImg.visible ? "transparent" : "#4F46E5"
                    clip: true

                    Image {
                        id: callAvatarImg
                        anchors.fill: parent
                        source: compactRoot.callAvatar
                        fillMode: Image.PreserveAspectCrop
                        visible: compactRoot.callAvatar !== "" && status === Image.Ready
                        sourceSize.width: 64; sourceSize.height: 64
                        asynchronous: true; cache: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (callAvatarImg.visible) return ""
                            if (compactRoot.callTitle && compactRoot.callTitle.length > 0) {
                                var parts = compactRoot.callTitle.trim().split(" ")
                                return (parts.length >= 2) ? (parts[0][0] + parts[1][0]).toUpperCase() : compactRoot.callTitle.trim().charAt(0).toUpperCase()
                            }
                            return "📞"
                        }
                        color: "white"
                        font.family: compactRoot.chosenFont
                        font.pixelSize: 12
                        font.weight: Font.Black
                        visible: !callAvatarImg.visible
                    }
                }

                Rectangle {
                    width: 12; height: 12; radius: 6
                    color: Theme.media
                    border.color: "#14141a"; border.width: 1.2
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -1
                    anchors.bottomMargin: -1

                    Text {
                        id: phoneRingIcon
                        anchors.centerIn: parent
                        text: "📞"
                        font.pixelSize: 7
                        transformOrigin: Item.Center

                        SequentialAnimation {
                            running: compactRoot.isCalling
                            loops: Animation.Infinite
                            NumberAnimation { target: phoneRingIcon; property: "rotation"; from: -16; to: 16; duration: 90; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: phoneRingIcon; property: "rotation"; from: 16; to: -16; duration: 90; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: phoneRingIcon; property: "rotation"; from: -16; to: 16; duration: 90; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: phoneRingIcon; property: "rotation"; from: 16; to: 0; duration: 90; easing.type: Easing.InOutQuad }
                            PauseAnimation { duration: 900 }
                        }
                    }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                width: parent.width - 32 - 100 - 20

                Text {
                    text: compactRoot.callTitle || "Teams 来电"
                    color: "white"
                    font.family: compactRoot.chosenFont
                    font.pixelSize: 13
                    font.weight: Font.Black
                    elide: Text.ElideRight
                    width: parent.width
                }

                Row {
                    spacing: 4
                    anchors.left: parent.left

                    Row {
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: 2; height: 8; radius: 1; color: Theme.media
                            SequentialAnimation on height {
                                running: compactRoot.isCalling; loops: Animation.Infinite
                                NumberAnimation { to: 11; duration: 240; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 4; duration: 240; easing.type: Easing.InOutSine }
                            }
                        }
                        Rectangle {
                            width: 2; height: 5; radius: 1; color: Theme.media
                            SequentialAnimation on height {
                                running: compactRoot.isCalling; loops: Animation.Infinite
                                NumberAnimation { to: 12; duration: 310; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 3; duration: 270; easing.type: Easing.InOutSine }
                            }
                        }
                        Rectangle {
                            width: 2; height: 9; radius: 1; color: Theme.media
                            SequentialAnimation on height {
                                running: compactRoot.isCalling; loops: Animation.Infinite
                                NumberAnimation { to: 4; duration: 260; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 10; duration: 260; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    Text {
                        text: compactRoot.callSubtitle || "正在呼叫..."
                        color: Theme.media
                        font.family: compactRoot.chosenFont
                        font.pixelSize: 10
                        font.weight: Font.Black
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 26; height: 26; radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: rejectCallTap.pressed ? Qt.rgba(239, 68, 68, 0.5) : (rejectCallHover.hovered ? Qt.rgba(239, 68, 68, 0.35) : Qt.rgba(239, 68, 68, 0.2))
                    border.color: Theme.danger
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "white"
                        font.pixelSize: 10
                        font.weight: Font.Black
                    }

                    HoverHandler { id: rejectCallHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: rejectCallTap
                        onTapped: if (typeof Bridge !== "undefined") Bridge.rejectTeamsCall()
                    }
                }

                Rectangle {
                    width: 58; height: 26; radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: directBtnTap.pressed ? "#15803d" : (directBtnHover.hovered ? "#16a34a" : "#22c55e")
                    border.color: Theme.media
                    border.width: 1
                    scale: directBtnTap.pressed ? 0.94 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Row {
                        anchors.centerIn: parent; spacing: 3
                        Text { text: "接听"; color: "white"; font.pixelSize: 10; font.weight: Font.Black; font.family: compactRoot.chosenFont }
                        Text { text: "↗"; color: "white"; font.pixelSize: 10; font.weight: Font.Black }
                    }

                    HoverHandler { id: directBtnHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: directBtnTap
                        onTapped: if (typeof Bridge !== "undefined") Bridge.answerTeamsCall()
                    }
                }
            }
        }
    }

    // =========================================================================
    // 2. 桌面切换动画展示栏
    // =========================================================================
    Row {
        id: wsLayoutRow
        anchors.centerIn: parent
        spacing: 9
        visible: compactRoot.activeTransient === "WORKSPACE" && !compactRoot.isCalling
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.90
        Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        Rectangle {
            width: 20; height: 20; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.25)
            border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.75)
            border.width: 1

            Text {
                id: badgeNumText
                anchors.centerIn: parent
                text: compactRoot.displayWsNumber
                color: "white"
                font.pixelSize: 11
                font.weight: Font.Black
                font.family: (compactRoot.chosenFont !== "") ? compactRoot.chosenFont : "Monospace"
            }
        }

        Item {
            id: wsNameWrapper
            height: 20
            width: Math.min(84, wsNameText.implicitWidth)
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: wsNameText
                anchors.verticalCenter: parent.verticalCenter
                text: compactRoot.wsName ? compactRoot.wsName : ("桌面 " + compactRoot.displayWsNumber)
                color: "white"
                font.family: compactRoot.chosenFont
                font.pixelSize: 13
                font.weight: Font.Black
                font.letterSpacing: 0.5
                elide: Text.ElideRight
                width: parent.width
            }
        }

        Rectangle {
            id: wsTrackContainer
            height: 16
            radius: 8
            width: wsDotsRow.implicitWidth + 10
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(1, 1, 1, 0.12)
            border.color: Qt.rgba(1, 1, 1, 0.15)
            border.width: 1

            Row {
                id: wsDotsRow
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: Math.min(8, Math.max(2, compactRoot.wsTotal))
                    Rectangle {
                        readonly property bool isCurrent: (index === compactRoot.activeSlotIndex)
                        width: isCurrent ? 14 : 4
                        height: 4
                        radius: 2
                        color: isCurrent ? Theme.workspace : Qt.rgba(1, 1, 1, 0.5)
                        scale: isCurrent ? 1.0 : (dotMouse.hovered ? 1.3 : 1.0)

                        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        HoverHandler { id: dotMouse; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (typeof Bridge !== "undefined") {
                                    var target = compactRoot.hasZeroWs ? index : (index + 1)
                                    Bridge.switchWorkspace(target)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 3. 🚀【极速原位流体音量/静音 OSD】：精确区分“0%”与“静音”状态机
    // =========================================================================
    Row {
        id: osdLayoutRow
        anchors.centerIn: parent
        spacing: 8
        visible: compactRoot.activeTransient === "OSD" && !compactRoot.isCalling
        opacity: visible ? 1.0 : 0.0
        scale: opacity > 0.4 ? 1.0 : 0.94

        readonly property bool isHardwareMuted: (compactRoot.osdIcon === "🔇" || compactRoot.osdIcon === "🚫")

        Behavior on opacity { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.04 } }

        // 滑轨槽底
        Rectangle {
            id: osdTrack
            width: Math.max(54, Math.min(94, compactRoot.width - 64))
            height: 5
            radius: 2.5
            color: Qt.rgba(1, 1, 1, 0.16)
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            Rectangle {
                id: osdFillBar
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                radius: parent.radius
                // 静音态滑块收束归零
                color: osdLayoutRow.isHardwareMuted ? Theme.danger : "white"

                width: osdLayoutRow.isHardwareMuted ?
                       0 :
                       Math.round(parent.width * Math.min(1.0, Math.max(0.0, compactRoot.osdValue / 100.0)))

                Behavior on width {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }

        // 读数百分比：静音态明确显示红字“静音”，0% 状态显示正常“0%”
        Text {
            id: osdValText
            text: osdLayoutRow.isHardwareMuted ?
                  "静音" :
                  (Math.min(100, Math.max(0, compactRoot.osdValue)) + "%")

            color: osdLayoutRow.isHardwareMuted ? Theme.danger : "white"
            font.family: osdLayoutRow.isHardwareMuted ? compactRoot.chosenFont : "Monospace"
            font.pixelSize: 12
            font.weight: Font.Black
            font.letterSpacing: 0.3
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    // =========================================================================
    // 4. 通知弹窗视图 (ALERT)
    // =========================================================================
    Item {
        id: alertContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right

        visible: opacity > 0.001
        opacity: compactRoot.isAlertActive ? 1.0 : 0.0
        scale: compactRoot.isAlertActive ? 1.0 : 0.92

        anchors.leftMargin: compactRoot.isAlertActive ? 14 : 6
        anchors.rightMargin: 14

        Behavior on opacity { NumberAnimation { duration: compactRoot.isAlertActive ? 180 : 120; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: compactRoot.isAlertActive ? 240 : 130; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
        Behavior on anchors.leftMargin { NumberAnimation { duration: compactRoot.isAlertActive ? 220 : 110; easing.type: Easing.OutCubic } }

        Item {
            id: avatarItem
            width: 36; height: 36
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: 18
                color: avatarImg.visible ? "transparent" : "#4F46E5"
                clip: true

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: (compactRoot.alertAvatar && compactRoot.alertAvatar.length > 5) ? compactRoot.alertAvatar : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    sourceSize.width: 72
                    sourceSize.height: 72
                    asynchronous: true
                    cache: true
                }

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (avatarImg.visible) return ""
                        if (compactRoot.alertTitle && compactRoot.alertTitle.length > 0) {
                            var parts = compactRoot.alertTitle.trim().split(" ")
                            return (parts.length >= 2) ? (parts[0][0] + parts[1][0]).toUpperCase() : compactRoot.alertTitle.trim().charAt(0).toUpperCase()
                        }
                        return "💬"
                    }
                    color: "white"
                    font.family: compactRoot.chosenFont
                    font.pixelSize: 14
                    font.weight: Font.Black
                    visible: !avatarImg.visible
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 18
                color: "transparent"
                border.color: Qt.rgba(compactRoot.alertThemeColor.r, compactRoot.alertThemeColor.g, compactRoot.alertThemeColor.b, 0.5)
                border.width: 1.5
            }
        }

        Column {
            id: alertTextCol
            anchors.left: avatarItem.right
            anchors.leftMargin: 11
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                id: alertTitleText
                text: compactRoot.alertTitle
                color: "white"
                font.family: compactRoot.chosenFont
                font.pixelSize: 13
                font.weight: Font.Black
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                id: alertSubText
                text: compactRoot.alertSubtitle
                color: Qt.rgba(1, 1, 1, 0.88)
                font.family: compactRoot.chosenFont
                font.pixelSize: 11
                font.weight: Font.Bold
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    // =========================================================================
    // 5. 常态时钟与网络
    // =========================================================================
    Row {
        id: compactTimeRow
        anchors.centerIn: parent
        spacing: 7

        visible: opacity > 0.001
        opacity: (compactRoot.activeTransient === "" && !compactRoot.isCalling) ? 1.0 : 0.0
        scale: opacity > 0.4 ? 1.0 : 0.92

        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        // =====================================================================
        // 🚀 核心重构：专业级微型网速胶囊卡片（带独立微槽与标准 KB/s 单位）
        // =====================================================================
        Rectangle {
            id: netSpeedItem
            visible: compactRoot.showNetSpeed
            width: compactRoot.showNetSpeed ? (speedCol.implicitWidth + 10) : 0
            height: 24
            radius: 5
            anchors.verticalCenter: parent.verticalCenter

            // 极简微槽背景，彻底告别文字裸奔悬空
            color: Qt.rgba(1, 1, 1, 0.06)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Column {
                id: speedCol
                anchors.centerIn: parent
                spacing: 1

                // 1. 下行速率 (绿色)
                Row {
                    spacing: 3
                    anchors.left: parent.left

                    Text {
                        text: "↓"
                        font.pixelSize: 8
                        font.weight: Font.Black
                        color: Theme.network
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: compactRoot.downCompact
                        color: "white"
                        font.pixelSize: 9
                        font.weight: Font.Black
                        font.family: "Monospace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // 2. 上行速率 (蓝色)
                Row {
                    spacing: 3
                    anchors.left: parent.left

                    Text {
                        text: "↑"
                        font.pixelSize: 8
                        font.weight: Font.Black
                        color: Theme.calendar
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: compactRoot.upCompact
                        color: "white"
                        font.pixelSize: 9
                        font.weight: Font.Black
                        font.family: "Monospace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Text {
            id: dateText
            text: compactRoot.displayDate
            color: Qt.rgba(1, 1, 1, 0.70)
            font.family: compactRoot.chosenFont
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 0.2
            visible: (typeof Config !== "undefined" && Config.showDate) && compactRoot.displayDate !== ""
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 0.5
        }

        Rectangle {
            width: 1
            height: 11
            radius: 0.5
            color: Qt.rgba(1, 1, 1, 0.14)
            anchors.verticalCenter: parent.verticalCenter
            visible: (typeof Config !== "undefined" && Config.showDate) && compactRoot.displayDate !== ""
        }

        Row {
            id: timeInnerRow
            spacing: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: compactRoot.displayTime
                color: "white"
                font.family: (compactRoot.chosenFont !== "") ? compactRoot.chosenFont : "Monospace"
                font.pixelSize: 18
                font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                id: secondsRow
                spacing: 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0.5
                visible: (typeof Config !== "undefined" && Config.showSeconds) && compactRoot.displaySeconds !== ""

                Text {
                    text: ":"
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.family: (compactRoot.chosenFont !== "") ? compactRoot.chosenFont : "Monospace"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: compactRoot.displaySeconds.replace(/^:/, "")
                    color: Theme.network
                    font.family: (compactRoot.chosenFont !== "") ? compactRoot.chosenFont : "Monospace"
                    font.pixelSize: 11
                    font.weight: Font.Black
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                text: compactRoot.displayPeriod
                color: Qt.rgba(1, 1, 1, 0.55)
                font.family: compactRoot.chosenFont
                font.pixelSize: 9
                font.weight: Font.Black
                font.capitalization: Font.AllUppercase
                visible: (typeof Config !== "undefined" && Config.timeFormat === "12h") && compactRoot.displayPeriod !== ""
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0.5
                leftPadding: 2
            }
        }
    }
}