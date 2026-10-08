// ==========================================
// 📄 File: process/ProcessCard.qml (引用通用工具库版)
// ==========================================
import QtQuick
import "ProcessUtils.js" as ProcessUtils

Rectangle {
    id: cardRoot
    height: 44
    radius: 8

    color: {
        if (contentMouseArea.containsMouse) return Qt.rgba(1, 1, 1, 0.08)
        if (cardRoot.taskStatus === "error") return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.08)
        return Qt.rgba(1, 1, 1, 0.035)
    }

    border.color: {
        if (cardRoot.taskStatus === "running") return Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.35)
        if (cardRoot.taskStatus === "error") return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.45)
        if (contentMouseArea.containsMouse) return Qt.rgba(1, 1, 1, 0.16)
        return Qt.rgba(1, 1, 1, 0.07)
    }
    border.width: (cardRoot.taskStatus === "error" || cardRoot.taskStatus === "running") ? 1.2 : 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    property string effectiveFont: Theme.activeFont
    property string effectiveMono: Theme.displayMonoFont
    property string taskId: ""
    property string taskName: ""
    property string taskCmd: ""
    property string taskCwd: ""
    property string taskIcon: ""
    property string taskStatus: "stopped"
    property int taskPid: 0

    signal cardClicked()
    signal toggleRunning()

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
                return toggleMouse.pressed ? "#7f1d1d" : (toggleMouse.containsMouse ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.28) : Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.14))
            }
            if (cardRoot.taskStatus === "error") {
                return toggleMouse.pressed ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.4) : (toggleMouse.containsMouse ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.25) : Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.12))
            }
            return toggleMouse.pressed ? "#065f46" : (toggleMouse.containsMouse ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.28) : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.14))
        }

        border.color: {
            if (cardRoot.taskStatus === "running") return Theme.danger
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

    Item {
        anchors.left: parent.left
        anchors.right: toggleBtn.left
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.bottom: parent.bottom

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

            // 🚀 核心优化：调用 ProcessUtils.getTechIcon
            Text {
                anchors.centerIn: parent
                text: ProcessUtils.getTechIcon(cardRoot.taskCmd, cardRoot.taskName)
                font.pixelSize: 14
                visible: !realIconImg.visible
            }
        }

        Column {
            anchors.left: iconBox.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: cardRoot.taskName || "未命名服务"
                color: "white"
                font.pixelSize: 13
                font.weight: Font.Bold
                font.family: cardRoot.effectiveFont
                elide: Text.ElideRight
                width: parent.width
            }

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

        MouseArea {
            id: contentMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cardRoot.cardClicked()
        }
    }
}