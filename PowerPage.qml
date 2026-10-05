// ==========================================
// 📄 File: PowerPage.qml (macOS 极简克制·纯净语法修复版)
// ==========================================
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import "power"

Item {
    id: powerRoot
    anchors.fill: parent

    property string chosenFont: ""
    readonly property string effectiveFont: {
        if (typeof Theme !== "undefined" && Theme.activeFont) return Theme.activeFont
        if (typeof Config !== "undefined" && Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) {
            return Config.fontFamily
        }
        if (chosenFont !== "" && chosenFont.indexOf("系统默认") === -1) return chosenFont
        return ""
    }

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
        powerRoot.pendingColor = item.isDestructive ? "#ef4444" : "#ffffff"
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

    // =========================================================================
    // 6 格 Bento 矩阵 (纯正 macOS 控制中心实体触感风格)
    // =========================================================================
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
                        (modelData.isDestructive ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.18) : Qt.rgba(1, 1, 1, 0.12)) : 
                        Qt.rgba(1, 1, 1, 0.045))

                border.color: cardMouse.containsMouse ? 
                              (modelData.isDestructive ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.5) : Qt.rgba(1, 1, 1, 0.35)) : 
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

                    // 1. 实体圆形图标微托盘
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        anchors.verticalCenter: parent.verticalCenter

                        color: cardMouse.containsMouse ?
                               (modelData.isDestructive ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.3) : "#ffffff") :
                               Qt.rgba(1, 1, 1, 0.09)

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Item {
                            anchors.centerIn: parent
                            width: 16
                            height: 16

                            // 🔒 锁定
                            Shape {
                                anchors.fill: parent
                                visible: modelData.iconType === "lock"
                                layer.enabled: true
                                layer.samples: 4

                                ShapePath {
                                    strokeColor: (cardMouse.containsMouse && !modelData.isDestructive) ? "#141416" : "#ffffff"
                                    strokeWidth: 1.4
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    startX: 5.0
                                    startY: 6.5
                                    PathLine { x: 5.0; y: 4.8 }
                                    PathArc { x: 11.0; y: 4.8; radiusX: 3.0; radiusY: 3.0; useLargeArc: false }
                                    PathLine { x: 11.0; y: 6.5 }
                                }
                                ShapePath {
                                    fillColor: (cardMouse.containsMouse && !modelData.isDestructive) ? "#141416" : "#ffffff"
                                    strokeColor: "transparent"
                                    startX: 3.0
                                    startY: 6.5
                                    PathLine { x: 13.0; y: 6.5 }
                                    PathLine { x: 13.0; y: 13.5 }
                                    PathLine { x: 3.0; y: 13.5 }
                                    PathLine { x: 3.0; y: 6.5 }
                                }
                            }

                            // 🌙 睡眠
                            Shape {
                                anchors.fill: parent
                                visible: modelData.iconType === "suspend"
                                layer.enabled: true
                                layer.samples: 4

                                ShapePath {
                                    fillColor: (cardMouse.containsMouse && !modelData.isDestructive) ? "#141416" : "#ffffff"
                                    strokeColor: "transparent"
                                    startX: 12.0
                                    startY: 2.2
                                    PathArc { x: 4.0; y: 13.5; radiusX: 6.5; radiusY: 6.5; useLargeArc: false }
                                    PathQuad { x: 12.0; y: 2.2; controlX: 9.0; controlY: 8.5 }
                                }
                            }

                            // ⇄ 切换用户
                            Shape {
                                anchors.fill: parent
                                visible: modelData.iconType === "switch"
                                layer.enabled: true
                                layer.samples: 4

                                ShapePath {
                                    strokeColor: (cardMouse.containsMouse && !modelData.isDestructive) ? "#141416" : "#ffffff"
                                    strokeWidth: 1.4
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    startX: 2.0
                                    startY: 5.0
                                    PathLine { x: 13.5; y: 5.0 }
                                    PathMove { x: 10.5; y: 2.5 }
                                    PathLine { x: 13.5; y: 5.0 }
                                    PathLine { x: 10.5; y: 7.5 }
                                }
                                ShapePath {
                                    strokeColor: (cardMouse.containsMouse && !modelData.isDestructive) ? "#141416" : "#ffffff"
                                    strokeWidth: 1.4
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    startX: 14.0
                                    startY: 11.0
                                    PathLine { x: 2.5; y: 11.0 }
                                    PathMove { x: 5.5; y: 8.5 }
                                    PathLine { x: 2.5; y: 11.0 }
                                    PathLine { x: 5.5; y: 13.5 }
                                }
                            }

                            // ⎋ 注销
                            Shape {
                                anchors.fill: parent
                                visible: modelData.iconType === "logout"
                                layer.enabled: true
                                layer.samples: 4

                                ShapePath {
                                    strokeColor: cardMouse.containsMouse ? "#f87171" : "#ffffff"
                                    strokeWidth: 1.4
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    startX: 8.0
                                    startY: 2.5
                                    PathLine { x: 2.5; y: 2.5 }
                                    PathLine { x: 2.5; y: 13.5 }
                                    PathLine { x: 8.0; y: 13.5 }
                                }
                                ShapePath {
                                    strokeColor: cardMouse.containsMouse ? "#f87171" : "#ffffff"
                                    strokeWidth: 1.5
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin
                                    startX: 6.0
                                    startY: 8.0
                                    PathLine { x: 13.5; y: 8.0 }
                                    PathMove { x: 10.5; y: 5.0 }
                                    PathLine { x: 13.5; y: 8.0 }
                                    PathLine { x: 10.5; y: 11.0 }
                                }
                            }

                            // ⟳ 重启
                            Shape {
                                anchors.fill: parent
                                visible: modelData.iconType === "reboot"
                                layer.enabled: true
                                layer.samples: 4

                                ShapePath {
                                    strokeColor: cardMouse.containsMouse ? "#f87171" : "#ffffff"
                                    strokeWidth: 1.5
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    startX: 8.0
                                    startY: 1.8
                                    PathArc { x: 14.0; y: 8.0; radiusX: 6.0; radiusY: 6.0; useLargeArc: false }
                                    PathArc { x: 8.0; y: 14.0; radiusX: 6.0; radiusY: 6.0; useLargeArc: false }
                                    PathArc { x: 2.6; y: 9.6; radiusX: 6.0; radiusY: 6.0; useLargeArc: false }
                                }
                                ShapePath {
                                    fillColor: cardMouse.containsMouse ? "#f87171" : "#ffffff"
                                    strokeColor: "transparent"
                                    startX: 1.0
                                    startY: 10.5
                                    PathLine { x: 4.5; y: 10.5 }
                                    PathLine { x: 2.6; y: 7.0 }
                                    PathLine { x: 1.0; y: 10.5 }
                                }
                            }

                            // ⏻ 关机
                            Shape {
                                anchors.fill: parent
                                visible: modelData.iconType === "poweroff"
                                layer.enabled: true
                                layer.samples: 4

                                ShapePath {
                                    strokeColor: cardMouse.containsMouse ? "#f87171" : "#ffffff"
                                    strokeWidth: 1.6
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    startX: 4.5
                                    startY: 4.5
                                    PathArc { x: 11.5; y: 4.5; radiusX: 5.2; radiusY: 5.2; useLargeArc: true }
                                }
                                ShapePath {
                                    strokeColor: cardMouse.containsMouse ? "#f87171" : "#ffffff"
                                    strokeWidth: 1.6
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    startX: 8.0
                                    startY: 1.8
                                    PathLine { x: 8.0; y: 8.0 }
                                }
                            }
                        }
                    }

                    // 2. 文本信息列
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

    // 二步确认模态组件
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