// =========================================================================
// 📄 File: ui/components/capsule/FluidSlotPod.qml
// 🌟 终极通用流体微囊底座 (内置 Apple-Tier 质感与级联菜单版)
// =========================================================================
import QtQuick
import "../tray" // 引入级联菜单组件

Item {
    id: podRoot

    property string slotId: "slot"
    property string slotName: "未命名槽位"
    property int targetWidth: 0
    property int podHeight: 24
    property real podRadius: podHeight / 2
    property int gapSpacing: 4

    // 🚀 核心抽象：通过一个 themeColor 控制全局背景与悬停色
    property color themeColor: "#ffffff"
    property bool showBackground: true
    
    // 交互与菜单配置
    property bool interactive: true
    property int acceptedButtons: Qt.LeftButton | Qt.RightButton
    property int cursorShape: Qt.PointingHandCursor
    property var menuItems: []

    readonly property bool isMenuOpen: cascadeMenu.isMenuOpen

    signal clicked(var mouse)
    signal rightClicked(var mouse)
    signal menuItemTriggered(int itemId, string label, string uniqueName)
    signal pointerEntered()
    signal pointerExited()

    default property alias contentData: contentSlot.data

    readonly property bool isAlive: targetWidth > 0
    readonly property real effectiveTargetFootprint: isAlive ? (targetWidth + gapSpacing) : 0.0

    width: 0.0
    height: podHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    clip: true
    visible: width > 0.2

    Behavior on width {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutQuint
        }
    }

    onEffectiveTargetFootprintChanged: {
        podRoot.width = effectiveTargetFootprint;
    }

    readonly property real expansionRatio: {
        if (!isAlive || targetWidth <= 0) return 0.0;
        return Math.min(1.0, Math.max(0.0, (width - gapSpacing) / targetWidth));
    }

    function smoothStep(e0, e1, x) {
        var t = Math.max(0.0, Math.min(1.0, (x - e0) / Math.max(0.0001, e1 - e0)));
        return t * t * (3.0 - 2.0 * t);
    }

    function closeAllMenus() {
        cascadeMenu.closeAll();
    }

    Rectangle {
        id: bgRect
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(0.0, podRoot.width - podRoot.gapSpacing)
        radius: podRoot.podRadius
        antialiasing: true

        // 🚀 完美的 Apple-Tier 玻璃态自动渲染
        color: podRoot.showBackground ? 
               (mouseArea.containsMouse ? Qt.rgba(podRoot.themeColor.r, podRoot.themeColor.g, podRoot.themeColor.b, 0.25) : 
                                          Qt.rgba(podRoot.themeColor.r, podRoot.themeColor.g, podRoot.themeColor.b, 0.15)) : 
               "transparent"

        border.color: podRoot.showBackground ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
        border.width: podRoot.showBackground ? 1 : 0

        scale: mouseArea.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }

        Item {
            id: contentSlot
            anchors.centerIn: parent
            width: podRoot.targetWidth > 0 ? podRoot.targetWidth : parent.width
            height: parent.height
            opacity: podRoot.smoothStep(0.12, 0.55, podRoot.expansionRatio)
            scale: 0.75 + 0.25 * podRoot.smoothStep(0.08, 0.85, podRoot.expansionRatio)
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: podRoot.interactive && podRoot.isAlive
            hoverEnabled: true
            cursorShape: podRoot.cursorShape
            acceptedButtons: podRoot.acceptedButtons

            onEntered: podRoot.pointerEntered()
            onExited: podRoot.pointerExited()

            onPressed: (mouse) => {
                mouse.accepted = true;
                if (mouse.button === Qt.RightButton) podRoot.rightClicked(mouse);
            }

            onClicked: (mouse) => {
                mouse.accepted = true;
                if (mouse.button === Qt.LeftButton) {
                    podRoot.closeAllMenus();
                    podRoot.clicked(mouse);
                } else if (mouse.button === Qt.RightButton) {
                    if (podRoot.isMenuOpen) {
                        podRoot.closeAllMenus();
                    } else {
                        if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) Bridge.openFullCorridorForMotion();
                        if (podRoot.menuItems && podRoot.menuItems.length > 0) {
                            cascadeMenu.openBelow(bgRect);
                        }
                    }
                }
            }
        }
    }

    CascadingDbusMenu {
        id: cascadeMenu
        menuItems: podRoot.menuItems
        onItemTriggered: (itemId, label, uniqueName) => podRoot.menuItemTriggered(itemId, label, uniqueName)
    }
}