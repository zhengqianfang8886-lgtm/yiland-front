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

    // 1. 桌面切换动画展示栏
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

    // 2. 音量/亮度 OSD
    Row {
        anchors.centerIn: parent
        spacing: 7
        visible: compactRoot.activeTransient === "OSD" && !compactRoot.isCalling
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
            font.pixelSize: 12
            font.weight: Font.Black
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // 3. 消息提醒卡片
    Item {
        id: alertContainer
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        visible: compactRoot.activeTransient === "ALERT" && !compactRoot.isCalling
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.88

        Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershoot } }

        Item {
            id: avatarItem
            width: 38; height: 38
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: 19
                color: avatarImg.visible ? "transparent" : "#4338ca"
                clip: true

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: (compactRoot.alertAvatar && compactRoot.alertAvatar.length > 5) ? compactRoot.alertAvatar : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    sourceSize.width: 76
                    sourceSize.height: 76
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
                    font.pixelSize: 15
                    font.weight: Font.Black
                    visible: !avatarImg.visible
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 19
                color: "transparent"
                border.color: Qt.rgba(compactRoot.alertThemeColor.r, compactRoot.alertThemeColor.g, compactRoot.alertThemeColor.b, 0.4)
                border.width: 1.5
            }
        }

        Column {
            anchors.left: avatarItem.right; anchors.leftMargin: 12
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: compactRoot.alertTitle
                color: "white"
                font.family: compactRoot.chosenFont
                font.pixelSize: 13
                font.weight: Font.Black
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: compactRoot.alertSubtitle
                color: Qt.rgba(1, 1, 1, 0.95)
                font.family: compactRoot.chosenFont
                font.pixelSize: 11
                font.weight: Font.Bold
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    // 4. 来电模式专属条
    Item {
        id: callCapsuleItem
        anchors.fill: parent
        visible: compactRoot.isCalling

        Item {
            id: callAvatarArea
            width: 32; height: 32
            anchors.left: parent.left
            anchors.leftMargin: 4
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
                        NumberAnimation { target: pulseRing; property: "scale"; from: 0.85; to: 1.35; duration: 1100; easing.type: Easing.OutQuad }
                        NumberAnimation { target: pulseRing; property: "opacity"; from: 0.85; to: 0.0; duration: 1100; easing.type: Easing.OutQuad }
                    }
                    PauseAnimation { duration: 150 }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: callAvatarImg.visible ? "transparent" : "#4338ca"
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
                    font.pixelSize: 11
                    font.weight: Font.Black
                    visible: !callAvatarImg.visible
                }
            }

            Rectangle {
                width: 13; height: 13; radius: 6.5
                color: Theme.media
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -2
                anchors.bottomMargin: -2

                Text {
                    id: phoneRingIcon
                    anchors.centerIn: parent
                    text: "📞"
                    font.pixelSize: 7
                    transformOrigin: Item.Center

                    SequentialAnimation {
                        running: compactRoot.isCalling
                        loops: Animation.Infinite
                        NumberAnimation { target: phoneRingIcon; property: "rotation"; from: -18; to: 18; duration: 90; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: phoneRingIcon; property: "rotation"; from: 18; to: -18; duration: 90; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: phoneRingIcon; property: "rotation"; from: -18; to: 18; duration: 90; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: phoneRingIcon; property: "rotation"; from: 18; to: 0; duration: 90; easing.type: Easing.InOutQuad }
                        PauseAnimation { duration: 900 }
                    }
                }
            }
        }

        Column {
            anchors.left: callAvatarArea.right; anchors.leftMargin: 8
            anchors.right: callDirectBtn.left; anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: compactRoot.callTitle || "Teams 来电"
                color: "white"
                font.family: compactRoot.chosenFont
                font.pixelSize: 12
                font.weight: Font.Black
                elide: Text.ElideRight
                width: parent.width
            }

            Row {
                spacing: 5
                anchors.left: parent.left

                Row {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 2.2; height: 8; radius: 1; color: Theme.media
                        SequentialAnimation on height {
                            running: compactRoot.isCalling; loops: Animation.Infinite
                            NumberAnimation { to: 11; duration: 240; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 4; duration: 240; easing.type: Easing.InOutSine }
                        }
                    }
                    Rectangle {
                        width: 2.2; height: 5; radius: 1; color: Theme.media
                        SequentialAnimation on height {
                            running: compactRoot.isCalling; loops: Animation.Infinite
                            NumberAnimation { to: 12; duration: 310; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 3; duration: 270; easing.type: Easing.InOutSine }
                        }
                    }
                    Rectangle {
                        width: 2.2; height: 9; radius: 1; color: Theme.media
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

        Rectangle {
            id: callDirectBtn
            width: 44; height: 20; radius: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: directBtnTap.pressed ? Qt.rgba(34, 197, 94, 0.4) : Qt.rgba(34, 197, 94, 0.22)
            border.color: Theme.media
            border.width: 1

            Row {
                anchors.centerIn: parent; spacing: 2
                Text { text: "接听"; color: "white"; font.pixelSize: 9; font.weight: Font.Black; font.family: compactRoot.chosenFont }
                Text { text: "↗"; color: Theme.media; font.pixelSize: 9; font.weight: Font.Black }
            }

            TapHandler {
                id: directBtnTap
                onTapped: if (typeof Bridge !== "undefined") Bridge.answerTeamsCall()
            }
        }
    }

    // 5. 常态时钟与网络（纯整数像素尺寸，杜绝类型异常）
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
            width: compactRoot.showNetSpeed ? 46 : 0
            height: 22
            visible: compactRoot.showNetSpeed
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Column {
                anchors.fill: parent; spacing: 1
                Row {
                    spacing: 2; anchors.left: parent.left
                    Text { text: "↓"; font.pixelSize: 8; color: Theme.calendar; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: compactRoot.downCompact
                        color: "white"
                        font.pixelSize: 10
                        font.family: "Monospace"
                        font.weight: Font.Black
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Row {
                    spacing: 2; anchors.left: parent.left
                    Text { text: "↑"; font.pixelSize: 8; color: Theme.network; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: compactRoot.upCompact
                        color: "white"
                        font.pixelSize: 10
                        font.family: "Monospace"
                        font.weight: Font.Black
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Text {
            id: dateText
            text: compactRoot.displayDate
            color: Qt.rgba(1, 1, 1, 0.82)
            font.family: compactRoot.chosenFont
            font.pixelSize: 11
            font.weight: Font.Black
            font.letterSpacing: 0.3
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
                font.weight: Font.Black
                visible: (typeof Config !== "undefined" && Config.showSeconds) && compactRoot.displaySeconds !== ""
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 1
            }

            Text {
                text: compactRoot.displayPeriod
                color: Qt.rgba(1, 1, 1, 0.65)
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