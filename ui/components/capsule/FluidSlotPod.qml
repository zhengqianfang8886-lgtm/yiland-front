// =========================================================================
// 📄 File: ui/components/capsule/FluidSlotPod.qml
// 🌟 通用流体微囊底座 (消除内容瞬灭 · 320ms 全程等比缩放与淡出版)
// =========================================================================
import QtQuick
import "../tray"
import "../../core/IslandLogger.js" as Logger

Item {
    id: podRoot

    property string slotId: "slot"
    property string slotName: "未命名槽位"
    property int targetWidth: 0
    property int podHeight: 24
    property real podRadius: podHeight / 2
    property int gapSpacing: 4

    property color themeColor: "#ffffff"
    property bool showBackground: true
    
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
    readonly property real effectiveTargetFootprint: isAlive ? (Math.ceil((targetWidth + gapSpacing) / 2) * 2) : 0.0

    // 记住最后的有效宽度，供退场全程对账
    property real lastActiveTargetWidth: 32.0
    onTargetWidthChanged: {
        if (targetWidth > 0) {
            lastActiveTargetWidth = targetWidth;
        }
    }

    width: 0.0
    height: podHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    clip: true

    // 🚀【定海神针】：只有当实体宽度真正收敛到 0.5px 以内，才彻底卸载渲染，动画中全程可见！
    visible: width > 0.5

    Behavior on width {
        id: widthAnimBehavior
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
            onRunningChanged: {
                if (running) {
                    Logger.slot(podRoot.slotId, "START", "插槽起跑 -> 目标: " + podRoot.effectiveTargetFootprint + "px");
                } else {
                    podRoot.width = podRoot.effectiveTargetFootprint;
                    Logger.slot(podRoot.slotId, "SETTLE", "插槽定格 -> 实体: " + Math.round(podRoot.width) + "px");
                }
            }
        }
    }

    onEffectiveTargetFootprintChanged: {
        Logger.geom("SLOT_TARGET", "[" + slotId + "] 收到目标占位变更", effectiveTargetFootprint, Math.round(width));
        podRoot.width = effectiveTargetFootprint;
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

        color: podRoot.showBackground ? 
               (mouseArea.containsMouse ? Qt.rgba(podRoot.themeColor.r, podRoot.themeColor.g, podRoot.themeColor.b, 0.25) : 
                                          Qt.rgba(podRoot.themeColor.r, podRoot.themeColor.g, podRoot.themeColor.b, 0.15)) : 
               "transparent"

        border.color: podRoot.showBackground ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
        border.width: podRoot.showBackground ? 1 : 0

        scale: mouseArea.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }

        // 🚀【终极修复核心】：让内容槽直接根据气泡当前宽度线性衰减（Progress 0.0 ~ 1.0）
        // 彻底消灭原先的硬切断，不管伸展还是收缩，内部图标全程陪伴气泡呼吸！
        Item {
            id: contentSlot
            anchors.centerIn: parent
            width: Math.max(0.0, podRoot.width - podRoot.gapSpacing)
            height: parent.height

            readonly property real animProgress: Math.max(0.0, Math.min(1.0, (podRoot.width - podRoot.gapSpacing) / Math.max(1.0, podRoot.lastActiveTargetWidth)))

            // 二次方平滑衰减曲线：退场时由 1.0 极其柔和地滑向 0.0，消除断崖感
            opacity: animProgress * animProgress
            scale: 0.55 + 0.45 * animProgress
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