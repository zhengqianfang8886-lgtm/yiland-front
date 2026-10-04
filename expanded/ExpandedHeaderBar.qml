// ==========================================
// 📄 File: expanded/ExpandedHeaderBar.qml
// ==========================================
import QtQuick

Item {
    id: barRoot
    width: parent.width
    height: 26

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont

    property string expandedTab: "workspace"
    property string previousTab: "workspace"
    property bool isCalling: false
    property var enabledTabs: []
    property var tabMeta: ({})

    signal tabWheel(var wheel)
    signal switchRoute(string targetTab, string targetSubPage)

    // =========================================================================
    // 🌟 方案 A：通栏一体式中控外层胶囊底托
    // =========================================================================
    Rectangle {
        id: outerCapsule
        anchors.fill: parent
        radius: height / 2

        // 默认极淡半透明毛玻璃底，鼠标悬浮时随当前模块主题色微光呼吸
        color: capsuleHover.hovered ? Qt.rgba(1, 1, 1, 0.065) : Qt.rgba(1, 1, 1, 0.035)
        border.color: capsuleHover.hovered ?
                      Qt.rgba(barRoot.tabMeta.color.r, barRoot.tabMeta.color.g, barRoot.tabMeta.color.b, 0.35) :
                      Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        HoverHandler { id: capsuleHover }

        // 🚀 全胶囊域滚轮捕捉：顶栏任何空白或内容区域滑动皆可切页
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => barRoot.tabWheel(event)
        }

        // =====================================================================
        // 1. 左侧：一体化自然内嵌面包屑标题（无任何生硬边框）
        // =====================================================================
        Item {
            id: leftContentArea
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            width: Math.max(40, outerCapsule.width - rightControlsRow.width - 24)

            readonly property bool isPowerPage: (barRoot.expandedTab === "power" && !barRoot.isCalling)

            // 返回会话态指示
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                visible: leftContentArea.isPowerPage

                Text { text: "‹"; color: "#ef4444"; font.pixelSize: 14; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "返回工作台"; color: powerBackHover.hovered ? "#ef4444" : "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: barRoot.effectiveFont; anchors.verticalCenter: parent.verticalCenter }

                HoverHandler { id: powerBackHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: barRoot.switchRoute(barRoot.previousTab || "workspace", "")
                }
            }

            // 常态标题行：直接自然排布在胶囊内
            Row {
                id: titleRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: !leftContentArea.isPowerPage
                width: parent.width

                // 模块主色发光原点
                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: barRoot.tabMeta.color
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                // 主分类英文标题
                Text {
                    text: barRoot.tabMeta.title
                    color: barRoot.tabMeta.color
                    font.pixelSize: 10
                    font.weight: Font.Black
                    font.letterSpacing: 0.8
                    font.family: barRoot.effectiveFont
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                // 分隔圆点
                Text {
                    text: "·"
                    color: Qt.rgba(1, 1, 1, 0.25)
                    font.pixelSize: 10
                    font.weight: Font.Black
                    anchors.verticalCenter: parent.verticalCenter
                    visible: barRoot.tabMeta.sub !== ""
                }

                // 中文副标题/状态提示
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

        // =====================================================================
        // 2. 右侧：直接内嵌切页点阵与一体电源键（无多余嵌套框）
        // =====================================================================
        Row {
            id: rightControlsRow
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // 2.1 Tab 指示点一体阵列（直接落在大胶囊轨道上）
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
                        width: isCurrent ? 18 : 6; height: 18
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width; height: 4; radius: 2
                            color: tabSlotItem.isCurrent ? (modelData.color ? modelData.color : Theme.workspace) : (tabMouseArea.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.28))
                            scale: tabSlotItem.isCurrent ? 1.0 : (tabMouseArea.containsMouse ? 1.3 : 1.0)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 100 } }
                        }

                        MouseArea {
                            id: tabMouseArea
                            anchors.fill: parent; anchors.margins: -4
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: barRoot.switchRoute(modelData.key, "")
                            onWheel: (wheel) => barRoot.tabWheel(wheel)
                        }
                    }
                }
            }

            // 2.2 细微内嵌分割竖线
            Rectangle {
                width: 1
                height: 10
                radius: 0.5
                color: Qt.rgba(1, 1, 1, 0.12)
                anchors.verticalCenter: parent.verticalCenter
                visible: !barRoot.isCalling && barRoot.enabledTabs && barRoot.enabledTabs.length > 1
            }

            // 2.3 电源按键：作为胶囊内嵌右侧旋钮
            Rectangle {
                id: powerBtn
                width: 20
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: !barRoot.isCalling

                readonly property bool isPowerActive: (barRoot.expandedTab === "power")
                color: isPowerActive ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.28) :
                       (powerHover.hovered ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.18) : Qt.rgba(1, 1, 1, 0.05))
                border.color: (isPowerActive || powerHover.hovered) ? "#ef4444" : "transparent"
                border.width: 1

                scale: powerTap.pressed ? 0.90 : (powerHover.hovered ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "⏻"
                    font.pixelSize: 10
                    font.weight: Font.Black
                    color: (powerBtn.isPowerActive || powerHover.hovered) ? "#ef4444" : Qt.rgba(1, 1, 1, 0.70)
                }

                HoverHandler { id: powerHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: powerTap
                    onTapped: {
                        if (barRoot.expandedTab === "power") {
                            barRoot.switchRoute(barRoot.previousTab || "workspace", "")
                        } else {
                            barRoot.switchRoute("power", "")
                        }
                    }
                }
            }
        }
    }
}