// ==========================================
// 📄 File: ui/components/expanded/ExpandedHeaderBar.qml
// 🌟 展开态顶栏 (唯一合法的滚轮切页专属热区版)
// ==========================================
import QtQuick

Item {
    id: barRoot
    width: parent.width
    height: 26

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont

    property string expandedTab: "workspace"
    property bool isCalling: false
    property var enabledTabs: []
    property var tabMeta: ({})

    signal tabWheel(var wheel)
    signal switchRoute(string targetTab)
    signal requestSettings()

    Rectangle {
        id: outerCapsule
        anchors.fill: parent
        radius: height / 2

        color: capsuleHover.hovered ? Qt.rgba(1, 1, 1, 0.065) : Qt.rgba(1, 1, 1, 0.035)
        border.color: capsuleHover.hovered ?
                      Qt.rgba(barRoot.tabMeta.color.r, barRoot.tabMeta.color.g, barRoot.tabMeta.color.b, 0.35) :
                      Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

        HoverHandler { id: capsuleHover }

        // 🚀【核心铁律】：这是全系统唯一合法响应滚轮切页的地方！
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                event.accepted = true;
                barRoot.tabWheel(event);
            }
        }

        // 左侧模块标题与摘要
        Item {
            id: leftContentArea
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            width: Math.max(40, outerCapsule.width - rightControlsRow.width - 24)

            Row {
                id: titleRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                width: parent.width

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: barRoot.tabMeta.color
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    text: barRoot.tabMeta.title
                    color: barRoot.tabMeta.color
                    font.pixelSize: 10
                    font.weight: Font.Black
                    font.letterSpacing: 0.8
                    font.family: barRoot.effectiveFont
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Text {
                    text: "·"
                    color: Qt.rgba(1, 1, 1, 0.25)
                    font.pixelSize: 10
                    font.weight: Font.Black
                    anchors.verticalCenter: parent.verticalCenter
                    visible: barRoot.tabMeta.sub !== ""
                }

                Text {
                    text: barRoot.tabMeta.sub
                    color: "white"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.family: barRoot.effectiveFont
                    elide: Text.ElideRight
                    width: Math.max(20, titleRow.width - parent.children[0].width - parent.children[1].implicitWidth - (parent.children[2].visible ? parent.children[2].implicitWidth : 0) - 18)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: barRoot.tabMeta.sub !== ""
                }
            }
        }

        // 右侧控制区 (小圆点指示器 + 设置齿轮)
        Row {
            id: rightControlsRow
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Row {
                id: dotsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                visible: !barRoot.isCalling && barRoot.enabledTabs && barRoot.enabledTabs.length > 1

                Repeater {
                    model: barRoot.enabledTabs || []
                    Item {
                        id: tabSlotItem
                        readonly property bool isCurrent: (barRoot.expandedTab === modelData.key)
                        width: isCurrent ? 16 : 6; height: 18
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.animFast
                                easing.type: Theme.curveSpring
                                easing.overshoot: Theme.springOvershootNormal
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width; height: 4; radius: 2
                            color: tabSlotItem.isCurrent ? (modelData.color ? modelData.color : Theme.workspace) : (tabMouseArea.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.28))
                            scale: tabSlotItem.isCurrent ? 1.0 : (tabMouseArea.containsMouse ? 1.3 : 1.0)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            Behavior on scale { NumberAnimation { duration: Theme.animInstant; easing.type: Theme.curveDecel } }
                        }

                        MouseArea {
                            id: tabMouseArea
                            anchors.fill: parent; anchors.margins: -4
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: barRoot.switchRoute(modelData.key)
                            onWheel: (wheel) => barRoot.tabWheel(wheel)
                        }
                    }
                }
            }

            Rectangle { width: 1; height: 12; color: Qt.rgba(1, 1, 1, 0.15); anchors.verticalCenter: parent.verticalCenter }

            // 设置按钮
            Rectangle {
                id: settingsBtn
                width: 20; height: 20; radius: 10
                anchors.verticalCenter: parent.verticalCenter
                color: setHover.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.06)
                border.color: setHover.hovered ? "#38bdf8" : "transparent"
                border.width: 1
                scale: setTap.pressed ? 0.9 : (setHover.hovered ? 1.08 : 1.0)

                Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                Behavior on color { ColorAnimation { duration: Theme.animInstant } }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -0.5
                    text: "⚙"
                    color: setHover.hovered ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: 12
                    font.bold: true
                }

                HoverHandler { id: setHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: setTap
                    onTapped: barRoot.requestSettings()
                }
            }
        }
    }
}