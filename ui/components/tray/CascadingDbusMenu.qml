// ==========================================
// 📄 File: ui/components/tray/CascadingDbusMenu.qml
// 🌟 生产级通用 DBus 级联菜单 (严密无缝贴合 · 智能左右翻转避障 · 防截断版)
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: menuRoot

    property var menuItems: []
    property int menuWidth: 204
    property int maxMenuHeight: 340

    signal itemTriggered(int itemId, string label, string uniqueName)
    signal menuClosed()

    readonly property bool isMenuOpen: menuPopup.opened || subPopup.opened

    function getRootItem(target) {
        var p = target;
        while (p && p.parent) p = p.parent;
        return p;
    }

    // -------------------------------------------------------------------------
    // 一级主菜单定位
    // -------------------------------------------------------------------------
    function openBelow(anchorItem) {
        if (!anchorItem) return;
        var rootObj = getRootItem(anchorItem);
        if (!rootObj) return;

        var screenW = rootObj.width > 0 ? rootObj.width : 780;
        var screenH = rootObj.height > 0 ? rootObj.height : 520;
        var pt = anchorItem.mapToItem(rootObj, 0, anchorItem.height + 6);

        menuPopup.parent = rootObj;
        menuPopup.x = Math.max(8, Math.min(screenW - menuPopup.width - 8, pt.x - (menuPopup.width / 2) + (anchorItem.width / 2)));
        menuPopup.y = Math.max(8, Math.min(screenH - menuPopup.height - 8, pt.y));
        menuPopup.open();
    }

    function closeAll() {
        intentTimer.stop();
        subPopup.close();
        menuPopup.close();
        menuRoot.menuClosed();
    }

    Timer {
        id: intentTimer
        interval: 120
        repeat: false
        property var pendingNode: null
        onTriggered: {
            if (pendingNode && pendingNode.hasSub) {
                if (subPopup.parentItemId !== pendingNode.id) {
                    subPopup.openSmartSub(pendingNode.id, pendingNode.kids, pendingNode.rowY);
                }
            } else {
                subPopup.close();
                subPopup.parentItemId = -1;
            }
        }
    }

    // =========================================================================
    // 1. 一级主菜单
    // =========================================================================
    Popup {
        id: menuPopup
        width: menuRoot.menuWidth
        height: Math.min(menuRoot.maxMenuHeight, mainCol.implicitHeight + 12)
        padding: 6
        modal: true
        dim: false
        focus: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        z: 9999

        Overlay.modal: Item {}
        onClosed: {
            intentTimer.stop();
            subPopup.close();
            subPopup.parentItemId = -1;
            menuRoot.menuClosed();
        }

        background: Rectangle {
            color: "#1c1e26"
            radius: 10
            border.color: Qt.rgba(255, 255, 255, 0.16)
            border.width: 1
        }

        contentItem: Flickable {
            contentWidth: width
            contentHeight: mainCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                width: 3
                policy: mainCol.implicitHeight > parent.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 1.5; color: Qt.rgba(255, 255, 255, 0.25) }
            }

            Column {
                id: mainCol
                spacing: 3
                width: parent.width - (mainCol.implicitHeight > parent.height ? 4 : 0)

                Repeater {
                    model: menuRoot.menuItems || []
                    delegate: Item {
                        id: rowItem
                        width: mainCol.width
                        height: modelData.isSeparator ? 6 : 28

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 8; height: 1
                            color: Qt.rgba(255, 255, 255, 0.10)
                            visible: Boolean(modelData.isSeparator)
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 5
                            visible: !modelData.isSeparator
                            color: (rowMouse.containsMouse || (modelData.hasSubmenu && subPopup.opened && subPopup.parentItemId === modelData.id)) ?
                                   Qt.rgba(255, 255, 255, 0.14) : "transparent"

                            Row {
                                anchors.left: parent.left; anchors.leftMargin: 10
                                anchors.right: statusBadge.left; anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                clip: true

                                Text {
                                    text: modelData.label || ""
                                    color: (modelData.enabled !== false) ? "white" : Qt.rgba(1, 1, 1, 0.4)
                                    font.pixelSize: 11
                                    font.bold: Boolean(modelData.isActive)
                                    elide: Text.ElideRight
                                    width: parent.width
                                    anchors.verticalCenter: parent.verticalCenter
                                    renderType: Text.QtRendering
                                }
                            }

                            Item {
                                id: statusBadge
                                anchors.right: parent.right; anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12; height: 12
                                visible: Boolean(modelData.isActive || modelData.hasSubmenu)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.isActive ? "✓" : (modelData.hasSubmenu ? "›" : "")
                                    color: "white"
                                    font.pixelSize: modelData.isActive ? 10 : 14
                                    font.bold: Boolean(modelData.hasSubmenu)
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
                                    var isSub = Boolean(modelData.hasSubmenu) && hasKids;
                                    var rootObj = menuRoot.getRootItem(menuRoot);
                                    var pt = rootObj ? rowItem.mapToItem(rootObj, 0, 0) : {x:0, y:0};

                                    intentTimer.pendingNode = {
                                        hasSub: isSub,
                                        id: modelData.id,
                                        kids: modelData.children || [],
                                        rowY: pt.y
                                    };
                                    intentTimer.restart();
                                }

                                onClicked: (mouse) => {
                                    mouse.accepted = true;
                                    if (!modelData || modelData.enabled === false) return;
                                    var hasKids = modelData.children && modelData.children.length > 0;
                                    if (modelData.hasSubmenu && hasKids) {
                                        intentTimer.stop();
                                        var rootObj = menuRoot.getRootItem(menuRoot);
                                        var pt = rootObj ? rowItem.mapToItem(rootObj, 0, 0) : {x:0, y:0};
                                        subPopup.openSmartSub(modelData.id, modelData.children, pt.y);
                                    } else {
                                        menuRoot.closeAll();
                                        menuRoot.itemTriggered(modelData.id, modelData.label || "", modelData.uniqueName || "");
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
    // 2. 二级子菜单 (🚀 严密咬合 · 坐标系统一 · 零缝隙贴合)
    // =========================================================================
    Popup {
        id: subPopup
        width: menuRoot.menuWidth
        height: Math.min(menuRoot.maxMenuHeight, subCol.implicitHeight + 12)
        padding: 6
        modal: false
        dim: false
        focus: false
        closePolicy: Popup.CloseOnEscape
        z: 10000

        property int parentItemId: -1
        property var items: []

        function openSmartSub(itemId, subItems, rowGlobalY) {
            parentItemId = itemId;
            items = subItems;

            var rootObj = menuRoot.getRootItem(menuRoot);
            if (!rootObj) return;

            // 🚀【核心修复 1】：必须显式将 subPopup 挂载至 rootObj，与 menuPopup 保持绝对相同的坐标系！
            subPopup.parent = rootObj;

            var screenW = rootObj.width > 0 ? rootObj.width : 780;
            var screenH = rootObj.height > 0 ? rootObj.height : 520;

            var targetW = subPopup.width;
            
            // 🚀【核心修复 2】：边缘微重叠 2px (menuPopup.width - 2)，让主菜单与子菜单严密咬合，消灭悬空大缝隙！
            var rightPos = menuPopup.x + menuPopup.width - 2;
            var leftPos = menuPopup.x - targetW + 2;

            if (rightPos + targetW <= screenW - 8) {
                // 右侧装得下，严密贴在右侧
                subPopup.x = rightPos;
            } else if (leftPos >= 8) {
                // 右侧装不下，向左翻转严密贴在左侧
                subPopup.x = leftPos;
            } else {
                subPopup.x = Math.max(8, screenW - targetW - 8);
            }

            // 垂直对齐当前行高（减去 padding: 6 让文字视觉对齐）
            var targetY = rowGlobalY - 6;
            var targetH = Math.min(menuRoot.maxMenuHeight, subItems.length * 28 + 12);
            if (targetY + targetH > screenH - 12) {
                subPopup.y = Math.max(8, screenH - targetH - 12);
            } else {
                subPopup.y = Math.max(8, targetY);
            }

            subPopup.open();
        }

        background: Rectangle {
            color: "#181a20"
            radius: 8
            border.color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35)
            border.width: 1
            HoverHandler { onHoveredChanged: if (hovered) intentTimer.stop(); }
        }

        contentItem: Flickable {
            contentWidth: width
            contentHeight: subCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                width: 3
                policy: subCol.implicitHeight > parent.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 1.5; color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.6) }
            }

            Column {
                id: subCol
                spacing: 3
                width: parent.width - (subCol.implicitHeight > parent.height ? 4 : 0)

                Repeater {
                    model: subPopup.items
                    delegate: Item {
                        width: subCol.width
                        height: modelData.isSeparator ? 6 : 28

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 8; height: 1
                            color: Qt.rgba(255, 255, 255, 0.08)
                            visible: Boolean(modelData.isSeparator)
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 5
                            visible: !modelData.isSeparator
                            color: modelData.isActive ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.22) :
                                   (subMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent")

                            Row {
                                anchors.left: parent.left; anchors.leftMargin: 10
                                anchors.right: subStatusIcon.left; anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: modelData.label || ""
                                    color: modelData.isActive ? "#38bdf8" : (modelData.enabled !== false ? "white" : Qt.rgba(1, 1, 1, 0.4))
                                    font.pixelSize: 11
                                    font.bold: Boolean(modelData.isActive)
                                    elide: Text.ElideRight
                                    width: parent.width
                                    anchors.verticalCenter: parent.verticalCenter
                                    renderType: Text.QtRendering
                                }
                            }

                            Item {
                                id: subStatusIcon
                                anchors.right: parent.right; anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12; height: 12
                                visible: Boolean(modelData.isActive)
                                Text { anchors.centerIn: parent; text: "✓"; color: "#38bdf8"; font.pixelSize: 10; renderType: Text.QtRendering }
                            }

                            MouseArea {
                                id: subMouse
                                anchors.fill: parent
                                hoverEnabled: modelData.enabled !== false
                                cursorShape: (modelData.enabled !== false) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: (mouse) => {
                                    mouse.accepted = true;
                                    if (!modelData || modelData.enabled === false) return;
                                    menuRoot.closeAll();
                                    menuRoot.itemTriggered(modelData.id, modelData.label || "", modelData.uniqueName || "");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}