// =========================================================================
// 📄 File: ui/components/capsule/FluidSlotPod.qml
// 🌟 锁相环流体微囊容器 (修复 QColor 空值报错 · 消除内外脱节版)
// =========================================================================
import QtQuick
import "../../core/IslandLogger.js" as Logger

Item {
    id: podRoot

    property string slotId: "slot"
    property string slotName: "未命名槽位"
    property int targetWidth: 0
    property int podHeight: 22
    property real podRadius: podHeight / 2
    property int gapSpacing: 4

    property color podColor: Qt.rgba(255, 255, 255, 0.08)
    property color podBorderColor: "transparent"
    property color hoverColor: "transparent"
    property color pressColor: "transparent"
    property color hoverBorderColor: "transparent"

    property bool interactive: true
    property int acceptedButtons: Qt.LeftButton | Qt.RightButton
    property int cursorShape: Qt.PointingHandCursor

    signal clicked(var mouse)
    signal rightClicked(var mouse)

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
            onRunningChanged: {
                if (!running) {
                    podRoot.reportSettled();
                }
            }
        }
    }

    onEffectiveTargetFootprintChanged: {
        podRoot.width = effectiveTargetFootprint;
        if (isAlive) {
            Logger.slot(slotId, "BUD", "【" + slotName + "】流体出芽 -> 目标宽: " + targetWidth + "px (总占位: " + effectiveTargetFootprint + "px)");
        } else {
            Logger.slot(slotId, "IMPLODE", "【" + slotName + "】流体坍缩 -> 实体与边距同步归零");
        }
    }

    function reportSettled() {
        if (isAlive && Math.abs(width - effectiveTargetFootprint) < 0.5) {
            Logger.slot(slotId, "SETTLE", "【" + slotName + "】状态定序收敛完成 -> 稳态宽: " + Math.round(width) + "px");
        } else if (!isAlive && width <= 0.5) {
            Logger.slot(slotId, "DISMISS", "【" + slotName + "】完全消融闭合 -> 物理占位归零");
        }
    }

    readonly property real expansionRatio: {
        if (!isAlive || targetWidth <= 0) {
            return targetWidth > 0 ? 0.0 : Math.min(1.0, Math.max(0.0, (width - gapSpacing) / Math.max(1, targetWidth)));
        }
        return Math.min(1.0, Math.max(0.0, (width - gapSpacing) / targetWidth));
    }

    function smoothStep(e0, e1, x) {
        var t = Math.max(0.0, Math.min(1.0, (x - e0) / Math.max(0.0001, e1 - e0)));
        return t * t * (3.0 - 2.0 * t);
    }

    Rectangle {
        id: bgRect
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(0.0, podRoot.width - podRoot.gapSpacing)
        radius: podRoot.podRadius
        antialiasing: true

        // 🚀【核心修复：避免未定义属性访问 .a 导致的 QColor 报错】
        color: {
            if (mouseArea.pressed && String(podRoot.pressColor) !== "transparent") return podRoot.pressColor;
            if (mouseArea.containsMouse && String(podRoot.hoverColor) !== "transparent") return podRoot.hoverColor;
            return podRoot.podColor ? podRoot.podColor : Qt.rgba(255, 255, 255, 0.08);
        }

        border.color: {
            if (mouseArea.containsMouse && String(podRoot.hoverBorderColor) !== "transparent") return podRoot.hoverBorderColor;
            return podRoot.pillBorderColor ? podRoot.pillBorderColor : "transparent";
        }
        border.width: (border.color !== "transparent") ? 1 : 0

        scale: mouseArea.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

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

            onClicked: (mouse) => {
                mouse.accepted = true;
                if (mouse.button === Qt.LeftButton) podRoot.clicked(mouse);
                else if (mouse.button === Qt.RightButton) podRoot.rightClicked(mouse);
            }
        }
    }
}