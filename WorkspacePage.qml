import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: wsPageRoot

    property string chosenFont: ""
    property int currentWs: 1
    property int totalWs: 4
    property string currentWsName: "Desktop 1"
    property var wsList: []

    // 智能获取真实桌面总数
    readonly property int effectiveTotal: Math.max(1, (wsList && wsList.length > 0) ? wsList.length : totalWs)

    // 智能计算自然数当前序号（1..N）
    readonly property int displayCurrentNumber: {
        if (wsList && wsList.length > 0) {
            for (var i = 0; i < wsList.length; i++) {
                if (wsList[i] && wsList[i].active) return (i + 1)
            }
        }
        return Math.max(1, currentWs)
    }

    // 面板内部支持直接滚动滚轮切换桌面
    MouseArea {
        anchors.fill: parent
        z: -1
        onWheel: (wheel) => {
            if (typeof Bridge !== "undefined") {
                if (wheel.angleDelta.y > 0) Bridge.switchWorkspacePrev()
                else if (wheel.angleDelta.y < 0) Bridge.switchWorkspaceNext()
            }
        }
    }

    Row {
        anchors.fill: parent
        spacing: 14

        // 1. 左侧状态看板
        Rectangle {
            width: 142
            height: parent.height
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(168, 85, 247, 0.25)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 6
                width: parent.width - 24

                Row {
                    spacing: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle { width: 6; height: 6; radius: 3; color: "#a855f7"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "WORKSPACE"; font.pixelSize: 9; font.weight: Font.Black; color: "#a855f7"; font.family: wsPageRoot.chosenFont; font.letterSpacing: 0.8 }
                }

                Text {
                    text: wsPageRoot.displayCurrentNumber
                    color: "white"
                    font.pixelSize: 48
                    font.weight: Font.Black
                    font.family: (wsPageRoot.chosenFont !== "") ? wsPageRoot.chosenFont : "Monospace"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: wsPageRoot.currentWsName ? wsPageRoot.currentWsName : ("工作区 " + wsPageRoot.displayCurrentNumber)
                    color: Qt.rgba(1, 1, 1, 0.85)
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.family: wsPageRoot.chosenFont
                    elide: Text.ElideRight
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "共 " + wsPageRoot.effectiveTotal + " 个虚拟桌面"
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: 9
                    font.family: wsPageRoot.chosenFont
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Item { height: 2 }

                Row {
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: 44; height: 24; radius: 12
                        opacity: wsPageRoot.effectiveTotal > 1 ? 1.0 : 0.35
                        color: prevArea.containsMouse ? Qt.rgba(168, 85, 247, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(168, 85, 247, 0.35)
                        border.width: 1
                        Text { anchors.centerIn: parent; text: "‹ 上个"; color: "white"; font.pixelSize: 9; font.weight: Font.Bold; font.family: wsPageRoot.chosenFont }
                        MouseArea {
                            id: prevArea; anchors.fill: parent; cursorShape: wsPageRoot.effectiveTotal > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: wsPageRoot.effectiveTotal > 1
                            onClicked: if (typeof Bridge !== "undefined") Bridge.switchWorkspacePrev()
                        }
                    }

                    Rectangle {
                        width: 44; height: 24; radius: 12
                        opacity: wsPageRoot.effectiveTotal > 1 ? 1.0 : 0.35
                        color: nextArea.containsMouse ? Qt.rgba(168, 85, 247, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(168, 85, 247, 0.35)
                        border.width: 1
                        Text { anchors.centerIn: parent; text: "下个 ›"; color: "white"; font.pixelSize: 9; font.weight: Font.Bold; font.family: wsPageRoot.chosenFont }
                        MouseArea {
                            id: nextArea; anchors.fill: parent; cursorShape: wsPageRoot.effectiveTotal > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: wsPageRoot.effectiveTotal > 1
                            onClicked: if (typeof Bridge !== "undefined") Bridge.switchWorkspaceNext()
                        }
                    }
                }
            }
        }

        // 2. 右侧工作区矩阵自适应容器（支持动态无限拓展）
        Column {
            width: parent.width - 156
            height: parent.height
            spacing: 6

            Item {
                width: parent.width; height: 22
                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "点击快速直达"
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.family: wsPageRoot.chosenFont
                }

                Text {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: wsGridFlickable.contentHeight > wsGridFlickable.height ? "可上下滑动查看 ↕" : ""
                    color: Qt.rgba(168, 85, 247, 0.6)
                    font.pixelSize: 9
                    font.family: wsPageRoot.chosenFont
                }
            }

            // 🚀 核心自适应滚动视口
            Flickable {
                id: wsGridFlickable
                width: parent.width
                height: parent.height - 28
                contentWidth: width
                contentHeight: wsGrid.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    width: 3
                    policy: wsGridFlickable.contentHeight > wsGridFlickable.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        radius: 1.5
                        color: Qt.rgba(168, 85, 247, 0.45)
                    }
                }

                Grid {
                    id: wsGrid
                    width: parent.width - (wsGridFlickable.contentHeight > wsGridFlickable.height ? 6 : 0)
                    columns: 2
                    spacing: 6

                    Repeater {
                        model: (wsPageRoot.wsList && wsPageRoot.wsList.length > 0) ? wsPageRoot.wsList : wsPageRoot.totalWs

                        Rectangle {
                            readonly property var itemData: (wsPageRoot.wsList && wsPageRoot.wsList.length > 0) ? modelData : null
                            readonly property int displayBadge: index + 1
                            readonly property string wsTitle: itemData ? (itemData.name || ("工作区 " + displayBadge)) : ("工作区 " + displayBadge)
                            readonly property bool isActive: itemData ? (itemData.active === true) : (displayBadge === wsPageRoot.displayCurrentNumber)
                            readonly property var targetParam: {
                                if (itemData) {
                                    if (itemData.id && String(itemData.id).length > 2) return String(itemData.id)
                                    if (itemData.name) return String(itemData.name)
                                }
                                return (index + 1)
                            }

                            width: (wsGrid.width - 6) / 2
                            height: 38
                            radius: 8
                            color: isActive ? Qt.rgba(168, 85, 247, 0.22) : (itemHover.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04))
                            border.color: isActive ? "#a855f7" : Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1
                            scale: itemArea.pressed ? 0.96 : (itemHover.hovered ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: itemHover }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Rectangle {
                                    width: 20; height: 20; radius: 10
                                    color: isActive ? "#a855f7" : Qt.rgba(1, 1, 1, 0.12)
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: displayBadge
                                        color: "white"
                                        font.pixelSize: 10
                                        font.weight: Font.Black
                                        font.family: "Monospace"
                                    }
                                }

                                Text {
                                    text: wsTitle
                                    color: isActive ? "white" : Qt.rgba(1, 1, 1, 0.75)
                                    font.pixelSize: 11
                                    font.weight: isActive ? Font.Black : Font.Bold
                                    font.family: wsPageRoot.chosenFont
                                    elide: Text.ElideRight
                                    width: parent.width - 64
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: isActive ? "●" : "↗"
                                    color: isActive ? "#34d399" : Qt.rgba(1, 1, 1, 0.25)
                                    font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: itemArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof Bridge !== "undefined") Bridge.switchWorkspace(targetParam)
                                }
                                onWheel: (wheel) => {
                                    if (typeof Bridge !== "undefined") {
                                        if (wheel.angleDelta.y > 0) Bridge.switchWorkspacePrev()
                                        else if (wheel.angleDelta.y < 0) Bridge.switchWorkspaceNext()
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