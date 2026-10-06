// ==========================================
// 📄 File: process/ProcessCard.qml (完整生产级三态响应版)
// ==========================================
import QtQuick

Rectangle {
    id: cardRoot
    height: 44
    radius: 8

    // 背景底色：悬浮增亮，错误态提供极淡红光呼吸底托
    color: {
        if (contentMouseArea.containsMouse) return Qt.rgba(1, 1, 1, 0.08)
        if (cardRoot.taskStatus === "error") return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.08)
        return Qt.rgba(1, 1, 1, 0.035)
    }

    // 边框逻辑：运行中翠绿、报错时警告红、悬浮时浅灰、默认微暗边框
    border.color: {
        if (cardRoot.taskStatus === "running") return Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.35)
        if (cardRoot.taskStatus === "error") return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.45)
        if (contentMouseArea.containsMouse) return Qt.rgba(1, 1, 1, 0.16)
        return Qt.rgba(1, 1, 1, 0.07)
    }
    border.width: (cardRoot.taskStatus === "error" || cardRoot.taskStatus === "running") ? 1.2 : 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    property string effectiveFont: ""
    property string effectiveMono: ""
    property string taskId: ""
    property string taskName: ""
    property string taskCmd: ""
    property string taskCwd: ""
    property string taskIcon: ""
    property string taskStatus: "stopped"  // "running" | "stopped" | "error"
    property int taskPid: 0

    signal cardClicked()
    signal toggleRunning()

    // 智能识别技术栈 Emoji
    function getTechIcon(cmd, name) {
        var c = (cmd || "").toLowerCase()
        var n = (name || "").toLowerCase()
        if (c.indexOf("python") !== -1 || n.indexOf("py") !== -1) return "🐍"
        if (c.indexOf("cargo") !== -1 || c.indexOf("rust") !== -1 || c.indexOf("tauri") !== -1) return "🦀"
        if (c.indexOf("npm") !== -1 || c.indexOf("node") !== -1 || c.indexOf("vite") !== -1 || c.indexOf("yarn") !== -1) return "⬢"
        if (c.indexOf("docker") !== -1) return "🐳"
        if (c.indexOf("go ") !== -1) return "🐹"
        if (c.indexOf("mac-engine") !== -1 || n.indexOf("engine") !== -1) return "⚙️"
        return "⚡"
    }

    // =========================================================================
    // 1. 右侧启停交互按钮 (支持启动、停止与故障重试态)
    // =========================================================================
    Rectangle {
        id: toggleBtn
        width: 48
        height: 26
        radius: 6
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        z: 10

        color: {
            if (cardRoot.taskStatus === "running") {
                return toggleMouse.pressed ? "#7f1d1d" : (toggleMouse.containsMouse ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.28) : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.14))
            }
            if (cardRoot.taskStatus === "error") {
                return toggleMouse.pressed ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.4) : (toggleMouse.containsMouse ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.25) : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.12))
            }
            return toggleMouse.pressed ? "#065f46" : (toggleMouse.containsMouse ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.28) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.14))
        }

        border.color: {
            if (cardRoot.taskStatus === "running") return "#ef4444"
            if (cardRoot.taskStatus === "error") return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.75)
            return "#10b981"
        }
        border.width: 1

        scale: toggleMouse.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 80 } }
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            anchors.centerIn: parent
            text: {
                if (cardRoot.taskStatus === "running") return "停止"
                if (cardRoot.taskStatus === "error") return "重试"
                return "启动"
            }
            color: {
                if (cardRoot.taskStatus === "running") return "#f87171"
                if (cardRoot.taskStatus === "error") return Theme.danger
                return "#34d399"
            }
            font.pixelSize: 11
            font.weight: Font.Bold
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

    // =========================================================================
    // 2. 左侧信息主区域 (图标、服务名与三态指示行)
    // =========================================================================
    Item {
        anchors.left: parent.left
        anchors.right: toggleBtn.left
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // 2.1 任务图标槽位
        Rectangle {
            id: iconBox
            width: 28
            height: 28
            radius: 6
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: {
                if (cardRoot.taskStatus === "running") return Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.15)
                if (cardRoot.taskStatus === "error") return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.15)
                return Qt.rgba(1, 1, 1, 0.06)
            }
            clip: true

            // 自定义图片图标
            Image {
                id: realIconImg
                anchors.fill: parent
                anchors.margins: 3
                fillMode: Image.PreserveAspectFit
                source: cardRoot.taskIcon ? (cardRoot.taskIcon.indexOf("://") !== -1 ? cardRoot.taskIcon : "file://" + cardRoot.taskIcon) : ""
                visible: status === Image.Ready && source != ""
                asynchronous: true
                smooth: true
            }

            // 回退技术栈 Emoji
            Text {
                anchors.centerIn: parent
                text: cardRoot.getTechIcon(cardRoot.taskCmd, cardRoot.taskName)
                font.pixelSize: 14
                visible: !realIconImg.visible
            }
        }

        // 2.2 文本展示列
        Column {
            anchors.left: iconBox.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            // 服务名称
            Text {
                text: cardRoot.taskName || "未命名服务"
                color: "white"
                font.pixelSize: 13
                font.weight: Font.Bold
                font.family: cardRoot.effectiveFont
                elide: Text.ElideRight
                width: parent.width
            }

            // 状态指示条（精确定位运行中/已停止/启动失败）
            Row {
                spacing: 4
                anchors.left: parent.left
                width: parent.width

                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: {
                        if (cardRoot.taskStatus === "running") return "#10b981"
                        if (cardRoot.taskStatus === "error") return Theme.danger
                        return Qt.rgba(1, 1, 1, 0.3)
                    }
                }

                Text {
                    text: {
                        if (cardRoot.taskStatus === "running") return "运行中 · PID " + cardRoot.taskPid
                        if (cardRoot.taskStatus === "error") return "启动失败 · 点击检查配置"
                        return "已停止 · 点击配置"
                    }
                    color: {
                        if (cardRoot.taskStatus === "running") return "#34d399"
                        if (cardRoot.taskStatus === "error") return Theme.danger
                        return Theme.textMuted
                    }
                    font.pixelSize: 10
                    font.weight: (cardRoot.taskStatus === "error" || cardRoot.taskStatus === "running") ? Font.Bold : Font.Normal
                    font.family: (cardRoot.taskStatus === "running") ? cardRoot.effectiveMono : cardRoot.effectiveFont
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    width: parent.width - 10
                }
            }
        }

        // 点击打开详情配置抽屉
        MouseArea {
            id: contentMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cardRoot.cardClicked()
        }
    }
}