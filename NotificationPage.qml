// ==========================================
// 📄 File: NotificationPage.qml (防背景穿透·实时一键清空修复版)
// ==========================================
import QtQuick
import QtQuick.Controls

Rectangle {
    id: notifPageRoot
    anchors.fill: parent
    radius: Theme.radiusCard
    
    // 🚀【核心修复 1】：深黑防穿透底板，彻底切断背后桌面/网页文字透视
    color: "#14141c"
    border.color: Theme.borderSubtle
    border.width: 1

    property string chosenFont: ""
    
    readonly property var notifModel: (typeof Bridge !== "undefined") ? Bridge.notificationModel : null
    
    // 🚀【核心修复 2】：使用带有变更通知的 model.count 替代死锁的 rowCount()
    readonly property int totalCount: notifModel ? notifModel.count : 0
    readonly property int unreadCount: notifModel ? notifModel.unreadCount : 0

    readonly property bool isDnd: (typeof Config !== "undefined" && Config.dndEnabled !== undefined) ? Config.dndEnabled : false
    readonly property bool allowCalls: (typeof Config !== "undefined" && Config.dndAllowCalls !== undefined) ? Config.dndAllowCalls : true

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // =====================================================================
        // 1. 顶部操作栏与批处理按钮
        // =====================================================================
        Item {
            width: parent.width
            height: 24

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
                spacing: 5

                // 🌙 勿扰切换胶囊
                Rectangle {
                    height: 20
                    width: dndRow.implicitWidth + 12
                    radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: notifPageRoot.isDnd ?
                           (dndTap.pressed ? Qt.rgba(129 / 255, 140 / 255, 248 / 255, 0.45) : Qt.rgba(129 / 255, 140 / 255, 248 / 255, 0.28)) :
                           (dndHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                    border.color: notifPageRoot.isDnd ? "#818cf8" : Theme.borderSubtle
                    border.width: 1

                    Row {
                        id: dndRow
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: notifPageRoot.isDnd ? "🌙" : "🔔"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: notifPageRoot.isDnd ? "勿扰中" : "普通"
                            color: notifPageRoot.isDnd ? "#a5b4fc" : Theme.textMuted
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.family: notifPageRoot.chosenFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: dndHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: dndTap
                        onTapped: if (typeof Config !== "undefined") Config.dndEnabled = !Config.dndEnabled
                    }
                }

                // 📞 通话穿透胶囊 (仅在勿扰时呼应展开)
                Rectangle {
                    height: 20
                    width: callBypassRow.implicitWidth + 10
                    radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: notifPageRoot.isDnd
                    color: notifPageRoot.allowCalls ? Qt.rgba(34 / 255, 197 / 255, 94 / 255, 0.22) : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.20)
                    border.color: notifPageRoot.allowCalls ? "#22c55e" : "#ef4444"
                    border.width: 1

                    Row {
                        id: callBypassRow
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: notifPageRoot.allowCalls ? "📞" : "🚫"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: notifPageRoot.allowCalls ? "允许通话" : "通话静默"
                            color: notifPageRoot.allowCalls ? "#86efac" : "#fca5a5"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.family: notifPageRoot.chosenFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: callHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: callTap
                        onTapped: if (typeof Config !== "undefined") Config.dndAllowCalls = !Config.dndAllowCalls
                    }
                }

                // 🚀【核心修复 3】：只要存在消息，100% 灵敏感知并弹出全部已读
                Rectangle {
                    width: 52; height: 20; radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: notifPageRoot.totalCount > 0
                    color: readAllTap.pressed ? Qt.rgba(1, 1, 1, 0.22) : (readAllHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06))
                    
                    Text {
                        anchors.centerIn: parent
                        text: "已读"
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

                // 🚀【核心修复 4】：一键清空彻底摆脱失效死锁，即时响应
                Rectangle {
                    width: 48; height: 20; radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: notifPageRoot.totalCount > 0
                    color: clearTap.pressed ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.4) : (clearHover.hovered ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.25) : Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.12))
                    border.color: clearHover.hovered ? Theme.danger : Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.4)
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 2
                        Text { text: "✕"; color: Theme.danger; font.pixelSize: 8; font.weight: Font.Black }
                        Text { text: "清空"; color: clearHover.hovered ? "white" : Theme.danger; font.pixelSize: 9; font.weight: Font.Bold; font.family: notifPageRoot.chosenFont }
                    }

                    HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: clearTap
                        onTapped: if (notifPageRoot.notifModel) notifPageRoot.notifModel.clearAll()
                    }
                }
            }
        }

        // =====================================================================
        // 2. 消息流列表 / 高质感空状态
        // =====================================================================
        Item {
            width: parent.width
            height: parent.height - 34

            // 🚀 空状态居中黑晶看板，杜绝任何杂字干扰
            Item {
                anchors.fill: parent
                visible: notifPageRoot.totalCount === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: notifPageRoot.isDnd ? "🌙 勿扰模式运行中" : "🎉 暂无归档消息"
                        color: "white"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        font.family: notifPageRoot.chosenFont
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: notifPageRoot.isDnd ? "所有消息将在此静默归档，不会弹出灵动岛横幅打扰" : "收到的 Teams 与系统通知将自动在此保存"
                        color: Theme.textMuted
                        font.pixelSize: 11
                        font.family: notifPageRoot.chosenFont
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            ListView {
                id: notifListView
                anchors.fill: parent
                clip: true
                spacing: 6
                model: notifPageRoot.notifModel
                visible: notifPageRoot.totalCount > 0

                ScrollBar.vertical: ScrollBar {
                    width: 4
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 2; color: Theme.borderSubtle }
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
                                color: "white"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                visible: !itemAvatar.visible
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
}