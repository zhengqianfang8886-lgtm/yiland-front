// ==========================================
// 📄 File: ui/components/compact/CompactImeView.qml
// 🌟 系统原生级输入法组件 (接入 CascadingDbusMenu 版)
// ==========================================
import QtQuick
import QtQuick.Controls
import "../tray"

Item {
    id: imeRoot
    width: 26
    height: 24

    property string fontFam: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    readonly property bool isActive: (typeof Bridge !== "undefined" && Bridge.isImeActive !== undefined) ? Bridge.isImeActive : false
    readonly property string iconUrl: (typeof Bridge !== "undefined" && Bridge.imeIcon !== undefined) ? Bridge.imeIcon : ""
    readonly property string fallbackLabel: (typeof Bridge !== "undefined" && Bridge.imeLabel !== undefined) ? Bridge.imeLabel : "A"
    readonly property bool isMenuOpen: cascadeMenu.isMenuOpen

    function closeAllMenus() {
        cascadeMenu.closeAll();
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onWindowDeactivated() { imeRoot.closeAllMenus(); }
    }

    Rectangle {
        id: imeBox
        anchors.centerIn: parent
        width: 22
        height: 22
        radius: 5
        antialiasing: true

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

        Image {
            id: sysImg
            anchors.centerIn: parent
            width: 17; height: 17
            source: imeRoot.iconUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            cache: false
            visible: imeRoot.iconUrl !== "" && status === Image.Ready
            smooth: true; mipmap: true
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
                    if (typeof Bridge !== "undefined" && Bridge.toggleIme) Bridge.toggleIme();
                } else if (mouse.button === Qt.RightButton) {
                    if (imeRoot.isMenuOpen) {
                        imeRoot.closeAllMenus();
                    } else {
                        if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) {
                            Bridge.openFullCorridorForMotion();
                        }
                        cascadeMenu.openBelow(imeBox);
                    }
                }
            }
        }
    }

    // 统合级联 DBus 菜单
    CascadingDbusMenu {
        id: cascadeMenu
        menuItems: (typeof Bridge !== "undefined" && Bridge.imeMenuList) ? Bridge.imeMenuList : []
        onItemTriggered: (itemId, label, uniqueName) => {
            if (typeof Bridge !== "undefined" && Bridge.activateImeMenuItem) {
                Bridge.activateImeMenuItem(itemId, uniqueName || label);
            }
        }
    }
}