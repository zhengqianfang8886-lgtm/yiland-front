// ==========================================
// 📄 File: AppManagerWindow.qml
// 🌟 独立的桌面应用管理与添加窗口 (对齐偏好设置)
// ==========================================
import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: appWinRoot
    title: "程序岛 · 应用程序管理"
    width: 440
    height: 600
    minimumWidth: 420
    minimumHeight: 520
    color: "#18181b"
    flags: Qt.Dialog | Qt.WindowCloseButtonHint

    property var systemAppsList: []
    property string searchKeyword: ""

    function reloadSystemApps() {
        if (typeof Bridge !== "undefined" && Bridge.getSystemInstalledApps) {
            appWinRoot.systemAppsList = Bridge.getSystemInstalledApps()
        }
    }

    Component.onCompleted: reloadSystemApps()

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onLocalAppFileSelected(path) {
            if (path) {
                var info = Bridge.parseDesktopFileInfo ? Bridge.parseDesktopFileInfo(path) : {}
                if (info && info.name) {
                    customNameInput.text = info.name
                    customCmdInput.text = info.exec || path
                    customIconInput.text = info.raw_icon || info.icon || ""
                } else {
                    customCmdInput.text = path
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            width: 4
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.25) }
        }

        Column {
            id: contentCol
            width: parent.width - 36
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 18
            spacing: 14

            // 标题
            Row {
                spacing: 8
                Text { text: "🚀"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "程序岛应用程序管理"; color: "white"; font.pixelSize: 16; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }

            // -----------------------------------------------------------------
            // 模块 1：从系统应用库直接一键点选导入
            // -----------------------------------------------------------------
            Rectangle {
                width: parent.width
                height: 230
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35)
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Row {
                        width: parent.width
                        Text { text: "📦 从系统已安装库快速添加"; color: "#38bdf8"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // 搜索框
                    Rectangle {
                        width: parent.width; height: 26; radius: 6
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Row {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 6
                            Text { text: "🔍"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            TextInput {
                                id: searchInput
                                width: parent.width - 24
                                anchors.verticalCenter: parent.verticalCenter
                                color: "white"; font.pixelSize: 11
                                text: appWinRoot.searchKeyword
                                onTextChanged: appWinRoot.searchKeyword = text.trim().toLowerCase()

                                Text {
                                    text: "搜索已安装应用 (如 Chrome, Code, 终端)..."
                                    color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 11
                                    visible: !searchInput.text
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // 应用列表
                    ListView {
                        id: sysListView
                        width: parent.width
                        height: parent.height - 72
                        clip: true
                        spacing: 4
                        model: {
                            if (!appWinRoot.searchKeyword) return appWinRoot.systemAppsList
                            return appWinRoot.systemAppsList.filter(function(item) {
                                return item.name.toLowerCase().indexOf(appWinRoot.searchKeyword) !== -1 ||
                                       item.exec.toLowerCase().indexOf(appWinRoot.searchKeyword) !== -1
                            })
                        }

                        delegate: Rectangle {
                            width: sysListView.width - 6
                            height: 32
                            radius: 6
                            color: itemHover.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.03)

                            HoverHandler { id: itemHover }

                            Row {
                                anchors.left: parent.left; anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Image {
                                    width: 20; height: 20
                                    source: modelData.icon || ""
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: status === Image.Ready
                                }

                                Text {
                                    text: modelData.name
                                    color: "white"; font.pixelSize: 11; font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle {
                                width: 52; height: 20; radius: 10
                                anchors.right: parent.right; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: addHover.hovered ? "#0284c7" : Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.25)
                                border.color: "#38bdf8"; border.width: 1

                                Text { anchors.centerIn: parent; text: "＋ 添加"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold }
                                HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        if (typeof Bridge !== "undefined" && Bridge.addAppManual) {
                                            Bridge.addAppManual(modelData.name, modelData.exec, modelData.raw_icon)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // 模块 2：手动自定义选填表单
            // -----------------------------------------------------------------
            Rectangle {
                width: parent.width
                height: 180
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: "✍️ 手动选填录入"; color: "white"; font.pixelSize: 12; font.bold: true }

                    // 名称
                    Rectangle {
                        width: parent.width; height: 28; radius: 6; color: Qt.rgba(1, 1, 1, 0.06)
                        Row {
                            anchors.fill: parent; anchors.margins: 6; spacing: 8
                            Text { text: "应用名称"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                            TextInput {
                                id: customNameInput
                                width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter
                                color: "white"; font.pixelSize: 11; selectByMouse: true
                                Text { text: "如: Google Chrome"; color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 10; visible: !customNameInput.text }
                            }
                        }
                    }

                    // 命令
                    Rectangle {
                        width: parent.width; height: 28; radius: 6; color: Qt.rgba(1, 1, 1, 0.06)
                        Row {
                            anchors.fill: parent; anchors.margins: 6; spacing: 8
                            Text { text: "执行命令"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                            TextInput {
                                id: customCmdInput
                                width: parent.width - 92; anchors.verticalCenter: parent.verticalCenter
                                color: "white"; font.pixelSize: 11; selectByMouse: true
                                Text { text: "可执行路径或命令..."; color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 10; visible: !customCmdInput.text }
                            }
                            Rectangle {
                                width: 22; height: 18; radius: 4
                                color: browseHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                                anchors.verticalCenter: parent.verticalCenter
                                Text { anchors.centerIn: parent; text: "📁"; font.pixelSize: 11 }
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

                    // 图标
                    Rectangle {
                        width: parent.width; height: 28; radius: 6; color: Qt.rgba(1, 1, 1, 0.06)
                        Row {
                            anchors.fill: parent; anchors.margins: 6; spacing: 8
                            Text { text: "图标标识"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                            TextInput {
                                id: customIconInput
                                width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter
                                color: "white"; font.pixelSize: 11; selectByMouse: true
                                Text { text: "系统图标名称或本地图片文件..."; color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 10; visible: !customIconInput.text }
                            }
                        }
                    }

                    Rectangle {
                        width: 100; height: 26; radius: 13
                        color: saveBtnHover.hovered ? "#0284c7" : "#0ea5e9"
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text { anchors.centerIn: parent; text: "✓ 保存并添加"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold }
                        HoverHandler { id: saveBtnHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                var n = customNameInput.text.trim()
                                var c = customCmdInput.text.trim()
                                var ic = customIconInput.text.trim()
                                if (!c) return
                                if (!n) n = c.split(" ")[0]
                                if (typeof Bridge !== "undefined" && Bridge.addAppManual) {
                                    Bridge.addAppManual(n, c, ic)
                                }
                                customNameInput.text = ""
                                customCmdInput.text = ""
                                customIconInput.text = ""
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // 模块 3：当前程序岛已收纳的应用管理
            // -----------------------------------------------------------------
            Rectangle {
                width: parent.width
                height: 140
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: "📋 当前程序岛已收录的应用"; color: "white"; font.pixelSize: 12; font.bold: true }

                    ListView {
                        id: addedListView
                        width: parent.width
                        height: parent.height - 30
                        clip: true
                        spacing: 4
                        model: (typeof Bridge !== "undefined") ? Bridge.appModel : null

                        delegate: Rectangle {
                            width: addedListView.width - 6
                            height: 28
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.03)

                            Row {
                                anchors.left: parent.left; anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Image {
                                    width: 18; height: 18
                                    source: model.icon || ""
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: status === Image.Ready
                                }

                                Text {
                                    text: model.name + " (" + model.execCmd + ")"
                                    color: "white"; font.pixelSize: 10
                                    elide: Text.ElideRight; width: 260
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Rectangle {
                                width: 22; height: 18; radius: 4
                                color: delHover.hovered ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.3) : "transparent"
                                anchors.right: parent.right; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter

                                Text { anchors.centerIn: parent; text: "✕"; color: "#ef4444"; font.pixelSize: 9; font.bold: true }
                                HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        if (typeof Bridge !== "undefined" && Bridge.deleteApp) {
                                            Bridge.deleteApp(model.appId)
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
}