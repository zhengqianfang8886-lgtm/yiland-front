// ==========================================
// 📄 File: ui/components/compact/CompactRecordPill.qml
// 🌟 纯正数据驱动录制胶囊 (宽敞大气版 · 支持事件动态刷新)
// ==========================================
import QtQuick
import QtQuick.Shapes
import QtQuick.Controls

Item {
    id: recRoot
    // 🚀 整体宽度放宽到 54px
    width: hasObsIcon ? 54 : 28
    height: 24

    readonly property bool isActive: (typeof Bridge !== "undefined" && Bridge.isRecordingActive !== undefined) ? Boolean(Bridge.isRecordingActive) : false
    readonly property string iconUrl: (typeof Bridge !== "undefined" && Bridge.recordingIcon !== undefined) ? String(Bridge.recordingIcon) : ""
    readonly property var recItems: (typeof Bridge !== "undefined" && Bridge.recordingItems !== undefined) ? Bridge.recordingItems : []
    readonly property var menuList: (typeof Bridge !== "undefined" && Bridge.recordingMenuList !== undefined) ? Bridge.recordingMenuList : []

    readonly property bool hasObsIcon: iconUrl !== ""
    readonly property bool isMenuOpen: menuPopup.opened || subPopup.opened

    function getRootItem() {
        var p = recRoot;
        while (p && p.parent) p = p.parent;
        return p;
    }

    function closeAllMenus() {
        menuIntentTimer.stop();
        subPopup.close();
        menuPopup.close();
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onWindowDeactivated() {
            recRoot.closeAllMenus();
        }
    }

    Rectangle {
        id: recBox
        anchors.centerIn: parent
        // 🚀 内部背景框放宽到 50px，高度提升到 22px，圆角变得更润
        width: hasObsIcon ? 50 : 24
        height: 22
        radius: 6

        color: recMouse.containsMouse ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.25) : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.12)
        border.color: recMouse.containsMouse ? "#ef4444" : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.45)
        border.width: 1

        scale: recMouse.pressed ? 0.90 : 1.0
        Behavior on scale { NumberAnimation { duration: 70 } }

        Row {
            anchors.centerIn: parent
            spacing: 8 // 🚀 图标与红点之间的间距从 5px 放大到 8px，呼吸感拉满

            Item {
                width: 8; height: 8
                anchors.verticalCenter: parent.verticalCenter
                
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 4; height: parent.height + 4; radius: width / 2
                    color: "transparent"
                    border.color: "#ef4444"
                    border.width: 1.2

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: recRoot.isActive
                        NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 6; height: 6; radius: 3
                    color: "#ef4444"
                }
            }

            Image {
                id: sysImg
                anchors.verticalCenter: parent.verticalCenter
                // 🚀 图标由 14px 放大至 16px，细节更清晰
                width: 16
                height: 16
                source: recRoot.iconUrl
                fillMode: Image.PreserveAspectFit
                // 必须关闭缓存，强制跟随 ?r=123 参数刷新，响应底层事件
                asynchronous: false
                cache: false
                visible: recRoot.hasObsIcon && status === Image.Ready
                smooth: true
                mipmap: true
            }

            Shape {
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14
                visible: recRoot.hasObsIcon && !sysImg.visible
                layer.enabled: true
                layer.samples: 4
                ShapePath { fillColor: "#ffffff"; strokeColor: "transparent"; PathAngleArc { centerX: 7.0; centerY: 7.0; radiusX: 6.5; radiusY: 6.5; startAngle: 0; sweepAngle: 360 } }
                ShapePath { fillColor: "#14151b"; strokeColor: "transparent"; PathAngleArc { centerX: 7.0; centerY: 4.5; radiusX: 2.6; radiusY: 2.6; startAngle: 0; sweepAngle: 360 } }
                ShapePath { fillColor: "#14151b"; strokeColor: "transparent"; PathAngleArc { centerX: 5.0; centerY: 8.5; radiusX: 2.6; radiusY: 2.6; startAngle: 0; sweepAngle: 360 } }
                ShapePath { fillColor: "#14151b"; strokeColor: "transparent"; PathAngleArc { centerX: 9.0; centerY: 8.5; radiusX: 2.6; radiusY: 2.6; startAngle: 0; sweepAngle: 360 } }
                ShapePath { fillColor: "#ffffff"; strokeColor: "transparent"; PathAngleArc { centerX: 7.0; centerY: 7.0; radiusX: 1.8; radiusY: 1.8; startAngle: 0; sweepAngle: 360 } }
            }
        }

        MouseArea {
            id: recMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onEntered: {
                if (!recRoot.isMenuOpen) {
                    var rootObj = recRoot.getRootItem();
                    if (rootObj) {
                        var pt = recBox.mapToItem(rootObj, 0, recBox.height + 6);
                        infoPopup.parent = rootObj;
                        infoPopup.x = Math.max(8, Math.min(rootObj.width - infoPopup.width - 8, pt.x - (infoPopup.width / 2) + 11));
                        infoPopup.y = pt.y;
                    }
                    infoPopup.open();
                }
            }
            onExited: infoPopup.close()

            onPressed: (mouse) => {
                mouse.accepted = true;
                if (mouse.button === Qt.RightButton && typeof Bridge !== "undefined" && Bridge.refreshRecordingMenu) {
                    Bridge.refreshRecordingMenu();
                }
            }

            onClicked: (mouse) => {
                mouse.accepted = true;
                infoPopup.close();
                if (mouse.button === Qt.LeftButton) {
                    recRoot.closeAllMenus();
                    if (typeof Bridge !== "undefined" && Bridge.toggleRecording) {
                        Bridge.toggleRecording();
                    }
                } else if (mouse.button === Qt.RightButton) {
                    if (recRoot.isMenuOpen) {
                        recRoot.closeAllMenus();
                    } else {
                        if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) {
                            Bridge.openFullCorridorForMotion();
                        }
                        var rootObj = recRoot.getRootItem();
                        if (rootObj) {
                            var pt = recBox.mapToItem(rootObj, 0, recBox.height + 6);
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

    Popup {
        id: infoPopup
        width: 170
        padding: 8
        modal: false; dim: false; closePolicy: Popup.CloseOnEscape
        z: 9998
        background: Rectangle { color: "#1c1e26"; radius: 8; border.color: Qt.rgba(255, 255, 255, 0.16); border.width: 1 }

        contentItem: Column {
            spacing: 6; width: parent.width
            Repeater {
                model: recRoot.recItems.length > 0 ? recRoot.recItems : [{ "title": "音频采集", "subtitle": "系统录制", "icon": "🎙️" }]
                delegate: Column {
                    width: parent.width; spacing: 2
                    Row {
                        spacing: 5
                        Text { text: modelData.icon || "🎙️"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.title || "音频采集"; color: "#ffffff"; font.pixelSize: 11; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: (modelData.subtitle || "系统录制") + " · 正在使用"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 9; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(255, 255, 255, 0.08); visible: index < recRoot.recItems.length - 1 }
                }
            }
        }
    }

    Timer {
        id: menuIntentTimer
        interval: 180
        repeat: false
        property var pendingRow: null
        
        onTriggered: {
            if (pendingRow && pendingRow.hasSub) {
                if (subPopup.parentItemId !== pendingRow.id) {
                    subPopup.openSubmenu(pendingRow.id, pendingRow.kids, pendingRow.tx, pendingRow.ty);
                }
            } else {
                subPopup.close();
                subPopup.parentItemId = -1;
            }
        }
    }

    Popup {
        id: menuPopup
        width: 220
        padding: 6
        modal: true; dim: false; focus: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        z: 9999
        Overlay.modal: Item {}

        onClosed: {
            menuIntentTimer.stop();
            subPopup.close();
            subPopup.parentItemId = -1;
        }

        background: Rectangle { color: "#1c1e26"; radius: 10; border.color: Qt.rgba(255, 255, 255, 0.16); border.width: 1 }

        contentItem: Column {
            spacing: 3; width: parent.width
            Repeater {
                model: recRoot.menuList && recRoot.menuList.length > 0 ? recRoot.menuList : [{ "id": 101, "label": "唤醒 OBS Studio 窗口", "isSeparator": false, "isActive": false, "enabled": true }]

                delegate: Item {
                    id: rowItem
                    width: parent.width
                    height: (modelData && modelData.isSeparator) ? 6 : 28

                    Rectangle { anchors.centerIn: parent; width: parent.width - 8; height: 1; color: Qt.rgba(255, 255, 255, 0.12); visible: modelData && Boolean(modelData.isSeparator) }

                    Rectangle {
                        anchors.fill: parent; radius: 5
                        visible: !(modelData && Boolean(modelData.isSeparator))
                        color: (itemMouse.containsMouse || (modelData && Boolean(modelData.hasSubmenu) && subPopup.opened && subPopup.parentItemId === modelData.id)) ? Qt.rgba(255, 255, 255, 0.15) : "transparent"

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 10; anchors.right: statusBadge.left; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 6; clip: true
                            Text {
                                text: (modelData && modelData.label) ? String(modelData.label) : ""
                                color: (modelData && Boolean(modelData.enabled)) ? "white" : Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 11; font.bold: Boolean(modelData && modelData.isActive); elide: Text.ElideRight; width: parent.width; anchors.verticalCenter: parent.verticalCenter; renderType: Text.QtRendering
                            }
                        }

                        Item {
                            id: statusBadge
                            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12
                            visible: Boolean(modelData && (modelData.isActive || modelData.hasSubmenu))
                            Text { anchors.centerIn: parent; text: Boolean(modelData && modelData.isActive) ? "✓" : (Boolean(modelData && modelData.hasSubmenu) ? "›" : ""); color: "white"; font.pixelSize: Boolean(modelData && modelData.isActive) ? 10 : 14; font.bold: Boolean(modelData && modelData.hasSubmenu); renderType: Text.QtRendering }
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: Boolean(modelData && modelData.enabled)
                            cursorShape: Boolean(modelData && modelData.enabled) ? Qt.PointingHandCursor : Qt.ArrowCursor

                            onEntered: {
                                var hasKids = modelData && modelData.children && modelData.children.length > 0;
                                var isSub = Boolean(modelData && modelData.hasSubmenu) && hasKids;
                                
                                var rootObj = recRoot.getRootItem();
                                var pt = {x: 0, y: 0};
                                if (rootObj && isSub) {
                                    pt = rowItem.mapToItem(rootObj, 0, 0);
                                }
                                
                                menuIntentTimer.pendingRow = {
                                    hasSub: isSub,
                                    id: modelData.id,
                                    kids: modelData.children || [],
                                    tx: pt.x,
                                    ty: pt.y
                                };
                                menuIntentTimer.restart();
                            }

                            onClicked: (mouse) => {
                                mouse.accepted = true;
                                if (!modelData || modelData.enabled === false) return; // 禁用项不可点

                                var hasKids = modelData.children && modelData.children.length > 0;
                                if (Boolean(modelData.hasSubmenu) && hasKids) {
                                    menuIntentTimer.stop();
                                    var rootObj = recRoot.getRootItem();
                                    if (rootObj) {
                                        var pt = rowItem.mapToItem(rootObj, 0, 0);
                                        subPopup.openSubmenu(modelData.id, modelData.children, pt.x, pt.y);
                                    }
                                } else {
                                    var targetId = parseInt(modelData.id); 
                                    recRoot.closeAllMenus();
                                    if (typeof Bridge !== "undefined" && Bridge.activateRecordingMenuItem && targetId !== undefined) {
                                        Bridge.activateRecordingMenuItem(targetId);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: subPopup
        width: 220
        padding: 6
        modal: false; dim: false; focus: false
        closePolicy: Popup.CloseOnEscape
        z: 10000

        property int parentItemId: -1
        property var items: []

        function openSubmenu(itemId, subItems, targetX, targetY) {
            if (parentItemId !== itemId) {
                parentItemId = itemId;
                items = subItems;
            }
            var rootObj = recRoot.getRootItem();
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
            color: "#181a20"; radius: 8; border.color: Qt.rgba(255, 255, 255, 0.25); border.width: 1
            HoverHandler { onHoveredChanged: if (hovered) menuIntentTimer.stop() }
        }

        contentItem: Column {
            id: subCol
            spacing: 3; width: parent.width

            Repeater {
                model: subPopup.items
                delegate: Item {
                    width: subCol.width; height: (modelData && modelData.isSeparator) ? 6 : 28

                    Rectangle { anchors.centerIn: parent; width: parent.width - 8; height: 1; color: Qt.rgba(255, 255, 255, 0.08); visible: modelData && Boolean(modelData.isSeparator) }

                    Rectangle {
                        anchors.fill: parent; radius: 5; visible: !(modelData && Boolean(modelData.isSeparator))
                        color: subMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 10; anchors.right: statusIcon.left; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                            Text {
                                text: (modelData && modelData.label) ? String(modelData.label) : ""
                                color: (modelData && Boolean(modelData.enabled)) ? "white" : Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 11; font.bold: Boolean(modelData && modelData.isActive); elide: Text.ElideRight; width: parent.width; anchors.verticalCenter: parent.verticalCenter; renderType: Text.QtRendering
                            }
                        }
                        
                        Item {
                            id: statusIcon
                            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12
                            visible: Boolean(modelData && modelData.isActive)
                            Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 10; renderType: Text.QtRendering }
                        }

                        MouseArea {
                            id: subMouse
                            anchors.fill: parent; hoverEnabled: Boolean(modelData && modelData.enabled); cursorShape: Boolean(modelData && modelData.enabled) ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: (mouse) => {
                                mouse.accepted = true;
                                if (!modelData || modelData.enabled === false) return;
                                var targetId = parseInt(modelData.id);
                                recRoot.closeAllMenus();
                                if (typeof Bridge !== "undefined" && Bridge.activateRecordingMenuItem && targetId !== undefined) {
                                    Bridge.activateRecordingMenuItem(targetId);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}