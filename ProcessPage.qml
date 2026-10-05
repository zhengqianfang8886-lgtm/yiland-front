// ==========================================
// 📄 File: ProcessPage.qml (双排版·真实图片图标版)
// ==========================================
import QtQuick
import QtQuick.Controls
import "process"

Item {
    id: procRoot
    anchors.fill: parent

    property string chosenFont: ""

    readonly property string effectiveFont: {
        if (typeof Theme !== "undefined" && Theme.activeFont) return Theme.activeFont
        if (typeof Config !== "undefined" && Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) return Config.fontFamily
        if (chosenFont !== "" && chosenFont.indexOf("系统默认") === -1) return chosenFont
        return ""
    }

    readonly property string displayFont: {
        if (typeof Theme !== "undefined" && Theme.displayMonoFont) return Theme.displayMonoFont
        return (effectiveFont !== "") ? effectiveFont : "Monospace"
    }

    readonly property var procModel: (typeof Bridge !== "undefined") ? Bridge.processModel : null
    property int totalCount: procModel ? procModel.count : 0
    property int runningCount: procModel ? procModel.runningCount : 0

    // 视图状态：'list'（列表主界面）或 'detail'（配置编辑界面）
    property string currentView: "list"
    // 🚀 排版状态："list"（单列卡片）或 "icon"（双列大图标网格）
    property string viewLayout: "list"

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

    // =========================================================================
    // 视图 1：服务概览界面 (支持 ☰ 单列卡片 与 ⊞ 双列大图标网格无缝切换)
    // =========================================================================
    Row {
        id: listViewRoot
        anchors.fill: parent
        spacing: 10
        visible: procRoot.currentView === "list"
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // 1.1 左侧中枢侧边栏（集成排版切换条）
        ProcessSidebar {
            effectiveFont: procRoot.effectiveFont
            effectiveMono: procRoot.displayFont
            totalCount: procRoot.totalCount
            runningCount: procRoot.runningCount
            viewLayout: procRoot.viewLayout

            onLayoutChanged: (layout) => procRoot.viewLayout = layout

            onRequestAdd: {
                detailView.openAdd()
                procRoot.currentView = "detail"
                if (typeof Bridge !== "undefined" && Bridge.requestWindowFocus) Bridge.requestWindowFocus()
            }
            onRequestStartAll: if (typeof Bridge !== "undefined") Bridge.startAllProcessTasks()
            onRequestStopAll: if (typeof Bridge !== "undefined") Bridge.stopAllProcessTasks()
        }

        // 1.2 右侧任务展示区
        Item {
            width: parent.width - 118
            height: parent.height

            // 空白指引
            Item {
                anchors.fill: parent
                visible: procRoot.totalCount === 0
                Column {
                    anchors.centerIn: parent; spacing: 4
                    Text { text: "暂无配置服务"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold; font.family: procRoot.effectiveFont; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { text: "点击左侧「+ 新建服务」开始托管"; color: Theme.textMuted; font.pixelSize: 10; font.family: procRoot.effectiveFont; anchors.horizontalCenter: parent.horizontalCenter }
                }
            }

            // 模式 A：单列标准列表视图 (viewLayout === "list")
            ListView {
                id: taskListView
                anchors.fill: parent
                clip: true
                spacing: 5
                model: procRoot.procModel
                visible: procRoot.totalCount > 0 && procRoot.viewLayout === "list"

                ScrollBar.vertical: ScrollBar {
                    width: 3; policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 1; color: Theme.borderSubtle }
                }

                delegate: ProcessCard {
                    width: taskListView.width - 4
                    effectiveFont: procRoot.effectiveFont
                    effectiveMono: procRoot.displayFont
                    taskId: model.taskId
                    taskName: model.name
                    taskCmd: model.cmd
                    taskCwd: model.cwd
                    taskIcon: model.icon || ""
                    taskStatus: model.status
                    taskPid: model.pid || 0

                    onCardClicked: {
                        detailView.openDetail(model)
                        procRoot.currentView = "detail"
                        if (typeof Bridge !== "undefined" && Bridge.requestWindowFocus) Bridge.requestWindowFocus()
                    }

                    onToggleRunning: {
                        if (typeof Bridge === "undefined") return
                        if (model.status === "running") Bridge.stopProcessTask(model.taskId)
                        else Bridge.startProcessTask(model.taskId)
                    }
                }
            }

            // 模式 B：🚀 双列 Bento 大图标网格视图 (viewLayout === "icon")
            GridView {
                id: taskGridView
                anchors.fill: parent
                clip: true
                cellWidth: Math.floor(width / 2)
                cellHeight: 70
                model: procRoot.procModel
                visible: procRoot.totalCount > 0 && procRoot.viewLayout === "icon"

                ScrollBar.vertical: ScrollBar {
                    width: 3; policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 1; color: Theme.borderSubtle }
                }

                delegate: Item {
                    width: taskGridView.cellWidth
                    height: taskGridView.cellHeight

                    ProcessGridCard {
                        width: parent.width - 6
                        anchors.centerIn: parent
                        effectiveFont: procRoot.effectiveFont
                        effectiveMono: procRoot.displayFont
                        taskId: model.taskId
                        taskName: model.name
                        taskCmd: model.cmd
                        taskCwd: model.cwd
                        taskIcon: model.icon || ""
                        taskStatus: model.status
                        taskPid: model.pid || 0

                        onCardClicked: {
                            detailView.openDetail(model)
                            procRoot.currentView = "detail"
                            if (typeof Bridge !== "undefined" && Bridge.requestWindowFocus) Bridge.requestWindowFocus()
                        }

                        onToggleRunning: {
                            if (typeof Bridge === "undefined") return
                            if (model.status === "running") Bridge.stopProcessTask(model.taskId)
                            else Bridge.startProcessTask(model.taskId)
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 视图 2：Bento 详情与配置界面
    // =========================================================================
    ProcessModal {
        id: detailView
        anchors.fill: parent
        effectiveFont: procRoot.effectiveFont
        effectiveMono: procRoot.displayFont
        visible: procRoot.currentView === "detail"
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        onSaveRequested: (id, name, cwd, cmd, icon) => {
            if (typeof Bridge !== "undefined") {
                if (id) Bridge.updateProcessTask(id, name, cwd, cmd, icon)
                else Bridge.addProcessTask(name, cwd, cmd, icon)
            }
            procRoot.currentView = "list"
        }

        onDeleteRequested: (id) => {
            if (typeof Bridge !== "undefined") Bridge.deleteProcessTask(id)
            procRoot.currentView = "list"
        }

        onCancelRequested: {
            procRoot.currentView = "list"
        }
    }
}