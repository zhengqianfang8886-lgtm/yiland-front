// =========================================================================
// 📄 File: ui/components/capsule/FluidPill.qml
// 🌟 苹果级流体微囊容器 (零间距断层 · 单一物理相位对齐 · 精准单次日志版)
// =========================================================================
import QtQuick

Item {
    id: pillRoot

    property string pillName: "slot"
    property int targetWidth: 0                 // 纯内容宽度 (例如 26, 40)
    property int pillHeight: 22
    property real pillRadius: pillHeight / 2
    property int gapSpacing: 4                  // 🚀 伴随微囊一起缩放的间距

    property color pillColor: Qt.rgba(255, 255, 255, 0.08)
    property color pillBorderColor: "transparent"
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

    // 🚀【核心设计 1：将间距作为微囊 Footprint 的一部分统一收拢】
    // 目标总占位宽度 = 内部宽度 + 动态外间距 (当 targetWidth=0 时，间距也必须平滑变为 0！)
    readonly property real effectiveTargetFootprint: isAlive ? (targetWidth + gapSpacing) : 0.0

    // 🚀【核心设计 2：物理相位锁相环】：与外层大岛完全一致的 300ms + OutQuint 极长尾缓动！
    width: 0.0
    height: pillHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    clip: true

    visible: width > 0.2

    Behavior on width {
        id: widthBehavior
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutQuint
            onRunningChanged: {
                if (!running) {
                    pillRoot.checkSettled();
                }
            }
        }
    }

    onEffectiveTargetFootprintChanged: {
        pillRoot.width = effectiveTargetFootprint;
        if (isAlive) {
            console.log("[FluidSlot:" + pillName + "] 🚀 出芽展开 -> 目标宽: " + targetWidth + "px (总占位: " + effectiveTargetFootprint + "px)");
        } else {
            console.log("[FluidSlot:" + pillName + "] 💨 塌缩消融 -> 实体与边距同步归零");
        }
    }

    // 🚀【核心设计 3：精准单次日志遥测，绝不再刷屏】
    function checkSettled() {
        if (isAlive && Math.abs(width - effectiveTargetFootprint) < 0.5) {
            console.log("[FluidSlot:" + pillName + "] 🟢 状态定序收敛完成 -> 稳态宽: " + Math.round(width) + "px");
        } else if (!isAlive && width <= 0.5) {
            console.log("[FluidSlot:" + pillName + "] ⚪ 完全消融闭合 -> 物理占位归零");
        }
    }

    // 连续展开比率 (0.00 ~ 1.00)
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

    // 实际的背景药丸主体 (右侧留出 gapSpacing 作为自然呼吸空隙)
    Rectangle {
        id: bgRect
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(0.0, pillRoot.width - pillRoot.gapSpacing)
        radius: pillRoot.pillRadius
        antialiasing: true

        color: {
            if (mouseArea.pressed && pillRoot.pressColor.a > 0.001) return pillRoot.pressColor;
            if (mouseArea.containsMouse && pillRoot.hoverColor.a > 0.001) return pillRoot.hoverColor;
            return pillRoot.pillColor;
        }
        border.color: {
            if (mouseArea.containsMouse && pillRoot.hoverBorderColor.a > 0.001) return pillRoot.hoverBorderColor;
            return pillRoot.pillBorderColor;
        }
        border.width: (border.color !== "transparent" && border.color.a > 0.01) ? 1 : 0

        scale: mouseArea.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Item {
            id: contentSlot
            anchors.centerIn: parent
            width: pillRoot.targetWidth > 0 ? pillRoot.targetWidth : parent.width
            height: parent.height

            // 柔和连续透明度与缩放 (同步展开，消除闪现)
            opacity: pillRoot.smoothStep(0.12, 0.55, pillRoot.expansionRatio)
            scale: 0.75 + 0.25 * pillRoot.smoothStep(0.08, 0.85, pillRoot.expansionRatio)
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: pillRoot.interactive && pillRoot.isAlive
            hoverEnabled: true
            cursorShape: pillRoot.cursorShape
            acceptedButtons: pillRoot.acceptedButtons

            onClicked: (mouse) => {
                mouse.accepted = true;
                if (mouse.button === Qt.LeftButton) pillRoot.clicked(mouse);
                else if (mouse.button === Qt.RightButton) pillRoot.rightClicked(mouse);
            }
        }
    }
}