// ==========================================
// 📄 File: power/PowerConfirmModal.qml (统一引用 PowerActionIcon 版)
// ==========================================
import QtQuick

Rectangle {
    id: modalRoot
    anchors.fill: parent
    radius: 12
    color: Qt.rgba(18 / 255, 18 / 255, 22 / 255, 0.96)
    border.color: isConfirming ? Qt.rgba(pendingColor.r, pendingColor.g, pendingColor.b, 0.5) : "transparent"
    border.width: 1.5
    visible: opacity > 0.001
    opacity: isConfirming ? 1.0 : 0.0
    scale: isConfirming ? 1.0 : 0.94
    z: 200

    property bool isConfirming: false
    property string pendingActionName: ""
    property string pendingIconType: ""
    property string pendingWarningText: ""
    property color pendingColor: Theme.danger
    property string chosenFont: ""
    readonly property string effectiveFont: chosenFont !== "" ? chosenFont : Theme.activeFont

    signal confirmed()
    signal cancelled()

    Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveFluid } }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animNormal
            easing.type: Theme.curveSpring
            easing.overshoot: Theme.springOvershootSubtle
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 40
        spacing: 12

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Rectangle {
                width: 32; height: 32; radius: 16
                color: Qt.rgba(modalRoot.pendingColor.r, modalRoot.pendingColor.g, modalRoot.pendingColor.b, 0.22)
                border.color: modalRoot.pendingColor; border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                // 🚀 核心优化：直接复用 PowerActionIcon
                PowerActionIcon {
                    anchors.centerIn: parent
                    iconType: modalRoot.pendingIconType
                    strokeColor: modalRoot.pendingColor
                    fillColor: modalRoot.pendingColor
                }
            }

            Text {
                text: "确定要执行 [ " + modalRoot.pendingActionName + " ] 吗？"
                color: "white"
                font.family: modalRoot.effectiveFont
                font.pixelSize: 15
                font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            text: modalRoot.pendingWarningText
            color: Qt.rgba(1, 1, 1, 0.75)
            font.family: modalRoot.effectiveFont
            font.pixelSize: 11
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Item { height: 2 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Rectangle {
                width: 100; height: 32; radius: 16
                color: cancelMouse.pressed ? Qt.rgba(1, 1, 1, 0.22) : (cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                border.color: Theme.borderSubtle; border.width: 1
                scale: cancelMouse.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: Theme.animInstant } }

                Row {
                    anchors.centerIn: parent; spacing: 4
                    Text { text: "✕"; color: Theme.textMuted; font.pixelSize: 11; font.weight: Font.Black }
                    Text { text: "取消"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: modalRoot.effectiveFont }
                }
                MouseArea { id: cancelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modalRoot.cancelled() }
            }

            Rectangle {
                width: 140; height: 32; radius: 16
                color: confirmMouse.pressed ? Qt.darker(modalRoot.pendingColor, 1.25) : (confirmMouse.containsMouse ? Qt.lighter(modalRoot.pendingColor, 1.1) : modalRoot.pendingColor)
                scale: confirmMouse.pressed ? 0.94 : (confirmMouse.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text { text: "✓"; color: "white"; font.pixelSize: 12; font.weight: Font.Black }
                    Text { text: "确认 " + modalRoot.pendingActionName; color: "white"; font.pixelSize: 12; font.weight: Font.Black; font.family: modalRoot.effectiveFont }
                }
                MouseArea { id: confirmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modalRoot.confirmed() }
            }
        }
    }
}