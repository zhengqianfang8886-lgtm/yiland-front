// ==========================================
// 📄 File: capsule/CapsuleTuckGesture.qml
// 🌟 纯透明顶边隐形唤醒感应器 (无蓝条 · 零视觉元素)
// ==========================================
import QtQuick

Item {
    id: tuckRoot
    anchors.fill: parent

    property bool isTucked: false

    // 鼠标在屏幕顶边停驻 160ms 或点击一下，灵动岛向下滑落还原
    property int restoreDwellMs: 160

    signal requestTuck()
    signal requestRestore()

    // -------------------------------------------------------------------------
    // 🚀【完全隐形唤醒区】：没有任何颜色，没有任何线条，纯粹透明！
    // -------------------------------------------------------------------------
    Timer {
        id: dwellRestoreTimer
        interval: tuckRoot.restoreDwellMs
        repeat: false
        onTriggered: {
            if (tuckRoot.isTucked) tuckRoot.requestRestore()
        }
    }

    MouseArea {
        id: invisibleTopHitArea
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 220
        height: 6 // 紧贴屏幕顶端 6px 的隐形热区
        enabled: tuckRoot.isTucked
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: dwellRestoreTimer.restart()
        onExited: dwellRestoreTimer.stop()
        onClicked: {
            dwellRestoreTimer.stop()
            tuckRoot.requestRestore()
        }
    }
}