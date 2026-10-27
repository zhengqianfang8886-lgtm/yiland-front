// ==========================================
// 📄 File: ui/components/expanded/ExpandedSensorCoordinator.qml
// 🌟 展开态动态感知协调器 (绝对几何包络网 · 零震荡加固版)
// ==========================================
import QtQuick

Item {
    id: coordinator
    anchors.fill: parent

    property Item targetCapsule: null
    property bool isExpanded: false
    property bool isArmReady: false

    signal requestCollapse(string reason)
    signal requestAcquireFocus()
    signal requestRestoreFocus()

    Timer {
        id: armTimer
        interval: 320 // 确保两段式展开彻底落定再激活离开感应
        repeat: false
        onTriggered: {
            coordinator.isArmReady = true;
        }
    }

    // 找到 onIsExpandedChanged 块，将其替换为：
    onIsExpandedChanged: {
        if (isExpanded) {
            coordinator.isArmReady = false;
            armTimer.restart();
            // 🚀 彻底删除原先的 coordinator.requestAcquireFocus()！展开卡片看日历绝不抢焦点！
        } else {
            coordinator.isArmReady = false;
            armTimer.stop();
            // 🚀 收拢时，确保任何残留的输入法提权被强制重置，恢复绝对静默
            if (typeof Bridge !== "undefined" && Bridge.setRequireFocus) {
                Bridge.setRequireFocus(false);
            }
            coordinator.requestRestoreFocus();
        }
    }

    // =========================================================================
    // 🚀【绝对几何包络网】：单个 MouseArea 监控全视口，基于窗口全局绝对坐标判定
    // 彻底消灭切片 MouseArea 局域坐标 (mouseY=5) 导致的误报死循环！
    // =========================================================================
    MouseArea {
        id: globalDismissShield
        anchors.fill: parent
        enabled: coordinator.isExpanded && coordinator.isArmReady
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        // 胶囊当前在整个视口窗口中的绝对外轮廓
        readonly property int cX: targetCapsule ? Math.round(targetCapsule.x) : Math.round((coordinator.width - 420) / 2)
        readonly property int cY: targetCapsule ? Math.round(targetCapsule.y) : 8
        readonly property int cW: targetCapsule ? Math.round(targetCapsule.width) : 420
        readonly property int cH: targetCapsule ? Math.round(targetCapsule.height) : 240

        // 36px 舒适安全边缘（只有彻底滑出卡片外 36px，才算真正离开）
        readonly property int deadZone: 36

        function isPointOutsideCard(px, py) {
            return (px < (cX - deadZone)) || 
                   (px > (cX + cW + deadZone)) || 
                   (py < (cY - deadZone)) || 
                   (py > (cY + cH + deadZone));
        }

        onPositionChanged: (mouse) => {
            if (!coordinator.isArmReady) return;
            if (isPointOutsideCard(mouse.x, mouse.y)) {
                coordinator.requestCollapse("Crossed_Absolute_DeadZone");
            }
        }

        onClicked: (mouse) => {
            if (!coordinator.isArmReady) return;
            // 点击卡片外空白处直接收拢
            if (mouse.x < cX || mouse.x > (cX + cW) || mouse.y < cY || mouse.y > (cY + cH)) {
                coordinator.requestCollapse("Clicked_Outside_Card");
            }
        }
    }
}