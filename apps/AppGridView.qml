// ==========================================
// 📄 File: apps/AppGridView.qml
// 🌟 导出子项悬停状态 · 彻底防止父容器失焦
// ==========================================
import QtQuick

Item {
    id: gridViewRoot
    anchors.fill: parent
    anchors.margins: 14

    property string hoveredAppName: ""
    property string activeDeleteId: ""

    // 🚀【核心属性】：告知外壳当前是否有任何子项目（图标或加号）正被鼠标悬停
    readonly property bool hasActiveChildHover: (hoveredAppName !== "") || addSlotItem.isHovered

    signal requestAdd()
    signal requestLaunch(string appId)
    signal requestDelete(string appId)

    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: gridViewRoot.activeDeleteId = ""
    }

    Flickable {
        id: appFlickable
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.bottom: tooltipPill.top
        anchors.bottomMargin: 4
        width: parent.width
        contentWidth: width
        contentHeight: appGrid.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        z: 1

        Grid {
            id: appGrid
            width: parent.width
            columns: 4
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: (typeof Bridge !== "undefined") ? Bridge.appModel : null

                Rectangle {
                    id: appSlot
                    width: 42
                    height: 42
                    radius: 10

                    scale: slotMouse.pressed ? 0.94 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.animInstant; easing.type: Easing.OutQuad } }

                    color: slotMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.04)
                    border.color: slotMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.35) : Qt.rgba(255, 255, 255, 0.08)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                    Image {
                        id: appIconImg
                        anchors.centerIn: parent
                        width: 28; height: 28
                        fillMode: Image.PreserveAspectFit
                        source: model.icon || ""
                        sourceSize.width: 56; sourceSize.height: 56
                        visible: status === Image.Ready && source != ""
                        smooth: true
                        asynchronous: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: model.name ? model.name.charAt(0).toUpperCase() : "🚀"
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        visible: !appIconImg.visible
                    }

                    Rectangle {
                        id: deleteBadge
                        width: 16
                        height: 16
                        radius: 8
                        color: Theme.danger

                        anchors.top: parent.top
                        anchors.topMargin: 1
                        anchors.right: parent.right
                        anchors.rightMargin: 1
                        visible: gridViewRoot.activeDeleteId === model.appId
                        z: 20

                        border.color: "#14141c"
                        border.width: 1.5

                        scale: delMouse.pressed ? 0.85 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.animInstant } }

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: "white"
                            font.pixelSize: 8
                            font.weight: Font.Black
                        }

                        MouseArea {
                            id: delMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                mouse.accepted = true
                                gridViewRoot.requestDelete(model.appId)
                                gridViewRoot.activeDeleteId = ""
                            }
                        }
                    }

                    MouseArea {
                        id: slotMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onEntered: gridViewRoot.hoveredAppName = model.name
                        onExited: {
                            if (gridViewRoot.hoveredAppName === model.name) gridViewRoot.hoveredAppName = ""
                        }

                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                if (gridViewRoot.activeDeleteId !== "") {
                                    gridViewRoot.activeDeleteId = ""
                                    return
                                }
                                gridViewRoot.requestLaunch(model.appId)
                            } else if (mouse.button === Qt.RightButton) {
                                gridViewRoot.activeDeleteId = (gridViewRoot.activeDeleteId === model.appId) ? "" : model.appId
                            }
                        }
                    }
                }
            }

            AppAddSlot {
                id: addSlotItem
                onClicked: gridViewRoot.requestAdd()
                onHoverChanged: (hovered) => {
                    if (hovered) gridViewRoot.hoveredAppName = "配置并管理应用"
                    else if (gridViewRoot.hoveredAppName === "配置并管理应用") gridViewRoot.hoveredAppName = ""
                }
            }
        }
    }

    Rectangle {
        id: tooltipPill
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: 20
        radius: 10
        width: Math.min(parent.width - 16, tooltipText.implicitWidth + 18)
        color: Qt.rgba(26 / 255, 30 / 255, 42 / 255, 0.95)
        border.color: Qt.rgba(255, 255, 255, 0.18)
        border.width: 1

        visible: opacity > 0.01
        opacity: gridViewRoot.hoveredAppName ? 1.0 : 0.0
        scale: gridViewRoot.hoveredAppName ? 1.0 : 0.92

        Behavior on opacity { NumberAnimation { duration: Theme.animInstant; easing.type: Theme.curveFluid } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveDecel } }

        Row {
            anchors.centerIn: parent
            spacing: 4
            Rectangle { width: 4; height: 4; radius: 2; color: "#38bdf8"; anchors.verticalCenter: parent.verticalCenter }
            Text {
                id: tooltipText
                text: gridViewRoot.hoveredAppName
                color: "white"
                font.pixelSize: 10
                font.weight: Font.Bold
                font.family: Theme.activeFont
                elide: Text.ElideRight
            }
        }
    }
}