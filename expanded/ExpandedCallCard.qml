import QtQuick

Item {
    id: callCardRoot
    anchors.fill: parent

    property string chosenFont: ""
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""
    property bool isCalling: false

    signal collapseRequested()

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
                    color: "transparent"; border.color: Theme.media; border.width: 1.5

                    SequentialAnimation {
                        running: callCardRoot.isCalling; loops: Animation.Infinite
                        ParallelAnimation {
                            NumberAnimation { target: cardPulse; property: "scale"; from: 0.9; to: 1.35; duration: 1200; easing.type: Easing.OutQuad }
                            NumberAnimation { target: cardPulse; property: "opacity"; from: 0.8; to: 0.0; duration: 1200; easing.type: Easing.OutQuad }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    Image {
                        id: cardAvatarRawImg; source: callCardRoot.callAvatar; visible: false; cache: true; asynchronous: true
                        onStatusChanged: if (status === Image.Ready) cardAvatarCanvas.requestPaint()
                    }
                    Canvas {
                        id: cardAvatarCanvas; anchors.fill: parent
                        renderTarget: Canvas.FramebufferObject; renderStrategy: Canvas.Threaded
                        visible: cardAvatarRawImg.status === Image.Ready
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset(); ctx.clearRect(0, 0, width, height)
                            if (cardAvatarRawImg.status !== Image.Ready) return
                            ctx.save(); ctx.beginPath(); ctx.arc(width / 2.0, height / 2.0, width / 2.0 - 0.5, 0, 2 * Math.PI, false)
                            ctx.closePath(); ctx.clip(); ctx.drawImage(cardAvatarRawImg, 0, 0, width, height); ctx.restore()
                        }
                    }
                    Rectangle {
                        anchors.fill: parent; radius: width / 2; color: "#4F46E5"; visible: cardAvatarRawImg.status !== Image.Ready
                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (callCardRoot.callTitle && callCardRoot.callTitle.length > 0) {
                                    var parts = callCardRoot.callTitle.trim().split(" ")
                                    return (parts.length >= 2) ? (parts[0][0] + parts[1][0]).toUpperCase() : callCardRoot.callTitle.trim().charAt(0).toUpperCase()
                                }
                                return "📞"
                            }
                            color: "white"; font.family: callCardRoot.chosenFont; font.pixelSize: 22; font.weight: Font.Black
                        }
                    }
                    Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.color: Qt.rgba(255, 255, 255, 0.2); border.width: 1.5 }
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 4; width: 280
                Text { text: callCardRoot.callTitle || "Teams 来电"; color: "white"; font.family: callCardRoot.chosenFont; font.pixelSize: 19; font.weight: Font.Black; elide: Text.ElideRight; width: parent.width }
                Text { text: (callCardRoot.callSubtitle || "正在呼叫...") + " · Microsoft Teams 语音通话"; color: Theme.media; font.family: callCardRoot.chosenFont; font.pixelSize: 11; font.weight: Font.Bold; elide: Text.ElideRight; width: parent.width }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Rectangle {
                width: 110; height: 40; radius: 20
                color: rejectArea.pressed ? Qt.rgba(239, 68, 68, 0.45) : (rejectArea.containsMouse ? Qt.rgba(239, 68, 68, 0.3) : Qt.rgba(239, 68, 68, 0.16))
                border.color: Theme.danger; border.width: 1; scale: rejectArea.pressed ? 0.96 : 1.0

                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text { text: "✕"; color: Theme.danger; font.pixelSize: 14; font.weight: Font.Black }
                    Text { text: "拒接"; color: "white"; font.family: callCardRoot.chosenFont; font.pixelSize: 12; font.weight: Font.Bold }
                }

                MouseArea {
                    id: rejectArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof Bridge !== "undefined") Bridge.rejectTeamsCall()
                        callCardRoot.collapseRequested()
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
                    Text { text: "直接接听呼叫"; color: "white"; font.family: callCardRoot.chosenFont; font.pixelSize: 13; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "✓"; color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 13; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: answerArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof Bridge !== "undefined") Bridge.answerTeamsCall()
                        callCardRoot.collapseRequested()
                    }
                }
            }
        }

        Text {
            text: "💡 点击一键接通电话并自动聚焦 Teams 窗口"
            color: Theme.textMuted; font.family: callCardRoot.chosenFont; font.pixelSize: 10; font.weight: Font.Bold
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}