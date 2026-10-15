// ==========================================
// 📄 File: PowerPage.qml (统一引用 PowerActionIcon 版)
// ==========================================
import QtQuick
import QtQuick.Controls
import "../power"

Item {
    id: powerRoot
    anchors.fill: parent

    property string chosenFont: ""
    readonly property string effectiveFont: chosenFont !== "" ? chosenFont : Theme.activeFont

    property bool isConfirming: false
    property string pendingActionName: ""
    property string pendingIpcAction: ""
    property string pendingIconType: ""
    property string pendingWarningText: ""
    property color pendingColor: "#ffffff"

    signal startCollapse()

    readonly property var actionList: [
        { name: "锁定屏幕", sub: "保留后台任务", cmd: "SESSION_LOCK", iconType: "lock", isDestructive: false },
        { name: "睡眠", sub: "深度低功耗待机", cmd: "POWER_SUSPEND", iconType: "suspend", isDestructive: false },
        { name: "切换用户", sub: "保留当前会话", cmd: "SESSION_SWITCH_USER", iconType: "switch", isDestructive: false },
        { name: "注销会话", sub: "退出当前登录", cmd: "SESSION_LOGOUT", iconType: "logout", isDestructive: true },
        { name: "重启", sub: "重新引导系统", cmd: "POWER_REBOOT", iconType: "reboot", isDestructive: true },
        { name: "关机", sub: "安全切断电源", cmd: "POWER_OFF", iconType: "poweroff", isDestructive: true }
    ]

    function requestAction(item) {
        powerRoot.pendingActionName = item.name
        powerRoot.pendingIpcAction = item.cmd
        powerRoot.pendingIconType = item.iconType
        powerRoot.pendingColor = item.isDestructive ? Theme.danger : "#ffffff"
        powerRoot.pendingWarningText = item.name === "关机" ? "所有未保存的数据将会丢失，计算机将完全切断电源。" :
                                       (item.name === "重启" ? "所有正在运行的程序将被关闭并重新引导系统。" :
                                       (item.name === "注销会话" ? "将关闭所有用户级应用程序并返回登录窗口。" : "将立即切换系统当前运行状态。"))
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
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => mouse.accepted = true
    }

    Grid {
        id: bentoGrid
        anchors.fill: parent
        columns: 3
        spacing: 8

        Repeater {
            model: powerRoot.actionList

            Rectangle {
                id: actionCard
                width: Math.floor((bentoGrid.width - 16) / 3)
                height: Math.floor((bentoGrid.height - 8) / 2)
                radius: 12

                color: cardMouse.pressed ? Qt.rgba(1, 1, 1, 0.22) : 
                       (cardMouse.containsMouse ? 
                        (modelData.isDestructive ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.18) : Qt.rgba(1, 1, 1, 0.12)) : 
                        Qt.rgba(1, 1, 1, 0.045))

                border.color: cardMouse.containsMouse ? 
                              (modelData.isDestructive ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.5) : Qt.rgba(1, 1, 1, 0.35)) : 
                              Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                scale: cardMouse.pressed ? 0.96 : (cardMouse.containsMouse ? 1.015 : 1.0)
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 9

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        anchors.verticalCenter: parent.verticalCenter

                        color: cardMouse.containsMouse ?
                               (modelData.isDestructive ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.3) : "#ffffff") :
                               Qt.rgba(1, 1, 1, 0.09)

                        Behavior on color { ColorAnimation { duration: 120 } }

                        // 🚀 核心优化：直接调用通用 PowerActionIcon 统一组件
                        PowerActionIcon {
                            anchors.centerIn: parent
                            iconType: modelData.iconType
                            strokeColor: (cardMouse.containsMouse && !modelData.isDestructive) ? "#141416" : (modelData.isDestructive ? Theme.danger : "#ffffff")
                            fillColor: strokeColor
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        width: parent.width - 41

                        Text {
                            text: modelData.name
                            color: "white"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            font.family: powerRoot.effectiveFont
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: modelData.sub
                            color: cardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.42)
                            font.pixelSize: 9
                            font.family: powerRoot.effectiveFont
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: powerRoot.requestAction(modelData)
                }
            }
        }
    }

    PowerConfirmModal {
        isConfirming: powerRoot.isConfirming
        pendingActionName: powerRoot.pendingActionName
        pendingIconType: powerRoot.pendingIconType
        pendingWarningText: powerRoot.pendingWarningText
        pendingColor: powerRoot.pendingColor
        chosenFont: powerRoot.effectiveFont
        onConfirmed: powerRoot.confirmExecute()
        onCancelled: powerRoot.isConfirming = false
    }
}