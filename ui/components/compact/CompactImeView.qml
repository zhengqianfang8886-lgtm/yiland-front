// ==========================================
// 📄 File: ui/components/compact/CompactImeView.qml
// 🌟 系统原生级输入法组件 (加固连击防穿透 · 任意手速秒切版)
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: imeRoot
    width: 26
    height: 24

    property string fontFam: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    readonly property bool isActive: (typeof Bridge !== "undefined" && Bridge.isImeActive !== undefined) ? Bridge.isImeActive : false
    readonly property string iconUrl: (typeof Bridge !== "undefined" && Bridge.imeIcon !== undefined) ? Bridge.imeIcon : ""
    readonly property string fallbackLabel: (typeof Bridge !== "undefined" && Bridge.imeLabel !== undefined) ? Bridge.imeLabel : "A"

    readonly property bool isMenuOpen: menuPopup.opened || subPopup.opened

    property var currentSubmenuItems: []
    property real currentSubmenuY: 0

    function closeAllMenus() {
        subPopup.close();
        menuPopup.close();
        currentSubmenuItems = [];
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onWindowDeactivated() {
            imeRoot.closeAllMenus();
        }
    }

    Rectangle {
        id: imeBox
        anchors.centerIn: parent
        width: 22
        height: 22
        radius: 5
        antialiasing: true

        color: (imeRoot.fallbackLabel === "朗" || imeRoot.fallbackLabel === "A") ? 
               (imeMouse.containsMouse ? "#2a2a34" : "#1a1a24") : 
               (imeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent")

        border.color: (imeRoot.fallbackLabel === "朗" || imeRoot.fallbackLabel === "A") ? 
                      Qt.rgba(255, 255, 255, 0.28) : 
                      (imeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent")
        border.width: 1

        scale: imeMouse.pressed ? 0.90 : 1.0
        Behavior on scale { NumberAnimation { duration: 70 } }
        Behavior on color { ColorAnimation { duration: 100 } }

        Image {
            id: sysImg
            anchors.centerIn: parent
            width: 17
            height: 17
            source: imeRoot.iconUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            cache: false
            visible: imeRoot.iconUrl !== "" && status === Image.Ready
            smooth: true
            mipmap: true
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -0.5
            text: imeRoot.fallbackLabel
            color: "#ffffff"
            font.family: imeRoot.fontFam
            font.pixelSize: (imeRoot.fallbackLabel === "A" || imeRoot.fallbackLabel === "朗") ? 13 : 11
            font.weight: Font.Black
            visible: !sysImg.visible
            renderType: Text.QtRendering
        }

        // =====================================================================
        // 🚀【核心加固点】：独占拦截点击与连击，绝对禁止事件向下穿透
        // =====================================================================
        MouseArea {
            id: imeMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            preventStealing: true  // 🚀 锁死事件所有权，严禁底层底板抢走事件
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onPressed: (mouse) => {
                mouse.accepted = true;
            }

            onClicked: (mouse) => {
                mouse.accepted = true;
                handleMouse(mouse);
            }

            onDoubleClicked: (mouse) => {
                mouse.accepted = true;
                handleMouse(mouse); // 🚀 快速连续点击也能顺畅触发切换，绝不变成展开
            }

            function handleMouse(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    imeRoot.closeAllMenus();
                    if (typeof Bridge !== "undefined" && Bridge.toggleIme) {
                        Bridge.toggleIme();
                    }
                } else if (mouse.button === Qt.RightButton) {
                    if (imeRoot.isMenuOpen) imeRoot.closeAllMenus();
                    else menuPopup.open();
                }
            }
        }
    }

    // 1. 一级主菜单
    Popup {
        id: menuPopup
        y: imeRoot.height + 8
        x: Math.round((imeRoot.width - width) / 2)
        width: 204
        padding: 6
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Overlay.modal: MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: (mouse) => {
                mouse.accepted = true;
                imeRoot.closeAllMenus();
            }
        }

        onOpened: {
            if (typeof Bridge !== "undefined") {
                if (Bridge.openFullCorridorForMotion) Bridge.openFullCorridorForMotion();
                if (Bridge.refreshImeMenu) Bridge.refreshImeMenu();
            }
        }

        onClosed: {
            subPopup.close();
            currentSubmenuItems = [];
        }

        background: Rectangle {
            color: "#1e2028"
            radius: 10
            border.color: Qt.rgba(255, 255, 255, 0.16)
            border.width: 1
        }

        contentItem: Column {
            id: menuCol
            spacing: 3
            width: parent.width

            Repeater {
                model: (typeof Bridge !== "undefined" && Bridge.imeMenuList) ? Bridge.imeMenuList : []

                delegate: Item {
                    id: rowItem
                    width: menuCol.width
                    height: modelData.isSeparator ? 8 : 30

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Qt.rgba(255, 255, 255, 0.08)
                        visible: modelData.isSeparator
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        visible: !modelData.isSeparator

                        color: (modelData.isActive || (modelData.hasSubmenu && subPopup.opened && imeRoot.currentSubmenuItems === modelData.children)) ? 
                               Qt.rgba(255, 255, 255, 0.15) : 
                               (rowMouse.containsMouse && (modelData.enabled !== false) ? Qt.rgba(255, 255, 255, 0.08) : "transparent")

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: statusBadge.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            clip: true

                            Text {
                                text: modelData.label || ""
                                color: (modelData.enabled !== false) ? "#ffffff" : Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 13
                                font.weight: modelData.isActive ? Font.Black : Font.DemiBold
                                elide: Text.ElideRight
                                width: parent.width
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.QtRendering
                            }
                        }

                        Item {
                            id: statusBadge
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12
                            height: 12
                            visible: modelData.isActive || modelData.hasSubmenu

                            Text {
                                anchors.centerIn: parent
                                text: modelData.isActive ? "●" : (modelData.hasSubmenu ? "›" : "")
                                color: modelData.isActive ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.5)
                                font.pixelSize: modelData.isActive ? 9 : 14
                                font.bold: modelData.hasSubmenu
                                renderType: Text.QtRendering
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: modelData.enabled !== false
                            cursorShape: (modelData.enabled !== false) ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onEntered: {
                                if (modelData.hasSubmenu && modelData.children && modelData.children.length > 0) {
                                    openSubmenu(modelData.children, rowItem.y);
                                } else {
                                    subPopup.close();
                                }
                            }

                            onClicked: {
                                if (modelData.hasSubmenu && modelData.children && modelData.children.length > 0) {
                                    openSubmenu(modelData.children, rowItem.y);
                                } else {
                                    imeRoot.closeAllMenus();
                                    if (typeof Bridge !== "undefined" && Bridge.activateImeMenuItem) {
                                        Bridge.activateImeMenuItem(modelData.id, modelData.uniqueName || "");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 2. 二级子菜单
    Popup {
        id: subPopup
        x: (menuPopup.x + menuPopup.width + 188 <= 660) ? (menuPopup.x + menuPopup.width + 4) : (menuPopup.x - width - 4)
        y: menuPopup.y + imeRoot.currentSubmenuY - 4
        width: 188
        padding: 6
        modal: false
        focus: false
        closePolicy: Popup.CloseOnEscape

        background: Rectangle {
            color: "#181a20"
            radius: 8
            border.color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35)
            border.width: 1
        }

        contentItem: Column {
            id: subCol
            spacing: 3
            width: parent.width

            Repeater {
                model: imeRoot.currentSubmenuItems

                delegate: Item {
                    width: subCol.width
                    height: modelData.isSeparator ? 6 : 28

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Qt.rgba(255, 255, 255, 0.08)
                        visible: modelData.isSeparator
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        visible: !modelData.isSeparator
                        color: modelData.isActive ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.22) : 
                               (subMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent")

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                text: modelData.label || ""
                                color: modelData.isActive ? "#38bdf8" : (modelData.enabled !== false ? "white" : Qt.rgba(1, 1, 1, 0.4))
                                font.pixelSize: 13
                                font.weight: modelData.isActive ? Font.Black : Font.DemiBold
                                elide: Text.ElideRight
                                width: parent.width - 18
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.QtRendering
                            }

                            Text {
                                text: modelData.isActive ? "●" : ""
                                color: "#38bdf8"
                                font.pixelSize: 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: modelData.isActive
                            }
                        }

                        MouseArea {
                            id: subMouse
                            anchors.fill: parent
                            hoverEnabled: modelData.enabled !== false
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                imeRoot.closeAllMenus();
                                if (typeof Bridge !== "undefined" && Bridge.activateImeMenuItem) {
                                    Bridge.activateImeMenuItem(modelData.id, "");
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function openSubmenu(items, anchorY) {
        currentSubmenuItems = items;
        currentSubmenuY = anchorY;
        subPopup.open();
    }
}