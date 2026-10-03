import QtQuick
import QtQuick.Controls
import "power"

Item {
    id: powerRoot
    anchors.fill: parent

    property string chosenFont: ""
    property bool isConfirming: false
    property string pendingActionName: ""
    property string pendingIpcAction: ""
    property string pendingIcon: ""
    property string pendingWarningText: ""
    property color pendingColor: Theme.danger

    signal startCollapse()

    // 🚀 数据驱动模型：彻底消灭 250 行手写重复样板
    readonly property var actionList: [
        { name: "睡眠", cmd: "POWER_SUSPEND", icon: "🌙", color: "#818cf8", tag: "SUSPEND", sub: "深度低功耗待机", warn: "系统将进入低功耗待机，保留当前会话" },
        { name: "重启", cmd: "POWER_REBOOT", icon: "⟳", color: "#f59e0b", tag: "REBOOT", sub: "重新引导系统", warn: "所有正在运行的程序将被关闭并重启计算机" },
        { name: "关机", cmd: "POWER_OFF", icon: "⏻", color: "#ef4444", tag: "POWER OFF", sub: "安全切断电源", warn: "未保存的内容将会丢失，计算机将切断电源" },
        { name: "锁定屏幕", cmd: "SESSION_LOCK", icon: "🔒", color: "#38bdf8", tag: "LOCK", sub: "保留后台任务运行", warn: "当前会话与后台程序保持运行，解锁需输入密码" },
        { name: "注销会话", cmd: "SESSION_LOGOUT", icon: "⎋", color: "#f43f5e", tag: "LOGOUT", sub: "退出当前账户登录", warn: "将退出当前用户登录并关闭所有运行中的窗口" },
        { name: "切换用户", cmd: "SESSION_SWITCH_USER", icon: "⇄", color: "#34d399", tag: "SWITCH", sub: "保留会话在后台运行", warn: "当前用户会话将保持锁定并挂起在后台" }
    ]

    function requestAction(item) {
        powerRoot.pendingActionName = item.name
        powerRoot.pendingIpcAction = item.cmd
        powerRoot.pendingIcon = item.icon
        powerRoot.pendingColor = item.color
        powerRoot.pendingWarningText = item.warn
        powerRoot.isConfirming = true
    }

    function confirmExecute() {
        if (powerRoot.pendingIpcAction && typeof Bridge !== "undefined" && Bridge.executePowerAction) {
            Bridge.executePowerAction(powerRoot.pendingIpcAction)
        }
        powerRoot.isConfirming = false
        powerRoot.startCollapse()
    }

    MouseArea {
        anchors.fill: parent; z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => mouse.accepted = true
    }

    // 1. 顶栏标头
    Item {
        id: topActionBar
        width: parent.width; height: 18; anchors.top: parent.top

        Row {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
            Rectangle { width: 5; height: 5; radius: 2.5; color: "#ef4444"; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: "SYSTEM POWER & SESSION · 会话管理"
                color: Theme.textMuted; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 0.6; font.family: powerRoot.chosenFont
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // 2. 6格 Bento 矩阵（数据驱动渲染）
    Grid {
        id: bentoGrid
        anchors.top: topActionBar.bottom; anchors.topMargin: 8
        width: parent.width; height: parent.height - 26
        columns: 3; spacing: 7

        Repeater {
            model: powerRoot.actionList

            Rectangle {
                width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
                color: cardArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem
                border.color: cardArea.containsMouse ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.6) : Theme.borderSubtle
                border.width: 1

                scale: cardArea.pressed ? 0.95 : (cardArea.containsMouse ? 1.015 : 1.0)
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: Theme.animInstant } }

                Column {
                    anchors.fill: parent; anchors.margins: 8; spacing: 2

                    Item {
                        width: parent.width; height: 22
                        Rectangle {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            width: 22; height: 22; radius: 6; color: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.16)
                            Text { anchors.centerIn: parent; text: modelData.icon; font.pixelSize: 12; color: modelData.color; font.weight: Font.Black }
                        }
                        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.tag; font.pixelSize: 8; font.weight: Font.Black; color: modelData.color; font.letterSpacing: 0.5 }
                    }

                    Item { height: 2 }
                    Text { text: modelData.name; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                    Text { text: modelData.sub; color: Theme.textMuted; font.pixelSize: 9; font.family: powerRoot.chosenFont }
                }

                MouseArea {
                    id: cardArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: powerRoot.requestAction(modelData)
                }
            }
        }
    }

    // 3. 独立二步确认弹窗组件
    PowerConfirmModal {
        isConfirming: powerRoot.isConfirming
        pendingActionName: powerRoot.pendingActionName
        pendingIcon: powerRoot.pendingIcon
        pendingWarningText: powerRoot.pendingWarningText
        pendingColor: powerRoot.pendingColor
        chosenFont: powerRoot.chosenFont
        onConfirmed: powerRoot.confirmExecute()
        onCancelled: powerRoot.isConfirming = false
    }
}