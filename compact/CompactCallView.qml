import QtQuick

Item {
    id: callRoot
    anchors.fill: parent

    property string chosenFont: ""
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""
    property bool isCalling: false

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12; anchors.rightMargin: 12
        spacing: 10

        Item {
            width: 32; height: 32
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: pulseRing
                anchors.centerIn: parent
                width: 32; height: 32; radius: 16
                color: "transparent"; border.color: Theme.media; border.width: 1.5

                SequentialAnimation {
                    running: callRoot.isCalling; loops: Animation.Infinite
                    ParallelAnimation {
                        NumberAnimation { target: pulseRing; property: "scale"; from: 0.9; to: 1.35; duration: 1200; easing.type: Easing.OutQuad }
                        NumberAnimation { target: pulseRing; property: "opacity"; from: 0.85; to: 0.0; duration: 1200; easing.type: Easing.OutQuad }
                    }
                    PauseAnimation { duration: 120 }
                }
            }

            Rectangle {
                anchors.fill: parent; radius: 16; color: callAvatarImg.visible ? "transparent" : "#4F46E5"; clip: true
                Image {
                    id: callAvatarImg; anchors.fill: parent; source: callRoot.callAvatar
                    fillMode: Image.PreserveAspectCrop; visible: callRoot.callAvatar !== "" && status === Image.Ready
                    sourceSize.width: 64; sourceSize.height: 64; asynchronous: true; cache: true
                }
                Text {
                    anchors.centerIn: parent
                    text: {
                        if (callAvatarImg.visible) return ""
                        if (callRoot.callTitle) {
                            var parts = callRoot.callTitle.trim().split(" ")
                            return (parts.length >= 2) ? (parts[0][0] + parts[1][0]).toUpperCase() : callRoot.callTitle.trim().charAt(0).toUpperCase()
                        }
                        return "📞"
                    }
                    color: "white"; font.family: callRoot.chosenFont; font.pixelSize: 12; font.weight: Font.Black
                    visible: !callAvatarImg.visible
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter; spacing: 2
            width: parent.width - 32 - 100 - 20

            Text { text: callRoot.callTitle || "Teams 来电"; color: "white"; font.family: callRoot.chosenFont; font.pixelSize: 13; font.weight: Font.Black; elide: Text.ElideRight; width: parent.width }
            Text { text: callRoot.callSubtitle || "正在呼叫..."; color: Theme.media; font.family: callRoot.chosenFont; font.pixelSize: 10; font.weight: Font.Black }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter; spacing: 6

            Rectangle {
                width: 26; height: 26; radius: 13
                anchors.verticalCenter: parent.verticalCenter
                color: rejectCallTap.pressed ? Qt.rgba(239, 68, 68, 0.5) : (rejectCallHover.hovered ? Qt.rgba(239, 68, 68, 0.35) : Qt.rgba(239, 68, 68, 0.2))
                border.color: Theme.danger; border.width: 1
                Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 10; font.weight: Font.Black }
                HoverHandler { id: rejectCallHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: rejectCallTap; onTapped: if (typeof Bridge !== "undefined") Bridge.rejectTeamsCall() }
            }

            Rectangle {
                width: 58; height: 26; radius: 13
                anchors.verticalCenter: parent.verticalCenter
                color: directBtnTap.pressed ? "#15803d" : (directBtnHover.hovered ? "#16a34a" : "#22c55e")
                border.color: Theme.media; border.width: 1
                scale: directBtnTap.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                Row {
                    anchors.centerIn: parent; spacing: 3
                    Text { text: "接听"; color: "white"; font.pixelSize: 10; font.weight: Font.Black; font.family: callRoot.chosenFont }
                    Text { text: "↗"; color: "white"; font.pixelSize: 10; font.weight: Font.Black }
                }
                HoverHandler { id: directBtnHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: directBtnTap; onTapped: if (typeof Bridge !== "undefined") Bridge.answerTeamsCall() }
            }
        }
    }
}