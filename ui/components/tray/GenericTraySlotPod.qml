// =========================================================================
// 📄 File: ui/components/tray/GenericTraySlotPod.qml
// 🌟 5分钟接入任意托盘应用的通用 QML 容器组件
// =========================================================================
import QtQuick
import "../capsule"

FluidSlotPod {
    id: trayPod

    property string serviceId: ""       // 如 "clash", "telegram"
    property string iconUrl: ""         // 如 "image://tray/clash?r=1"
    property string fallbackText: "✇"
    property var menuItems: []

    signal primaryAction()              // 左键触发
    signal menuRefresh()                // 右键触发懒加载
    signal menuItemActivated(int id, string label)

    targetWidth: iconUrl !== "" ? 26 : 0
    gapSpacing: 4
    interactive: false
    podColor: "transparent"
    podBorderColor: "transparent"

    Rectangle {
        id: innerBox
        anchors.centerIn: parent
        width: 22; height: 22; radius: 5
        color: mouse.containsMouse ? Qt.rgba(255, 255, 255, 0.14) : "transparent"
        border.color: mouse.containsMouse ? Qt.rgba(255, 255, 255, 0.22) : "transparent"
        border.width: 1

        Image {
            id: img
            anchors.centerIn: parent
            width: 16; height: 16
            source: trayPod.iconUrl
            visible: trayPod.iconUrl !== "" && status === Image.Ready
            smooth: true; mipmap: true
        }

        Text {
            anchors.centerIn: parent
            text: trayPod.fallbackText
            color: "white"
            visible: !img.visible
            font.pixelSize: 11
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: (m) => {
                if (m.button === Qt.LeftButton) {
                    cascadeMenu.closeAll();
                    trayPod.primaryAction();
                } else if (m.button === Qt.RightButton) {
                    trayPod.menuRefresh();
                    cascadeMenu.openBelow(innerBox);
                }
            }
        }
    }

    CascadingDbusMenu {
        id: cascadeMenu
        menuItems: trayPod.menuItems
        onItemTriggered: (itemId, label) => trayPod.menuItemActivated(itemId, label)
    }
}