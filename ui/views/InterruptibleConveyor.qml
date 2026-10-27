// ==========================================
// 📄 File: ui/views/InterruptibleConveyor.qml
// 🌟 纯数学归一化可打断平滑滑动传送带 (双槽位 · 零跳帧 · 动态卸载版)
// ==========================================
import QtQuick

Item {
    id: conveyorRoot
    anchors.fill: parent
    clip: true

    property string currentKey: "hardware"
    property var keyToComponentMap: ({})

    // 内部运行状态
    property string activeKey: currentKey
    property string departingKey: ""
    property int slideDir: 1 // 1: 从右向左入场 (Next), -1: 从左向右入场 (Prev)
    property real progress: 1.0

    readonly property bool isTransitioning: progressAnim.running

    signal transitionStarted(string fromKey, string toKey, int direction)
    signal transitionFinished(string settledKey)

    // 🚀【核心切页入口】：支持瞬时打断与动态变向
    function switchTo(newKey, explicitDir) {
        if (!newKey || !keyToComponentMap || !keyToComponentMap[newKey]) return;
        if (newKey === activeKey && !isTransitioning) return;

        // 如果在过渡中途再次收到新目标
        if (isTransitioning) {
            progressAnim.stop();
            // 将当前的入场者降级为离场者
            departingKey = activeKey;
        } else {
            departingKey = activeKey;
        }

        activeKey = newKey;
        slideDir = (explicitDir !== undefined && explicitDir !== 0) ? explicitDir : 1;

        transitionStarted(departingKey, activeKey, slideDir);

        progressAnim.restart();
    }

    NumberAnimation {
        id: progressAnim
        target: conveyorRoot
        property: "progress"
        from: 0.0
        to: 1.0
        duration: (typeof Theme !== "undefined") ? Theme.animFast : 180
        easing.type: Easing.OutCubic
        onFinished: {
            conveyorRoot.departingKey = "";
            conveyorRoot.transitionFinished(conveyorRoot.activeKey);
        }
    }

    // =========================================================================
    // 槽位 1：离场视图 (Departing Slot)
    // 从 0.0 线性/平滑推向 -slideDir * width
    // =========================================================================
    Loader {
        id: departingLoader
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width
        visible: conveyorRoot.departingKey !== "" && conveyorRoot.isTransitioning
        active: visible

        x: -conveyorRoot.progress * (conveyorRoot.slideDir * conveyorRoot.width)

        sourceComponent: (conveyorRoot.departingKey && conveyorRoot.keyToComponentMap) ? 
                         conveyorRoot.keyToComponentMap[conveyorRoot.departingKey] : null

        // 退场时伴随微弱淡出，减少视觉冲击
        opacity: Math.max(0.0, 1.0 - conveyorRoot.progress * 1.2)
    }

    // =========================================================================
    // 槽位 2：入场激活视图 (Active Slot)
    // 从 slideDir * width 逼近到 0.0
    // =========================================================================
    Loader {
        id: activeLoader
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width
        x: (1.0 - conveyorRoot.progress) * (conveyorRoot.slideDir * conveyorRoot.width)

        sourceComponent: (conveyorRoot.activeKey && conveyorRoot.keyToComponentMap) ? 
                         conveyorRoot.keyToComponentMap[conveyorRoot.activeKey] : null

        opacity: Math.min(1.0, conveyorRoot.progress * 1.5)
    }
}