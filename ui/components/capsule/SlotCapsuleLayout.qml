// =========================================================================
// 📄 File: ui/components/capsule/SlotCapsuleLayout.qml
// 🌟 苹果灵动岛三槽位布局引擎 (Leading / Center / Trailing + 自适应约束)
// =========================================================================
import QtQuick

Item {
    id: slotLayout
    anchors.fill: parent

    property Component leadingComponent: null
    property Component centerComponent: null
    property Component trailingComponent: null

    readonly property int paddingH: 14
    readonly property int slotSpacing: 8

    // 🚀【核心设计】：根据三个槽位内插组件的实际尺寸，动态推导所需最小物理宽度
    readonly property real desiredContentWidth: {
        var total = paddingH * 2;
        var validSlots = 0;

        if (leadingLoader.item && leadingLoader.item.implicitWidth > 0) {
            total += leadingLoader.item.implicitWidth;
            validSlots++;
        }
        if (centerLoader.item && centerLoader.item.implicitWidth > 0) {
            total += centerLoader.item.implicitWidth;
            validSlots++;
        }
        if (trailingLoader.item && trailingLoader.item.implicitWidth > 0) {
            total += trailingLoader.item.implicitWidth;
            validSlots++;
        }

        if (validSlots > 1) {
            total += (validSlots - 1) * slotSpacing;
        }

        return Math.max(180, Math.ceil(total / 2) * 2);
    }

    // 1. 左侧槽位 (Leading Slot)
    Loader {
        id: leadingLoader
        anchors.left: parent.left
        anchors.leftMargin: slotLayout.paddingH
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: slotLayout.leadingComponent
        active: sourceComponent !== null

        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    // 2. 中间槽位 (Center Cavity)
    Loader {
        id: centerLoader
        anchors.centerIn: parent
        sourceComponent: slotLayout.centerComponent
        active: sourceComponent !== null

        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    // 3. 右侧槽位 (Trailing Slot)
    Loader {
        id: trailingLoader
        anchors.right: parent.right
        anchors.rightMargin: slotLayout.paddingH
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: slotLayout.trailingComponent
        active: sourceComponent !== null

        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}