// ==========================================
// 📄 File: ui/components/pages/MediaPage.qml
// 🌟 媒体控制页 (攻克 Chrome 伪时长 · 强语义直播识别版)
// ==========================================
import QtQuick
import QtQuick.Shapes

Item {
    id: mediaRoot

    property string chosenFont: ""
    readonly property string effectiveFont: chosenFont !== "" ? chosenFont : Theme.activeFont
    readonly property string displayFont: Theme.displayMonoFont

    property string title: "等待播放..."
    property string artist: "未知歌手"
    property string status: "Paused"
    property string artUrl: ""
    property real position: 0
    property real duration: 0
    property color dominantColor: "#38bdf8"
    property int mediaRevision: 0

    // =========================================================================
    // 🚀【核心识别引擎】：完美破解 Chrome / YouTube Live 上报伪造 DVR 时长的 Bug
    // =========================================================================
    readonly property bool isLiveStream: {
        // 1. 物理极值判定：没有时长、或者时长大于 24 小时的，绝对是直播
        if (duration <= 0 || duration >= 86400) return true;

        var t = (title || "").toLowerCase();
        var a = (artist || "").toLowerCase();
        var fullInfo = t + " " + a;

        // 2. 强语义特征：只要包含这些关键字，无视系统瞎报的几分钟时长，强判为直播！
        if (fullInfo.indexOf("🔴") !== -1 ||
            fullInfo.indexOf("直播中") !== -1 ||
            fullInfo.indexOf("live stream") !== -1 ||
            fullInfo.indexOf("livestream") !== -1 ||
            fullInfo.indexOf("24/7 live") !== -1 ||
            fullInfo.indexOf("live 4k") !== -1 ||
            t.indexOf("[live]") !== -1 ||
            t.indexOf("【live】") !== -1 ||
            t.indexOf("(live)") !== -1) {
            return true;
        }

        // 3. 弱特征词防误判：如果只是单纯带个 "live" 词汇，可能是 "XX演唱会 Live版" 的普通歌曲
        // 只有当它同时满足时长极其离谱(>2小时)时，才判定为直播
        if (fullInfo.indexOf("live") !== -1 || fullInfo.indexOf("直播") !== -1) {
            if (duration > 7200) return true;
        }

        return false;
    }

    onTitleChanged: {
        mediaRevision++
        resetFadeAnim.restart()
    }
    onArtUrlChanged: mediaRevision++

    signal cancelCollapse()
    signal requestCollapse()
    signal startCollapse()

    function formatMediaTime(sec, forceHours) {
        if (!sec || isNaN(sec) || sec <= 0 || sec >= 86400) return forceHours ? "0:00:00" : "0:00"
        var totalSec = Math.floor(sec)
        var h = Math.floor(totalSec / 3600)
        var m = Math.floor((totalSec % 3600) / 60)
        var s = totalSec % 60
        if (h > 0 || forceHours) {
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
        }
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Column {
        width: parent.width
        anchors.centerIn: parent
        spacing: 10

        // =====================================================================
        // 1. 头栏信息
        // =====================================================================
        Item {
            width: parent.width
            height: 48

            Row {
                anchors.fill: parent
                spacing: 12

                Rectangle {
                    width: 48
                    height: 48
                    radius: 10
                    color: "#242428"
                    border.color: mediaPortalHover.containsMouse ? mediaRoot.dominantColor : Theme.borderSubtle
                    border.width: 1
                    clip: true

                    Image {
                        id: coverImg
                        anchors.fill: parent
                        source: {
                            if (!mediaRoot.artUrl) return ""
                            var url = mediaRoot.artUrl.trim()
                            if (url.indexOf("://") === -1) url = "file://" + url
                            if (url.indexOf("http://") === 0 || url.indexOf("https://") === 0) {
                                var sep = url.indexOf("?") !== -1 ? "&" : "?"
                                return url + sep + "rev=" + mediaRoot.mediaRevision
                            }
                            return url
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

                    Text {
                        anchors.centerIn: parent
                        text: mediaRoot.isLiveStream ? "📡" : "🎵"
                        font.pixelSize: 18
                        visible: coverImg.status !== Image.Ready || coverImg.opacity <= 0.5
                    }

                    Rectangle {
                        anchors.fill: parent; radius: 10
                        color: Qt.rgba(0, 0, 0, 0.45)
                        visible: mediaPortalHover.containsMouse
                        Text { anchors.centerIn: parent; text: "↗"; color: "white"; font.pixelSize: 16; font.weight: Font.Bold }
                    }
                }

                Column {
                    width: parent.width - 60
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Row {
                        width: parent.width
                        spacing: 6

                        // 🔴 智能直播红标
                        Rectangle {
                            height: 16
                            width: liveBadgeText.implicitWidth + 8
                            radius: 4
                            color: "#ef4444"
                            visible: mediaRoot.isLiveStream
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: liveBadgeText
                                anchors.centerIn: parent
                                text: "LIVE"
                                color: "white"
                                font.pixelSize: 9
                                font.weight: Font.Black
                            }
                        }

                        Text {
                            text: mediaRoot.title ? mediaRoot.title : "等待播放..."
                            color: mediaPortalHover.containsMouse ? mediaRoot.dominantColor : "white"
                            font.family: mediaRoot.effectiveFont
                            font.pixelSize: 13
                            font.weight: Font.Black
                            elide: Text.ElideRight
                            width: parent.width - (mediaRoot.isLiveStream ? 56 : 20)
                        }

                        Text {
                            text: "↗"
                            color: mediaRoot.dominantColor
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            visible: mediaPortalHover.containsMouse
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        text: (mediaRoot.artist ? mediaRoot.artist : (mediaRoot.isLiveStream ? "实时音频流" : "未知歌手")) + (mediaPortalHover.containsMouse ? " · 点击聚焦客户端" : "")
                        color: Theme.textSecondary
                        font.family: mediaRoot.effectiveFont
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
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof Bridge !== "undefined" && Bridge.focusMediaWindow) {
                        Bridge.focusMediaWindow(mediaRoot.title, mediaRoot.artist)
                    }
                    mediaRoot.startCollapse()
                }
            }
        }

        // =====================================================================
        // 2. 媒体时间轴：歌曲进度 vs 直播流光能量带
        // =====================================================================
        Item {
            width: parent.width
            height: 14

            Text {
                id: posText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: mediaRoot.isLiveStream ? 
                      (mediaRoot.position > 0 ? mediaRoot.formatMediaTime(mediaRoot.position, false) : "实时流") : 
                      mediaRoot.formatMediaTime(mediaRoot.position, mediaRoot.duration >= 3600)
                color: mediaRoot.isLiveStream ? "#ef4444" : Theme.textMuted
                font.family: mediaRoot.isLiveStream ? mediaRoot.effectiveFont : mediaRoot.displayFont
                font.pixelSize: 10
                font.weight: Font.Bold
            }

            Rectangle {
                id: progressTrack
                anchors.left: posText.right
                anchors.right: durItem.left
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.14)
                clip: true

                // 普通歌曲进度
                Rectangle {
                    visible: !mediaRoot.isLiveStream
                    width: mediaRoot.duration > 0 ? (progressTrack.width * Math.min(1.0, Math.max(0.0, mediaRoot.position / mediaRoot.duration))) : 0
                    height: parent.height
                    radius: 2
                    color: mediaRoot.dominantColor

                    Behavior on width {
                        NumberAnimation { duration: 250; easing.type: Easing.Linear }
                    }
                }

                // 🔴 直播专属：红色流光呼吸脉冲能量带
                Rectangle {
                    visible: mediaRoot.isLiveStream
                    anchors.fill: parent
                    radius: 2
                    color: Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.35)

                    Rectangle {
                        id: livePulseGlow
                        width: parent.width * 0.4
                        height: parent.height
                        radius: 2
                        color: "#ef4444"

                        SequentialAnimation on x {
                            running: mediaRoot.isLiveStream && mediaRoot.status === "Playing"
                            loops: Animation.Infinite
                            NumberAnimation { from: -livePulseGlow.width; to: progressTrack.width; duration: 2200; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }

            Item {
                id: durItem
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: mediaRoot.isLiveStream ? liveBadgeRow.implicitWidth : durText.implicitWidth
                height: parent.height

                Text {
                    id: durText
                    visible: !mediaRoot.isLiveStream
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: mediaRoot.formatMediaTime(mediaRoot.duration)
                    color: Theme.textMuted
                    font.family: mediaRoot.displayFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }

                // 🔴 直播专属：右侧呼吸灯微标
                Row {
                    id: liveBadgeRow
                    visible: mediaRoot.isLiveStream
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Rectangle {
                        id: liveDot
                        width: 6; height: 6; radius: 3
                        color: "#ef4444"
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            running: mediaRoot.isLiveStream && mediaRoot.status === "Playing"
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 800; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.00; duration: 800; easing.type: Easing.InOutQuad }
                        }
                    }

                    Text {
                        text: "LIVE"
                        color: "#ef4444"
                        font.pixelSize: 10
                        font.weight: Font.Black
                        font.family: mediaRoot.effectiveFont
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // =====================================================================
        // 3. 播控按键区
        // =====================================================================
        Item {
            width: parent.width
            height: 42

            Row {
                anchors.centerIn: parent
                spacing: 36

                Rectangle {
                    width: 32; height: 32; radius: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    opacity: mediaRoot.isLiveStream ? 0.35 : 1.0 // 🔴 直播弱化
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
                            startX: 2.0; startY: 2.5
                            PathLine { x: 3.5; y: 2.5 }
                            PathLine { x: 3.5; y: 11.5 }
                            PathLine { x: 2.0; y: 11.5 }
                            PathLine { x: 2.0; y: 2.5 }
                            PathMove { x: 12.0; y: 2.5 }
                            PathLine { x: 4.5; y: 7.0 }
                            PathLine { x: 12.0; y: 11.5 }
                            PathLine { x: 12.0; y: 2.5 }
                        }
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent; hoverEnabled: !mediaRoot.isLiveStream; cursorShape: mediaRoot.isLiveStream ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: (mouse) => { 
                            if (!mediaRoot.isLiveStream) {
                                mouse.accepted = true; 
                                Bridge.sendMediaCmd("MEDIA_PREV") 
                            }
                        }
                    }
                }

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

                    Row {
                        anchors.centerIn: parent
                        spacing: 4.5
                        visible: mediaRoot.status === "Playing"
                        Rectangle { width: 3.5; height: 13; radius: 1.75; color: "white" }
                        Rectangle { width: 3.5; height: 13; radius: 1.75; color: "white" }
                    }

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

                Rectangle {
                    width: 32; height: 32; radius: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    opacity: mediaRoot.isLiveStream ? 0.35 : 1.0 // 🔴 直播弱化
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
                            startX: 2.0; startY: 2.5
                            PathLine { x: 9.5; y: 7.0 }
                            PathLine { x: 2.0; y: 11.5 }
                            PathLine { x: 2.0; y: 2.5 }
                            PathMove { x: 10.5; y: 2.5 }
                            PathLine { x: 12.0; y: 2.5 }
                            PathLine { x: 12.0; y: 11.5 }
                            PathLine { x: 10.5; y: 11.5 }
                            PathLine { x: 10.5; y: 2.5 }
                        }
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent; hoverEnabled: !mediaRoot.isLiveStream; cursorShape: mediaRoot.isLiveStream ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: (mouse) => { 
                            if (!mediaRoot.isLiveStream) {
                                mouse.accepted = true; 
                                Bridge.sendMediaCmd("MEDIA_NEXT") 
                            }
                        }
                    }
                }
            }
        }
    }
}