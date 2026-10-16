// ==========================================
// 📄 File: PreviewSandbox.qml
// 🌟 独立调试工作台（单岛纯净版）
// ==========================================
import QtQuick
import QtQuick.Controls

Rectangle {
    id: sandboxRoot
    width: 1000
    height: 520

    property int bgMode: 0

    color: {
        if (bgMode === 0) return "#f1f5f9"
        if (bgMode === 1) return "#0f172a"
        return "#1e293b"
    }
    Behavior on color { ColorAnimation { duration: 200 } }

    Grid {
        anchors.fill: parent
        visible: sandboxRoot.bgMode === 2
        columns: 50; rows: 26
        Repeater {
            model: 50 * 26
            Rectangle {
                width: 20; height: 20
                color: ((index % 50 + Math.floor(index / 50)) % 2 === 0) ? "#334155" : "#1e293b"
            }
        }
    }

    Rectangle {
        id: ceilingLine
        anchors.top: parent.top
        anchors.topMargin: 20
        width: parent.width; height: 2
        color: "#ef4444"; opacity: 0.6; z: 99

        Text {
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.bottom: parent.top; anchors.bottomMargin: 2
            text: "▲ 模拟屏幕最顶端边界 (Screen Top: y=0)"
            color: "#ef4444"; font.pixelSize: 10; font.bold: true
        }
    }

    Item {
        id: islandHost
        anchors.top: ceilingLine.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 860; height: 270

        Island {
            id: realIsland
            anchors.fill: parent
        }
    }

    Rectangle {
        id: controlDock
        anchors.bottom: parent.bottom; anchors.bottomMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        height: 48; width: dockRow.implicitWidth + 24; radius: 24
        color: Qt.rgba(15 / 255, 23 / 255, 42 / 255, 0.92)
        border.color: Qt.rgba(255, 255, 255, 0.15); border.width: 1; z: 100

        Row {
            id: dockRow
            anchors.centerIn: parent; spacing: 8

            Button {
                text: sandboxRoot.bgMode === 0 ? "🎨 白底(测残影)" : (sandboxRoot.bgMode === 1 ? "🎨 深色底" : "🎨 棋盘格")
                onClicked: sandboxRoot.bgMode = (sandboxRoot.bgMode + 1) % 3
            }

            Rectangle { width: 1; height: 24; color: Qt.rgba(1, 1, 1, 0.2); anchors.verticalCenter: parent.verticalCenter }

            Button { text: "🔄 滚轮切桌面"; onClicked: Bridge.mockNextWorkspace() }
            Button { text: "🎵 播放/暂停"; onClicked: Bridge.mockToggleMusic() }
            Button { text: "🔔 模拟通知"; onClicked: Bridge.mockTriggerAlert() }
            Button { text: "📞 模拟来电"; onClicked: Bridge.mockTriggerCall() }
            Button { text: "❌ 挂断"; onClicked: Bridge.mockEndCall() }
        }
    }

    Rectangle {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        width: statusCol.implicitWidth + 16; height: statusCol.implicitHeight + 12
        radius: 8; color: Qt.rgba(0, 0, 0, 0.75); z: 100

        Column {
            id: statusCol
            anchors.centerIn: parent; spacing: 3
            Text {
                text: "FSM 状态: " + (realIsland.capsule && realIsland.capsule.fsm ? realIsland.capsule.fsm.stateName : "UNKNOWN")
                color: "#38bdf8"; font.pixelSize: 11; font.bold: true; font.family: "Monospace"
            }
            Text {
                text: "主岛着陆: " + (realIsland.capsule && realIsland.capsule.fsm ? realIsland.capsule.fsm.isSettled : "false")
                color: "#34d399"; font.pixelSize: 10; font.family: "Monospace"
            }
            Text {
                text: "胶囊宽度: " + (realIsland.capsule ? Math.round(realIsland.capsule.width) : 0) + " px"
                color: "#f59e0b"; font.pixelSize: 10; font.family: "Monospace"
            }
        }
    }
}