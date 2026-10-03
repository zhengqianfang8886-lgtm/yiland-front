import QtQuick
import QtQuick.Shapes

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

    property color dominantColor: "#22c55e"
    property int mediaRevision: 0

    onTitleChanged: {
        mediaRevision++
        resetFadeAnim.restart()
    }
    onArtUrlChanged: {
        mediaRevision++
    }

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

    // 🚀 整体紧凑型流式布局
    Column {
        width: parent.width
        anchors.centerIn: parent
        spacing: mediaRoot.isCalling ? 10 : 10

        // =====================================================================
        // 1. 媒体头栏信息（精炼紧凑 48px）
        // =====================================================================
        Item {
            width: parent.width
            height: 48

            Row {
                anchors.fill: parent
                spacing: 12

                // 专辑封面
                Rectangle {
                    width: 48
                    height: 48
                    radius: 10
                    color: mediaRoot.isCalling ? "#4F46E5" : "#242428"
                    border.color: (!mediaRoot.isCalling && mediaPortalHover.containsMouse) ? mediaRoot.dominantColor : Theme.borderSubtle
                    border.width: 1
                    clip: true

                    Image {
                        id: coverImg
                        anchors.fill: parent
                        source: {
                            if (mediaRoot.isCalling) return mediaRoot.callAvatar
                            if (!mediaRoot.artUrl) return ""
                            var base = mediaRoot.artUrl.indexOf("://") !== -1 ? mediaRoot.artUrl : ("file://" + mediaRoot.artUrl)
                            var sep = base.indexOf("?") !== -1 ? "&" : "?"
                            return base + sep + "rev=" + mediaRoot.mediaRevision
                        }
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 96
                        sourceSize.height: 96
                        asynchronous: true
                        cache: false

                        visible: status === Image.Ready
                        opacity: visible ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                        NumberAnimation {
                            id: resetFadeAnim
                            target: coverImg
                            property: "opacity"
                            from: 0.2; to: 1.0
                            duration: 260
                            easing.type: Easing.OutQuad
                        }
                    }

                    // 缺省封面音符
                    Text {
                        anchors.centerIn: parent
                        text: mediaRoot.isCalling ? "📞" : "🎵"
                        font.pixelSize: 18
                        visible: coverImg.status !== Image.Ready || coverImg.opacity <= 0.5
                    }

                    Rectangle {
                        anchors.fill: parent; radius: 10
                        color: Qt.rgba(0, 0, 0, 0.45)
                        visible: !mediaRoot.isCalling && mediaPortalHover.containsMouse
                        Text { anchors.centerIn: parent; text: "↗"; color: "white"; font.pixelSize: 16; font.weight: Font.Bold }
                    }
                }

                // 歌曲与歌手信息
                Column {
                    width: parent.width - 60
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Row {
                        width: parent.width
                        spacing: 4

                        Text {
                            text: mediaRoot.isCalling ? mediaRoot.callTitle : (mediaRoot.title ? mediaRoot.title : "等待播放...")
                            color: (!mediaRoot.isCalling && mediaPortalHover.containsMouse) ? mediaRoot.dominantColor : "white"
                            font.family: mediaRoot.chosenFont
                            font.pixelSize: 13
                            font.weight: Font.Black
                            elide: Text.ElideRight
                            width: (!mediaRoot.isCalling) ? (parent.width - 20) : parent.width
                        }

                        Text {
                            text: "↗"
                            color: mediaRoot.dominantColor
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            visible: !mediaRoot.isCalling && mediaPortalHover.containsMouse
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        text: mediaRoot.isCalling ? mediaRoot.callSubtitle : ((mediaRoot.artist ? mediaRoot.artist : "未知歌手") + (mediaPortalHover.containsMouse ? " · 点击聚焦客户端" : ""))
                        color: mediaRoot.isCalling ? Theme.media : Theme.textSecondary
                        font.family: mediaRoot.chosenFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            MouseArea {
                id: mediaPortalHover
                anchors.fill: parent
                enabled: !mediaRoot.isCalling
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Bridge.focusMediaWindow(mediaRoot.title, mediaRoot.artist)
                    mediaRoot.startCollapse()
                }
            }
        }

        // =====================================================================
        // 2. 来电跳转专区 (Calling Mode)
        // =====================================================================
        Column {
            width: parent.width
            spacing: 6
            visible: mediaRoot.isCalling

            Rectangle {
                width: parent.width; height: 38; radius: 19
                color: callPortalArea.pressed ? "#15803d" : (callPortalArea.containsMouse ? "#16a34a" : Theme.media)
                scale: callPortalArea.pressed ? 0.98 : 1.0
                Behavior on scale { NumberAnimation { duration: Theme.animInstant } }

                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text { text: "📞"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "唤起 Teams 窗口接听"; color: "white"; font.family: mediaRoot.chosenFont; font.pixelSize: 13; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "↗"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 13; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: callPortalArea
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { Bridge.focusTeamsWindow(); mediaRoot.startCollapse() }
                }
            }
        }

        // =====================================================================
        // 3. 音乐播放时间轴与进度条（紧凑 12px）
        // =====================================================================
        Item {
            width: parent.width
            height: 12
            visible: !mediaRoot.isCalling

            Text {
                id: posText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: mediaRoot.formatMediaTime(mediaRoot.position, mediaRoot.duration >= 3600)
                color: Theme.textMuted
                font.family: "Monospace"
                font.pixelSize: 10
                font.weight: Font.Bold
            }

            Rectangle {
                id: progressTrack
                anchors.left: posText.right
                anchors.right: durText.left
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.14)

                Rectangle {
                    width: mediaRoot.duration > 0 ? (progressTrack.width * Math.min(1.0, Math.max(0.0, mediaRoot.position / mediaRoot.duration))) : 0
                    height: parent.height
                    radius: 2
                    color: mediaRoot.dominantColor
                    Behavior on color { ColorAnimation { duration: 250 } }
                }
            }

            Text {
                id: durText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: mediaRoot.formatMediaTime(mediaRoot.duration)
                color: Theme.textMuted
                font.family: "Monospace"
                font.pixelSize: 10
                font.weight: Font.Bold
            }
        }

        // =====================================================================
        // 4. 音乐播控区：零字体偏差、100% 居中纯矢量按键
        // =====================================================================
        Item {
            width: parent.width
            height: 42
            visible: !mediaRoot.isCalling

            Row {
                anchors.centerIn: parent
                spacing: 36

                // ⏮ 上一首 (纯矢量精密双构件)
                Rectangle {
                    width: 32; height: 32; radius: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    scale: prevArea.pressed ? 0.9 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.animInstant } }

                    Shape {
                        anchors.centerIn: parent
                        width: 14; height: 14
                        opacity: prevArea.containsMouse ? 1.0 : 0.75
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            fillColor: "white"
                            strokeColor: "transparent"

                            // 左竖挡杆
                            startX: 2.0; startY: 2.5
                            PathLine { x: 3.5; y: 2.5 }
                            PathLine { x: 3.5; y: 11.5 }
                            PathLine { x: 2.0; y: 11.5 }
                            PathLine { x: 2.0; y: 2.5 }

                            // 倒向三角
                            PathMove { x: 12.0; y: 2.5 }
                            PathLine { x: 4.5; y: 7.0 }
                            PathLine { x: 12.0; y: 11.5 }
                            PathLine { x: 12.0; y: 2.5 }
                        }
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => { mouse.accepted = true; Bridge.sendMediaCmd("MEDIA_PREV") }
                    }
                }

                // ⏯ 核心播放/暂停键（数学级绝对居中）
                Rectangle {
                    id: playBtnContainer
                    width: 42; height: 42; radius: 21
                    anchors.verticalCenter: parent.verticalCenter

                    color: playArea.pressed ?
                           Qt.rgba(mediaRoot.dominantColor.r, mediaRoot.dominantColor.g, mediaRoot.dominantColor.b, 0.38) :
                           (playArea.containsMouse ?
                            Qt.rgba(mediaRoot.dominantColor.r, mediaRoot.dominantColor.g, mediaRoot.dominantColor.b, 0.24) :
                            Qt.rgba(1, 1, 1, 0.14))

                    border.color: playArea.containsMouse ? mediaRoot.dominantColor : Theme.borderSubtle
                    border.width: 1
                    scale: playArea.pressed ? 0.92 : (playArea.containsMouse ? 1.04 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                    Behavior on color { ColorAnimation { duration: Theme.animInstant } }

                    // 1. 暂停态：双立柱纯矩形（彻底杜绝 Unicode 字体倾斜偏心）
                    Row {
                        anchors.centerIn: parent
                        spacing: 4.5
                        visible: mediaRoot.status === "Playing"

                        Rectangle {
                            width: 3.5; height: 13
                            radius: 1.75
                            color: "white"
                        }
                        Rectangle {
                            width: 3.5; height: 13
                            radius: 1.75
                            color: "white"
                        }
                    }

                    // 2. 播放态：实心矢量三角（带 +1.2px 视觉重心补偿，绝不往左塌）
                    Shape {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1.2
                        width: 14; height: 14
                        visible: mediaRoot.status !== "Playing"
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            fillColor: "white"
                            strokeColor: "white"
                            strokeWidth: 1.0
                            joinStyle: ShapePath.RoundJoin
                            capStyle: ShapePath.RoundCap

                            startX: 3.0; startY: 1.8
                            PathLine { x: 12.0; y: 7.0 }
                            PathLine { x: 3.0; y: 12.2 }
                            PathLine { x: 3.0; y: 1.8 }
                        }
                    }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => { mouse.accepted = true; Bridge.sendMediaCmd("MEDIA_PLAY_PAUSE") }
                    }
                }

                // ⏭ 下一首 (纯矢量精密双构件)
                Rectangle {
                    width: 32; height: 32; radius: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    scale: nextArea.pressed ? 0.9 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.animInstant } }

                    Shape {
                        anchors.centerIn: parent
                        width: 14; height: 14
                        opacity: nextArea.containsMouse ? 1.0 : 0.75
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            fillColor: "white"
                            strokeColor: "transparent"

                            // 正向三角
                            startX: 2.0; startY: 2.5
                            PathLine { x: 9.5; y: 7.0 }
                            PathLine { x: 2.0; y: 11.5 }
                            PathLine { x: 2.0; y: 2.5 }

                            // 右竖挡杆
                            PathMove { x: 10.5; y: 2.5 }
                            PathLine { x: 12.0; y: 2.5 }
                            PathLine { x: 12.0; y: 11.5 }
                            PathLine { x: 10.5; y: 11.5 }
                            PathLine { x: 10.5; y: 2.5 }
                        }
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => { mouse.accepted = true; Bridge.sendMediaCmd("MEDIA_NEXT") }
                    }
                }
            }
        }
    }
}