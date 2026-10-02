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

    readonly property bool isLongAlert: {
        if (compactRoot.activeTransient !== "ALERT") return false
        var tLen = (compactRoot.alertTitle || "").length
        var sLen = (compactRoot.alertSubtitle || "").length
        return (tLen + sLen > 20) || (compactRoot.alertSubtitle || "").indexOf("\n") !== -1
    }

    readonly property int textRowImplicitWidth: compactTimeRow.implicitWidth
    readonly property int wsRowImplicitWidth: wsLayoutRow.implicitWidth

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

    // 🚀 核心修复：尊重系统的原始桌面编号，0 始终如实显示为 0，不再强行加 1 或取 max(1, n)
    readonly property int displayWsNumber: {
        var n = Number(compactRoot.wsCurrent)
        if (isNaN(n)) return 0
        if (compactRoot.wsName) {
            var trimmedName = compactRoot.wsName.trim()
            if (/^\d+$/.test(trimmedName)) return Number(trimmedName)
            if (trimmedName.indexOf(String(n)) !== -1) return n
            // 仅当名称明确表明偏移（如名字是 "Desktop 2" 而 n 是 1）时才做对齐，若为 0 则维持 0
            if (n !== 0 && trimmedName.indexOf(String(n + 1)) !== -1) return n + 1
        }
        return n
    }

    readonly property bool hasZeroWs: (compactRoot.wsCurrent === 0 || compactRoot.displayWsNumber === 0)

    // 🚀 确保槽位索引与桌面系统（0-based / 1-based）精准匹配
    readonly property int activeSlotIndex: {
        var n = compactRoot.displayWsNumber
        var tot = Math.max(1, compactRoot.wsTotal)
        if (isNaN(n)) return 0
        if (hasZeroWs) {
            return Math.max(0, Math.min(n, tot - 1))
        }
        return Math.max(0, Math.min(n - 1, tot - 1))
    }

    onWsCurrentChanged: {
        if (compactRoot.activeTransient === "WORKSPACE") {
            var dir = wsCurrent >= previousWsCurrent ? 1 : -1
            previousWsCurrent = wsCurrent
            wsChangeAnim.direction = dir
            wsChangeAnim.restart()
        } else {
            previousWsCurrent = wsCurrent
        }
    }

    onWsNameChanged: {
        if (compactRoot.activeTransient === "WORKSPACE" && !wsChangeAnim.running) {
            wsChangeAnim.direction = 1
            wsChangeAnim.restart()
        }
    }

    // 1. 切换桌面时的动画展示栏
    Row {
        id: wsLayoutRow
        anchors.centerIn: parent
        spacing: 9
        
        visible: compactRoot.activeTransient === "WORKSPACE"
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.90

        Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        // 桌面编号小徽章
        Rectangle {
            width: 20; height: 20; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.25)
            border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.75)
            border.width: 1

            Text {
                id: badgeNumText
                anchors.centerIn: parent
                // 0 会直接输出 "0"
                text: compactRoot.displayWsNumber
                color: "white"
                font.pixelSize: 11
                font.weight: Font.Black
                font.family: (compactRoot.chosenFont !== "") ? compactRoot.chosenFont : "Monospace"

                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: badgeNumText; property: "scale"; to: 0.8; duration: 50 }
                        NumberAnimation { target: badgeNumText; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }
                }
            }
        }

        Item {
            id: wsNameWrapper
            height: 20
            width: Math.min(80, wsNameText.implicitWidth)
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
                font.letterSpacing: 0.4
                elide: Text.ElideRight
                width: parent.width

                transform: [
                    Translate { id: wsTextTrans; y: 0 }
                ]
            }

            SequentialAnimation {
                id: wsChangeAnim
                property int direction: 1

                ParallelAnimation {
                    NumberAnimation { target: wsTextTrans; property: "y"; to: -8 * wsChangeAnim.direction; duration: 60; easing.type: Easing.OutQuad }
                    NumberAnimation { target: wsNameText; property: "opacity"; to: 0.2; duration: 60 }
                }
                ScriptAction { script: { wsTextTrans.y = 8 * wsChangeAnim.direction } }
                ParallelAnimation {
                    NumberAnimation { target: wsTextTrans; property: "y"; to: 0; duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    NumberAnimation { target: wsNameText; property: "opacity"; to: 1.0; duration: 130 }
                }
            }
        }

        // 桌面小圆点轨道
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

    // 2. 音量/亮度 OSD
    Row {
        anchors.centerIn: parent
        spacing: 7
        visible: compactRoot.activeTransient === "OSD"
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 100 } }

        Text { text: compactRoot.osdIcon; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
        Rectangle {
            width: 86; height: 4; radius: 99; color: Qt.rgba(1, 1, 1, 0.2)
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                width: parent.width * Math.min(1.0, Math.max(0.0, compactRoot.osdValue / 100.0))
                height: parent.height; radius: 99; color: "white"
            }
        }
        Text {
            text: compactRoot.osdValue + "%"; color: "white"
            font.family: (compactRoot.chosenFont !== "") ? compactRoot.chosenFont : "Monospace"
            font.pixelSize: 11; font.weight: Font.Black
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // 3. 消息提醒卡片
    Item {
        id: alertContainer
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        visible: compactRoot.activeTransient === "ALERT"
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.88

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershoot } }

        Item {
            id: avatarItem
            width: 40; height: 40
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: 12
                color: avatarImg.visible ? "transparent" : "#4338ca"
                clip: true

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: (compactRoot.alertAvatar && compactRoot.alertAvatar.length > 5) ? compactRoot.alertAvatar : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    sourceSize.width: 80
                    sourceSize.height: 80
                    asynchronous: true
                    cache: true
                    onStatusChanged: if (status === Image.Error) source = ""
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
                    font.pixelSize: 15
                    font.weight: Font.Black
                    visible: !avatarImg.visible
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "transparent"
                border.color: Qt.rgba(compactRoot.alertThemeColor.r, compactRoot.alertThemeColor.g, compactRoot.alertThemeColor.b, 0.4)
                border.width: 1.5
            }
        }

        Rectangle {
            id: actionBtn
            width: 28; height: 28; radius: 14
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: alertActionTap.pressed ? Qt.rgba(compactRoot.alertThemeColor.r, compactRoot.alertThemeColor.g, compactRoot.alertThemeColor.b, 0.4) : (alertActionHover.hovered ? Qt.rgba(compactRoot.alertThemeColor.r, compactRoot.alertThemeColor.g, compactRoot.alertThemeColor.b, 0.28) : Qt.rgba(1, 1, 1, 0.1))
            border.color: Qt.rgba(compactRoot.alertThemeColor.r, compactRoot.alertThemeColor.g, compactRoot.alertThemeColor.b, 0.5)
            border.width: 1

            Text { anchors.centerIn: parent; text: "↗"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold }
            HoverHandler { id: alertActionHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { id: alertActionTap }
        }

        Column {
            id: textColumn
            anchors.left: avatarItem.right; anchors.leftMargin: 12
            anchors.right: actionBtn.left; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: compactRoot.isLongAlert ? 3 : 2

            Row {
                id: metaRow
                width: parent.width; spacing: 7

                Text {
                    id: titleText
                    text: compactRoot.alertTitle
                    color: "white"
                    font.family: compactRoot.chosenFont
                    font.pixelSize: 13
                    font.weight: Font.Black
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, metaRow.width - badgeRect.width - timeText.implicitWidth - 20)
                }

                Rectangle {
                    id: badgeRect
                    height: 16; radius: 4
                    width: badgeInnerRow.implicitWidth + 10
                    color: Qt.rgba(compactRoot.alertThemeColor.r, compactRoot.alertThemeColor.g, compactRoot.alertThemeColor.b, 0.22)
                    border.color: Qt.rgba(compactRoot.alertThemeColor.r, compactRoot.alertThemeColor.g, compactRoot.alertThemeColor.b, 0.55)
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: badgeInnerRow
                        anchors.centerIn: parent; spacing: 4

                        Rectangle {
                            width: 5; height: 5; radius: 2.5
                            color: compactRoot.alertThemeColor
                            anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity {
                                running: compactRoot.activeTransient === "ALERT"
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                            }
                        }

                        Text {
                            id: sourceTagText
                            text: compactRoot.alertSourceTag
                            color: compactRoot.alertThemeColor
                            font.family: compactRoot.chosenFont
                            font.pixelSize: 10; font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Text {
                    id: timeText
                    text: "刚刚"
                    color: Theme.textMuted
                    font.family: compactRoot.chosenFont
                    font.pixelSize: 10; font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                id: subText
                text: compactRoot.alertSubtitle
                color: Qt.rgba(1, 1, 1, 0.88)
                font.family: compactRoot.chosenFont
                font.pixelSize: 11
                font.weight: Font.Medium
                lineHeight: 1.15
                wrapMode: Text.WrapAnywhere
                maximumLineCount: compactRoot.isLongAlert ? 2 : 1
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    // 4. 通话中
    Row {
        anchors.fill: parent; spacing: 10
        visible: compactRoot.isCalling && compactRoot.activeTransient === ""

        Rectangle {
            width: 26; height: 26; radius: 13
            color: callAvatarImg.visible ? "transparent" : Theme.media
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            Image {
                id: callAvatarImg; anchors.fill: parent; source: compactRoot.callAvatar
                fillMode: Image.PreserveAspectCrop
                visible: compactRoot.callAvatar !== "" && status === Image.Ready
                sourceSize.width: 52; sourceSize.height: 52
                asynchronous: true; cache: true
            }
            Text {
                anchors.centerIn: parent
                text: (compactRoot.callTitle && compactRoot.callTitle.length > 0) ? compactRoot.callTitle.trim().charAt(0).toUpperCase() : "📞"
                color: "white"; font.family: compactRoot.chosenFont; font.pixelSize: 12; font.weight: Font.Black; visible: !callAvatarImg.visible
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter; spacing: 1; width: parent.width - 36
            Text { text: compactRoot.callTitle; color: "white"; font.family: compactRoot.chosenFont; font.pixelSize: 12; font.weight: Font.Black; elide: Text.ElideRight; width: parent.width }
            Text { text: compactRoot.callSubtitle + "  ➔ 点击直达"; color: Theme.media; font.family: compactRoot.chosenFont; font.pixelSize: 10; font.weight: Font.Bold; elide: Text.ElideRight; width: parent.width }
        }
    }

    // 5. 常态时钟
    Row {
        id: compactTimeRow
        anchors.centerIn: parent
        spacing: 9

        visible: (compactRoot.activeTransient === "" && !compactRoot.isCalling)
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.92

        Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

        Item {
            id: netSpeedItem
            width: compactRoot.showNetSpeed ? 44 : 0
            height: 22
            visible: compactRoot.showNetSpeed
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Column {
                anchors.fill: parent
                spacing: 1

                Row {
                    spacing: 2; anchors.left: parent.left
                    Text { text: "↓"; font.pixelSize: 8; color: Theme.calendar; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: compactRoot.downCompact
                        color: Theme.textSecondary
                        font.pixelSize: 9
                        font.family: "Monospace"
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Row {
                    spacing: 2; anchors.left: parent.left
                    Text { text: "↑"; font.pixelSize: 8; color: Theme.network; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: compactRoot.upCompact
                        color: Theme.textSecondary
                        font.pixelSize: 9
                        font.family: "Monospace"
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Text {
            id: dateText
            text: compactRoot.displayDate
            color: Qt.rgba(1, 1, 1, 0.65)
            font.family: compactRoot.chosenFont
            font.pixelSize: 10
            font.weight: Font.Bold
            visible: (typeof Config !== "undefined" && Config.showDate) && compactRoot.displayDate !== ""
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            id: timeInnerRow
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: compactRoot.displayTime
                color: "white"
                font.family: (compactRoot.chosenFont !== "") ? compactRoot.chosenFont : "Monospace"
                font.pixelSize: 20
                font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: compactRoot.displaySeconds
                color: Theme.network
                font.family: (compactRoot.chosenFont !== "") ? compactRoot.chosenFont : "Monospace"
                font.pixelSize: 13
                font.weight: Font.ExtraBold
                visible: (typeof Config !== "undefined" && Config.showSeconds) && compactRoot.displaySeconds !== ""
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 1
            }

            Text {
                text: compactRoot.displayPeriod
                color: Qt.rgba(1, 1, 1, 0.5)
                font.family: compactRoot.chosenFont
                font.pixelSize: 10
                font.weight: Font.Black
                font.capitalization: Font.AllUppercase
                visible: (typeof Config !== "undefined" && Config.timeFormat === "12h") && compactRoot.displayPeriod !== ""
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 2
            }
        }
    }
}