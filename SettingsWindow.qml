import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: settingsWin
    title: "Alcove Island 偏好设置"
    width: 400
    height: 720
    minimumWidth: 400
    minimumHeight: 600
    color: "#18181b"
    flags: Qt.Dialog | Qt.WindowCloseButtonHint

    property bool fontPickerOpen: false
    property string fontSearchText: ""

    // 动态搜索过滤系统字体库
    readonly property var filteredFonts: {
        if (typeof Config === "undefined" || !Config.systemFonts) return ["系统默认 (Default)"]
        var list = Config.systemFonts
        var kw = fontSearchText.trim().toLowerCase()
        if (!kw) return list
        return list.filter(function(name) {
            return name.toLowerCase().indexOf(kw) !== -1
        })
    }

    Flickable {
        id: mainScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: settingsCol.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: vbar
            width: 4
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                radius: 2
                color: vbar.pressed ? "#818cf8" : Qt.rgba(1, 1, 1, 0.25)
            }
        }

        Column {
            id: settingsCol
            width: parent.width - 40
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 12

            Text {
                text: "⚙️ 灵动岛模块与偏好设置"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }

            // ==========================================
            // 分组 0：字体样式与排版
            // ==========================================
            Rectangle {
                width: parent.width
                height: settingsWin.fontPickerOpen ? 260 : 78
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: settingsWin.fontPickerOpen ? "#818cf8" : Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 24

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Text { text: "🔤"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "字体样式"; color: "#818cf8"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: currentFontLabel.implicitWidth + 24
                            height: 24
                            radius: 12
                            color: fontBtnArea.containsMouse ? Qt.rgba(129, 140, 248, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: settingsWin.fontPickerOpen ? "#818cf8" : Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    id: currentFontLabel
                                    text: (typeof Config !== "undefined" && Config.fontFamily) ? Config.fontFamily : "系统默认"
                                    color: "white"
                                    font.pixelSize: 10
                                    font.bold: true
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                }
                                Text {
                                    text: settingsWin.fontPickerOpen ? "▲" : "▼"
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    font.pixelSize: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: fontBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsWin.fontPickerOpen = !settingsWin.fontPickerOpen
                            }
                        }
                    }

                    Text {
                        text: "预览: 12:34:56 PM · 专注工作 · Alcove Island"
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 11
                        font.family: (typeof Config !== "undefined" && Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) ? Config.fontFamily : ""
                        visible: !settingsWin.fontPickerOpen
                    }

                    Column {
                        width: parent.width
                        height: 200
                        spacing: 6
                        visible: settingsWin.fontPickerOpen

                        Rectangle {
                            width: parent.width
                            height: 26
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                spacing: 6

                                Text { text: "🔍"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }

                                TextInput {
                                    id: fontInput
                                    width: parent.width - 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "white"
                                    font.pixelSize: 11
                                    text: settingsWin.fontSearchText
                                    onTextChanged: settingsWin.fontSearchText = text

                                    Text {
                                        text: "搜索系统字体名称 (如 Mono, Fira, Inter)..."
                                        color: Qt.rgba(1, 1, 1, 0.35)
                                        font.pixelSize: 11
                                        visible: !fontInput.text
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        ListView {
                            id: fontListView
                            width: parent.width
                            height: parent.height - 32
                            clip: true
                            spacing: 2
                            model: settingsWin.filteredFonts

                            ScrollBar.vertical: ScrollBar {
                                width: 3
                                policy: ScrollBar.AsNeeded
                                contentItem: Rectangle { radius: 1.5; color: Qt.rgba(1, 1, 1, 0.3) }
                            }

                            delegate: Rectangle {
                                width: fontListView.width - 6
                                height: 32
                                radius: 6
                                readonly property bool isSelected: (typeof Config !== "undefined") && (Config.fontFamily === modelData)
                                color: isSelected ? Qt.rgba(129, 140, 248, 0.22) : (fontItemHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                border.color: isSelected ? "#818cf8" : "transparent"
                                border.width: 1

                                HoverHandler { id: fontItemHover }

                                // 左右分离锚点，彻底移除无效的 Layout.fillWidth
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.right: checkMark.left
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10

                                    Text {
                                        text: modelData
                                        color: isSelected ? "white" : Qt.rgba(1, 1, 1, 0.8)
                                        font.pixelSize: 11
                                        font.bold: isSelected
                                        width: 130
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "12:34 灵动岛"
                                        color: isSelected ? "#a5b4fc" : Qt.rgba(1, 1, 1, 0.4)
                                        font.pixelSize: 11
                                        font.family: (modelData.indexOf("系统默认") === -1) ? modelData : ""
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Text {
                                    id: checkMark
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "✓"
                                    color: "#818cf8"
                                    font.pixelSize: 12
                                    font.bold: true
                                    visible: isSelected
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (typeof Config !== "undefined") {
                                            Config.fontFamily = modelData
                                        }
                                        settingsWin.fontPickerOpen = false
                                        settingsWin.fontSearchText = ""
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 分组 1：多副岛排布方向与副岛间距控制
            // ==========================================
            Rectangle {
                width: parent.width
                height: 136
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(129, 140, 248, 0.3)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            text: "多副岛扩展方向"
                            color: "#818cf8"
                            font.pixelSize: 12
                            font.bold: true
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: (typeof Config !== "undefined" && Config.multiIslandExpandDirection === "left") ? "当前：向左延伸" : "当前：向右延伸"
                            color: Qt.rgba(1, 1, 1, 0.45)
                            font.pixelSize: 10
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 26
                        radius: 13
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Row {
                            anchors.fill: parent
                            Rectangle {
                                width: parent.width / 2; height: parent.height; radius: 13
                                color: (typeof Config !== "undefined" && Config.multiIslandExpandDirection === "left") ? Qt.rgba(129, 140, 248, 0.25) : "transparent"
                                border.color: (typeof Config !== "undefined" && Config.multiIslandExpandDirection === "left") ? "#818cf8" : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "⬅️ 优先向左扩展"
                                    color: (typeof Config !== "undefined" && Config.multiIslandExpandDirection === "left") ? "white" : Qt.rgba(1, 1, 1, 0.5)
                                    font.pixelSize: 10; font.weight: Font.Bold
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (typeof Config !== "undefined") Config.multiIslandExpandDirection = "left"
                                }
                            }

                            Rectangle {
                                width: parent.width / 2; height: parent.height; radius: 13
                                color: (typeof Config !== "undefined" && Config.multiIslandExpandDirection !== "left") ? Qt.rgba(129, 140, 248, 0.25) : "transparent"
                                border.color: (typeof Config !== "undefined" && Config.multiIslandExpandDirection !== "left") ? "#818cf8" : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "➡️ 优先向右扩展"
                                    color: (typeof Config !== "undefined" && Config.multiIslandExpandDirection !== "left") ? "white" : Qt.rgba(1, 1, 1, 0.5)
                                    font.pixelSize: 10; font.weight: Font.Bold
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (typeof Config !== "undefined") Config.multiIslandExpandDirection = "right"
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            text: "主副岛呼吸间距"
                            color: "#818cf8"
                            font.pixelSize: 12
                            font.bold: true
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: ((typeof Config !== "undefined" && Config.splitGap !== undefined) ? Config.splitGap : 8) + " px"
                            color: "#38bdf8"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.family: "Monospace"
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Slider {
                        id: gapSlider
                        width: parent.width
                        height: 22
                        from: 2
                        to: 24
                        stepSize: 1
                        value: (typeof Config !== "undefined" && Config.splitGap !== undefined) ? Config.splitGap : 8
                        onMoved: if (typeof Config !== "undefined") Config.splitGap = Math.round(value)

                        background: Rectangle {
                            x: gapSlider.leftPadding
                            y: gapSlider.topPadding + gapSlider.availableHeight / 2 - height / 2
                            width: gapSlider.availableWidth
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.12)

                            Rectangle {
                                width: gapSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: "#818cf8"
                            }
                        }

                        handle: Rectangle {
                            x: gapSlider.leftPadding + gapSlider.visualPosition * (gapSlider.availableWidth - width)
                            y: gapSlider.topPadding + gapSlider.availableHeight / 2 - height / 2
                            width: 16
                            height: 16
                            radius: 8
                            color: gapSlider.pressed ? "#a5b4fc" : "#818cf8"
                            border.color: "#ffffff"
                            border.width: 1.5
                        }
                    }
                }
            }

            // ==========================================
            // 分组 2：胶囊常态显示项
            // ==========================================
            Rectangle {
                width: parent.width
                height: 140
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.1)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 2

                    Text { text: "胶囊常态显示项"; color: "#38bdf8"; font.pixelSize: 12; font.bold: true }

                    Item {
                        width: parent.width; height: 32
                        Text { text: "显示实时网速 (↓↑)"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showNetSpeed !== undefined) ? Config.showNetSpeed : true
                            onToggled: if (typeof Config !== "undefined" && Config.showNetSpeed !== undefined) Config.showNetSpeed = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Text { text: "显示当前日期"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showDate !== undefined) ? Config.showDate : false
                            onToggled: if (typeof Config !== "undefined" && Config.showDate !== undefined) Config.showDate = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Text { text: "显示时间秒数"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showSeconds !== undefined) ? Config.showSeconds : false
                            onToggled: if (typeof Config !== "undefined" && Config.showSeconds !== undefined) Config.showSeconds = checked
                        }
                    }
                }
            }

            // ==========================================
            // 分组 3：展开大卡片模块
            // ==========================================
            Rectangle {
                width: parent.width
                height: 240
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.1)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 2

                    Text { text: "展开卡片模块 (Tab 栏)"; color: "#34d399"; font.pixelSize: 12; font.bold: true }

                    Item {
                        width: parent.width; height: 32
                        Text { text: "🎵 媒体卡片 (播放/播控)"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showMediaTab !== undefined) ? Config.showMediaTab : true
                            onToggled: if (typeof Config !== "undefined" && Config.showMediaTab !== undefined) Config.showMediaTab = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Text { text: "📅 日历卡片 (Bento 风格)"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showCalendarTab !== undefined) ? Config.showCalendarTab : true
                            onToggled: if (typeof Config !== "undefined" && Config.showCalendarTab !== undefined) Config.showCalendarTab = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Text { text: "🎧 蓝牙卡片 (设备/电量/连接)"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showBluetoothTab !== undefined) ? Config.showBluetoothTab : true
                            onToggled: if (typeof Config !== "undefined" && Config.showBluetoothTab !== undefined) Config.showBluetoothTab = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Text { text: "📶 实时网络详情面板"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showNetworkTab !== undefined) ? Config.showNetworkTab : true
                            onToggled: if (typeof Config !== "undefined" && Config.showNetworkTab !== undefined) Config.showNetworkTab = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Text { text: "🌍 世界时钟面板"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showClockTab !== undefined) ? Config.showClockTab : true
                            onToggled: if (typeof Config !== "undefined" && Config.showClockTab !== undefined) Config.showClockTab = checked
                        }
                    }
                }
            }

            Text {
                text: "💡 提示：间距与字体点击实时生效，自动写入本地配置。"
                color: Qt.rgba(1, 1, 1, 0.45)
                font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Item { height: 10 }
        }
    }
}