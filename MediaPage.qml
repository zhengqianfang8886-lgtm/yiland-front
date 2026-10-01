import QtQuick 2.15

Item {
    id: mediaRoot

    property string chosenFont: ""
    property bool isCalling: false
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""
    property string title: "等待播放..."
    property string artist: "未知歌手"
    property string status: "Paused"
    property string artUrl: ""
    property real position: 0
    property real duration: 0

    signal cancelCollapse()
    signal requestCollapse()
    signal startCollapse()

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

    // 垂直完美居中，彻底消除底部空旷
    Column {
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        spacing: mediaRoot.isCalling ? 14 : 16

        // 1. 媒体与通话头栏信息
        Item {
            width: parent.width; height: 58

            Row {
                anchors.fill: parent
                spacing: 14

                Rectangle {
                    width: 58; height: 58; radius: 14
                    color: mediaRoot.isCalling ? "#4F46E5" : "#242428"
                    border.color: (!mediaRoot.isCalling && mediaPortalHover.containsMouse) ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    clip: true

                    Image {
                        id: coverImg; anchors.fill: parent
                        source: mediaRoot.isCalling ? mediaRoot.callAvatar : (mediaRoot.artUrl ? (mediaRoot.artUrl.indexOf("://") !== -1 ? mediaRoot.artUrl : "file://" + mediaRoot.artUrl) : "")
                        fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (coverImg.status === Image.Ready) return ""
                            if (mediaRoot.isCalling) {
                                if (mediaRoot.callTitle && mediaRoot.callTitle.length > 0) {
                                    var parts = mediaRoot.callTitle.trim().split(" ")
                                    return (parts.length >= 2) ? (parts[0][0] + parts[1][0]).toUpperCase() : mediaRoot.callTitle.trim().charAt(0).toUpperCase()
                                }
                                return "📞"
                            }
                            return "🎵"
                        }
                        font.pixelSize: 22; font.family: mediaRoot.chosenFont; font.weight: Font.Black; color: "white"
                        visible: coverImg.status !== Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent; radius: 14
                        color: Qt.rgba(0, 0, 0, 0.45)
                        visible: !mediaRoot.isCalling && mediaPortalHover.containsMouse
                        Text { anchors.centerIn: parent; text: "↗"; color: "white"; font.pixelSize: 20; font.weight: Font.Bold }
                    }
                }

                Column {
                    width: parent.width - 74
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Row {
                        width: parent.width; spacing: 6
                        Text {
                            text: mediaRoot.isCalling ? mediaRoot.callTitle : (mediaRoot.title ? mediaRoot.title : "等待播放...")
                            color: (!mediaRoot.isCalling && mediaPortalHover.containsMouse) ? "#38bdf8" : "white"
                            font.family: mediaRoot.chosenFont; font.pixelSize: 15; font.weight: Font.Black; elide: Text.ElideRight
                            width: (!mediaRoot.isCalling) ? (parent.width - 22) : parent.width
                        }
                        Text {
                            text: "↗"; color: "#38bdf8"; font.pixelSize: 13; font.weight: Font.Bold
                            visible: !mediaRoot.isCalling && mediaPortalHover.containsMouse
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        text: mediaRoot.isCalling ? mediaRoot.callSubtitle : ((mediaRoot.artist ? mediaRoot.artist : "未知歌手") + (mediaPortalHover.containsMouse ? " · 点击直达客户端" : ""))
                        color: mediaRoot.isCalling ? "#22c55e" : Qt.rgba(1, 1, 1, 0.6)
                        font.family: mediaRoot.chosenFont; font.pixelSize: 12; font.weight: Font.DemiBold
                        elide: Text.ElideRight; width: parent.width
                    }
                }
            }

            MouseArea {
                id: mediaPortalHover
                anchors.fill: parent
                enabled: !mediaRoot.isCalling
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: mediaRoot.cancelCollapse()
                onExited: mediaRoot.requestCollapse()
                onClicked: {
                    Bridge.focusMediaWindow(mediaRoot.title, mediaRoot.artist)
                    mediaRoot.startCollapse()
                }
            }
        }

        // 2. 通话中的跳转大按钮
        Column {
            width: parent.width
            spacing: 8
            visible: mediaRoot.isCalling

            Rectangle {
                id: callPortalBtn
                width: parent.width; height: 42; radius: 21
                color: callPortalArea.pressed ? "#15803d" : (callPortalArea.containsMouse ? "#16a34a" : "#22c55e")
                scale: callPortalArea.pressed ? 0.98 : (callPortalArea.containsMouse ? 1.01 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: "📞"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "唤起 Teams 窗口接听"; color: "white"; font.family: mediaRoot.chosenFont; font.pixelSize: 14; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "↗"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 14; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: callPortalArea
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: mediaRoot.cancelCollapse()
                    onExited: mediaRoot.requestCollapse()
                    onClicked: (mouse) => { mouse.accepted = true; Bridge.focusTeamsWindow(); mediaRoot.startCollapse() }
                }
            }
            Text {
                text: "💡 跨桌面秒级聚焦 · 确认摄像头与麦克风状态"
                color: Qt.rgba(1, 1, 1, 0.45); font.family: mediaRoot.chosenFont; font.pixelSize: 11; font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // 3. 音乐播放进度条与时间
        Item {
            width: parent.width; height: 18
            visible: !mediaRoot.isCalling

            Text {
                id: posText
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                text: mediaRoot.formatMediaTime(mediaRoot.position, mediaRoot.duration >= 3600)
                color: Qt.rgba(1, 1, 1, 0.75); font.family: (mediaRoot.chosenFont !== "") ? mediaRoot.chosenFont : "Monospace"
                font.pixelSize: 11; font.weight: Font.Bold
            }

            Rectangle {
                id: progressTrack
                anchors.left: posText.right; anchors.right: durText.left
                anchors.leftMargin: 12; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 4.5; radius: 99; color: Qt.rgba(1, 1, 1, 0.16)

                Rectangle {
                    width: mediaRoot.duration > 0 ? (progressTrack.width * Math.min(1.0, Math.max(0.0, mediaRoot.position / mediaRoot.duration))) : 0
                    height: parent.height; radius: 99; color: "white"
                }
            }

            Text {
                id: durText
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: mediaRoot.formatMediaTime(mediaRoot.duration)
                color: Qt.rgba(1, 1, 1, 0.75); font.family: (mediaRoot.chosenFont !== "") ? mediaRoot.chosenFont : "Monospace"
                font.pixelSize: 11; font.weight: Font.Bold
            }
        }

        // 4. 音乐播控操作栏
        Item {
            width: parent.width; height: 44
            visible: !mediaRoot.isCalling

            Row {
                anchors.centerIn: parent
                spacing: 42

                Rectangle {
                    width: 36; height: 36; radius: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    scale: prevArea.pressed ? 0.9 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        text: "⏮"; color: "white"; font.pixelSize: 18
                        opacity: prevArea.containsMouse ? 1.0 : 0.75
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: mediaRoot.cancelCollapse()
                        onExited: mediaRoot.requestCollapse()
                        onClicked: (mouse) => { mouse.accepted = true; Bridge.sendMediaCmd("MEDIA_PREV") }
                    }
                }

                Rectangle {
                    width: 44; height: 44; radius: 22
                    anchors.verticalCenter: parent.verticalCenter
                    color: playArea.pressed ? Qt.rgba(1, 1, 1, 0.28) : (playArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.14))
                    border.color: Qt.rgba(1, 1, 1, 0.18); border.width: 1
                    scale: playArea.pressed ? 0.92 : (playArea.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: mediaRoot.status === "Playing" ? 0 : 1
                        text: mediaRoot.status === "Playing" ? "⏸" : "▶"
                        color: "white"; font.pixelSize: 20
                    }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: mediaRoot.cancelCollapse()
                        onExited: mediaRoot.requestCollapse()
                        onClicked: (mouse) => { mouse.accepted = true; Bridge.sendMediaCmd("MEDIA_PLAY_PAUSE") }
                    }
                }

                Rectangle {
                    width: 36; height: 36; radius: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    scale: nextArea.pressed ? 0.9 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                    Text {
                        anchors.centerIn: parent
                        text: "⏭"; color: "white"; font.pixelSize: 18
                        opacity: nextArea.containsMouse ? 1.0 : 0.75
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: mediaRoot.cancelCollapse()
                        onExited: mediaRoot.requestCollapse()
                        onClicked: (mouse) => { mouse.accepted = true; Bridge.sendMediaCmd("MEDIA_NEXT") }
                    }
                }
            }
        }
    }
}