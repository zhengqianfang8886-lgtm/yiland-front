import QtQuick

Rectangle {
    id: modalRoot
    anchors.fill: parent
    radius: 12
    color: Qt.rgba(18 / 255, 18 / 255, 22 / 255, 0.94)
    border.color: isConfirming ? pendingColor : "transparent"
    border.width: 1.5
    visible: isConfirming
    opacity: visible ? 1.0 : 0.0
    scale: visible ? 1.0 : 0.92
    z: 200

    property bool isConfirming: false
    property string pendingActionName: ""
    property string pendingIcon: ""
    property string pendingWarningText: ""
    property color pendingColor: Theme.danger
    property string chosenFont: ""

    signal confirmed()
    signal cancelled()

    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }

    Column {
        anchors.centerIn: parent
        width: parent.width - 40
        spacing: 10

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Rectangle {
                width: 32; height: 32; radius: 16
                color: Qt.rgba(modalRoot.pendingColor.r, modalRoot.pendingColor.g, modalRoot.pendingColor.b, 0.22)
                border.color: modalRoot.pendingColor; border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: modalRoot.pendingIcon; font.pixelSize: 16; font.weight: Font.Black; color: modalRoot.pendingColor }
            }

            Text {
                text: "确定要执行 [ " + modalRoot.pendingActionName + " ] 吗？"
                color: "white"; font.family: modalRoot.chosenFont; font.pixelSize: 15; font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Text {
            text: modalRoot.pendingWarningText
            color: Qt.rgba(1, 1, 1, 0.75); font.family: modalRoot.chosenFont; font.pixelSize: 11; font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; width: parent.width
        }

        Item { height: 4 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Rectangle {
                width: 100; height: 32; radius: 16
                color: cancelMouse.pressed ? Qt.rgba(1, 1, 1, 0.22) : (cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                border.color: Theme.borderSubtle; border.width: 1
                scale: cancelMouse.pressed ? 0.94 : 1.0

                Row {
                    anchors.centerIn: parent; spacing: 4
                    Text { text: "✕"; color: Theme.textMuted; font.pixelSize: 11; font.weight: Font.Black }
                    Text { text: "取消"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: modalRoot.chosenFont }
                }
                MouseArea { id: cancelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modalRoot.cancelled() }
            }

            Rectangle {
                width: 140; height: 32; radius: 16
                color: confirmMouse.pressed ? Qt.darker(modalRoot.pendingColor, 1.25) : (confirmMouse.containsMouse ? Qt.lighter(modalRoot.pendingColor, 1.1) : modalRoot.pendingColor)
                scale: confirmMouse.pressed ? 0.94 : (confirmMouse.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 100 } }

                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text { text: "✓"; color: "white"; font.pixelSize: 12; font.weight: Font.Black }
                    Text { text: "确认 " + modalRoot.pendingActionName; color: "white"; font.pixelSize: 12; font.weight: Font.Black; font.family: modalRoot.chosenFont }
                }
                MouseArea { id: confirmMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modalRoot.confirmed() }
            }
        }
    }
}