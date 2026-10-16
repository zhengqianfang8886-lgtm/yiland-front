// ==========================================
// 📄 File: settings/SettingsFontCard.qml
// ==========================================
import QtQuick
import QtQuick.Controls

Rectangle {
    id: cardRoot
    height: fontPickerOpen ? 260 : 78
    radius: 12
    color: Qt.rgba(1, 1, 1, 0.05)
    border.color: fontPickerOpen ? "#818cf8" : Qt.rgba(1, 1, 1, 0.1)
    border.width: 1

    property bool fontPickerOpen: false
    property string fontSearchText: ""

    readonly property var filteredFonts: {
        if (typeof Config === "undefined" || !Config.systemFonts) return ["系统默认 (Default)"]
        var list = Config.systemFonts
        var kw = fontSearchText.trim().toLowerCase()
        if (!kw) return list
        return list.filter(function(name) {
            return name.toLowerCase().indexOf(kw) !== -1
        })
    }

    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Item {
            width: parent.width; height: 24

            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Text { text: "🔤"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "字体样式"; color: "#818cf8"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: currentFontLabel.implicitWidth + 24
                height: 24
                radius: 12
                color: fontBtnArea.containsMouse ? Qt.rgba(129, 140, 248, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                border.color: cardRoot.fontPickerOpen ? "#818cf8" : Qt.rgba(1, 1, 1, 0.15)
                border.width: 1

                Row {
                    anchors.centerIn: parent; spacing: 4
                    Text {
                        id: currentFontLabel
                        text: (typeof Config !== "undefined" && Config.fontFamily) ? Config.fontFamily : "系统默认"
                        color: "white"; font.pixelSize: 10; font.bold: true
                        elide: Text.ElideMiddle; maximumLineCount: 1
                    }
                    Text {
                        text: cardRoot.fontPickerOpen ? "▲" : "▼"
                        color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: fontBtnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: cardRoot.fontPickerOpen = !cardRoot.fontPickerOpen
                }
            }
        }

        Text {
            text: "预览: 12:34:56 PM · 专注工作 · Alcove Island"
            color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 11
            font.family: (typeof Config !== "undefined" && Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) ? Config.fontFamily : ""
            visible: !cardRoot.fontPickerOpen
        }

        Column {
            width: parent.width; height: 200; spacing: 6
            visible: cardRoot.fontPickerOpen

            Rectangle {
                width: parent.width; height: 26; radius: 6; color: Qt.rgba(1, 1, 1, 0.08)

                Row {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                    Text { text: "🔍"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }

                    TextInput {
                        id: fontInput
                        width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter
                        color: "white"; font.pixelSize: 11
                        text: cardRoot.fontSearchText
                        onTextChanged: cardRoot.fontSearchText = text

                        Text {
                            text: "搜索系统字体 (如 Mono, Fira, Inter)..."
                            color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 11
                            visible: !fontInput.text; anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            ListView {
                id: fontListView
                width: parent.width; height: parent.height - 32; clip: true; spacing: 2
                model: cardRoot.filteredFonts

                ScrollBar.vertical: ScrollBar {
                    width: 3; policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 1.5; color: Qt.rgba(1, 1, 1, 0.3) }
                }

                delegate: Rectangle {
                    width: fontListView.width - 6; height: 32; radius: 6
                    readonly property bool isSelected: (typeof Config !== "undefined") && (Config.fontFamily === modelData)
                    color: isSelected ? Qt.rgba(129, 140, 248, 0.22) : (fontItemHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    border.color: isSelected ? "#818cf8" : "transparent"; border.width: 1

                    HoverHandler { id: fontItemHover }

                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 10
                        anchors.right: checkMark.left; anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter; spacing: 10

                        Text {
                            text: modelData; color: isSelected ? "white" : Qt.rgba(1, 1, 1, 0.8)
                            font.pixelSize: 11; font.bold: isSelected; width: 130; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "12:34 灵动岛"; color: isSelected ? "#a5b4fc" : Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 11
                            font.family: (modelData.indexOf("系统默认") === -1) ? modelData : ""; anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        id: checkMark; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                        text: "✓"; color: "#818cf8"; font.pixelSize: 12; font.bold: true; visible: isSelected
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof Config !== "undefined") Config.fontFamily = modelData
                            cardRoot.fontPickerOpen = false
                            cardRoot.fontSearchText = ""
                        }
                    }
                }
            }
        }
    }
}