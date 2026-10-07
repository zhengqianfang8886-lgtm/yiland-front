// ==========================================
// 📄 File: power/PowerConfirmModal.qml (流体阻尼模态弹窗)
// ==========================================
import QtQuick
import QtQuick.Shapes

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
    readonly property string effectiveFont: {
        if (typeof Config !== "undefined" && Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) {
            return Config.fontFamily
        }
        return ""
    }

    signal confirmed()
    signal cancelled()

    // 中央动效接管
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

                Item {
                    anchors.centerIn: parent
                    width: 16; height: 16

                    Shape {
                        anchors.fill: parent
                        visible: modalRoot.pendingIconType === "poweroff"
                        layer.enabled: true
                        layer.samples: 4
                        ShapePath {
                            strokeColor: modalRoot.pendingColor
                            strokeWidth: 1.8
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 4.8; startY: 4.4
                            PathArc { x: 11.2; y: 4.4; radiusX: 5.8; radiusY: 5.8; useLargeArc: true }
                        }
                        ShapePath {
                            strokeColor: modalRoot.pendingColor
                            strokeWidth: 1.8
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 8.0; startY: 1.5
                            PathLine { x: 8.0; y: 8.0 }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        visible: modalRoot.pendingIconType === "reboot"
                        layer.enabled: true
                        layer.samples: 4
                        ShapePath {
                            strokeColor: modalRoot.pendingColor
                            strokeWidth: 1.7
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 8.0; startY: 1.8
                            PathArc { x: 14.2; y: 8.0; radiusX: 6.2; radiusY: 6.2; useLargeArc: false }
                            PathArc { x: 8.0; y: 14.2; radiusX: 6.2; radiusY: 6.2; useLargeArc: false }
                            PathArc { x: 2.5; y: 9.8; radiusX: 6.2; radiusY: 6.2; useLargeArc: false }
                        }
                        ShapePath {
                            fillColor: modalRoot.pendingColor
                            strokeColor: "transparent"
                            startX: 0.8; startY: 10.5
                            PathLine { x: 4.5; y: 10.5 }
                            PathLine { x: 2.6; y: 6.8 }
                            PathLine { x: 0.8; y: 10.5 }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        visible: modalRoot.pendingIconType === "suspend"
                        layer.enabled: true
                        layer.samples: 4
                        ShapePath {
                            fillColor: modalRoot.pendingColor
                            strokeColor: "transparent"
                            startX: 12.0; startY: 2.5
                            PathArc { x: 4.0; y: 13.5; radiusX: 6.5; radiusY: 6.5; useLargeArc: false }
                            PathQuad { x: 12.0; y: 2.5; controlX: 9.2; controlY: 8.5 }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        visible: modalRoot.pendingIconType === "lock"
                        layer.enabled: true
                        layer.samples: 4
                        ShapePath {
                            strokeColor: modalRoot.pendingColor
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 5.0; startY: 6.8
                            PathLine { x: 5.0; y: 4.8 }
                            PathArc { x: 11.0; y: 4.8; radiusX: 3.0; radiusY: 3.0; useLargeArc: false }
                            PathLine { x: 11.0; y: 6.8 }
                        }
                        ShapePath {
                            fillColor: modalRoot.pendingColor
                            strokeColor: "transparent"
                            startX: 2.8; startY: 6.8
                            PathLine { x: 13.2; y: 6.8 }
                            PathLine { x: 13.2; y: 14.5 }
                            PathLine { x: 2.8; y: 14.5 }
                            PathLine { x: 2.8; y: 6.8 }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        visible: modalRoot.pendingIconType === "logout"
                        layer.enabled: true
                        layer.samples: 4
                        ShapePath {
                            strokeColor: modalRoot.pendingColor
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            startX: 8.5; startY: 2.0
                            PathLine { x: 2.5; y: 2.0 }
                            PathLine { x: 2.5; y: 14.0 }
                            PathLine { x: 8.5; y: 14.0 }
                        }
                        ShapePath {
                            strokeColor: modalRoot.pendingColor
                            strokeWidth: 1.7
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            startX: 6.2; startY: 8.0
                            PathLine { x: 14.2; y: 8.0 }
                            PathMove { x: 11.2; y: 4.8 }
                            PathLine { x: 14.2; y: 8.0 }
                            PathLine { x: 11.2; y: 11.2 }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        visible: modalRoot.pendingIconType === "switch"
                        layer.enabled: true
                        layer.samples: 4
                        ShapePath {
                            strokeColor: modalRoot.pendingColor
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            startX: 2.0; startY: 5.0
                            PathLine { x: 13.0; y: 5.0 }
                            PathMove { x: 10.0; y: 2.5 }
                            PathLine { x: 13.0; y: 5.0 }
                            PathLine { x: 10.0; y: 7.5 }
                        }
                        ShapePath {
                            strokeColor: modalRoot.pendingColor
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            startX: 14.0; startY: 11.0
                            PathLine { x: 3.0; y: 11.0 }
                            PathMove { x: 6.0; y: 8.5 }
                            PathLine { x: 3.0; y: 11.0 }
                            PathLine { x: 6.0; y: 13.5 }
                        }
                    }
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