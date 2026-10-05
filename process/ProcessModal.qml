// ==========================================
// 📄 File: process/ProcessModal.qml (已修复布尔类型安全)
// ==========================================
import QtQuick

Row {
    id: modalRoot
    anchors.fill: parent
    spacing: 10

    property string effectiveFont: ""
    property string effectiveMono: ""

    property string editId: ""
    property string editStatus: "stopped"
    property int editPid: 0
    property string editIcon: ""

    // 🚀 安全布尔计算属性：杜绝任何 undefined 泄漏至 QML 属性系统
    readonly property bool hasCustomIcon: Boolean(modalRoot.editIcon && modalRoot.editIcon.trim().length > 0)
    readonly property bool isPreviewReady: Boolean(previewImg.status === Image.Ready && previewImg.source != "")

    signal saveRequested(string id, string name, string cwd, string cmd, string icon)
    signal deleteRequested(string id)
    signal cancelRequested()

    function getTechIcon(cmd, name) {
        var c = (cmd || "").toLowerCase()
        var n = (name || "").toLowerCase()
        if (c.indexOf("python") !== -1 || n.indexOf("py") !== -1) return "🐍"
        if (c.indexOf("cargo") !== -1 || c.indexOf("rust") !== -1 || c.indexOf("tauri") !== -1) return "🦀"
        if (c.indexOf("npm") !== -1 || c.indexOf("node") !== -1 || c.indexOf("vite") !== -1 || c.indexOf("yarn") !== -1) return "⬢"
        if (c.indexOf("docker") !== -1) return "🐳"
        if (c.indexOf("go ") !== -1) return "🐹"
        return "⚡"
    }

    function openAdd() {
        modalRoot.editId = ""
        modalRoot.editStatus = "stopped"
        modalRoot.editPid = 0
        modalRoot.editIcon = ""
        nameInput.text = ""
        cwdInput.text = "~"
        cmdInput.text = ""
        focusTimer.restart()
    }

    function openDetail(item) {
        modalRoot.editId = item.taskId || ""
        modalRoot.editStatus = item.status || "stopped"
        modalRoot.editPid = item.pid || 0
        modalRoot.editIcon = item.icon || ""
        nameInput.text = item.name || ""
        cwdInput.text = item.cwd || ""
        cmdInput.text = item.cmd || ""
        focusTimer.restart()
    }

    function submitForm() {
        var nameVal = nameInput.text.trim()
        var cwdVal = cwdInput.text.trim() || "~"
        var cmdVal = cmdInput.text.trim()
        if (!nameVal || !cmdVal) return
        modalRoot.saveRequested(modalRoot.editId, nameVal, cwdVal, cmdVal, modalRoot.editIcon)
    }

    Timer {
        id: focusTimer; interval: 60; repeat: false
        onTriggered: { nameInput.forceActiveFocus(); nameInput.selectAll() }
    }

    // 1. 左列：服务概览与【真实图片自选槽】
    Rectangle {
        width: 120
        height: parent.height
        radius: Theme.radiusCard
        color: "#18181f"
        border.color: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.3)
        border.width: 1
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            // 可交互的真实图片上传卡槽
            Rectangle {
                width: 44; height: 44; radius: 10
                color: modalRoot.editStatus === "running" ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                border.color: imgHover.hovered ? "#c084fc" : (modalRoot.editStatus === "running" ? "#10b981" : Qt.rgba(1, 1, 1, 0.15))
                border.width: imgHover.hovered ? 1.5 : 1
                anchors.horizontalCenter: parent.horizontalCenter
                clip: true

                Image {
                    id: previewImg
                    anchors.fill: parent
                    anchors.margins: 4
                    fillMode: Image.PreserveAspectFit
                    source: modalRoot.hasCustomIcon ? (modalRoot.editIcon.indexOf("://") !== -1 ? modalRoot.editIcon : "file://" + modalRoot.editIcon) : ""
                    visible: modalRoot.isPreviewReady
                    asynchronous: true
                }

                // 🚀【关键修复】：严格消除 undefined 求值，杜绝类型报错
                Text {
                    anchors.centerIn: parent
                    text: modalRoot.getTechIcon(cmdInput.text, nameInput.text)
                    font.pixelSize: 22
                    visible: !modalRoot.isPreviewReady
                }

                // 悬停换图提示
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.55)
                    visible: Boolean(imgHover.hovered)

                    Text {
                        anchors.centerIn: parent
                        text: "📷\n换图"
                        color: "white"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    id: imgHover
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof Bridge !== "undefined" && Bridge.selectLocalImageFile) {
                            var p = Bridge.selectLocalImageFile()
                            if (p && p.trim().length > 0) modalRoot.editIcon = p.trim()
                        }
                    }
                }
            }

            // 清除自定义图标按钮
            Rectangle {
                width: 68; height: 16; radius: 8
                color: Qt.rgba(1, 1, 1, 0.08)
                anchors.horizontalCenter: parent.horizontalCenter
                visible: modalRoot.hasCustomIcon

                Text {
                    anchors.centerIn: parent; text: "✕ 恢复默认"
                    color: Theme.textMuted; font.pixelSize: 8; font.family: modalRoot.effectiveFont
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: modalRoot.editIcon = ""
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Text {
                    text: nameInput.text.trim() ? nameInput.text.trim() : "新建服务"
                    color: "white"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.family: modalRoot.effectiveFont
                    elide: Text.ElideRight
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    height: 16
                    width: Math.min(parent.width, stateBadgeText.implicitWidth + 12)
                    radius: 8
                    color: modalRoot.editStatus === "running" ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.2) : Qt.rgba(1, 1, 1, 0.06)
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Rectangle {
                            width: 4; height: 4; radius: 2
                            color: modalRoot.editStatus === "running" ? "#10b981" : Theme.textMuted
                        }
                        Text {
                            id: stateBadgeText
                            text: modalRoot.editStatus === "running" ? ("运行中 · " + modalRoot.editPid) : "已停止"
                            color: modalRoot.editStatus === "running" ? "#34d399" : Theme.textMuted
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.family: modalRoot.effectiveMono
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 24; radius: 6
                color: backHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                scale: backTap.pressed ? 0.95 : 1.0

                Row {
                    anchors.centerIn: parent; spacing: 4
                    Text { text: "‹"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: modalRoot.effectiveFont }
                    Text { text: "返回列表"; color: "white"; font.pixelSize: 9; font.weight: Font.Bold; font.family: modalRoot.effectiveFont }
                }
                HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: backTap; onTapped: modalRoot.cancelRequested() }
            }
        }
    }

    // 2. 右列：参数配置专属工作区
    Rectangle {
        width: parent.width - 130
        height: parent.height
        radius: Theme.radiusCard
        color: "#18181f"
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 6

            Item {
                width: parent.width; height: 16

                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: modalRoot.editId ? "参数配置" : "新建参数"
                    color: "#c084fc"; font.pixelSize: 11; font.weight: Font.Bold; font.family: modalRoot.effectiveFont
                }

                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: delText.implicitWidth + 8; height: 18; radius: 4
                    visible: Boolean(modalRoot.editId !== "")
                    color: delHover.hovered ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.2) : "transparent"

                    Text {
                        id: delText; anchors.centerIn: parent
                        text: "✕ 删除服务"
                        color: delHover.hovered ? Theme.danger : Theme.textMuted
                        font.pixelSize: 10; font.family: modalRoot.effectiveFont
                    }
                    HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: modalRoot.deleteRequested(modalRoot.editId) }
                }
            }

            Column {
                width: parent.width
                spacing: 5

                // 1. 服务名称
                Rectangle {
                    width: parent.width; height: 26; radius: 5
                    color: nameInput.activeFocus ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: nameInput.activeFocus ? "#a855f7" : Qt.rgba(1, 1, 1, 0.08); border.width: 1
                    clip: true

                    Text {
                        id: lblName
                        anchors.left: parent.left; anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "名称"
                        color: Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: modalRoot.effectiveFont
                    }

                    TextInput {
                        id: nameInput
                        anchors.left: lblName.right; anchors.leftMargin: 8
                        anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        color: "white"; font.pixelSize: 11; font.family: modalRoot.effectiveFont
                        selectByMouse: true; activeFocusOnPress: true
                        KeyNavigation.tab: cwdInput
                        Keys.onReturnPressed: modalRoot.submitForm()
                        Keys.onEscapePressed: modalRoot.cancelRequested()

                        Text {
                            text: "服务标识 (如 ythought-things)..."
                            color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 10; font.family: modalRoot.effectiveFont
                            visible: !nameInput.text && !nameInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight; width: parent.width
                        }
                    }
                }

                // 2. 工作目录
                Rectangle {
                    width: parent.width; height: 26; radius: 5
                    color: cwdInput.activeFocus ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: cwdInput.activeFocus ? "#a855f7" : Qt.rgba(1, 1, 1, 0.08); border.width: 1
                    clip: true

                    Text {
                        id: lblCwd
                        anchors.left: parent.left; anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "目录"
                        color: Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: modalRoot.effectiveFont
                    }

                    Rectangle {
                        id: browseBtn
                        anchors.right: parent.right; anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20; height: 20; radius: 4
                        color: browseHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                        Text { anchors.centerIn: parent; text: "📁"; font.pixelSize: 11; font.family: modalRoot.effectiveFont }
                        HoverHandler { id: browseHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (typeof Bridge !== "undefined" && Bridge.selectLocalDirectory) {
                                    var dir = Bridge.selectLocalDirectory()
                                    if (dir) cwdInput.text = dir
                                }
                            }
                        }
                    }

                    TextInput {
                        id: cwdInput
                        anchors.left: lblCwd.right; anchors.leftMargin: 8
                        anchors.right: browseBtn.left; anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        color: Theme.textSecondary; font.pixelSize: 10; font.family: modalRoot.effectiveMono
                        selectByMouse: true; activeFocusOnPress: true
                        KeyNavigation.tab: cmdInput
                        Keys.onReturnPressed: modalRoot.submitForm()
                        Keys.onEscapePressed: modalRoot.cancelRequested()

                        Text {
                            text: "工作目录路径 (默认: ~)..."
                            color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 10; font.family: modalRoot.effectiveMono
                            visible: !cwdInput.text && !cwdInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight; width: parent.width
                        }
                    }
                }

                // 3. 执行命令
                Rectangle {
                    width: parent.width; height: 26; radius: 5
                    color: cmdInput.activeFocus ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: cmdInput.activeFocus ? "#a855f7" : Qt.rgba(1, 1, 1, 0.08); border.width: 1
                    clip: true

                    Text {
                        id: lblCmd
                        anchors.left: parent.left; anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "命令"
                        color: Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: modalRoot.effectiveFont
                    }

                    Text {
                        id: promptSymbol
                        anchors.left: lblCmd.right; anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: "$"
                        color: "#c084fc"; font.pixelSize: 11; font.family: modalRoot.effectiveMono
                    }

                    TextInput {
                        id: cmdInput
                        anchors.left: promptSymbol.right; anchors.leftMargin: 4
                        anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        color: "white"; font.pixelSize: 11; font.family: modalRoot.effectiveMono
                        selectByMouse: true; activeFocusOnPress: true
                        Keys.onReturnPressed: modalRoot.submitForm()
                        Keys.onEscapePressed: modalRoot.cancelRequested()

                        Text {
                            text: "npm start / cargo run / python3 main.py..."
                            color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 10; font.family: modalRoot.effectiveMono
                            visible: !cmdInput.text && !cmdInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight; width: parent.width
                        }
                    }
                }
            }

            // 底部操作栏
            Row {
                anchors.right: parent.right
                spacing: 8

                Rectangle {
                    width: 48; height: 24; radius: 5
                    color: cancelHover.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Text { anchors.centerIn: parent; text: "取消"; color: Theme.textMuted; font.pixelSize: 10; font.family: modalRoot.effectiveFont }
                    HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: modalRoot.cancelRequested() }
                }

                Rectangle {
                    width: 76; height: 24; radius: 12
                    color: saveHover.hovered ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.35) : Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.22)
                    border.color: saveHover.hovered ? "#c084fc" : Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.6); border.width: 1
                    scale: saveTap.pressed ? 0.95 : 1.0

                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "✓"; color: "white"; font.pixelSize: 10; font.weight: Font.Black; font.family: modalRoot.effectiveFont }
                        Text { text: "保存"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: modalRoot.effectiveFont }
                    }
                    HoverHandler { id: saveHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: saveTap; onTapped: modalRoot.submitForm() }
                }
            }
        }
    }
}