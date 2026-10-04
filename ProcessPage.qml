// ==========================================
// 📄 File: ProcessPage.qml (组件化优雅编排版)
// ==========================================
import QtQuick
import QtQuick.Controls
import "process"

Item {
    id: procRoot
    anchors.fill: parent

    property string chosenFont: ""

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
    // 视图 1：服务概览列表界面 (currentView === 'list')
    // =========================================================================
    Row {
        id: listViewRoot
        anchors.fill: parent
        spacing: 10
        visible: procRoot.currentView === "list"
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // 1.1 左侧中枢侧边栏组件
        ProcessSidebar {
            effectiveFont: procRoot.effectiveFont
            effectiveMono: procRoot.displayFont
            totalCount: procRoot.totalCount
            runningCount: procRoot.runningCount

            onRequestAdd: {
                detailView.openAdd()
                procRoot.currentView = "detail"
                if (typeof Bridge !== "undefined" && Bridge.requestWindowFocus) Bridge.requestWindowFocus()
            }
            onRequestStartAll: if (typeof Bridge !== "undefined") Bridge.startAllProcessTasks()
            onRequestStopAll: if (typeof Bridge !== "undefined") Bridge.stopAllProcessTasks()
        }

        // 1.2 右侧任务列表组件
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

                delegate: ProcessCard {
                    width: taskListView.width - 4
                    effectiveFont: procRoot.effectiveFont
                    effectiveMono: procRoot.displayFont
                    taskId: model.taskId
                    taskName: model.name
                    taskCmd: model.cmd
                    taskCwd: model.cwd
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

    // =========================================================================
    // 视图 2：专属双列 Bento 详情与配置界面 (currentView === 'detail')
    // =========================================================================
    ProcessModal {
        id: detailView
        anchors.fill: parent
        effectiveFont: procRoot.effectiveFont
        effectiveMono: procRoot.displayFont
        visible: procRoot.currentView === "detail"
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        onSaveRequested: (id, name, cwd, cmd) => {
            if (typeof Bridge !== "undefined") {
                if (id) Bridge.updateProcessTask(id, name, cwd, cmd)
                else Bridge.addProcessTask(name, cwd, cmd)
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