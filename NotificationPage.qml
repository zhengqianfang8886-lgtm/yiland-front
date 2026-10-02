import QtQuick
import QtQuick.Controls

Item {
    id: notifPageRoot

    property string chosenFont: ""
    
    readonly property var notifModel: (typeof Bridge !== "undefined") ? Bridge.notificationModel : null
    readonly property int unreadCount: notifModel ? notifModel.unreadCount : 0

    Column {
        anchors.fill: parent
        spacing: 8

        // 1. 顶部状态栏与批处理按钮
        Item {
            width: parent.width
            height: 22

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
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
                    height: 16
                    radius: 8
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
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: notifPageRoot.notifModel && notifPageRoot.notifModel.rowCount() > 0

                Rectangle {
                    width: 58; height: 20; radius: 10
                    color: readAllTap.pressed ? Qt.rgba(1, 1, 1, 0.22) : (readAllHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06))
                    
                    Text {
                        anchors.centerIn: parent
                        text: "全部已读"
                        color: Theme.textSecondary
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.family: notifPageRoot.chosenFont
                    }

                    HoverHandler { id: readAllHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: readAllTap
                        onTapped: if (notifPageRoot.notifModel) notifPageRoot.notifModel.markAllRead()
                    }
                }

                Rectangle {
                    width: 44; height: 20; radius: 10
                    color: clearTap.pressed ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.35) : (clearHover.hovered ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.22) : Qt.rgba(1, 1, 1, 0.06))
                    
                    Text {
                        anchors.centerIn: parent
                        text: "清空"
                        color: clearHover.hovered ? Theme.danger : Theme.textMuted
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.family: notifPageRoot.chosenFont
                    }

                    HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: clearTap
                        onTapped: if (notifPageRoot.notifModel) notifPageRoot.notifModel.clearAll()
                    }
                }
            }
        }

        // 2. 消息流列表
        ListView {
            id: notifListView
            width: parent.width
            height: parent.height - 30
            clip: true
            spacing: 6
            model: notifPageRoot.notifModel

            ScrollBar.vertical: ScrollBar {
                width: 4
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 2; color: Theme.borderSubtle }
            }

            Item {
                anchors.fill: parent
                visible: !notifPageRoot.notifModel || notifPageRoot.notifModel.rowCount() === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Text { text: "🎉 暂无未读消息"; color: "white"; font.pixelSize: 13; font.weight: Font.Bold; font.family: notifPageRoot.chosenFont; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "收到的 Teams 与系统通知将自动在灵动岛归档保存"; color: Theme.textMuted; font.pixelSize: 11; font.family: notifPageRoot.chosenFont; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }

            delegate: Rectangle {
                id: notifCard
                width: notifListView.width - 6
                height: 52
                radius: 10
                
                color: notifCardHover.hovered ? Theme.bgCardHover : (model.read ? Qt.rgba(1, 1, 1, 0.03) : Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.08))
                border.color: model.read ? Theme.borderSubtle : Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.35)
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                HoverHandler { id: notifCardHover }

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    // 🚀 正圆形通知头像（radius: 18）
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: itemAvatar.visible ? "transparent" : "#4F46E5"
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Image {
                            id: itemAvatar
                            anchors.fill: parent
                            source: (model.avatar && model.avatar.length > 5) ? model.avatar : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 72
                            sourceSize.height: 72
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready
                            onStatusChanged: if (status === Image.Error) source = ""
                        }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (itemAvatar.visible) return ""
                                if (model.title && model.title.length > 0) return model.title.charAt(0).toUpperCase()
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
                                text: model.title || "新提醒"
                                color: "white"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                font.family: notifPageRoot.chosenFont
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "• Teams"
                                color: Theme.notification
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: model.time || ""
                                color: Theme.textMuted
                                font.pixelSize: 9
                                font.family: "Monospace"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            text: model.content || "未提供正文详情"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            font.family: notifPageRoot.chosenFont
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    Rectangle {
                        width: 58; height: 26; radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: actionBtnTap.pressed ? "#4338ca" : (actionBtnHover.hovered ? "#4f46e5" : Qt.rgba(Theme.notification.r, Theme.notification.g, Theme.notification.b, 0.2))
                        border.color: Theme.notification
                        border.width: 1
                        scale: actionBtnTap.pressed ? 0.94 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.animInstant } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 2
                            Text { text: "回复"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: notifPageRoot.chosenFont }
                            Text { text: "↗"; color: Theme.notification; font.pixelSize: 10; font.weight: Font.Bold }
                        }

                        HoverHandler { id: actionBtnHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            id: actionBtnTap
                            onTapped: {
                                if (typeof Bridge !== "undefined") {
                                    Bridge.focusTeamsWindow()
                                    if (notifPageRoot.notifModel) notifPageRoot.notifModel.markAllRead()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}