// =========================================================================
// 📄 File: ui/components/expanded/ExpandedSensorCoordinator.qml
// 🌟 展开态独立交互协调器 (免疫滚轮干扰 · 绝对物理坐标锁定版)
// =========================================================================
import QtQuick

Item {
    id: coordinator
    anchors.fill: parent

    property Item targetCapsule: null
    property bool isExpanded: false
    property int leaveDelayMs: 150 // 150ms 顺滑跟手收缩

    signal requestCollapse(string reason)
    signal requestAcquireFocus()
    signal requestRestoreFocus()

    // 🚀【绝对物理包围盒】：大卡片在 680x480 中的安全几何区 (宽 420, 高 240, 水平居中)
    // X: (680-420)/2 = 130 -> [120 ~ 560]
    // Y: topMargin 8 + 高 240 = 248 -> [0 ~ 258]
    function isInsideCardBounds(mx, my) {
        return (mx >= 120 && mx <= 560 && my >= 0 && my <= 258);
    }

    // 供顶栏切页滚轮调用的主动制动锁
    function brakeTimerOnWheel() {
        leaveTimer.stop();
    }

    onIsExpandedChanged: {
        leaveTimer.stop();
        if (isExpanded) {
            coordinator.requestAcquireFocus();
            console.log("[ExpandedCoordinator] ✅ 大卡片已展开 -> 启动纯物理坐标守护 (免疫滚轮与假离开)");
        } else {
            coordinator.requestRestoreFocus();
            console.log("[ExpandedCoordinator] 🔒 大卡片已收起 -> 归还键盘焦点");
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: coordinator.isExpanded
        onActivated: {
            leaveTimer.stop();
            console.log("[ExpandedCoordinator] 按下 Escape 键 -> 主动收起大卡片");
            coordinator.requestCollapse("Shortcut_Escape");
        }
    }

    // 1. 点击大卡片外部的真正桌面空白处立即收起 (Outside Click)
    MouseArea {
        id: outsideBackdropClickArea
        anchors.fill: parent
        z: 10
        enabled: coordinator.isExpanded
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (!coordinator.isInsideCardBounds(mouse.x, mouse.y)) {
                console.log("[ExpandedCoordinator] 🎯 点击了大卡片外部的桌面空白处 (x=" + mouse.x + ", y=" + mouse.y + ") -> 立即收起");
                leaveTimer.stop();
                coordinator.requestCollapse("Outside_Blank_Click");
            }
        }
    }

    // 2. 🚀【纯真坐标追踪雷达】：
    // 彻底切断 onExited 监听！无论底层报多少次假离开、无论滚轮怎么滚，只看真实 (x,y) 坐标！
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
                // 只要鼠标坐标在卡片矩形里（包括顶栏药丸），强行踩死收起定时器！
                leaveTimer.stop();
            } else {
                // 只有当鼠标坐标真真切切越过了卡片边界，才允许开启 150ms 跟手收起
                if (!leaveTimer.running) {
                    console.log("[ExpandedCoordinator] ⚠️ 坐标真正越过大卡片边界 (x=" + mouse.x + ", y=" + mouse.y + ") -> 启动 150ms 跟手收起");
                    leaveTimer.restart();
                }
            }
        }
    }

    // 3. 150ms 跟手平滑收起定时器
    Timer {
        id: leaveTimer
        interval: coordinator.leaveDelayMs
        repeat: false
        onTriggered: {
            if (coordinator.isExpanded) {
                console.log("[ExpandedCoordinator] 💥 确认划出大卡片 -> 执行跟手收起 COLLAPSE");
                coordinator.requestCollapse("Follow_Leave_" + coordinator.leaveDelayMs + "ms");
            }
        }
    }
}