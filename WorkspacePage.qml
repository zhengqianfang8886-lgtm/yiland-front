import QtQuick
import QtQuick.Controls

Item {
    id: wsPageRoot

    property string chosenFont: ""
    property int currentWs: 0
    property int totalWs: 5
    property string currentWsName: "Main"
    property var wsList: []

    readonly property bool isVisibleOnScreen: wsPageRoot.visible && wsPageRoot.opacity > 0.1
    readonly property int effectiveTotal: Math.max(1, (wsList && wsList.length > 0) ? wsList.length : totalWs)

    // 🚀【核心修复】：Main 严格作为 0 号起始，多空间编号全局一致
    function getWorkspaceNumber(itemData, idx) {
        if (itemData && typeof itemData === "object") {
            if (itemData.id !== undefined && itemData.id !== null && !isNaN(Number(itemData.id))) {
                return Number(itemData.id)
            }
            if (itemData.index !== undefined && itemData.index !== null && !isNaN(Number(itemData.index))) {
                return Number(itemData.index)
            }
        }
        return idx
    }

    // 当前活跃工作区的真实编号（从 0 开始）
    readonly property int displayCurrentNumber: {
        if (wsList && wsList.length > 0) {
            for (var i = 0; i < wsList.length; i++) {
                var item = wsList[i]
                if (item && typeof item === "object" && item.active) {
                    return getWorkspaceNumber(item, i)
                }
            }
        }
        return currentWs
    }

    // 当前在列表中的槽位索引（0 ~ total-1）
    readonly property int currentSlotIndex: {
        if (wsList && wsList.length > 0) {
            for (var i = 0; i < wsList.length; i++) {
                var item = wsList[i]
                if (item) {
                    if (typeof item === "object" && item.active) return i
                    if (getWorkspaceNumber(item, i) === displayCurrentNumber) return i
                }
            }
        }
        return Math.max(0, Math.min(displayCurrentNumber, effectiveTotal - 1))
    }

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
        // 1. 左侧【苹果 Bento 空间聚焦卡片】（零文字截断、苹果分页点）
        // =====================================================================
        Rectangle {
            id: leftDashboard
            width: 136
            height: parent.height
            radius: Theme.radiusCard
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(255, 255, 255, 0.1)
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 0

                // 顶栏：微型状态标签与当前序号
                Item {
                    width: parent.width
                    height: 18

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Rectangle {
                            width: 5; height: 5; radius: 2.5
                            color: Theme.workspace
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "当前空间"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.family: wsPageRoot.chosenFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: (wsPageRoot.currentSlotIndex + 1) + " of " + wsPageRoot.effectiveTotal
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.family: "Monospace"
                    }
                }

                Item { height: 6 }

                // 核心英雄区：纵向层次排版（彻底解决 Pers... 截断硬伤）
                Rectangle {
                    width: parent.width
                    height: 60
                    radius: 10
                    color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.14)
                    border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.32)
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 2

                        Row {
                            spacing: 6
                            anchors.horizontalCenter: parent.horizontalCenter

                            // 0 起始数字徽标
                            Rectangle {
                                width: 20; height: 20; radius: 6
                                color: Theme.workspace
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: heroNumText
                                    anchors.centerIn: parent
                                    text: wsPageRoot.displayCurrentNumber
                                    color: "white"
                                    font.pixelSize: 11
                                    font.weight: Font.Black
                                    font.family: (wsPageRoot.chosenFont !== "") ? wsPageRoot.chosenFont : "Monospace"

                                    Behavior on text {
                                        SequentialAnimation {
                                            NumberAnimation { target: heroNumText; property: "scale"; to: 0.85; duration: 40; easing.type: Easing.OutQuad }
                                            NumberAnimation { target: heroNumText; property: "scale"; to: 1.0; duration: 110; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                        }
                                    }
                                }
                            }

                            // 完整无截断桌面名称
                            Text {
                                text: wsPageRoot.currentWsName ? wsPageRoot.currentWsName : ("桌面 " + wsPageRoot.displayCurrentNumber)
                                color: "white"
                                font.pixelSize: 14
                                font.weight: Font.Black
                                font.family: wsPageRoot.chosenFont
                                elide: Text.ElideRight
                                width: parent.parent.width - 30
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            text: "活跃工作区"
                            color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.9)
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.family: wsPageRoot.chosenFont
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                Item { height: 8 }

                // 苹果同款分页微胶囊（根据空间总数自动舒展与高亮）
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    height: 6

                    Repeater {
                        model: wsPageRoot.effectiveTotal

                        Rectangle {
                            readonly property bool isCurrent: (index === wsPageRoot.currentSlotIndex)
                            width: isCurrent ? 14 : 4
                            height: 4
                            radius: 2
                            color: isCurrent ? Theme.workspace : Qt.rgba(1, 1, 1, 0.22)
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                }

                Item { height: 8 }

                // 底部切页操作微胶囊
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
        // 2. 右侧【macOS Spaces 矩阵】（0-indexed 对齐、苹果微光质感）
        // =====================================================================
        Item {
            width: parent.width - 148
            height: parent.height

            Flickable {
                id: wsFlickable
                anchors.fill: parent
                contentWidth: width
                contentHeight: wsGrid.height + 4
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
                            
                            // 🚀 严格以 0 号为基准（Main 为 0）
                            readonly property int displayBadge: wsPageRoot.getWorkspaceNumber(itemData, index)
                            readonly property string wsTitle: (itemData && typeof itemData === "object") ? (itemData.name || ("桌面 " + displayBadge)) : (typeof itemData === "string" ? itemData : ("桌面 " + displayBadge))
                            readonly property bool isActive: (itemData && typeof itemData === "object" && itemData.active !== undefined) ? (itemData.active === true) : (displayBadge === wsPageRoot.displayCurrentNumber)
                            
                            readonly property var targetParam: {
                                if (itemData && typeof itemData === "object") {
                                    if (itemData.id !== undefined) return itemData.id
                                    if (itemData.name) return itemData.name
                                }
                                return displayBadge
                            }

                            width: (wsGrid.width - 6) / 2
                            height: 42
                            radius: 10

                            // 苹果质感微光背景与描边
                            color: isActive ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.16) :
                                   (itemHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.035))
                            border.color: isActive ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.72) :
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
                                    color: isActive ? Theme.workspace : Qt.rgba(1, 1, 1, 0.08)
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: displayBadge
                                        color: isActive ? "white" : Qt.rgba(1, 1, 1, 0.7)
                                        font.pixelSize: 11
                                        font.weight: Font.Black
                                        font.family: "Monospace"
                                    }
                                }

                                // 空间标题
                                Text {
                                    text: wsTitle
                                    color: isActive ? "white" : Qt.rgba(1, 1, 1, 0.8)
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

                                    // 当前空间状态绿点
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 5; height: 5; radius: 2.5
                                        color: "#10b981"
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