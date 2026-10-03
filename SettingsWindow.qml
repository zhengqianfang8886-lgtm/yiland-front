import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: settingsWin
    title: "Alcove Island 偏好设置"
    width: 420
    height: 880
    minimumWidth: 400
    minimumHeight: 600
    color: "#18181b"
    flags: Qt.Dialog | Qt.WindowCloseButtonHint

    property bool fontPickerOpen: false
    property string fontSearchText: ""

    function getIslandName(key) {
        if (key === "memory") return "💾 内存监控"
        if (key === "music") return "🎵 媒体音乐"
        if (key === "hardware") return "🔊 硬件控制"
        if (key === "timer") return "⏱️ 专注计时"
        if (key === "notification") return "💬 未读通知"
        return key
    }

    function moveIslandUp(side, index) {
        if (index <= 0) return
        var list = (side === "left" ? Config.subIslandsLeft : Config.subIslandsRight).slice()
        var temp = list[index]
        list[index] = list[index - 1]
        list[index - 1] = temp
        if (side === "left") Config.subIslandsLeft = list
        else Config.subIslandsRight = list
    }

    function moveIslandDown(side, index) {
        var list = (side === "left" ? Config.subIslandsLeft : Config.subIslandsRight).slice()
        if (index >= list.length - 1) return
        var temp = list[index]
        list[index] = list[index + 1]
        list[index + 1] = temp
        if (side === "left") Config.subIslandsLeft = list
        else Config.subIslandsRight = list
    }

    function switchIslandSide(fromSide, index) {
        var left = (Config.subIslandsLeft || []).slice()
        var right = (Config.subIslandsRight || []).slice()
        if (fromSide === "left") {
            var item = left.splice(index, 1)[0]
            right.push(item)
        } else {
            var item = right.splice(index, 1)[0]
            left.push(item)
        }
        Config.subIslandsLeft = left
        Config.subIslandsRight = right
    }

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
            spacing: 14

            Text {
                text: "⚙️ 灵动岛模块与偏好设置"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }

            // ==========================================
            // 悬浮间距与手势灵敏度
            // ==========================================
            Rectangle {
                width: parent.width
                height: positionCol.implicitHeight + 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(56, 189, 248, 0.35)
                border.width: 1

                Column {
                    id: positionCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Row {
                        spacing: 6
                        Text { text: "📐"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "悬浮位置与手势灵敏度"; color: "#38bdf8"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // 1. 顶部下落距离滑块
                    Column {
                        width: parent.width
                        spacing: 4

                        Item {
                            width: parent.width; height: 16
                            Text { text: "顶部距离 (Top Margin)"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; anchors.left: parent.left }
                            Text {
                                text: ((typeof Config !== "undefined") ? Config.topMargin : 0) + " px"
                                color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Black; font.family: "Monospace"; anchors.right: parent.right
                            }
                        }

                        Slider {
                            id: topMarginSlider
                            width: parent.width; height: 22
                            from: 0; to: 40; stepSize: 1
                            value: (typeof Config !== "undefined") ? Config.topMargin : 0
                            onMoved: if (typeof Config !== "undefined") Config.topMargin = Math.round(value)

                            background: Rectangle {
                                x: topMarginSlider.leftPadding
                                y: topMarginSlider.topPadding + topMarginSlider.availableHeight / 2 - height / 2
                                width: topMarginSlider.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12)
                                Rectangle { width: topMarginSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#38bdf8" }
                            }
                            handle: Rectangle {
                                x: topMarginSlider.leftPadding + topMarginSlider.visualPosition * (topMarginSlider.availableWidth - width)
                                y: topMarginSlider.topPadding + topMarginSlider.availableHeight / 2 - height / 2
                                width: 14; height: 14; radius: 7; color: topMarginSlider.pressed ? "#7dd3fc" : "#38bdf8"; border.color: "#ffffff"; border.width: 1.5
                            }
                        }
                    }

                    // 2. 鼠标悬停展开延时滑块
                    Column {
                        width: parent.width
                        spacing: 4

                        Item {
                            width: parent.width; height: 16
                            Text { text: "鼠标悬停展开延时 (Dwell Time)"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; anchors.left: parent.left }
                            Text {
                                text: ((typeof Config !== "undefined") ? Config.hoverDwellTime : 240) + " ms"
                                color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Black; font.family: "Monospace"; anchors.right: parent.right
                            }
                        }

                        Slider {
                            id: dwellSlider
                            width: parent.width; height: 22
                            from: 80; to: 600; stepSize: 10
                            value: (typeof Config !== "undefined") ? Config.hoverDwellTime : 240
                            onMoved: if (typeof Config !== "undefined") Config.hoverDwellTime = Math.round(value)

                            background: Rectangle {
                                x: dwellSlider.leftPadding
                                y: dwellSlider.topPadding + dwellSlider.availableHeight / 2 - height / 2
                                width: dwellSlider.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12)
                                Rectangle { width: dwellSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#38bdf8" }
                            }
                            handle: Rectangle {
                                x: dwellSlider.leftPadding + dwellSlider.visualPosition * (dwellSlider.availableWidth - width)
                                y: dwellSlider.topPadding + dwellSlider.availableHeight / 2 - height / 2
                                width: 14; height: 14; radius: 7; color: dwellSlider.pressed ? "#7dd3fc" : "#38bdf8"; border.color: "#ffffff"; border.width: 1.5
                            }
                        }
                    }

                    // 3. 🚀 主胶囊右键隐藏时长滑块
                    Column {
                        width: parent.width
                        spacing: 6

                        Item {
                            width: parent.width; height: 16
                            Text { text: "主胶囊右键隐藏时长 (Auto-hide)"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; anchors.left: parent.left }
                            Text {
                                text: ((typeof Config !== "undefined" && Config.autoHideDurationSeconds !== undefined) ? Config.autoHideDurationSeconds : 5) + " 秒"
                                color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Black; font.family: "Monospace"; anchors.right: parent.right
                            }
                        }

                        Slider {
                            id: autoHideSlider
                            width: parent.width; height: 22
                            from: 1; to: 30; stepSize: 1
                            value: (typeof Config !== "undefined" && Config.autoHideDurationSeconds !== undefined) ? Config.autoHideDurationSeconds : 5
                            onMoved: if (typeof Config !== "undefined") Config.autoHideDurationSeconds = Math.round(value)

                            background: Rectangle {
                                x: autoHideSlider.leftPadding
                                y: autoHideSlider.topPadding + autoHideSlider.availableHeight / 2 - height / 2
                                width: autoHideSlider.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12)
                                Rectangle { width: autoHideSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#38bdf8" }
                            }
                            handle: Rectangle {
                                x: autoHideSlider.leftPadding + autoHideSlider.visualPosition * (autoHideSlider.availableWidth - width)
                                y: autoHideSlider.topPadding + autoHideSlider.availableHeight / 2 - height / 2
                                width: 14; height: 14; radius: 7; color: autoHideSlider.pressed ? "#7dd3fc" : "#38bdf8"; border.color: "#ffffff"; border.width: 1.5
                            }
                        }

                        Row {
                            spacing: 6
                            Repeater {
                                model: [3, 5, 10, 15]
                                Rectangle {
                                    width: 44; height: 20; radius: 10
                                    readonly property bool isSel: (typeof Config !== "undefined" && Config.autoHideDurationSeconds === modelData)
                                    color: isSel ? Qt.rgba(56, 189, 248, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                                    border.color: isSel ? "#38bdf8" : "transparent"
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData + "s"
                                        color: parent.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5)
                                        font.pixelSize: 10; font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (typeof Config !== "undefined") Config.autoHideDurationSeconds = modelData
                                    }
                                }
                            }
                        }

                        Text {
                            text: "💡 右键点击主胶囊可立即让全岛系统淡出（完全穿透底层），到达秒数后自动复原，轻触屏幕顶边缘也可随时提前呼醒。"
                            color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 9
                        }
                    }
                }
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
            // 分组 0.5：动效物理质感
            // ==========================================
            Rectangle {
                width: parent.width
                height: 96
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.3)
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Item {
                        width: parent.width; height: 16
                        Text { text: "🎭 灵动岛收放物理动效"; color: Theme.workspace; font.pixelSize: 12; font.bold: true; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: (typeof Config !== "undefined" && Config.animStyle === "jelly") ? "有机果冻流" : "精密克制流"
                            color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 10; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Row {
                            anchors.fill: parent

                            Rectangle {
                                id: precBtn
                                width: parent.width / 2; height: parent.height; radius: 14
                                readonly property bool isSel: (typeof Config !== "undefined" && Config.animStyle !== "jelly")
                                color: precBtn.isSel ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.28) : "transparent"
                                border.color: precBtn.isSel ? Theme.workspace : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.centerIn: parent; spacing: 4
                                    Text { text: "🎯"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        text: "精密克制 (阻尼沉稳)"
                                        color: precBtn.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5)
                                        font.pixelSize: 10; font.weight: Font.Bold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (typeof Config !== "undefined") Config.animStyle = "precision"
                                }
                            }

                            Rectangle {
                                id: jellyBtn
                                width: parent.width / 2; height: parent.height; radius: 14
                                readonly property bool isSel: (typeof Config !== "undefined" && Config.animStyle === "jelly")
                                color: jellyBtn.isSel ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.28) : "transparent"
                                border.color: jellyBtn.isSel ? Theme.workspace : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.centerIn: parent; spacing: 4
                                    Text { text: "🍮"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                    Text {
                                        text: "有机果冻 (流体相位)"
                                        color: jellyBtn.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5)
                                        font.pixelSize: 10; font.weight: Font.Bold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (typeof Config !== "undefined") Config.animStyle = "jelly"
                                }
                            }
                        }
                    }

                    Text {
                        text: (typeof Config !== "undefined" && Config.animStyle === "jelly") ?
                              "✨ 高度先行下冲，宽度滞后 32ms 舒展，带丰满回弹。" :
                              "✨ 极微弱超临界阻尼，单次微沉降，适合专注工作。"
                        color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // ==========================================
            // 分组 1：副岛排列、位置顺序与呼吸间距控制
            // ==========================================
            Rectangle {
                width: parent.width
                height: dockSettingsCol.implicitHeight + 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(129, 140, 248, 0.3)
                border.width: 1

                Column {
                    id: dockSettingsCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Row {
                        spacing: 6
                        Text { text: "🧩"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "副岛排列与间距控制"; color: "#818cf8"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // 左侧副岛列表
                    Rectangle {
                        width: parent.width; height: leftIslandCol.implicitHeight + 16
                        radius: 8; color: Qt.rgba(1, 1, 1, 0.04)
                        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                        Column {
                            id: leftIslandCol
                            anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "⬅️ 左侧小岛 (胶囊左侧排布)"; color: "#38bdf8"; font.pixelSize: 10; font.bold: true }

                            Repeater {
                                model: Config.subIslandsLeft || []
                                Rectangle {
                                    width: parent.width; height: 28; radius: 6
                                    color: Qt.rgba(1, 1, 1, 0.06)

                                    Text {
                                        anchors.left: parent.left; anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: settingsWin.getIslandName(modelData)
                                        color: "white"; font.pixelSize: 11; font.bold: true
                                    }

                                    Row {
                                        anchors.right: parent.right; anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Rectangle {
                                            width: 22; height: 20; radius: 4
                                            color: index > 0 ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                            Text { anchors.centerIn: parent; text: "↑"; color: "white"; font.pixelSize: 11; opacity: index > 0 ? 1 : 0.2 }
                                            MouseArea { anchors.fill: parent; enabled: index > 0; cursorShape: Qt.PointingHandCursor; onClicked: settingsWin.moveIslandUp("left", index) }
                                        }

                                        Rectangle {
                                            width: 22; height: 20; radius: 4
                                            color: index < (Config.subIslandsLeft.length - 1) ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                            Text { anchors.centerIn: parent; text: "↓"; color: "white"; font.pixelSize: 11; opacity: index < (Config.subIslandsLeft.length - 1) ? 1 : 0.2 }
                                            MouseArea { anchors.fill: parent; enabled: index < (Config.subIslandsLeft.length - 1); cursorShape: Qt.PointingHandCursor; onClicked: settingsWin.moveIslandDown("left", index) }
                                        }

                                        Rectangle {
                                            width: 32; height: 20; radius: 4
                                            color: Qt.rgba(56, 189, 248, 0.2)
                                            Text { anchors.centerIn: parent; text: "⇄ 右"; color: "#38bdf8"; font.pixelSize: 9; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsWin.switchIslandSide("left", index) }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 右侧副岛列表
                    Rectangle {
                        width: parent.width; height: rightIslandCol.implicitHeight + 16
                        radius: 8; color: Qt.rgba(1, 1, 1, 0.04)
                        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                        Column {
                            id: rightIslandCol
                            anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Text { text: "➡️ 右侧小岛 (胶囊右侧排布)"; color: "#34d399"; font.pixelSize: 10; font.bold: true }

                            Repeater {
                                model: Config.subIslandsRight || []
                                Rectangle {
                                    width: parent.width; height: 28; radius: 6
                                    color: Qt.rgba(1, 1, 1, 0.06)

                                    Text {
                                        anchors.left: parent.left; anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: settingsWin.getIslandName(modelData)
                                        color: "white"; font.pixelSize: 11; font.bold: true
                                    }

                                    Row {
                                        anchors.right: parent.right; anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Rectangle {
                                            width: 22; height: 20; radius: 4
                                            color: index > 0 ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                            Text { anchors.centerIn: parent; text: "↑"; color: "white"; font.pixelSize: 11; opacity: index > 0 ? 1 : 0.2 }
                                            MouseArea { anchors.fill: parent; enabled: index > 0; cursorShape: Qt.PointingHandCursor; onClicked: settingsWin.moveIslandUp("right", index) }
                                        }

                                        Rectangle {
                                            width: 22; height: 20; radius: 4
                                            color: index < (Config.subIslandsRight.length - 1) ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                            Text { anchors.centerIn: parent; text: "↓"; color: "white"; font.pixelSize: 11; opacity: index < (Config.subIslandsRight.length - 1) ? 1 : 0.2 }
                                            MouseArea { anchors.fill: parent; enabled: index < (Config.subIslandsRight.length - 1); cursorShape: Qt.PointingHandCursor; onClicked: settingsWin.moveIslandDown("right", index) }
                                        }

                                        Rectangle {
                                            width: 32; height: 20; radius: 4
                                            color: Qt.rgba(52, 211, 153, 0.2)
                                            Text { anchors.centerIn: parent; text: "左 ⇄"; color: "#34d399"; font.pixelSize: 9; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsWin.switchIslandSide("right", index) }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 主副岛呼吸间距设置滑块
                    Column {
                        width: parent.width
                        spacing: 6

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
            }

            // ==========================================
            // 分组 2：健康关怀与硬件监控
            // ==========================================
            Rectangle {
                id: healthCard
                width: parent.width
                height: healthSettingsCol.implicitHeight + 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(52, 211, 153, 0.3)
                border.width: 1

                Column {
                    id: healthSettingsCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: "🌿 健康关怀与硬件监控"; color: "#34d399"; font.pixelSize: 12; font.bold: true }

                    Item {
                        width: parent.width; height: 30
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Text { text: "💾"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "内存监控小岛 (RAM %)"; color: "white"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showMemoryBubble !== undefined) ? Config.showMemoryBubble : true
                            onToggled: if (typeof Config !== "undefined") Config.showMemoryBubble = checked
                        }
                    }

                    Row {
                        width: parent.width
                        height: 26
                        spacing: 6
                        visible: (typeof Config !== "undefined" && Config.showMemoryBubble !== false)

                        Text {
                            text: "弹出阈值:"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 11; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                            model: [
                                { label: "常驻", val: 0 },
                                { label: "60%", val: 60 },
                                { label: "70%", val: 70 },
                                { label: "75%", val: 75 },
                                { label: "80%", val: 80 },
                                { label: "85%", val: 85 }
                            ]
                            Rectangle {
                                width: 44; height: 22; radius: 11
                                readonly property bool isSel: (typeof Config !== "undefined" && Config.memoryThreshold === modelData.val)
                                color: isSel ? Qt.rgba(52, 211, 153, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: isSel ? "#34d399" : "transparent"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: parent.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5)
                                    font.pixelSize: 10; font.weight: Font.Bold
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (typeof Config !== "undefined") Config.memoryThreshold = modelData.val
                                }
                            }
                        }
                    }

                    Item { height: 2 }

                    Item {
                        width: parent.width; height: 30
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Text { text: "🧘"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "久坐伏案提醒 (特大打断弹窗)"; color: "white"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.sedentaryReminderEnabled !== undefined) ? Config.sedentaryReminderEnabled : true
                            onToggled: if (typeof Config !== "undefined") Config.sedentaryReminderEnabled = checked
                        }
                    }

                    Row {
                        width: parent.width
                        height: 26
                        spacing: 8
                        visible: (typeof Config !== "undefined" && Config.sedentaryReminderEnabled !== false)

                        Text {
                            text: "提醒周期:"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 11; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Repeater {
                            model: [30, 45, 60]
                            Rectangle {
                                width: 54; height: 24; radius: 12
                                readonly property bool isSel: (typeof Config !== "undefined" && Config.sedentaryIntervalMinutes === modelData)
                                color: isSel ? Qt.rgba(52, 211, 153, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: isSel ? "#34d399" : "transparent"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "m"
                                    color: parent.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5)
                                    font.pixelSize: 10; font.weight: Font.Bold
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (typeof Config !== "undefined") Config.sedentaryIntervalMinutes = modelData
                                }
                            }
                        }
                    }

                    Item { height: 4 }

                    // 滚轮音量调节步长配置
                    Column {
                        width: parent.width
                        spacing: 6

                        Item {
                            width: parent.width; height: 16
                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                                Text { text: "🔊"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "滚轮音量调节步长"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text {
                                text: ((typeof Config !== "undefined" && Config.volumeStep !== undefined) ? Config.volumeStep : 5) + " %"
                                color: "#34d399"; font.pixelSize: 11; font.weight: Font.Black; font.family: "Monospace"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Slider {
                            id: volumeStepSlider
                            width: parent.width; height: 22
                            from: 1; to: 20; stepSize: 1
                            value: (typeof Config !== "undefined" && Config.volumeStep !== undefined) ? Config.volumeStep : 5
                            onMoved: if (typeof Config !== "undefined") Config.volumeStep = Math.round(value)

                            background: Rectangle {
                                x: volumeStepSlider.leftPadding
                                y: volumeStepSlider.topPadding + volumeStepSlider.availableHeight / 2 - height / 2
                                width: volumeStepSlider.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12)
                                Rectangle { width: volumeStepSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#34d399" }
                            }
                            handle: Rectangle {
                                x: volumeStepSlider.leftPadding + volumeStepSlider.visualPosition * (volumeStepSlider.availableWidth - width)
                                y: volumeStepSlider.topPadding + volumeStepSlider.availableHeight / 2 - height / 2
                                width: 14; height: 14; radius: 7; color: volumeStepSlider.pressed ? "#6ee7b7" : "#34d399"; border.color: "#ffffff"; border.width: 1.5
                            }
                        }

                        Row {
                            spacing: 6
                            Repeater {
                                model: [1, 2, 5, 10]
                                Rectangle {
                                    width: 44; height: 20; radius: 10
                                    readonly property bool isSel: (typeof Config !== "undefined" && Config.volumeStep === modelData)
                                    color: isSel ? Qt.rgba(52, 211, 153, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                                    border.color: isSel ? "#34d399" : "transparent"
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData + "%"
                                        color: parent.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5)
                                        font.pixelSize: 10; font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (typeof Config !== "undefined") Config.volumeStep = modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 分组 3：胶囊常态显示项
            // ==========================================
            Rectangle {
                width: parent.width
                height: 172
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
                        Text { text: "使用 24 小时制时间格式"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.timeFormat === "24h")
                            onToggled: if (typeof Config !== "undefined") Config.timeFormat = checked ? "24h" : "12h"
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Text { text: "显示实时网速 (↓↑)"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showNetSpeed !== undefined) ? Config.showNetSpeed : true
                            onToggled: if (typeof Config !== "undefined") Config.showNetSpeed = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Text { text: "显示当前日期"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showDate !== undefined) ? Config.showDate : false
                            onToggled: if (typeof Config !== "undefined") Config.showDate = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Text { text: "显示时间秒数"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showSeconds !== undefined) ? Config.showSeconds : false
                            onToggled: if (typeof Config !== "undefined") Config.showSeconds = checked
                        }
                    }
                }
            }

            // ==========================================
            // 分组 4：独立界面直达开关
            // ==========================================
            Rectangle {
                width: parent.width
                height: tabSwitchesCol.implicitHeight + 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.1)

                Column {
                    id: tabSwitchesCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 2

                    Text { text: "独立界面管理 (点条轨道直达项)"; color: "#34d399"; font.pixelSize: 12; font.bold: true }

                    Item {
                        width: parent.width; height: 32
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Rectangle { width: 4; height: 12; radius: 2; color: Theme.workspace; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "⊞ 桌面工作区 (多桌面切页)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showWorkspaceTab !== undefined) ? Config.showWorkspaceTab : true
                            onToggled: if (typeof Config !== "undefined") Config.showWorkspaceTab = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Rectangle { width: 4; height: 12; radius: 2; color: Theme.media; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "🎵 媒体播放器 (播放与播控)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showMediaTab !== undefined) ? Config.showMediaTab : true
                            onToggled: if (typeof Config !== "undefined") Config.showMediaTab = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Rectangle { width: 4; height: 12; radius: 2; color: Theme.calendar; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "📅 本地日历 (Bento 风格)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showCalendarTab !== undefined) ? Config.showCalendarTab : true
                            onToggled: if (typeof Config !== "undefined") Config.showCalendarTab = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Rectangle { width: 4; height: 12; radius: 2; color: Theme.timer; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "⏱️ 专注计时与秒表 (独立直达)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showTimerTab !== undefined) ? Config.showTimerTab : true
                            onToggled: if (typeof Config !== "undefined") Config.showTimerTab = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Rectangle { width: 4; height: 12; radius: 2; color: Theme.clock; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "🌍 世界时钟 (跨时区换算)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showClockTab !== undefined) ? Config.showClockTab : true
                            onToggled: if (typeof Config !== "undefined") Config.showClockTab = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Rectangle { width: 4; height: 12; radius: 2; color: Theme.network; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "📶 实时网络监控 (上下行与IP)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showNetworkTab !== undefined) ? Config.showNetworkTab : true
                            onToggled: if (typeof Config !== "undefined") Config.showNetworkTab = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Rectangle { width: 4; height: 12; radius: 2; color: Theme.bluetooth; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "🎧 蓝牙外设管理 (电量与连接)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showBluetoothTab !== undefined) ? Config.showBluetoothTab : true
                            onToggled: if (typeof Config !== "undefined") Config.showBluetoothTab = checked
                        }
                    }

                    Item {
                        width: parent.width; height: 32
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Rectangle { width: 4; height: 12; radius: 2; color: Theme.notification; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "💬 消息归档中心 (未读与历史)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Switch {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            checked: (typeof Config !== "undefined" && Config.showNotificationTab !== undefined) ? Config.showNotificationTab : true
                            onToggled: if (typeof Config !== "undefined") Config.showNotificationTab = checked
                        }
                    }
                }
            }

            Text {
                text: "💡 提示：所有配置点击即刻生效，并在灵动岛顶部自动增减微药丸指示点。"
                color: Qt.rgba(1, 1, 1, 0.45)
                font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Item { height: 10 }
        }
    }
}