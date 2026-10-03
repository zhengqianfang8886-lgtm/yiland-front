import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import "power"

Item {
    id: powerRoot
    anchors.fill: parent

    // 🚀 补回供 ExpandedCardView 绑定的属性，消除编译报错
    property string chosenFont: ""

    // 🚀 动态热更新字体：优先直连 Config 监听设置变更，其次使用传入值，默认传空交由系统引擎
    readonly property string effectiveFont: {
        if (typeof Config !== "undefined" && Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) {
            return Config.fontFamily
        }
        if (chosenFont !== "" && chosenFont.indexOf("系统默认") === -1) {
            return chosenFont
        }
        return ""
    }

    property bool isConfirming: false
    property string pendingActionName: ""
    property string pendingIpcAction: ""
    property string pendingIconType: ""
    property string pendingWarningText: ""
    property color pendingColor: Theme.danger

    signal startCollapse()

    readonly property var actionList: [
        { name: "睡眠", cmd: "POWER_SUSPEND", iconType: "suspend", color: "#818cf8", tag: "SUSPEND", sub: "深度低功耗待机", warn: "系统将进入低功耗待机状态，保留当前所有运行中的会话" },
        { name: "重启", cmd: "POWER_REBOOT", iconType: "reboot", color: "#f59e0b", tag: "REBOOT", sub: "重新引导系统", warn: "所有正在运行的应用程序将被关闭并重新引导计算机" },
        { name: "关机", cmd: "POWER_OFF", iconType: "poweroff", color: "#ef4444", tag: "POWER OFF", sub: "安全切断电源", warn: "所有未保存的数据将会丢失，计算机将完全切断电源" },
        { name: "锁定屏幕", cmd: "SESSION_LOCK", iconType: "lock", color: "#38bdf8", tag: "LOCK", sub: "保留后台任务运行", warn: "屏幕将立即锁定，当前会话与后台程序继续保持安全运行" },
        { name: "注销会话", cmd: "SESSION_LOGOUT", iconType: "logout", color: "#f43f5e", tag: "LOGOUT", sub: "退出当前账户登录", warn: "将退出当前登录用户，关闭并结束所有用户级进程" },
        { name: "切换用户", cmd: "SESSION_SWITCH_USER", iconType: "switch", color: "#34d399", tag: "SWITCH", sub: "保留会话在后台运行", warn: "当前用户会话将保持锁定并挂起，返回系统欢迎登录界面" }
    ]

    function requestAction(item) {
        powerRoot.pendingActionName = item.name
        powerRoot.pendingIpcAction = item.cmd
        powerRoot.pendingIconType = item.iconType
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

    // 🚀 6格 Bento 矩阵（直接填满父容器，卡片高度充裕，绝不切底）
    Grid {
        id: bentoGrid
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: 4
        columns: 3
        spacing: 8

        Repeater {
            model: powerRoot.actionList

            Rectangle {
                id: actionCard
                width: (bentoGrid.width - 16) / 3
                height: (bentoGrid.height - 8) / 2
                radius: 12
                color: cardArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem
                border.color: cardArea.containsMouse ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.55) : Theme.borderSubtle
                border.width: 1

                scale: cardArea.pressed ? 0.96 : (cardArea.containsMouse ? 1.015 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                Behavior on color { ColorAnimation { duration: Theme.animInstant } }
                Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    // 1. 图标与 TAG 胶囊行
                    Item {
                        width: parent.width; height: 22

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22; height: 22; radius: 6
                            color: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.16)

                            Item {
                                anchors.centerIn: parent
                                width: 14; height: 14

                                // 🌙 1. 睡眠
                                Shape {
                                    anchors.fill: parent
                                    visible: modelData.iconType === "suspend"
                                    layer.enabled: true
                                    layer.samples: 4
                                    ShapePath {
                                        fillColor: modelData.color
                                        strokeColor: "transparent"
                                        startX: 10.5; startY: 2.0
                                        PathArc { x: 3.5; y: 11.5; radiusX: 5.5; radiusY: 5.5; useLargeArc: false }
                                        PathQuad { x: 10.5; y: 2.0; controlX: 8.0; controlY: 7.5 }
                                    }
                                }

                                // ⟳ 2. 重启
                                Shape {
                                    anchors.fill: parent
                                    visible: modelData.iconType === "reboot"
                                    layer.enabled: true
                                    layer.samples: 4
                                    ShapePath {
                                        strokeColor: modelData.color
                                        strokeWidth: 1.5
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        startX: 7.0; startY: 1.5
                                        PathArc { x: 12.5; y: 7.0; radiusX: 5.5; radiusY: 5.5; useLargeArc: false }
                                        PathArc { x: 7.0; y: 12.5; radiusX: 5.5; radiusY: 5.5; useLargeArc: false }
                                        PathArc { x: 2.2; y: 8.5; radiusX: 5.5; radiusY: 5.5; useLargeArc: false }
                                    }
                                    ShapePath {
                                        fillColor: modelData.color
                                        strokeColor: "transparent"
                                        startX: 0.5; startY: 9.0
                                        PathLine { x: 3.8; y: 9.0 }
                                        PathLine { x: 2.2; y: 5.8 }
                                        PathLine { x: 0.5; y: 9.0 }
                                    }
                                }

                                // ⏻ 3. 关机
                                Shape {
                                    anchors.fill: parent
                                    visible: modelData.iconType === "poweroff"
                                    layer.enabled: true
                                    layer.samples: 4
                                    ShapePath {
                                        strokeColor: modelData.color
                                        strokeWidth: 1.6
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        startX: 4.2; startY: 4.0
                                        PathArc { x: 9.8; y: 4.0; radiusX: 4.8; radiusY: 4.8; useLargeArc: true }
                                    }
                                    ShapePath {
                                        strokeColor: modelData.color
                                        strokeWidth: 1.6
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        startX: 7.0; startY: 1.5
                                        PathLine { x: 7.0; y: 7.0 }
                                    }
                                }

                                // 🔒 4. 锁定
                                Shape {
                                    anchors.fill: parent
                                    visible: modelData.iconType === "lock"
                                    layer.enabled: true
                                    layer.samples: 4
                                    ShapePath {
                                        strokeColor: modelData.color
                                        strokeWidth: 1.4
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        startX: 4.5; startY: 6.0
                                        PathLine { x: 4.5; y: 4.2 }
                                        PathArc { x: 9.5; y: 4.2; radiusX: 2.5; radiusY: 2.5; useLargeArc: false }
                                        PathLine { x: 9.5; y: 6.0 }
                                    }
                                    ShapePath {
                                        fillColor: modelData.color
                                        strokeColor: "transparent"
                                        startX: 2.5; startY: 6.0
                                        PathLine { x: 11.5; y: 6.0 }
                                        PathLine { x: 11.5; y: 12.8 }
                                        PathLine { x: 2.5; y: 12.8 }
                                        PathLine { x: 2.5; y: 6.0 }
                                    }
                                    ShapePath {
                                        strokeColor: "#18181b"
                                        strokeWidth: 1.4
                                        capStyle: ShapePath.RoundCap
                                        startX: 7.0; startY: 8.2
                                        PathLine { x: 7.0; y: 10.6 }
                                    }
                                }

                                // ⎋ 5. 注销
                                Shape {
                                    anchors.fill: parent
                                    visible: modelData.iconType === "logout"
                                    layer.enabled: true
                                    layer.samples: 4
                                    ShapePath {
                                        strokeColor: modelData.color
                                        strokeWidth: 1.4
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin
                                        startX: 7.5; startY: 1.8
                                        PathLine { x: 2.2; y: 1.8 }
                                        PathLine { x: 2.2; y: 12.2 }
                                        PathLine { x: 7.5; y: 12.2 }
                                    }
                                    ShapePath {
                                        strokeColor: modelData.color
                                        strokeWidth: 1.5
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin
                                        startX: 5.5; startY: 7.0
                                        PathLine { x: 12.5; y: 7.0 }
                                        PathMove { x: 9.8; y: 4.2 }
                                        PathLine { x: 12.5; y: 7.0 }
                                        PathLine { x: 9.8; y: 9.8 }
                                    }
                                }

                                // ⇄ 6. 切换用户
                                Shape {
                                    anchors.fill: parent
                                    visible: modelData.iconType === "switch"
                                    layer.enabled: true
                                    layer.samples: 4
                                    ShapePath {
                                        strokeColor: modelData.color
                                        strokeWidth: 1.4
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin
                                        startX: 1.8; startY: 4.5
                                        PathLine { x: 11.5; y: 4.5 }
                                        PathMove { x: 8.8; y: 2.2 }
                                        PathLine { x: 11.5; y: 4.5 }
                                        PathLine { x: 8.8; y: 6.8 }
                                    }
                                    ShapePath {
                                        strokeColor: modelData.color
                                        strokeWidth: 1.4
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin
                                        startX: 12.2; startY: 9.5
                                        PathLine { x: 2.5; y: 9.5 }
                                        PathMove { x: 5.2; y: 7.2 }
                                        PathLine { x: 2.5; y: 9.5 }
                                        PathLine { x: 5.2; y: 11.8 }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 14; width: tagText.implicitWidth + 8; radius: 7
                            color: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.10)
                            border.color: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.25)
                            border.width: 1

                            Text {
                                id: tagText
                                anchors.centerIn: parent
                                text: modelData.tag
                                font.pixelSize: 8
                                font.weight: Font.Black
                                color: modelData.color
                                font.letterSpacing: 0.5
                                font.family: powerRoot.effectiveFont
                            }
                        }
                    }

                    // 2. 主标题
                    Text {
                        text: modelData.name
                        color: "white"
                        font.pixelSize: 13
                        font.weight: Font.Black
                        font.family: powerRoot.effectiveFont
                    }

                    // 3. 副标题说明
                    Text {
                        text: modelData.sub
                        color: Theme.textMuted
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.family: powerRoot.effectiveFont
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                MouseArea {
                    id: cardArea
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