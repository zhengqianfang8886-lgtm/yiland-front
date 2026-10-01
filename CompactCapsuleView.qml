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
        return (tLen + sLen > 18) || (compactRoot.alertSubtitle || "").indexOf("\n") !== -1
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
        if (compactRoot.alertIcon === "⏰") return "#f97316"
        if (isBluetoothAlert) return "#38bdf8"
        if (compactRoot.alertIcon === "🛡️") return "#10b981"
        if (compactRoot.alertIcon === "📞") return "#22c55e"
        return "#818cf8"
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

    // 1. 工作区切换
    Row {
        id: wsLayoutRow
        anchors.centerIn: parent
        spacing: 9
        opacity: compactRoot.activeTransient === "WORKSPACE" ? 1.0 : 0.0
        visible: opacity > 0.01
        scale: compactRoot.activeTransient === "WORKSPACE" ? 1.0 : 0.90

        Behavior on opacity { NumberAnimation { duration: compactRoot.activeTransient === "WORKSPACE" ? 150 : 85; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: compactRoot.activeTransient === "WORKSPACE" ? 220 : 95; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

        Item {
            id: wsNameWrapper
            height: 18
            width: wsNameText.implicitWidth
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: wsNameText
                anchors.centerIn: parent
                text: compactRoot.wsName ? compactRoot.wsName : ("桌面 " + compactRoot.wsCurrent)
                color: "white"
                font.family: compactRoot.chosenFont
                font.pixelSize: 12
                font.weight: Font.Black
                font.letterSpacing: 0.3

                transform: [
                    Translate { id: wsTextTrans; x: 0 },
                    Scale { id: wsTextScale; origin.x: wsNameText.width / 2; origin.y: wsNameText.height / 2; xScale: 1.0; yScale: 1.0 }
                ]
            }

            SequentialAnimation {
                id: wsChangeAnim
                property int direction: 1

                ParallelAnimation {
                    NumberAnimation { target: wsTextTrans; property: "x"; to: -8 * wsChangeAnim.direction; duration: 65; easing.type: Easing.OutQuad }
                    NumberAnimation { target: wsNameText; property: "opacity"; to: 0.25; duration: 65; easing.type: Easing.OutQuad }
                    NumberAnimation { target: wsTextScale; properties: "xScale,yScale"; to: 0.88; duration: 65 }
                }
                ScriptAction { script: { wsTextTrans.x = 9 * wsChangeAnim.direction } }
                ParallelAnimation {
                    NumberAnimation { target: wsTextTrans; property: "x"; to: 0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                    NumberAnimation { target: wsNameText; property: "opacity"; to: 1.0; duration: 160; easing.type: Easing.OutQuad }
                    NumberAnimation { target: wsTextScale; properties: "xScale,yScale"; to: 1.0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                }
            }
        }

        Row {
            spacing: 4.5
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: Math.min(10, Math.max(1, compactRoot.wsTotal))
                Rectangle {
                    readonly property int dotIndex: index + 1
                    readonly property bool isCurrent: dotIndex === compactRoot.wsCurrent
                    width: isCurrent ? 15 : (dotMouse.containsMouse ? 7 : 4.5)
                    height: 4.5
                    radius: 2.25
                    color: isCurrent ? "#ffffff" : (dotMouse.containsMouse ? "#a855f7" : Qt.rgba(1, 1, 1, 0.24))
                    scale: isCurrent ? 1.0 : (dotMouse.containsMouse ? 1.2 : 0.85)

                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 160 } }

                    MouseArea {
                        id: dotMouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            mouse.accepted = true
                            if (typeof Bridge !== "undefined") Bridge.switchWorkspace(dotIndex)
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
        opacity: compactRoot.activeTransient === "OSD" ? 1.0 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

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

    // 3. 消息提醒
    Item {
        id: alertContainer
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        opacity: compactRoot.activeTransient === "ALERT" ? 1.0 : 0.0
        visible: opacity > 0.01
        scale: compactRoot.activeTransient === "ALERT" ? 1.0 : 0.88

        Behavior on opacity { NumberAnimation { duration: compactRoot.activeTransient === "ALERT" ? 180 : 100; easing.type: Easing.OutQuad } }
        Behavior on scale {
            NumberAnimation {
                duration: compactRoot.activeTransient === "ALERT" ? 260 : 120
                easing.type: compactRoot.activeTransient === "ALERT" ? Easing.OutBack : Easing.InQuad
                easing.overshoot: 1.15
            }
        }

        Item {
            id: avatarItem
            width: 36; height: 36
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: avatarBg
                anchors.fill: parent
                radius: 18
                color: avatarImg.visible ? "transparent" : "#4338ca"
                clip: true

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: (compactRoot.alertAvatar && compactRoot.alertAvatar.length > 5) ? compactRoot.alertAvatar : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                    cache: false
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
                    font.pixelSize: 13
                    font.weight: Font.Black
                    visible: !avatarImg.visible
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 18
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.22)
                border.width: 1.5
            }
        }

        Rectangle {
            id: actionBtn
            width: 26; height: 26; radius: 13
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: alertActionHover.containsMouse ? Qt.rgba(129, 140, 248, 0.35) : Qt.rgba(1, 1, 1, 0.1)
            border.color: Qt.rgba(129, 140, 248, 0.45)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "↗"
                color: "white"
                font.pixelSize: 11
                font.weight: Font.Bold
            }
            HoverHandler { id: alertActionHover }
        }

        Column {
            id: textColumn
            anchors.left: avatarItem.right
            anchors.leftMargin: 10
            anchors.right: actionBtn.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: compactRoot.isLongAlert ? 3 : 2

            Row {
                id: metaRow
                width: parent.width
                spacing: 6

                Text {
                    id: titleText
                    text: compactRoot.alertTitle
                    color: "white"
                    font.family: compactRoot.chosenFont
                    font.pixelSize: 12
                    font.weight: Font.Black
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, metaRow.width - badgeRect.width - timeText.implicitWidth - 16)
                }

                Rectangle {
                    id: badgeRect
                    height: 15
                    radius: 4
                    width: sourceTagText.implicitWidth + 8
                    color: Qt.rgba(compactRoot.alertThemeColor.r, compactRoot.alertThemeColor.g, compactRoot.alertThemeColor.b, 0.2)
                    border.color: Qt.rgba(compactRoot.alertThemeColor.r, compactRoot.alertThemeColor.g, compactRoot.alertThemeColor.b, 0.5)
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: sourceTagText
                        anchors.centerIn: parent
                        text: compactRoot.alertSourceTag
                        color: compactRoot.alertThemeColor
                        font.family: compactRoot.chosenFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }

                Text {
                    id: timeText
                    text: "刚刚"
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.family: compactRoot.chosenFont
                    font.pixelSize: 9
                    font.weight: Font.Bold
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
        anchors.fill: parent
        spacing: 10
        visible: compactRoot.isCalling && compactRoot.activeTransient === ""

        Rectangle {
            width: 26; height: 26; radius: 13
            color: callAvatarImg.visible ? "transparent" : "#22c55e"
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            Image {
                id: callAvatarImg; anchors.fill: parent; source: compactRoot.callAvatar
                fillMode: Image.PreserveAspectCrop; visible: compactRoot.callAvatar !== "" && status === Image.Ready; cache: false
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
            Text { text: compactRoot.callSubtitle + "  ➔ 点击直达"; color: "#22c55e"; font.family: compactRoot.chosenFont; font.pixelSize: 10; font.weight: Font.Bold; elide: Text.ElideRight; width: parent.width }
        }
    }

    // 5. 常态时钟
    Row {
        id: compactTimeRow
        anchors.centerIn: parent
        spacing: 8

        opacity: (compactRoot.activeTransient === "" && !compactRoot.isCalling) ? 1.0 : 0.0
        visible: opacity > 0.01
        scale: opacity > 0.5 ? 1.0 : 0.94

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: compactRoot.activeTransient === "" ? 40 : 0 }
                NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
            }
        }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        Item {
            width: compactRoot.showNetSpeed ? 42 : 0
            height: 22
            visible: compactRoot.showNetSpeed
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Column {
                anchors.fill: parent
                spacing: 1

                Row {
                    spacing: 2
                    anchors.left: parent.left
                    Text { text: "↓"; font.pixelSize: 8; color: "#38bdf8"; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: compactRoot.downCompact
                        color: Qt.rgba(1, 1, 1, 0.85)
                        font.pixelSize: 9
                        font.family: "Monospace"
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Row {
                    spacing: 2
                    anchors.left: parent.left
                    Text { text: "↑"; font.pixelSize: 8; color: "#34d399"; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: compactRoot.upCompact
                        color: Qt.rgba(1, 1, 1, 0.85)
                        font.pixelSize: 9
                        font.family: "Monospace"
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Text {
            text: compactRoot.displayDate; color: Qt.rgba(1, 1, 1, 0.82)
            font.family: compactRoot.chosenFont; font.pixelSize: 12; font.weight: Font.Bold
            visible: (typeof Config !== "undefined" && Config.showDate) && compactRoot.displayDate !== ""
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: compactRoot.displayTime; color: "white"
                font.family: (compactRoot.chosenFont !== "") ? compactRoot.chosenFont : "Monospace"
                font.pixelSize: 22; font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: compactRoot.displaySeconds; color: "#34d399"
                font.family: (compactRoot.chosenFont !== "") ? compactRoot.chosenFont : "Monospace"
                font.pixelSize: 14; font.weight: Font.ExtraBold
                visible: (typeof Config !== "undefined" && Config.showSeconds) && compactRoot.displaySeconds !== ""
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 1
            }
            Text {
                text: compactRoot.displayPeriod; color: Qt.rgba(1, 1, 1, 0.65)
                font.family: compactRoot.chosenFont; font.pixelSize: 10; font.weight: Font.Black
                font.capitalization: Font.AllUppercase
                visible: (typeof Config !== "undefined" && Config.timeFormat === "12h") && compactRoot.displayPeriod !== ""
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 2
            }
        }
    }
}