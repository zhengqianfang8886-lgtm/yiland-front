// =========================================================================
// 📄 File: ui/components/expanded/ExpandedSensorCoordinator.qml
// 🌟 展开态动态感知协调器 (纯相对坐标映射 · 零硬编码 · 完美契合任意 Margin)
// =========================================================================
import QtQuick

Item {
    id: coordinator
    anchors.fill: parent

    property Item targetCapsule: null
    property bool isExpanded: false
    property int leaveDelayMs: 150

    signal requestCollapse(string reason)
    signal requestAcquireFocus()
    signal requestRestoreFocus()

    // 🚀【彻底消灭硬编码】：通过 mapToItem 动态换算当前卡片在 Coordinator 视口中的真实几何包围盒
    function isInsideCardBounds(mx, my) {
        if (!targetCapsule) return false;

        var pos = targetCapsule.mapToItem(coordinator, 0, 0);
        var marginTolerance = 4; // 容错边缘

        var minX = pos.x - marginTolerance;
        var maxX = pos.x + targetCapsule.width + marginTolerance;
        var minY = pos.y - marginTolerance;
        var maxY = pos.y + targetCapsule.height + marginTolerance;

        return (mx >= minX && mx <= maxX && my >= minY && my <= maxY);
    }

    function brakeTimerOnWheel() {
        leaveTimer.stop();
    }

    onIsExpandedChanged: {
        leaveTimer.stop();
        if (isExpanded) {
            coordinator.requestAcquireFocus();
        } else {
            coordinator.requestRestoreFocus();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: coordinator.isExpanded
        onActivated: {
            leaveTimer.stop();
            coordinator.requestCollapse("Shortcut_Escape");
        }
    }

    // 1. 点击大卡片外部的真正桌面空白处立即收起
    MouseArea {
        id: outsideBackdropClickArea
        anchors.fill: parent
        z: 10
        enabled: coordinator.isExpanded
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (!coordinator.isInsideCardBounds(mouse.x, mouse.y)) {
                leaveTimer.stop();
                coordinator.requestCollapse("Outside_Blank_Click");
            }
        }
    }

    // 2. 动态自适应坐标雷达追踪
    MouseArea {
        id: coordinateRadar
        anchors.fill: parent
        z: 12
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: coordinator.isExpanded

        onPositionChanged: (mouse) => {
            var inside = coordinator.isInsideCardBounds(mouse.x, mouse.y);
            if (inside) {
                leaveTimer.stop();
            } else {
                if (!leaveTimer.running) {
                    leaveTimer.restart();
                }
            }
        }
    }

    // 3. 150ms 顺滑跟手收起定时器
    Timer {
        id: leaveTimer
        interval: coordinator.leaveDelayMs
        repeat: false
        onTriggered: {
            if (coordinator.isExpanded) {
                coordinator.requestCollapse("Follow_Leave_" + coordinator.leaveDelayMs + "ms");
            }
        }
    }
}