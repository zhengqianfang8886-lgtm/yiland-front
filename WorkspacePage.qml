import QtQuick
import QtQuick.Controls

Item {
    id: wsPageRoot

    property string chosenFont: ""
    property int currentWs: 1
    property int totalWs: 4
    property string currentWsName: "Desktop 1"
    property var wsList: []

    readonly property int effectiveTotal: Math.max(1, (wsList && wsList.length > 0) ? wsList.length : totalWs)

    readonly property int displayCurrentNumber: {
        if (wsList && wsList.length > 0) {
            for (var i = 0; i < wsList.length; i++) {
                if (wsList[i] && wsList[i].active) return (i + 1)
            }
        }
        return Math.max(1, currentWs)
    }

    property real wsWheelAccum: 0
    Timer { id: wsWheelReset; interval: 260; onTriggered: wsPageRoot.wsWheelAccum = 0 }

    function stepWorkspace(delta) {
        if (typeof Bridge === "undefined") return
        if (delta > 0) Bridge.switchWorkspacePrev()
        else Bridge.switchWorkspaceNext()
    }

    // 全局防漏拦截滚轮切桌面
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

        // ==========================================
        // 1. 左侧【核心工作区看板】(Bento 极简微光卡片)
        // ==========================================
        Rectangle {
            id: leftDashboard
            width: 136
            height: parent.height
            radius: Theme.radiusCard
            color: Qt.rgba(1, 1, 1, 0.035)
            border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.22)
            border.width: 1

            // 内部微光渐变层
            Rectangle {
                anchors.fill: parent; radius: parent.radius; z: 0
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 0
                z: 1

                // 1.1 顶栏：呼吸指示灯 + 模块标签
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    height: 18

                    // 看板顶栏呼吸灯
                    Item {
                        width: 8; height: 8
                        anchors.verticalCenter: parent.verticalCenter

                        // 呼吸发光外圈
                        Rectangle {
                            anchors.centerIn: parent
                            width: 14; height: 14; radius: 7
                            color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.4)
                            SequentialAnimation on scale {
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.8; to: 1.35; duration: 1600; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1.35; to: 0.8; duration: 1600; easing.type: Easing.InOutSine }
                            }
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.2; to: 0.7; duration: 1600; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 0.7; to: 0.2; duration: 1600; easing.type: Easing.InOutSine }
                            }
                        }

                        // 核心实心点
                        Rectangle {
                            anchors.centerIn: parent
                            width: 5; height: 5; radius: 2.5
                            color: Theme.workspace
                        }
                    }

                    Text {
                        text: "WORKSPACE"
                        font.pixelSize: 9
                        font.weight: Font.Black
                        color: Theme.workspace
                        font.family: wsPageRoot.chosenFont
                        font.letterSpacing: 0.9
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Item { height: 4 }

                // 1.2 核心巨幅数字 (带切桌面弹性微动效)
                Item {
                    width: parent.width
                    height: 52

                    Text {
                        id: wsNumText
                        anchors.centerIn: parent
                        text: wsPageRoot.displayCurrentNumber
                        color: "white"
                        font.pixelSize: 44
                        font.weight: Font.Black
                        font.family: (wsPageRoot.chosenFont !== "") ? wsPageRoot.chosenFont : "Monospace"

                        // 数字切换时带有一点灵动弹跳缩放
                        Behavior on text {
                            SequentialAnimation {
                                NumberAnimation { target: wsNumText; property: "scale"; to: 0.86; duration: 60; easing.type: Easing.OutQuad }
                                NumberAnimation { target: wsNumText; property: "scale"; to: 1.0; duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                            }
                        }
                    }
                }

                // 1.3 当前桌面名 (胶囊标签质感)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 20
                    radius: 10
                    width: Math.min(parent.width - 8, wsNameLabel.implicitWidth + 14)
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        id: wsNameLabel
                        anchors.centerIn: parent
                        text: wsPageRoot.currentWsName ? wsPageRoot.currentWsName : ("桌面 " + wsPageRoot.displayCurrentNumber)
                        color: "white"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.family: wsPageRoot.chosenFont
                        elide: Text.ElideRight
                        width: parent.width - 12
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Item { height: 4 }

                // 1.4 总数摘要
                Text {
                    text: "共 " + wsPageRoot.effectiveTotal + " 个空间"
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.family: wsPageRoot.chosenFont
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Item { height: 8 }

                // 1.5 底部切换双连药丸按钮 (带微交互弹性)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 98; height: 24; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.3)
                    border.width: 1

                    Row {
                        anchors.fill: parent

                        // 左半边：上一页
                        Rectangle {
                            width: parent.width / 2; height: parent.height; radius: 12
                            color: prevBtnMouse.pressed ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.4) :
                                   (prevBtnMouse.containsMouse ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.2) : "transparent")
                            scale: prevBtnMouse.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text { anchors.centerIn: parent; text: "‹ 上个"; font.pixelSize: 9; font.weight: Font.Bold; color: "white"; font.family: wsPageRoot.chosenFont }
                            MouseArea {
                                id: prevBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: if (typeof Bridge !== "undefined") Bridge.switchWorkspacePrev()
                            }
                        }

                        // 分割细线
                        Rectangle { width: 1; height: 12; color: Qt.rgba(1, 1, 1, 0.12); anchors.verticalCenter: parent.verticalCenter }

                        // 右半边：下一页
                        Rectangle {
                            width: parent.width / 2; height: parent.height; radius: 12
                            color: nextBtnMouse.pressed ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.4) :
                                   (nextBtnMouse.containsMouse ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.2) : "transparent")
                            scale: nextBtnMouse.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text { anchors.centerIn: parent; text: "下个 ›"; font.pixelSize: 9; font.weight: Font.Bold; color: "white"; font.family: wsPageRoot.chosenFont }
                            MouseArea {
                                id: nextBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: if (typeof Bridge !== "undefined") Bridge.switchWorkspaceNext()
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // 2. 右侧【桌面矩阵】(通透条目 + 活力呼吸光晕)
        // ==========================================
        Column {
            width: parent.width - 148
            height: parent.height
            spacing: 6

            // 2.1 顶部微提示栏
            Item {
                width: parent.width; height: 18

                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "点击直达桌面"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.family: wsPageRoot.chosenFont
                }

                // 极简微徽章
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    opacity: 0.65

                    Text { text: "🖱️"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "滚轮速切"
                        color: Theme.workspace
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.family: wsPageRoot.chosenFont
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // 2.2 虚拟桌面网格列表
            Flickable {
                id: wsFlickable
                width: parent.width
                height: parent.height - 24
                contentWidth: width
                contentHeight: wsGrid.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    width: 3
                    policy: wsFlickable.contentHeight > wsFlickable.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 1.5; color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.4) }
                }

                Grid {
                    id: wsGrid
                    width: parent.width - (wsFlickable.contentHeight > wsFlickable.height ? 6 : 0)
                    columns: 2
                    spacing: 6

                    Repeater {
                        model: (wsPageRoot.wsList && wsPageRoot.wsList.length > 0) ? wsPageRoot.wsList : wsPageRoot.totalWs

                        Rectangle {
                            id: itemCard
                            readonly property var itemData: (wsPageRoot.wsList && wsPageRoot.wsList.length > 0) ? modelData : null
                            readonly property int displayBadge: index + 1
                            readonly property string wsTitle: itemData ? (itemData.name || ("桌面 " + displayBadge)) : ("桌面 " + displayBadge)
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
                            radius: 10
                            
                            // 选中时带有通透紫色微发光，未选中时轻量灰度
                            color: isActive ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.16) :
                                   (itemHover.hovered ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.035))
                            border.color: isActive ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.65) :
                                          (itemHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06))
                            border.width: isActive ? 1.2 : 1

                            scale: itemArea.pressed ? 0.96 : (itemHover.hovered ? 1.015 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            HoverHandler { id: itemHover }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                spacing: 7

                                // 数字徽章
                                Rectangle {
                                    width: 20; height: 20; radius: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: isActive ? Theme.workspace : Qt.rgba(1, 1, 1, 0.08)
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: displayBadge
                                        color: "white"
                                        font.pixelSize: 10
                                        font.weight: Font.Black
                                        font.family: "Monospace"
                                    }
                                }

                                // 桌面标题
                                Text {
                                    text: wsTitle
                                    color: isActive ? "white" : Qt.rgba(1, 1, 1, 0.75)
                                    font.pixelSize: 11
                                    font.weight: isActive ? Font.Black : Font.Bold
                                    font.family: wsPageRoot.chosenFont
                                    elide: Text.ElideRight
                                    width: parent.width - 54
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // 🚀 活力双层呼吸灯 (仅在当前激活桌面上绽放)
                                Item {
                                    width: 14; height: 14
                                    anchors.verticalCenter: parent.verticalCenter

                                    // 外层光晕波纹 (Halo Ripple)
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 14; height: 14; radius: 7
                                        color: Qt.rgba(52, 211, 153, 0.35)
                                        visible: isActive

                                        SequentialAnimation on scale {
                                            running: isActive
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.6; to: 1.4; duration: 1400; easing.type: Easing.InOutSine }
                                            NumberAnimation { from: 1.4; to: 0.6; duration: 1400; easing.type: Easing.InOutSine }
                                        }
                                        SequentialAnimation on opacity {
                                            running: isActive
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.2; to: 0.75; duration: 1400; easing.type: Easing.InOutSine }
                                            NumberAnimation { from: 0.75; to: 0.2; duration: 1400; easing.type: Easing.InOutSine }
                                        }
                                    }

                                    // 内层核心发光微珠
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 5; height: 5; radius: 2.5
                                        color: isActive ? "#34d399" : "transparent"
                                        visible: isActive

                                        SequentialAnimation on opacity {
                                            running: isActive
                                            loops: Animation.Infinite
                                            NumberAnimation { from: 0.7; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                                            NumberAnimation { from: 1.0; to: 0.7; duration: 700; easing.type: Easing.InOutQuad }
                                        }
                                    }

                                    // 未激活时的淡灰色微小箭头
                                    Text {
                                        anchors.centerIn: parent
                                        text: "↗"
                                        color: itemHover.hovered ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(1, 1, 1, 0.2)
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        visible: !isActive
                                    }
                                }
                            }

                            MouseArea {
                                id: itemArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
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