// ==========================================
// 📄 File: ui/components/compact/CompactImeView.qml
// 🌟 系统原生级输入法组件 (Portal 菜单 · 原生零拷贝 ImageProvider 协议版)
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

    function closeAllMenus() {
        subPopup.close();
        menuPopup.close();
    }

    // 向上寻找顶级根节点，挂载 Popup 彻底防剪裁
    function getRootItem() {
        var p = imeRoot;
        while (p && p.parent) {
            p = p.parent;
        }
        return p;
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

        // 样式按当前是位图图标还是文本标签优雅自适应
        color: sysImg.visible ? 
               (imeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent") :
               ((imeRoot.fallbackLabel === "朗" || imeRoot.fallbackLabel === "A") ? 
                   (imeMouse.containsMouse ? "#2a2a34" : "#1a1a24") : 
                   (imeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"))

        border.color: sysImg.visible ?
                      (imeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent") :
                      ((imeRoot.fallbackLabel === "朗" || imeRoot.fallbackLabel === "A") ? 
                          Qt.rgba(255, 255, 255, 0.28) : 
                          (imeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"))
        border.width: 1

        scale: imeMouse.pressed ? 0.90 : 1.0
        Behavior on scale { NumberAnimation { duration: 70 } }
        Behavior on color { ColorAnimation { duration: 100 } }

        // 🚀【核心零拷贝渲染】：直通 image://ime/current 协议，免去 Base64 解码与 CPU 损耗
        Image {
            id: sysImg
            anchors.centerIn: parent
            width: 17
            height: 17
            source: imeRoot.iconUrl ? imeRoot.iconUrl : ""
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

        MouseArea {
            id: imeMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            preventStealing: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onPressed: (mouse) => {
                mouse.accepted = true;
                if (mouse.button === Qt.RightButton && typeof Bridge !== "undefined" && Bridge.refreshImeMenu) {
                    Bridge.refreshImeMenu();
                }
            }

            onClicked: (mouse) => {
                mouse.accepted = true;
                if (mouse.button === Qt.LeftButton) {
                    imeRoot.closeAllMenus();
                    if (typeof Bridge !== "undefined" && Bridge.toggleIme) {
                        Bridge.toggleIme();
                    }
                } else if (mouse.button === Qt.RightButton) {
                    if (imeRoot.isMenuOpen) {
                        imeRoot.closeAllMenus();
                    } else {
                        if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) {
                            Bridge.openFullCorridorForMotion();
                        }
                        var rootObj = imeRoot.getRootItem();
                        if (rootObj) {
                            var pt = imeBox.mapToItem(rootObj, 0, imeBox.height + 8);
                            menuPopup.parent = rootObj;
                            menuPopup.x = Math.max(8, Math.min(rootObj.width - menuPopup.width - 8, pt.x - (menuPopup.width / 2)));
                            menuPopup.y = pt.y;
                        }
                        menuPopup.open();
                    }
                }
            }
        }
    }

    // =========================================================================
    // 1. 一级主菜单 (Portal 模式渲染)
    // =========================================================================
    Popup {
        id: menuPopup
        width: 204
        padding: 6
        modal: true
        dim: false
        focus: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        z: 9999

        Overlay.modal: Item {}

        onClosed: {
            subPopup.close();
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
                        color: Qt.rgba(255, 255, 255, 0.12)
                        visible: modelData.isSeparator
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        visible: !modelData.isSeparator

                        color: (modelData.isActive || (modelData.hasSubmenu && subPopup.opened && subPopup.parentItemId === modelData.id)) ? 
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
                                var hasKids = modelData.children && modelData.children.length > 0;
                                if (modelData.hasSubmenu && hasKids) {
                                    var rootObj = imeRoot.getRootItem();
                                    if (rootObj) {
                                        var pt = rowItem.mapToItem(rootObj, 0, 0);
                                        subPopup.parent = rootObj;
                                        subPopup.openSubmenu(modelData.id, modelData.children, pt.x, pt.y);
                                    }
                                } else {
                                    subPopup.close();
                                }
                            }

                            onClicked: {
                                var hasKids = modelData.children && modelData.children.length > 0;
                                if (modelData.hasSubmenu && hasKids) {
                                    var rootObj = imeRoot.getRootItem();
                                    if (rootObj) {
                                        var pt = rowItem.mapToItem(rootObj, 0, 0);
                                        subPopup.parent = rootObj;
                                        subPopup.openSubmenu(modelData.id, modelData.children, pt.x, pt.y);
                                    }
                                } else {
                                    imeRoot.closeAllMenus();
                                    if (typeof Bridge !== "undefined" && Bridge.activateImeMenuItem) {
                                        Bridge.activateImeMenuItem(modelData.id, modelData.uniqueName || modelData.label || "");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 2. 二级子菜单 (Portal 模式渲染)
    // =========================================================================
    Popup {
        id: subPopup
        width: 188
        padding: 6
        modal: false
        dim: false
        focus: false
        closePolicy: Popup.CloseOnEscape
        z: 10000

        property int parentItemId: -1
        property var items: []

        function openSubmenu(itemId, subItems, targetX, targetY) {
            parentItemId = itemId;
            items = subItems;
            var rootObj = imeRoot.getRootItem();
            var screenW = rootObj ? rootObj.width : 680;

            if (targetX + menuPopup.width + width + 4 <= screenW) {
                x = targetX + menuPopup.width + 4;
            } else {
                x = targetX - width - 4;
            }
            y = targetY;
            open();
        }

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
                model: subPopup.items

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
                                    Bridge.activateImeMenuItem(modelData.id, modelData.label || "");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}