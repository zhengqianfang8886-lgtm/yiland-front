import QtQuick

Item {
    id: barRoot
    width: parent.width
    height: 26

    property string chosenFont: ""
    property string expandedTab: "workspace"
    property string previousTab: "workspace"
    property bool isCalling: false
    property var enabledTabs: []
    property var tabMeta: ({})

    signal tabWheel(var wheel)
    signal switchRoute(string targetTab, string targetSubPage)

    // 全行滚轮拦截区（点击穿透，任意空白处滑动皆可切页）
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => barRoot.tabWheel(wheel)
    }

    // 1. 左侧：面包屑标题微胶囊
    Rectangle {
        id: titleBadge
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: 26
        radius: 13
        z: 1

        readonly property bool isPowerPage: (barRoot.expandedTab === "power" && !barRoot.isCalling)
        width: isPowerPage ? (backRow.implicitWidth + 20) : Math.min(220, titleRow.implicitWidth + 20)

        color: badgeHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
        border.color: badgeHover.hovered ?
                      Qt.rgba(barRoot.tabMeta.color.r, barRoot.tabMeta.color.g, barRoot.tabMeta.color.b, 0.45) :
                      Qt.rgba(1, 1, 1, 0.09)
        border.width: 1

        scale: badgeTap.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
        Behavior on color { ColorAnimation { duration: Theme.animInstant } }
        Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        Row {
            id: backRow
            anchors.centerIn: parent
            spacing: 5
            visible: titleBadge.isPowerPage
            Text { text: "‹"; color: "#ef4444"; font.pixelSize: 14; font.weight: Font.Black }
            Text { text: "返回工作台"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: barRoot.chosenFont }
        }

        Row {
            id: titleRow
            anchors.centerIn: parent
            spacing: 6
            visible: !titleBadge.isPowerPage
            width: parent.width - 20

            Rectangle {
                width: 6; height: 6; radius: 3; color: barRoot.tabMeta.color
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                text: barRoot.tabMeta.title
                color: barRoot.tabMeta.color
                font.pixelSize: 10; font.weight: Font.Black; font.letterSpacing: 0.6; font.family: barRoot.chosenFont
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text { text: "·"; color: Qt.rgba(1, 1, 1, 0.3); font.pixelSize: 10; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter; visible: barRoot.tabMeta.sub !== "" }

            Text {
                text: barRoot.tabMeta.sub
                color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: barRoot.chosenFont; elide: Text.ElideRight
                width: Math.max(20, titleRow.width - 12 - parent.children[1].implicitWidth - (parent.children[2].visible ? parent.children[2].implicitWidth : 0))
                anchors.verticalCenter: parent.verticalCenter; visible: barRoot.tabMeta.sub !== ""
            }
        }

        HoverHandler { id: badgeHover; cursorShape: titleBadge.isPowerPage ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler {
            id: badgeTap
            onTapped: {
                if (titleBadge.isPowerPage) {
                    barRoot.switchRoute(barRoot.previousTab || "workspace", "")
                }
            }
        }
        WheelHandler { acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad; onWheel: (event) => barRoot.tabWheel(event) }
    }

    // 2. 右侧：一体化中控舱
    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        z: 1

        // 2.1 Tab 指示点一体舱
        Rectangle {
            id: tabTrackContainer
            height: 26; radius: 13
            width: dotsLayoutRow.implicitWidth + 18
            anchors.verticalCenter: parent.verticalCenter
            color: trackHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
            border.color: trackHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09)
            border.width: 1
            visible: !barRoot.isCalling && barRoot.enabledTabs && barRoot.enabledTabs.length > 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            HoverHandler { id: trackHover }
            WheelHandler { acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad; onWheel: (event) => barRoot.tabWheel(event) }

            Row {
                id: dotsLayoutRow
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: barRoot.enabledTabs || []
                    Item {
                        id: tabSlotItem
                        readonly property bool isCurrent: (barRoot.expandedTab === modelData.key)
                        width: isCurrent ? 18 : 6; height: 26
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width; height: 5; radius: 2.5
                            color: tabSlotItem.isCurrent ? (modelData.color ? modelData.color : Theme.workspace) : (tabMouseArea.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.32))
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
        }

        // 2.2 电源快捷按键
        Rectangle {
            id: powerQuickBtn
            width: 26; height: 26; radius: 13
            anchors.verticalCenter: parent.verticalCenter
            visible: !barRoot.isCalling

            readonly property bool isPowerActive: (barRoot.expandedTab === "power")
            color: isPowerActive ? Qt.rgba(239, 68, 68, 0.30) : (powerBtnHover.hovered ? Qt.rgba(239, 68, 68, 0.16) : Qt.rgba(1, 1, 1, 0.04))
            border.color: (isPowerActive || powerBtnHover.hovered) ? "#ef4444" : Qt.rgba(1, 1, 1, 0.09)
            border.width: 1

            scale: powerBtnTap.pressed ? 0.92 : (powerBtnHover.hovered ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent; text: "⏻"; font.pixelSize: 11; font.weight: Font.Black
                color: (powerQuickBtn.isPowerActive || powerBtnHover.hovered) ? "#ef4444" : Qt.rgba(1, 1, 1, 0.70)
            }

            HoverHandler { id: powerBtnHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: powerBtnTap
                onTapped: {
                    if (barRoot.expandedTab === "power") {
                        barRoot.switchRoute(barRoot.previousTab || "workspace", "")
                    } else {
                        barRoot.switchRoute("power", "")
                    }
                }
            }
            WheelHandler { acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad; onWheel: (event) => barRoot.tabWheel(event) }
        }
    }
}