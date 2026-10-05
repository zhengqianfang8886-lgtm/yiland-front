// ==========================================
// 📄 File: process/ProcessGridCard.qml (图标视图双列卡片)
// ==========================================
import QtQuick

Rectangle {
    id: gridCardRoot
    height: 64
    radius: 10
    color: cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.035)
    border.color: gridCardRoot.taskStatus === "running" ?
                  Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.45) :
                  (cardHover.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07))
    border.width: 1

    property string effectiveFont: ""
    property string effectiveMono: ""
    property string taskId: ""
    property string taskName: ""
    property string taskCmd: ""
    property string taskCwd: ""
    property string taskIcon: ""
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

    Row {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // 🚀 大尺寸高质感真实图片显示槽
        Rectangle {
            width: 38; height: 38; radius: 8
            color: gridCardRoot.taskStatus === "running" ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.15) : Qt.rgba(1, 1, 1, 0.06)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            Image {
                id: gridIconImg
                anchors.fill: parent
                anchors.margins: 3
                fillMode: Image.PreserveAspectFit
                source: gridCardRoot.taskIcon ? (gridCardRoot.taskIcon.indexOf("://") !== -1 ? gridCardRoot.taskIcon : "file://" + gridCardRoot.taskIcon) : ""
                visible: status === Image.Ready && source != ""
                asynchronous: true
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                text: gridCardRoot.getTechIcon(gridCardRoot.taskCmd, gridCardRoot.taskName)
                font.pixelSize: 18
                visible: !gridIconImg.visible
            }
        }

        // 文字信息与迷你启停
        Column {
            width: parent.width - 38 - 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Item {
                width: parent.width; height: 16

                Text {
                    anchors.left: parent.left; anchors.right: toggleMiniBtn.left; anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    text: gridCardRoot.taskName
                    color: "white"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.family: gridCardRoot.effectiveFont
                    elide: Text.ElideRight
                }

                // 迷你极简启停胶囊
                Rectangle {
                    id: toggleMiniBtn
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 38; height: 18; radius: 4
                    color: gridCardRoot.taskStatus === "running" ?
                           (miniMouse.pressed ? "#7f1d1d" : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.22)) :
                           (miniMouse.pressed ? "#065f46" : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.22))
                    border.color: gridCardRoot.taskStatus === "running" ? "#ef4444" : "#10b981"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: gridCardRoot.taskStatus === "running" ? "停止" : "启动"
                        color: gridCardRoot.taskStatus === "running" ? "#f87171" : "#34d399"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.family: gridCardRoot.effectiveFont
                    }

                    MouseArea {
                        id: miniMouse
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            mouse.accepted = true
                            gridCardRoot.toggleRunning()
                        }
                    }
                }
            }

            Row {
                spacing: 4
                Rectangle {
                    width: 4; height: 4; radius: 2
                    color: gridCardRoot.taskStatus === "running" ? "#10b981" : Qt.rgba(1, 1, 1, 0.3)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: gridCardRoot.taskStatus === "running" ? ("PID " + gridCardRoot.taskPid) : "已停止"
                    color: gridCardRoot.taskStatus === "running" ? "#34d399" : Theme.textMuted
                    font.pixelSize: 9
                    font.family: gridCardRoot.effectiveMono
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    MouseArea {
        id: cardHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: gridCardRoot.cardClicked()
    }
}