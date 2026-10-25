// ==========================================
// 📄 File: ui/views/InterruptibleConveyor.qml
// 🌟 零卡顿可打断传送带引擎 (Dual-Slot Conveyor 防空健壮版)
// ==========================================
import QtQuick

Item {
    id: conveyorRoot
    clip: true

    property string currentKey: "hardware"
    property var keyToComponentMap: ({})

    property string activeKey: currentKey
    property string departingKey: ""
    property real slideOffset: 0.0
    property int slideDir: 1

    onCurrentKeyChanged: {
        if (activeKey !== currentKey && departingKey === "") {
            activeKey = currentKey;
        }
    }

    function switchTo(newKey, explicitDir) {
        if (!newKey || (newKey === activeKey && departingKey === "")) return;

        slideDir = explicitDir !== undefined && explicitDir !== 0 ? explicitDir : 1;

        departingKey = activeKey;
        activeKey = newKey;

        slideAnim.stop();
        slideAnim.from = slideDir > 0 ? width : -width;
        slideAnim.to = 0;
        slideAnim.start();
    }

    NumberAnimation {
        id: slideAnim
        target: conveyorRoot
        property: "slideOffset"
        duration: (typeof Theme !== "undefined") ? Theme.animFast : 160
        easing.type: Easing.OutCubic
        onFinished: {
            conveyorRoot.departingKey = "";
        }
    }

    // 槽位 1：正在离去的视图
    Loader {
        id: departingLoader
        width: parent.width; height: parent.height
        visible: conveyorRoot.departingKey !== ""
        x: conveyorRoot.slideOffset - (conveyorRoot.slideDir > 0 ? conveyorRoot.width : -conveyorRoot.width)
        sourceComponent: (conveyorRoot.keyToComponentMap && conveyorRoot.departingKey) ? conveyorRoot.keyToComponentMap[conveyorRoot.departingKey] : null
    }

    // 槽位 2：正在入场的激活视图
    Loader {
        id: activeLoader
        width: parent.width; height: parent.height
        x: conveyorRoot.slideOffset
        sourceComponent: (conveyorRoot.keyToComponentMap && conveyorRoot.activeKey) ? conveyorRoot.keyToComponentMap[conveyorRoot.activeKey] : null
    }
}