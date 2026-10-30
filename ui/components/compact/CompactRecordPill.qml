// ==========================================
// 📄 File: ui/components/compact/CompactRecordPill.qml
// 🌟 纯正数据驱动录制胶囊 (接入 CascadingDbusMenu 版)
// ==========================================
import QtQuick
import QtQuick.Shapes
import QtQuick.Controls
import "../tray"

Item {
    id: recRoot
    width: hasObsIcon ? 54 : 28
    height: 24

    readonly property bool isActive: (typeof Bridge !== "undefined" && Bridge.isRecordingActive !== undefined) ? Boolean(Bridge.isRecordingActive) : false
    readonly property string iconUrl: (typeof Bridge !== "undefined" && Bridge.recordingIcon !== undefined) ? String(Bridge.recordingIcon) : ""
    readonly property var recItems: (typeof Bridge !== "undefined" && Bridge.recordingItems !== undefined) ? Bridge.recordingItems : []
    readonly property var menuList: (typeof Bridge !== "undefined" && Bridge.recordingMenuList !== undefined) ? Bridge.recordingMenuList : []

    readonly property bool hasObsIcon: iconUrl !== ""
    readonly property bool isMenuOpen: cascadeMenu.isMenuOpen

    function closeAllMenus() {
        cascadeMenu.closeAll();
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onWindowDeactivated() { recRoot.closeAllMenus(); }
    }

    Rectangle {
        id: recBox
        anchors.centerIn: parent
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
            spacing: 8

            // 1. 经典红色录制脉冲圆环与核心红点
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

            // 2. OBS 动态托盘位图
            Image {
                id: sysImg
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                source: recRoot.iconUrl
                fillMode: Image.PreserveAspectFit
                asynchronous: false
                cache: false
                visible: recRoot.hasObsIcon && status === Image.Ready
                smooth: true; mipmap: true
            }

            // 3. OBS 矢量兜底
            Shape {
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14
                visible: recRoot.hasObsIcon && !sysImg.visible
                layer.enabled: true; layer.samples: 4
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
                    var rootObj = cascadeMenu.getRootItem(recRoot);
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
                    if (typeof Bridge !== "undefined" && Bridge.toggleRecording) Bridge.toggleRecording();
                } else if (mouse.button === Qt.RightButton) {
                    if (recRoot.isMenuOpen) {
                        recRoot.closeAllMenus();
                    } else {
                        if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) {
                            Bridge.openFullCorridorForMotion();
                        }
                        cascadeMenu.openBelow(recBox);
                    }
                }
            }
        }
    }

    // 音频采音流悬停提示
    Popup {
        id: infoPopup
        width: 170; padding: 8
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

    // 统合级联 DBus 菜单
    CascadingDbusMenu {
        id: cascadeMenu
        menuItems: recRoot.menuList
        onItemTriggered: (itemId, label) => {
            if (typeof Bridge !== "undefined" && Bridge.activateRecordingMenuItem) {
                Bridge.activateRecordingMenuItem(itemId);
            }
        }
    }
}