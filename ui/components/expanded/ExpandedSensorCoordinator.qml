// ==========================================
// 📄 File: ui/components/expanded/ExpandedSensorCoordinator.qml
// 🌟 展开态动态感知协调器 (已彻底移除冲突快捷键 · 纯粹外围几何感应版)
// ==========================================
import QtQuick

Item {
    id: coordinator
    anchors.fill: parent

    property Item targetCapsule: null
    property bool isExpanded: false

    // 展开动画过程中的防误触锁 (220ms)
    property bool isArmReady: false

    signal requestCollapse(string reason)
    signal requestAcquireFocus()
    signal requestRestoreFocus()

    Timer {
        id: armTimer
        interval: 220
        repeat: false
        onTriggered: {
            coordinator.isArmReady = true;
            console.log("[SensorDiag] 🛡️ 展开动画就绪，外围离开感应环正式激活");
        }
    }

    onIsExpandedChanged: {
        if (isExpanded) {
            coordinator.isArmReady = false;
            armTimer.restart();
            console.log("[SensorDiag] 🌟 展开状态确立，申请交互焦点");
            coordinator.requestAcquireFocus();
        } else {
            coordinator.isArmReady = false;
            armTimer.stop();
            console.log("[SensorDiag] 📦 收拢状态确立，恢复此前窗口焦点");
            coordinator.requestRestoreFocus();
        }
    }

    // 🚀【核心优化】：已彻底删除原先重复声明的 Shortcut { sequence: "Escape" }
    // 全局快捷键由顶级窗口 Island.qml 唯一仲裁，杜绝 Qt Quick 事件冲突。

    // =========================================================================
    // 🚀【空心环形外围感应区】：卡片中央 420x240 完全镂空，绝不被子控件劫持！
    // =========================================================================
    Item {
        id: hollowOuterField
        anchors.fill: parent
        enabled: coordinator.isExpanded && coordinator.isArmReady
        visible: enabled

        readonly property int cardW: 420
        readonly property int cardH: 240
        readonly property int cardX: Math.round((coordinator.width - cardW) / 2)
        readonly property int cardY: coordinator.targetCapsule ? Math.round(coordinator.targetCapsule.y) : 8
        readonly property int cardBottomY: cardY + cardH

        // 1. 左侧外围带 (宽 cardX)
        MouseArea {
            x: 0
            y: 0
            width: Math.max(0, hollowOuterField.cardX - 6)
            height: parent.height
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: {
                console.log("[SensorDiag] 🚪 光标向左划出卡片 -> 触发收拢");
                coordinator.requestCollapse("Crossed_Left_Boundary");
            }
            onClicked: {
                console.log("[SensorDiag] 🎯 点击卡片左侧空白处 -> 触发收拢");
                coordinator.requestCollapse("Click_Left_Blank");
            }
        }

        // 2. 右侧外围带 (宽 cardX)
        MouseArea {
            x: hollowOuterField.cardX + hollowOuterField.cardW + 6
            y: 0
            width: Math.max(0, coordinator.width - x)
            height: parent.height
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: {
                console.log("[SensorDiag] 🚪 光标向右划出卡片 -> 触发收拢");
                coordinator.requestCollapse("Crossed_Right_Boundary");
            }
            onClicked: {
                console.log("[SensorDiag] 🎯 点击卡片右侧空白处 -> 触发收拢");
                coordinator.requestCollapse("Click_Right_Blank");
            }
        }

        // 3. 下方外围带 (卡片底边以下的所有区域)
        MouseArea {
            x: Math.max(0, hollowOuterField.cardX - 6)
            y: hollowOuterField.cardBottomY + 6
            width: hollowOuterField.cardW + 12
            height: Math.max(0, coordinator.height - y)
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: {
                console.log("[SensorDiag] 🚪 光标向下划出卡片 -> 触发收拢");
                coordinator.requestCollapse("Crossed_Bottom_Boundary");
            }
            onClicked: {
                console.log("[SensorDiag] 🎯 点击卡片下方空白处 -> 触发收拢");
                coordinator.requestCollapse("Click_Bottom_Blank");
            }
        }
    }
}