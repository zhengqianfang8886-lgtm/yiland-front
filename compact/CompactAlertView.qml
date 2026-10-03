import QtQuick

Item {
    id: alertRoot
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right

    // 🚀 核心修复 1：安全留白，彻底避开胶囊的圆角与 3px 描边切边
    anchors.leftMargin: 10
    anchors.rightMargin: 12

    property string chosenFont: ""
    property string alertTitle: ""
    property string alertSubtitle: ""
    property string alertAvatar: ""
    property color alertThemeColor: Theme.notification

    // 动态内容宽度（头像 34 + 间距 9 + 文字实际宽度）
    readonly property int implicitContentWidth: 34 + 9 + Math.max(alertTitleText.implicitWidth, alertSubText.implicitWidth)

    // 1. 头像区（34×34 完美正圆，绝不穿帮切角）
    Item {
        id: avatarItem
        width: 34
        height: 34
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            radius: 17
            color: avatarImg.visible ? "transparent" : "#4F46E5"
            clip: true

            Image {
                id: avatarImg
                anchors.fill: parent
                source: (alertRoot.alertAvatar && alertRoot.alertAvatar.length > 5) ? alertRoot.alertAvatar : ""
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                sourceSize.width: 68
                sourceSize.height: 68
                asynchronous: true
                cache: true
            }

            Text {
                anchors.centerIn: parent
                text: {
                    if (avatarImg.visible) return ""
                    if (alertRoot.alertTitle) {
                        var parts = alertRoot.alertTitle.trim().split(" ")
                        return (parts.length >= 2) ? (parts[0][0] + parts[1][0]).toUpperCase() : alertRoot.alertTitle.trim().charAt(0).toUpperCase()
                    }
                    return "💬"
                }
                color: "white"
                font.family: alertRoot.chosenFont
                font.pixelSize: 13
                font.weight: Font.Black
                visible: !avatarImg.visible
            }
        }

        // 精致微光描边
        Rectangle {
            anchors.fill: parent
            radius: 17
            color: "transparent"
            border.color: Qt.rgba(alertRoot.alertThemeColor.r, alertRoot.alertThemeColor.g, alertRoot.alertThemeColor.b, 0.45)
            border.width: 1
        }
    }

    // 2. 文字信息区（标题与内容清晰排版）
    Column {
        anchors.left: avatarItem.right
        anchors.leftMargin: 9
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            id: alertTitleText
            text: alertRoot.alertTitle
            color: "white"
            font.family: alertRoot.chosenFont
            font.pixelSize: 13
            font.weight: Font.Black
            elide: Text.ElideRight
            width: parent.width
        }

        Text {
            id: alertSubText
            text: alertRoot.alertSubtitle
            color: Qt.rgba(1, 1, 1, 0.75)
            font.family: alertRoot.chosenFont
            font.pixelSize: 11
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            width: parent.width
        }
    }
}