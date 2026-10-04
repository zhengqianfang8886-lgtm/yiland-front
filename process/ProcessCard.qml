// ==========================================
// 📄 File: process/ProcessCard.qml
// ==========================================
import QtQuick

Rectangle {
    id: cardRoot
    height: 44
    radius: 8
    color: contentMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.035)
    border.color: cardRoot.taskStatus === "running" ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.35) :
                  (contentMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07))
    border.width: 1

    property string effectiveFont: ""
    property string effectiveMono: ""
    property string taskId: ""
    property string taskName: ""
    property string taskCmd: ""
    property string taskCwd: ""
    property string taskStatus: "stopped"
    property int taskPid: 0

    signal cardClicked()
    signal toggleRunning()

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

    // 1. 右侧独立启停开关（吞噬点击事件，防止穿透冒泡触发 cardClicked）
    Rectangle {
        id: toggleBtn
        width: 48; height: 26; radius: 6
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        z: 10

        color: cardRoot.taskStatus === "running" ?
               (toggleMouse.pressed ? "#7f1d1d" : (toggleMouse.containsMouse ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.28) : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.14))) :
               (toggleMouse.pressed ? "#065f46" : (toggleMouse.containsMouse ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.28) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.14)))
        border.color: cardRoot.taskStatus === "running" ? "#ef4444" : "#10b981"
        border.width: 1
        scale: toggleMouse.pressed ? 0.94 : 1.0

        Text {
            anchors.centerIn: parent
            text: cardRoot.taskStatus === "running" ? "停止" : "启动"
            color: cardRoot.taskStatus === "running" ? "#f87171" : "#34d399"
            font.pixelSize: 11; font.weight: Font.Bold
            font.family: cardRoot.effectiveFont
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                mouse.accepted = true
                cardRoot.toggleRunning()
            }
        }
    }

    // 2. 左侧展示与跳转触发区（与右侧按钮几何解耦）
    Item {
        anchors.left: parent.left
        anchors.right: toggleBtn.left
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Rectangle {
            id: iconBox
            width: 28; height: 28; radius: 6
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: cardRoot.taskStatus === "running" ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.15) : Qt.rgba(1, 1, 1, 0.06)

            Text {
                anchors.centerIn: parent
                text: cardRoot.getTechIcon(cardRoot.taskCmd, cardRoot.taskName)
                font.pixelSize: 14
            }
        }

        Column {
            anchors.left: iconBox.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: cardRoot.taskName
                color: "white"
                font.pixelSize: 13
                font.weight: Font.Bold
                font.family: cardRoot.effectiveFont
                elide: Text.ElideRight
                width: parent.width
            }

            Row {
                spacing: 4
                Rectangle {
                    width: 4; height: 4; radius: 2
                    color: cardRoot.taskStatus === "running" ? "#10b981" : Qt.rgba(1, 1, 1, 0.3)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: cardRoot.taskStatus === "running" ? ("运行中 · PID " + cardRoot.taskPid) : "已停止 · 点击配置"
                    color: cardRoot.taskStatus === "running" ? "#34d399" : Theme.textMuted
                    font.pixelSize: 10
                    font.family: cardRoot.taskStatus === "running" ? cardRoot.effectiveMono : cardRoot.effectiveFont
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        MouseArea {
            id: contentMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cardRoot.cardClicked()
        }
    }
}