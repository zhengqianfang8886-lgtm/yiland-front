// ==========================================
// 📄 File: ui/components/compact/CompactObsTray.qml
// 🌟 OBS 原生级联托盘 (完全支持多级 DBusMenu 渲染)
// ==========================================
import QtQuick
import QtQuick.Shapes
import QtQuick.Controls

Item {
    id: obsRoot
    width: 24
    height: 22

    readonly property bool isRunning: (typeof Bridge !== "undefined" && Bridge.isObsRunning !== undefined) ? Boolean(Bridge.isObsRunning) : false
    readonly property string iconUrl: (typeof Bridge !== "undefined" && Bridge.obsIcon !== undefined && Bridge.obsIcon) ? String(Bridge.obsIcon) : ""
    
    // 从后端传来的真实 DBusMenu 结构数据 (现在它包含了 children 数组)
    readonly property var menuList: (typeof Bridge !== "undefined" && Bridge.obsMenuList !== undefined && Bridge.obsMenuList) ? Bridge.obsMenuList : []

    readonly property bool isMenuOpen: menuPopup.opened || subPopup.opened

    function getRootItem() {
        var p = obsRoot;
        while (p && p.parent) p = p.parent;
        return p;
    }

    function closeAllMenus() {
        subPopup.close();
        menuPopup.close();
    }

    Rectangle {
        id: obsBox
        anchors.centerIn: parent
        width: 20
        height: 20
        radius: 4

        color: obsMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.16) : Qt.rgba(255, 255, 255, 0.06)
        border.color: obsMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.3) : "transparent"
        border.width: 1

        scale: obsMouse.pressed ? 0.90 : 1.0
        Behavior on scale { NumberAnimation { duration: 70 } }
        Behavior on color { ColorAnimation { duration: 100 } }

        Image {
            id: sysImg
            anchors.centerIn: parent
            width: 15
            height: 15
            source: obsRoot.iconUrl
            fillMode: Image.PreserveAspectFit
            visible: obsRoot.iconUrl !== "" && status === Image.Ready
            smooth: true
            mipmap: true
        }

        Shape {
            id: fallbackObsLogo
            anchors.centerIn: parent
            width: 12; height: 12
            visible: !sysImg.visible
            layer.enabled: true
            layer.samples: 4
            ShapePath { fillColor: "#ffffff"; strokeColor: "transparent"; PathAngleArc { centerX: 6.0; centerY: 6.0; radiusX: 5.5; radiusY: 5.5; startAngle: 0; sweepAngle: 360 } }
            ShapePath { fillColor: "#14151b"; strokeColor: "transparent"; PathAngleArc { centerX: 6.0; centerY: 3.5; radiusX: 2.2; radiusY: 2.2; startAngle: 0; sweepAngle: 360 } }
            ShapePath { fillColor: "#14151b"; strokeColor: "transparent"; PathAngleArc { centerX: 4.1; centerY: 7.3; radiusX: 2.2; radiusY: 2.2; startAngle: 0; sweepAngle: 360 } }
            ShapePath { fillColor: "#14151b"; strokeColor: "transparent"; PathAngleArc { centerX: 7.9; centerY: 7.3; radiusX: 2.2; radiusY: 2.2; startAngle: 0; sweepAngle: 360 } }
            ShapePath { fillColor: "#ffffff"; strokeColor: "transparent"; PathAngleArc { centerX: 6.0; centerY: 6.0; radiusX: 1.4; radiusY: 1.4; startAngle: 0; sweepAngle: 360 } }
        }

        MouseArea {
            id: obsMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    obsRoot.closeAllMenus();
                    if (typeof Bridge !== "undefined" && Bridge.toggleObsWindow) {
                        Bridge.toggleObsWindow();
                    }
                } else if (mouse.button === Qt.RightButton) {
                    if (obsRoot.isMenuOpen) {
                        obsRoot.closeAllMenus();
                    } else {
                        if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) {
                            Bridge.openFullCorridorForMotion();
                        }
                        var rootObj = obsRoot.getRootItem();
                        if (rootObj) {
                            var pt = obsBox.mapToItem(rootObj, 0, obsBox.height + 6);
                            menuPopup.parent = rootObj;
                            menuPopup.x = Math.max(8, Math.min(rootObj.width - menuPopup.width - 8, pt.x - (menuPopup.width / 2) + 10));
                            menuPopup.y = pt.y;
                        }
                        menuPopup.open();
                    }
                }
            }
        }
    }

    // =========================================================================
    // 1. 一级主菜单 (数据驱动支持级联)
    // =========================================================================
    Popup {
        id: menuPopup
        width: 180
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
            color: "#1c1e26"
            radius: 10
            border.color: Qt.rgba(255, 255, 255, 0.16)
            border.width: 1
        }

        contentItem: Column {
            spacing: 3
            width: parent.width

            Repeater {
                model: obsRoot.menuList && obsRoot.menuList.length > 0 ? obsRoot.menuList : [
                    { "id": 101, "label": "唤醒 OBS Studio 窗口", "isSeparator": false, "isActive": false, "enabled": true }
                ]

                delegate: Item {
                    id: rowItem
                    width: parent.width
                    height: (modelData && modelData.isSeparator) ? 6 : 28

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Qt.rgba(255, 255, 255, 0.12)
                        visible: modelData && Boolean(modelData.isSeparator)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        visible: !(modelData && Boolean(modelData.isSeparator))

                        // 选中或子菜单展开时维持高亮
                        color: (rowMouse.containsMouse || (modelData.hasSubmenu && subPopup.opened && subPopup.parentItemId === modelData.id)) ? 
                               Qt.rgba(255, 255, 255, 0.15) : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: statusBadge.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            clip: true

                            Text {
                                text: (modelData && modelData.label) ? String(modelData.label) : ""
                                color: (modelData && Boolean(modelData.enabled)) ? "white" : Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 11
                                font.bold: Boolean(modelData && modelData.isActive)
                                elide: Text.ElideRight
                                width: parent.width
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.QtRendering
                            }
                        }

                        // 🚀 右侧的 `>` 级联指示器
                        Item {
                            id: statusBadge
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12; height: 12
                            visible: Boolean(modelData && (modelData.isActive || modelData.hasSubmenu))

                            Text {
                                anchors.centerIn: parent
                                text: Boolean(modelData && modelData.isActive) ? "✓" : (Boolean(modelData && modelData.hasSubmenu) ? "›" : "")
                                color: "white"
                                font.pixelSize: Boolean(modelData && modelData.isActive) ? 10 : 14
                                font.bold: Boolean(modelData && modelData.hasSubmenu)
                                renderType: Text.QtRendering
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: Boolean(modelData && modelData.enabled)
                            cursorShape: Boolean(modelData && modelData.enabled) ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onEntered: {
                                var hasKids = modelData && modelData.children && modelData.children.length > 0;
                                if (Boolean(modelData && modelData.hasSubmenu) && hasKids) {
                                    var rootObj = obsRoot.getRootItem();
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
                                var hasKids = modelData && modelData.children && modelData.children.length > 0;
                                if (Boolean(modelData && modelData.hasSubmenu) && hasKids) {
                                    var rootObj = obsRoot.getRootItem();
                                    if (rootObj) {
                                        var pt = rowItem.mapToItem(rootObj, 0, 0);
                                        subPopup.parent = rootObj;
                                        subPopup.openSubmenu(modelData.id, modelData.children, pt.x, pt.y);
                                    }
                                } else {
                                    obsRoot.closeAllMenus();
                                    if (typeof Bridge !== "undefined" && Bridge.activateObsMenuItem && modelData && modelData.id !== undefined) {
                                        Bridge.activateObsMenuItem(modelData.id);
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
    // 2. 二级子菜单 (Portal 模式渲染，处理投影仪等多级选择)
    // =========================================================================
    Popup {
        id: subPopup
        width: 200
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
            var rootObj = obsRoot.getRootItem();
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
            border.color: Qt.rgba(255, 255, 255, 0.25)
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
                    height: (modelData && modelData.isSeparator) ? 6 : 28

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Qt.rgba(255, 255, 255, 0.08)
                        visible: modelData && Boolean(modelData.isSeparator)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        visible: !(modelData && Boolean(modelData.isSeparator))
                        color: subMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                text: (modelData && modelData.label) ? String(modelData.label) : ""
                                color: (modelData && Boolean(modelData.enabled)) ? "white" : Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 11
                                font.bold: Boolean(modelData && modelData.isActive)
                                elide: Text.ElideRight
                                width: parent.width - 18
                                anchors.verticalCenter: parent.verticalCenter
                                renderType: Text.QtRendering
                            }
                        }

                        MouseArea {
                            id: subMouse
                            anchors.fill: parent
                            hoverEnabled: Boolean(modelData && modelData.enabled)
                            cursorShape: Boolean(modelData && modelData.enabled) ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onClicked: {
                                obsRoot.closeAllMenus();
                                if (typeof Bridge !== "undefined" && Bridge.activateObsMenuItem && modelData && modelData.id !== undefined) {
                                    Bridge.activateObsMenuItem(modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}