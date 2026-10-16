// ==========================================
// 📄 File: IslandMaskController.qml
// 🌟 方案 B：物理视窗模式空实现保底（零开销）
// ==========================================
import QtQuick

Item {
    id: maskCtrl

    property var fsm: null
    property var rootItem: null
    property var capsuleItem: null
    property bool maskActive: false

    // 🚀【彻底切断死循环】：不再向系统派发任何遮罩指令，物理窗口即灵动岛本身
    function commit() {
        return;
    }
}