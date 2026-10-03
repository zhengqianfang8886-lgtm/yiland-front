import QtQuick
import QtQuick.Controls

Item {
    id: wsPageRoot

    property string chosenFont: ""
    property int currentWs: 1
    property int totalWs: 4
    property string currentWsName: "Desktop 1"
    property var wsList: []

    readonly property bool isVisibleOnScreen: wsPageRoot.visible && wsPageRoot.opacity > 0.1
    readonly property int effectiveTotal: Math.max(1, (wsList && wsList.length > 0) ? wsList.length : totalWs)

    readonly property int displayCurrentNumber: {
        if (wsList && wsList.length > 0) {
            for (var i = 0; i < wsList.length; i++) {
                if (wsList[i] && wsList[i].active) {
                    if (wsList[i].id !== undefined && !isNaN(Number(wsList[i].id))) {
                        return Number(wsList[i].id)
                    }
                    return i
                }
            }
        }
        return currentWs
    }

    readonly property bool hasZeroWs: (wsPageRoot.currentWs === 0 || wsPageRoot.displayCurrentNumber === 0)

    property real wsWheelAccum: 0
    Timer { id: wsWheelReset; interval: 260; onTriggered: wsPageRoot.wsWheelAccum = 0 }

    function stepWorkspace(delta) {
        if (typeof Bridge === "undefined") return
        if (delta > 0) Bridge.switchWorkspacePrev()
        else Bridge.switchWorkspaceNext()
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            wheel.accepted = true
            wsWheelReset.restart()
            wsPageRoot.wsWheelAccum += wheel.angleDelta.y
            if (Math.abs(wsPageRoot.wsWheelAccum) >= 80) {
                wsPageRoot.stepWorkspace(wsPageRoot.wsWheelAccum)
                wsPageRoot.wsWheelAccum = 0
            }
        }
    }

    Row {
        anchors.fill: parent
        spacing: 12

        // =====================================================================
        // 1. 左侧【当前工作区精工看板】（去重、去光圈、收敛字号）
        // =====================================================================
        Rectangle {
            id: leftDashboard
            width: 132
            height: parent.height
            radius: Theme.radiusCard
            color: Qt.rgba(1, 1, 1, 0.035)
            border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.24)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 0

                // 顶部状态指示微槽（无冗余 WORKSPACE 字符）
                Item {
                    width: parent.width
                    height: 20

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Rectangle {
                            width: 6; height: 6; radius: 3
                            color: Theme.workspace
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "当前空间"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font.family: wsPageRoot.chosenFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: (wsPageRoot.hasZeroWs ? (wsPageRoot.displayCurrentNumber + 1) : wsPageRoot.displayCurrentNumber) + " / " + wsPageRoot.effectiveTotal
                        color: Theme.workspace
                        font.pixelSize: 10
                        font.weight: Font.Black
                        font.family: "Monospace"
                    }
                }

                Item { height: 6 }

                // 核心数字徽章与名称整合区（摒弃 44px 突兀巨字）
                Rectangle {
                    width: parent.width
                    height: 58
                    radius: 10
                    color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.12)
                    border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.28)
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        // 匀称等宽编号
                        Text {
                            id: wsNumText
                            text: wsPageRoot.displayCurrentNumber
                            color: "white"
                            font.pixelSize: 26
                            font.weight: Font.Black
                            font.family: (wsPageRoot.chosenFont !== "") ? wsPageRoot.chosenFont : "Monospace"
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on text {
                                SequentialAnimation {
                                    NumberAnimation { target: wsNumText; property: "scale"; to: 0.9; duration: 50; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: wsNumText; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                                }
                            }
                        }

                        Rectangle {
                            width: 1
                            height: 20
                            color: Qt.rgba(1, 1, 1, 0.15)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // 桌面名称
                        Text {
                            id: wsNameLabel
                            text: wsPageRoot.currentWsName ? wsPageRoot.currentWsName : ("空间 " + wsPageRoot.displayCurrentNumber)
                            color: "white"
                            font.pixelSize: 13
                            font.weight: Font.Black
                            font.family: wsPageRoot.chosenFont
                            elide: Text.ElideRight
                            width: parent.parent.width - 64
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Item { height: 8 }

                // 空间指示微轨
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 8
                    height: 3
                    radius: 1.5
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Rectangle {
                        height: parent.height
                        radius: 1.5
                        color: Theme.workspace
                        width: parent.width * Math.min(1.0, Math.max(0.15, (wsPageRoot.hasZeroWs ? (wsPageRoot.displayCurrentNumber + 1) : wsPageRoot.displayCurrentNumber) / Math.max(1, wsPageRoot.effectiveTotal)))
                        Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                    }
                }

                Item { height: 10 }

                // 底部快速切页控制胶囊
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 4
                    height: 26
                    radius: 13
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    Row {
                        anchors.fill: parent

                        Rectangle {
                            width: parent.width / 2; height: parent.height; radius: 13
                            color: prevBtnMouse.pressed ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.35) :
                                   (prevBtnMouse.containsMouse ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.18) : "transparent")
                            scale: prevBtnMouse.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "‹ 上个"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: prevBtnMouse.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.7)
                                font.family: wsPageRoot.chosenFont
                            }
                            MouseArea {
                                id: prevBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: if (typeof Bridge !== "undefined") Bridge.switchWorkspacePrev()
                            }
                        }

                        Rectangle { width: 1; height: 12; color: Qt.rgba(1, 1, 1, 0.12); anchors.verticalCenter: parent.verticalCenter }

                        Rectangle {
                            width: parent.width / 2; height: parent.height; radius: 13
                            color: nextBtnMouse.pressed ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.35) :
                                   (nextBtnMouse.containsMouse ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.18) : "transparent")
                            scale: nextBtnMouse.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "下个 ›"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: nextBtnMouse.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.7)
                                font.family: wsPageRoot.chosenFont
                            }
                            MouseArea {
                                id: nextBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: if (typeof Bridge !== "undefined") Bridge.switchWorkspaceNext()
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2. 右侧【空间网格矩阵】（去状态提示噪点、去不明确 ↗、去剧烈光晕）
        // =====================================================================
        Item {
            width: parent.width - 144
            height: parent.height

            Flickable {
                id: wsFlickable
                anchors.fill: parent
                contentWidth: width
                contentHeight: wsGrid.height + 6
                clip: wsFlickable.contentHeight > wsFlickable.height
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    width: 3
                    policy: wsFlickable.contentHeight > wsFlickable.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 1.5; color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.4) }
                }

                Grid {
                    id: wsGrid
                    x: 2
                    y: 2
                    width: parent.width - 4 - (wsFlickable.contentHeight > wsFlickable.height ? 6 : 0)
                    columns: 2
                    spacing: 6

                    Repeater {
                        model: (wsPageRoot.wsList && wsPageRoot.wsList.length > 0) ? wsPageRoot.wsList : wsPageRoot.totalWs

                        Rectangle {
                            id: itemCard
                            readonly property var itemData: (wsPageRoot.wsList && wsPageRoot.wsList.length > 0) ? modelData : null
                            readonly property int displayBadge: {
                                if (itemData && itemData.id !== undefined && !isNaN(Number(itemData.id))) return Number(itemData.id)
                                return wsPageRoot.hasZeroWs ? index : (index + 1)
                            }
                            readonly property string wsTitle: itemData ? (itemData.name || ("桌面 " + displayBadge)) : ("桌面 " + displayBadge)
                            readonly property bool isActive: itemData ? (itemData.active === true) : (displayBadge === wsPageRoot.displayCurrentNumber)
                            readonly property var targetParam: {
                                if (itemData) {
                                    if (itemData.id && String(itemData.id).length > 2) return String(itemData.id)
                                    if (itemData.name) return String(itemData.name)
                                }
                                return wsPageRoot.hasZeroWs ? index : (index + 1)
                            }

                            width: (wsGrid.width - 6) / 2
                            height: 42
                            radius: 10

                            color: isActive ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.18) :
                                   (itemHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.035))
                            border.color: isActive ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.75) :
                                          (itemHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07))
                            border.width: isActive ? 1.5 : 1

                            scale: itemArea.pressed ? 0.96 : (itemHover.hovered ? 1.015 : 1.0)
                            Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

                            HoverHandler { id: itemHover }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                spacing: 8

                                // 编号微胶囊
                                Rectangle {
                                    width: 22; height: 22; radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: isActive ? Theme.workspace : Qt.rgba(1, 1, 1, 0.09)
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: displayBadge
                                        color: "white"
                                        font.pixelSize: 11
                                        font.weight: Font.Black
                                        font.family: "Monospace"
                                    }
                                }

                                // 空间名称
                                Text {
                                    text: wsTitle
                                    color: isActive ? "white" : Qt.rgba(1, 1, 1, 0.75)
                                    font.pixelSize: 11
                                    font.weight: isActive ? Font.Black : Font.Bold
                                    font.family: wsPageRoot.chosenFont
                                    elide: Text.ElideRight
                                    width: parent.width - 50
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item {
                                    width: 8; height: 8
                                    anchors.verticalCenter: parent.verticalCenter

                                    // 当前激活状态仅展示一颗克制纯净的实心小圆点（彻底废除晃动的光晕和不明确的 ↗）
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 5; height: 5; radius: 2.5
                                        color: "#34d399"
                                        visible: isActive
                                    }
                                }
                            }

                            MouseArea {
                                id: itemArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (typeof Bridge !== "undefined") Bridge.switchWorkspace(targetParam)
                                onWheel: (wheel) => {
                                    wheel.accepted = true
                                    wsWheelReset.restart()
                                    wsPageRoot.wsWheelAccum += wheel.angleDelta.y
                                    if (Math.abs(wsPageRoot.wsWheelAccum) >= 80) {
                                        wsPageRoot.stepWorkspace(wsPageRoot.wsWheelAccum)
                                        wsPageRoot.wsWheelAccum = 0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}