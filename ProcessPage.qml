// ==========================================
// 📄 File: ProcessPage.qml (修复编译报错与排版切底版)
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: procRoot
    anchors.fill: parent

    // 🚀【核心修复】：补回供 ExpandedCardView 绑定的外部接口属性，彻底消除编译报错
    property string chosenFont: ""

    // 🚀 优先接入全局 Theme 统一字体引擎，同时向后兼容外部传参
    readonly property string effectiveFont: {
        if (typeof Theme !== "undefined" && Theme.activeFont) {
            return Theme.activeFont
        }
        if (typeof Config !== "undefined" && Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) {
            return Config.fontFamily
        }
        if (chosenFont !== "" && chosenFont.indexOf("系统默认") === -1) {
            return chosenFont
        }
        return ""
    }

    readonly property string displayFont: {
        if (typeof Theme !== "undefined" && Theme.displayMonoFont) {
            return Theme.displayMonoFont
        }
        return (effectiveFont !== "") ? effectiveFont : "Monospace"
    }

    readonly property var procModel: (typeof Bridge !== "undefined") ? Bridge.processModel : null
    property int totalCount: procModel ? procModel.count : 0
    property int runningCount: procModel ? procModel.runningCount : 0

    // 视图状态：'list'（列表主界面）或 'detail'（配置独立界面）
    property string currentView: "list"
    property string editId: ""
    property string editStatus: "stopped"
    property int editPid: 0

    Connections {
        target: procRoot.procModel
        ignoreUnknownSignals: true
        function onCountChanged() { if (procRoot.procModel) procRoot.totalCount = procRoot.procModel.count }
        function onRunningCountChanged() { if (procRoot.procModel) procRoot.runningCount = procRoot.procModel.runningCount }
        function onModelReset() {
            if (procRoot.procModel) {
                procRoot.totalCount = procRoot.procModel.count
                procRoot.runningCount = procRoot.procModel.runningCount
            }
        }
    }

    Component.onCompleted: {
        if (procModel) {
            procRoot.totalCount = procModel.count
            procRoot.runningCount = procModel.runningCount
        }
    }

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

    function goToAdd() {
        procRoot.editId = ""
        procRoot.editStatus = "stopped"
        procRoot.editPid = 0
        nameInput.text = ""
        cwdInput.text = "~"
        cmdInput.text = ""
        procRoot.currentView = "detail"
        if (typeof Bridge !== "undefined" && Bridge.requestWindowFocus) Bridge.requestWindowFocus()
        focusTimer.restart()
    }

    function goToDetail(item) {
        procRoot.editId = item.taskId
        procRoot.editStatus = item.status || "stopped"
        procRoot.editPid = item.pid || 0
        nameInput.text = item.name
        cwdInput.text = item.cwd
        cmdInput.text = item.cmd
        procRoot.currentView = "detail"
        if (typeof Bridge !== "undefined" && Bridge.requestWindowFocus) Bridge.requestWindowFocus()
        focusTimer.restart()
    }

    function goBackToList() {
        nameInput.text = ""
        cwdInput.text = ""
        cmdInput.text = ""
        procRoot.editId = ""
        procRoot.currentView = "list"
    }

    function submitForm() {
        var nameVal = nameInput.text.trim()
        var cwdVal = cwdInput.text.trim() || "~"
        var cmdVal = cmdInput.text.trim()
        if (!nameVal || !cmdVal) return

        if (typeof Bridge !== "undefined") {
            if (procRoot.editId) {
                Bridge.updateProcessTask(procRoot.editId, nameVal, cwdVal, cmdVal)
            } else {
                Bridge.addProcessTask(nameVal, cwdVal, cmdVal)
            }
        }
        procRoot.goBackToList()
    }

    function deleteCurrentTask() {
        if (procRoot.editId && typeof Bridge !== "undefined") {
            Bridge.deleteProcessTask(procRoot.editId)
        }
        procRoot.goBackToList()
    }

    Timer {
        id: focusTimer; interval: 60; repeat: false
        onTriggered: { nameInput.forceActiveFocus(); nameInput.selectAll() }
    }

    // =========================================================================
    // 视图 1：服务概览列表界面 (currentView === 'list')
    // =========================================================================
    Row {
        id: listViewRoot
        anchors.fill: parent
        spacing: 10
        visible: procRoot.currentView === "list"
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // 1.1 左侧中枢：精细紧凑化，彻底消除截图中的切底截断
        Rectangle {
            width: 108
            height: parent.height
            radius: Theme.radiusCard
            color: Qt.rgba(1, 1, 1, 0.035)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.leftMargin: 6; anchors.rightMargin: 6
                anchors.topMargin: 6; anchors.bottomMargin: 6
                spacing: 4

                // 统计数据区
                Column {
                    width: parent.width
                    spacing: 1

                    Row {
                        spacing: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        Rectangle {
                            width: 5; height: 5; radius: 2.5
                            color: procRoot.runningCount > 0 ? "#10b981" : "#a855f7"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "服务管控"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Theme.textSecondary
                            font.family: procRoot.effectiveFont
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2
                        Text {
                            text: procRoot.runningCount
                            color: procRoot.runningCount > 0 ? "#10b981" : "white"
                            font.pixelSize: 19
                            font.weight: Font.Black
                            font.family: procRoot.displayFont
                        }
                        Text {
                            text: "/" + procRoot.totalCount
                            color: Qt.rgba(1, 1, 1, 0.4)
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.family: procRoot.displayFont
                            anchors.baseline: parent.children[0].baseline
                        }
                    }

                    Text {
                        text: procRoot.runningCount > 0 ? (procRoot.runningCount + " 活跃中") : "服务就绪"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: procRoot.runningCount > 0 ? "#34d399" : Theme.textMuted
                        font.family: procRoot.effectiveFont
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                // 三大动作按钮区：高度规范为 24px/22px/22px，在 170px 容器内留有呼吸空间
                Column {
                    width: parent.width
                    spacing: 4

                    // + 新建服务
                    Rectangle {
                        width: parent.width; height: 24; radius: 5
                        color: addHover.hovered ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.3) : Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.16)
                        border.color: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.55); border.width: 1
                        scale: addTap.pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Row {
                            anchors.centerIn: parent; spacing: 3
                            Text { text: "+"; color: "#c084fc"; font.pixelSize: 12; font.weight: Font.Black; font.family: procRoot.effectiveFont }
                            Text { text: "新建服务"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: procRoot.effectiveFont }
                        }
                        HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: addTap; onTapped: procRoot.goToAdd() }
                    }

                    // ▶ 全部启动
                    Rectangle {
                        width: parent.width; height: 22; radius: 5
                        color: startAllHover.hovered ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.28) : Qt.rgba(1, 1, 1, 0.12)
                        border.color: startAllHover.hovered ? "#10b981" : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.35); border.width: 1
                        scale: startAllTap.pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Row {
                            anchors.centerIn: parent; spacing: 3
                            Text { text: "▶"; color: "#10b981"; font.pixelSize: 8; font.family: procRoot.effectiveFont }
                            Text { text: "全部启动"; color: startAllHover.hovered ? "#34d399" : "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: procRoot.effectiveFont }
                        }
                        HoverHandler { id: startAllHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: startAllTap; onTapped: if (typeof Bridge !== "undefined") Bridge.startAllProcessTasks() }
                    }

                    // ■ 全部停止
                    Rectangle {
                        width: parent.width; height: 22; radius: 5
                        color: stopAllHover.hovered ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.26) : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.08)
                        border.color: stopAllHover.hovered ? Theme.danger : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.3); border.width: 1
                        scale: stopAllTap.pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        Row {
                            anchors.centerIn: parent; spacing: 3
                            Text { text: "■"; color: Theme.danger; font.pixelSize: 8; font.family: procRoot.effectiveFont }
                            Text { text: "全部停止"; color: stopAllHover.hovered ? Theme.danger : Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: procRoot.effectiveFont }
                        }
                        HoverHandler { id: stopAllHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: stopAllTap; onTapped: if (typeof Bridge !== "undefined") Bridge.stopAllProcessTasks() }
                    }
                }
            }
        }

        // 1.2 右侧任务列表
        Item {
            width: parent.width - 118
            height: parent.height

            Item {
                anchors.fill: parent
                visible: procRoot.totalCount === 0
                Column {
                    anchors.centerIn: parent; spacing: 4
                    Text { text: "暂无配置服务"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold; font.family: procRoot.effectiveFont; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "点击左侧「+ 新建服务」开始托管"; color: Theme.textMuted; font.pixelSize: 10; font.family: procRoot.effectiveFont; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }

            ListView {
                id: taskListView
                anchors.fill: parent
                clip: true
                spacing: 5
                model: procRoot.procModel
                visible: procRoot.totalCount > 0

                ScrollBar.vertical: ScrollBar {
                    width: 3; policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 1; color: Theme.borderSubtle }
                }

                delegate: Rectangle {
                    id: taskCard
                    width: taskListView.width - 4
                    height: 44
                    radius: 8
                    color: contentMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.035)
                    border.color: model.status === "running" ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.35) :
                                  (contentMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07))
                    border.width: 1

                    Rectangle {
                        id: toggleBtn
                        width: 48; height: 26; radius: 6
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        z: 10

                        color: model.status === "running" ?
                               (toggleMouse.pressed ? "#7f1d1d" : (toggleMouse.containsMouse ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.28) : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.14))) :
                               (toggleMouse.pressed ? "#065f46" : (toggleMouse.containsMouse ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.28) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.14)))
                        border.color: model.status === "running" ? "#ef4444" : "#10b981"
                        border.width: 1
                        scale: toggleMouse.pressed ? 0.94 : 1.0

                        Text {
                            anchors.centerIn: parent
                            text: model.status === "running" ? "停止" : "启动"
                            color: model.status === "running" ? "#f87171" : "#34d399"
                            font.pixelSize: 11; font.weight: Font.Bold
                            font.family: procRoot.effectiveFont
                        }

                        MouseArea {
                            id: toggleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                mouse.accepted = true
                                if (typeof Bridge === "undefined") return
                                if (model.status === "running") Bridge.stopProcessTask(model.taskId)
                                else Bridge.startProcessTask(model.taskId)
                            }
                        }
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.right: toggleBtn.left
                        anchors.rightMargin: 6
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        Rectangle {
                            id: iconContainer
                            width: 28; height: 28; radius: 6
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: model.status === "running" ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.15) : Qt.rgba(1, 1, 1, 0.06)

                            Text {
                                anchors.centerIn: parent
                                text: procRoot.getTechIcon(model.cmd, model.name)
                                font.pixelSize: 14
                            }
                        }

                        Column {
                            anchors.left: iconContainer.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: model.name
                                color: "white"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                font.family: procRoot.effectiveFont
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Row {
                                spacing: 4
                                Rectangle {
                                    width: 4; height: 4; radius: 2
                                    color: model.status === "running" ? "#10b981" : Qt.rgba(1, 1, 1, 0.3)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: model.status === "running" ? ("运行中 · PID " + model.pid) : "已停止 · 点击配置"
                                    color: model.status === "running" ? "#34d399" : Theme.textMuted
                                    font.pixelSize: 10
                                    font.family: model.status === "running" ? procRoot.displayFont : procRoot.effectiveFont
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        MouseArea {
                            id: contentMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: procRoot.goToDetail(model)
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 视图 2：专属双列 Bento 详情与配置界面
    // =========================================================================
    Row {
        id: detailViewRoot
        anchors.fill: parent
        spacing: 10
        visible: procRoot.currentView === "detail"
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // 2.1 左列：服务看板
        Rectangle {
            width: 120
            height: parent.height
            radius: Theme.radiusCard
            color: "#18181f"
            border.color: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.3)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Rectangle {
                    width: 42; height: 42; radius: 10
                    color: procRoot.editStatus === "running" ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: procRoot.editStatus === "running" ? "#10b981" : Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        anchors.centerIn: parent
                        text: procRoot.getTechIcon(cmdInput.text, nameInput.text)
                        font.pixelSize: 22
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2

                    Text {
                        text: nameInput.text.trim() ? nameInput.text.trim() : "新建服务"
                        color: "white"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        font.family: procRoot.effectiveFont
                        elide: Text.ElideRight
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Rectangle {
                        height: 16
                        width: Math.min(parent.width, stateBadgeText.implicitWidth + 12)
                        radius: 8
                        color: procRoot.editStatus === "running" ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.2) : Qt.rgba(1, 1, 1, 0.06)
                        anchors.horizontalCenter: parent.horizontalCenter

                        Row {
                            anchors.centerIn: parent
                            spacing: 3
                            Rectangle {
                                width: 4; height: 4; radius: 2
                                color: procRoot.editStatus === "running" ? "#10b981" : Theme.textMuted
                            }
                            Text {
                                id: stateBadgeText
                                text: procRoot.editStatus === "running" ? ("运行中 · " + procRoot.editPid) : "已停止"
                                color: procRoot.editStatus === "running" ? "#34d399" : Theme.textMuted
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.family: procRoot.displayFont
                            }
                        }
                    }
                }

                Item { height: 4 }

                Rectangle {
                    width: parent.width; height: 26; radius: 6
                    color: backHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                    scale: backTap.pressed ? 0.95 : 1.0

                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "‹"; color: "white"; font.pixelSize: 14; font.weight: Font.Black; font.family: procRoot.effectiveFont }
                        Text { text: "返回列表"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: procRoot.effectiveFont }
                    }
                    HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: backTap; onTapped: procRoot.goBackToList() }
                }
            }
        }

        // 2.2 右列：参数配置专属工作区
        Rectangle {
            width: parent.width - 130
            height: parent.height
            radius: Theme.radiusCard
            color: "#18181f"
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 6

                Item {
                    width: parent.width; height: 16

                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: procRoot.editId ? "参数配置" : "新建参数"
                        color: "#c084fc"; font.pixelSize: 11; font.weight: Font.Bold; font.family: procRoot.effectiveFont
                    }

                    Rectangle {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: delText.implicitWidth + 8; height: 18; radius: 4
                        visible: procRoot.editId !== ""
                        color: delHover.hovered ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.2) : "transparent"

                        Text {
                            id: delText; anchors.centerIn: parent
                            text: "✕ 删除服务"
                            color: delHover.hovered ? Theme.danger : Theme.textMuted
                            font.pixelSize: 10; font.family: procRoot.effectiveFont
                        }
                        HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: procRoot.deleteCurrentTask() }
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

                        Row {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            Text { text: "名称"; color: Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: procRoot.effectiveFont; anchors.verticalCenter: parent.verticalCenter; width: 32 }
                            TextInput {
                                id: nameInput
                                width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter
                                color: "white"; font.pixelSize: 11; font.family: procRoot.effectiveFont
                                selectByMouse: true; activeFocusOnPress: true
                                KeyNavigation.tab: cwdInput
                                Keys.onReturnPressed: procRoot.submitForm()
                                Keys.onEnterPressed: procRoot.submitForm()
                                Keys.onEscapePressed: procRoot.goBackToList()
                                Text { text: "服务标识 (如 book-search)..."; color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 10; font.family: procRoot.effectiveFont; visible: !nameInput.text && !nameInput.activeFocus; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    // 2. 工作目录
                    Rectangle {
                        width: parent.width; height: 26; radius: 5
                        color: cwdInput.activeFocus ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: cwdInput.activeFocus ? "#a855f7" : Qt.rgba(1, 1, 1, 0.08); border.width: 1

                        Row {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 4
                            Text { text: "目录"; color: Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: procRoot.effectiveFont; anchors.verticalCenter: parent.verticalCenter; width: 32 }
                            TextInput {
                                id: cwdInput
                                width: parent.width - 32 - 24; anchors.verticalCenter: parent.verticalCenter
                                color: Theme.textSecondary; font.pixelSize: 10; font.family: procRoot.displayFont
                                selectByMouse: true; activeFocusOnPress: true
                                KeyNavigation.tab: cmdInput
                                Keys.onReturnPressed: procRoot.submitForm()
                                Keys.onEnterPressed: procRoot.submitForm()
                                Keys.onEscapePressed: procRoot.goBackToList()
                                Text { text: "工作目录路径 (默认: ~)..."; color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 10; font.family: procRoot.displayFont; visible: !cwdInput.text && !cwdInput.activeFocus; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Rectangle {
                                width: 20; height: 20; radius: 4; anchors.verticalCenter: parent.verticalCenter
                                color: browseHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                                Text { anchors.centerIn: parent; text: "📁"; font.pixelSize: 11; font.family: procRoot.effectiveFont }
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
                        }
                    }

                    // 3. 执行命令
                    Rectangle {
                        width: parent.width; height: 26; radius: 5
                        color: cmdInput.activeFocus ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: cmdInput.activeFocus ? "#a855f7" : Qt.rgba(1, 1, 1, 0.08); border.width: 1

                        Row {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            Text { text: "命令"; color: Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: procRoot.effectiveFont; anchors.verticalCenter: parent.verticalCenter; width: 32 }
                            Text { text: "$"; color: "#c084fc"; font.pixelSize: 11; font.family: procRoot.displayFont; anchors.verticalCenter: parent.verticalCenter; rightPadding: 4 }
                            TextInput {
                                id: cmdInput
                                width: parent.width - 32 - 14; anchors.verticalCenter: parent.verticalCenter
                                color: "white"; font.pixelSize: 11; font.family: procRoot.displayFont
                                selectByMouse: true; activeFocusOnPress: true
                                Keys.onReturnPressed: procRoot.submitForm()
                                Keys.onEnterPressed: procRoot.submitForm()
                                Keys.onEscapePressed: procRoot.goBackToList()
                                Text { text: "npm start / python3 main.py..."; color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 10; font.family: procRoot.displayFont; visible: !cmdInput.text && !cmdInput.activeFocus; anchors.verticalCenter: parent.verticalCenter }
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
                        Text { anchors.centerIn: parent; text: "取消"; color: Theme.textMuted; font.pixelSize: 10; font.family: procRoot.effectiveFont }
                        HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: procRoot.goBackToList() }
                    }

                    Rectangle {
                        width: 76; height: 24; radius: 12
                        color: saveHover.hovered ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.35) : Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.22)
                        border.color: saveHover.hovered ? "#c084fc" : Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.6); border.width: 1
                        scale: saveTap.pressed ? 0.95 : 1.0

                        Row {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: "✓"; color: "white"; font.pixelSize: 10; font.weight: Font.Black; font.family: procRoot.effectiveFont }
                            Text { text: "保存"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: procRoot.effectiveFont }
                        }
                        HoverHandler { id: saveHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: saveTap; onTapped: procRoot.submitForm() }
                    }
                }
            }
        }
    }
}