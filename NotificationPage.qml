import QtQuick
import QtQuick.Controls

Item {
    id: notifPageRoot

    property string chosenFont: ""
    property var historyList: []
    property int unreadCount: 0

    signal openHistoryItem(string title, string content)

    function refresh() {
        if (typeof Bridge !== "undefined" && Bridge.getNotificationHistory) {
            notifPageRoot.historyList = Bridge.getNotificationHistory()
            notifPageRoot.unreadCount = Bridge.getUnreadNotificationCount()
        }
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onNotificationHistoryUpdated(list) {
            notifPageRoot.historyList = list
        }
        function onUnreadCountChanged(cnt) {
            notifPageRoot.unreadCount = cnt
        }
    }

    Component.onCompleted: refresh()

    Column {
        anchors.fill: parent
        spacing: 8

        Item {
            width: parent.width; height: 22

            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text {
                    text: "已归档消息"
                    color: "white"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.family: notifPageRoot.chosenFont
                }
                Rectangle {
                    width: Math.max(16, unreadBadgeText.implicitWidth + 8)
                    height: 16; radius: 8
                    color: "#6366f1"
                    visible: notifPageRoot.unreadCount > 0
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        id: unreadBadgeText
                        anchors.centerIn: parent
                        text: notifPageRoot.unreadCount
                        color: "white"
                        font.pixelSize: 9
                        font.weight: Font.Black
                    }
                }
            }

            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: notifPageRoot.historyList.length > 0

                Rectangle {
                    width: 58; height: 20; radius: 10
                    color: readAllArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                    Text { anchors.centerIn: parent; text: "全部已读"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 9; font.weight: Font.Bold; font.family: notifPageRoot.chosenFont }
                    MouseArea {
                        id: readAllArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (typeof Bridge !== "undefined") Bridge.markAllNotificationsRead()
                    }
                }

                Rectangle {
                    width: 44; height: 20; radius: 10
                    color: clearArea.containsMouse ? Qt.rgba(239, 68, 68, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                    Text { anchors.centerIn: parent; text: "清空"; color: clearArea.containsMouse ? "#ef4444" : Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 9; font.weight: Font.Bold; font.family: notifPageRoot.chosenFont }
                    MouseArea {
                        id: clearArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (typeof Bridge !== "undefined") Bridge.clearNotificationHistory()
                    }
                }
            }
        }

        ListView {
            id: notifListView
            width: parent.width
            height: parent.height - 30
            clip: true
            spacing: 6
            model: notifPageRoot.historyList

            ScrollBar.vertical: ScrollBar {
                width: 4; policy: ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.3) }
            }

            Item {
                anchors.fill: parent
                visible: notifPageRoot.historyList.length === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "🎉 暂无未读消息"; color: "white"; font.pixelSize: 13; font.weight: Font.Bold; font.family: notifPageRoot.chosenFont; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "收到的 Teams 与系统通知将自动在灵动岛归档保存"; color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 11; font.family: notifPageRoot.chosenFont; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }

            delegate: Rectangle {
                id: notifCard
                width: notifListView.width - 6
                height: 52
                radius: 10
                color: notifHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : (modelData.read ? Qt.rgba(1, 1, 1, 0.03) : Qt.rgba(99, 102, 241, 0.08))
                border.color: modelData.read ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(129, 140, 248, 0.35)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }

                HoverHandler { id: notifHover }

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    Rectangle {
                        width: 36; height: 36; radius: 10
                        color: itemAvatar.visible ? "transparent" : "#4F46E5"
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Image {
                            id: itemAvatar
                            anchors.fill: parent
                            source: (modelData.avatar && modelData.avatar.length > 5) ? modelData.avatar : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    source = ""
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (itemAvatar.visible) return ""
                                if (modelData.title && modelData.title.length > 0) return modelData.title.charAt(0).toUpperCase()
                                return "💬"
                            }
                            color: "white"; font.pixelSize: 14; font.weight: Font.Bold; visible: !itemAvatar.visible
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        width: parent.width - 120

                        Row {
                            spacing: 6
                            Text {
                                text: modelData.title || "新提醒"
                                color: "white"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                font.family: notifPageRoot.chosenFont
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "• Teams"
                                color: "#818cf8"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.time || ""
                                color: Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 9
                                font.family: "Monospace"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            text: modelData.content || "未提供正文详情"
                            color: Qt.rgba(1, 1, 1, 0.75)
                            font.pixelSize: 11
                            font.family: notifPageRoot.chosenFont
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    Rectangle {
                        width: 58; height: 26; radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: actionBtnArea.pressed ? "#4338ca" : (actionBtnArea.containsMouse ? "#4f46e5" : Qt.rgba(99, 102, 241, 0.2))
                        border.color: "#6366f1"
                        border.width: 1
                        scale: actionBtnArea.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 2
                            Text { text: "回复"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: notifPageRoot.chosenFont }
                            Text { text: "↗"; color: "#818cf8"; font.pixelSize: 10; font.weight: Font.Bold }
                        }

                        MouseArea {
                            id: actionBtnArea
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof Bridge !== "undefined") {
                                    Bridge.focusTeamsWindow()
                                    Bridge.markAllNotificationsRead()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}