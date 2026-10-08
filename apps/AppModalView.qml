// ==========================================
// 📄 File: apps/AppModalView.qml
// 🌟 类似设置风格的应用选填配置弹窗组件
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: modalRoot
    anchors.fill: parent
    anchors.margins: 12

    signal closeRequested()
    signal saveRequested(string name, string cmd, string icon)

    function resetAndFocus() {
        nameInput.text = ""
        cmdInput.text = ""
        iconInput.text = ""
        nameInput.forceActiveFocus()
    }

    function applySelectedInfo(name, cmd, icon) {
        if (name) nameInput.text = name
        if (cmd) cmdInput.text = cmd
        if (icon) iconInput.text = icon
    }

    Column {
        anchors.fill: parent
        spacing: 6

        // 顶栏操作区
        Item {
            width: parent.width
            height: 18

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text { text: "⚙️"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "添加应用程序"; color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Bold; font.family: Theme.activeFont }
            }

            Rectangle {
                width: 18; height: 18; radius: 9
                color: closeModalHover.hovered ? Qt.rgba(255, 255, 255, 0.16) : "transparent"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Text { anchors.centerIn: parent; text: "✕"; color: Qt.rgba(255, 255, 255, 0.6); font.pixelSize: 9; font.weight: Font.Bold }
                HoverHandler { id: closeModalHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: modalRoot.closeRequested() }
            }
        }

        // 快速导入按钮
        Rectangle {
            width: parent.width; height: 22; radius: 5
            color: quickPickHover.hovered ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.22) : Qt.rgba(255, 255, 255, 0.06)
            border.color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35); border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 4
                Text { text: "📦"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "从系统应用库选择导入 ▾"; color: "#38bdf8"; font.pixelSize: 9; font.weight: Font.Bold; font.family: Theme.activeFont }
            }

            HoverHandler { id: quickPickHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    if (typeof Bridge !== "undefined" && Bridge.openAddAppDialog) {
                        Bridge.openAddAppDialog()
                    }
                }
            }
        }

        // 选填表单
        Column {
            width: parent.width
            spacing: 5

            // 1. 应用名称
            Rectangle {
                width: parent.width; height: 26; radius: 5
                color: nameInput.activeFocus ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                border.color: nameInput.activeFocus ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.08); border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 6; anchors.rightMargin: 6
                    spacing: 4

                    Text { text: "名称"; color: Theme.textMuted; font.pixelSize: 9; font.weight: Font.Bold; font.family: Theme.activeFont; anchors.verticalCenter: parent.verticalCenter }

                    TextInput {
                        id: nameInput
                        width: parent.width - 32
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"; font.pixelSize: 10; font.family: Theme.activeFont
                        selectByMouse: true; clip: true

                        Text {
                            text: "如: 谷歌浏览器 / 终端..."
                            color: Qt.rgba(255, 255, 255, 0.25); font.pixelSize: 9; font.family: Theme.activeFont
                            visible: !nameInput.text && !nameInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // 2. 启动命令
            Rectangle {
                width: parent.width; height: 26; radius: 5
                color: cmdInput.activeFocus ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                border.color: cmdInput.activeFocus ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.08); border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 6; anchors.rightMargin: 4
                    spacing: 4

                    Text { text: "命令"; color: Theme.textMuted; font.pixelSize: 9; font.weight: Font.Bold; font.family: Theme.activeFont; anchors.verticalCenter: parent.verticalCenter }

                    TextInput {
                        id: cmdInput
                        width: parent.width - 56
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"; font.pixelSize: 10; font.family: Theme.displayMonoFont
                        selectByMouse: true; clip: true

                        Text {
                            text: "命令或可执行文件路径..."
                            color: Qt.rgba(255, 255, 255, 0.25); font.pixelSize: 9; font.family: Theme.activeFont
                            visible: !cmdInput.text && !cmdInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        width: 18; height: 18; radius: 3
                        color: browseHover.hovered ? Qt.rgba(255, 255, 255, 0.15) : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Text { anchors.centerIn: parent; text: "📁"; font.pixelSize: 10 }
                        HoverHandler { id: browseHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (typeof Bridge !== "undefined" && Bridge.selectLocalExecutableOrDesktop) {
                                    Bridge.selectLocalExecutableOrDesktop()
                                }
                            }
                        }
                    }
                }
            }

            // 3. 图标名称
            Rectangle {
                width: parent.width; height: 26; radius: 5
                color: iconInput.activeFocus ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.12) : Qt.rgba(255, 255, 255, 0.05)
                border.color: iconInput.activeFocus ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.08); border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 6; anchors.rightMargin: 6
                    spacing: 4

                    Text { text: "图标"; color: Theme.textMuted; font.pixelSize: 9; font.weight: Font.Bold; font.family: Theme.activeFont; anchors.verticalCenter: parent.verticalCenter }

                    TextInput {
                        id: iconInput
                        width: parent.width - 32
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"; font.pixelSize: 10; font.family: Theme.displayMonoFont
                        selectByMouse: true; clip: true

                        Text {
                            text: "系统图标名或本地图片..."
                            color: Qt.rgba(255, 255, 255, 0.25); font.pixelSize: 9; font.family: Theme.activeFont
                            visible: !iconInput.text && !iconInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // 底部保存/取消
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 2
            spacing: 8

            Rectangle {
                width: 44; height: 24; radius: 5
                color: cancelModalHover.hovered ? Qt.rgba(255, 255, 255, 0.1) : "transparent"
                Text { anchors.centerIn: parent; text: "取消"; color: Theme.textMuted; font.pixelSize: 10; font.family: Theme.activeFont }
                HoverHandler { id: cancelModalHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: modalRoot.closeRequested() }
            }

            Rectangle {
                width: 68; height: 24; radius: 12
                color: saveAppHover.hovered ? "#0284c7" : "#0ea5e9"
                scale: saveAppTap.pressed ? 0.94 : 1.0

                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    Text { text: "✓"; color: "white"; font.pixelSize: 9; font.weight: Font.Black }
                    Text { text: "保存"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: Theme.activeFont }
                }

                HoverHandler { id: saveAppHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: saveAppTap
                    onTapped: {
                        var n = nameInput.text.trim()
                        var c = cmdInput.text.trim()
                        var ic = iconInput.text.trim()
                        if (!n) n = c ? c.split(" ")[0] : "新应用"
                        if (!c) return
                        modalRoot.saveRequested(n, c, ic)
                    }
                }
            }
        }
    }
}