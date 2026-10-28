// =========================================================================
// 📄 File: ui/components/capsule/FluidPill.qml
// 🌟 苹果级流体微囊容器 (OutQuint 丝滑共振版)
// =========================================================================
import QtQuick

Item {
    id: pillRoot

    property int targetWidth: 0
    property int pillHeight: 26
    property real pillRadius: pillHeight / 2

    readonly property bool isAlive: targetWidth > 0
    readonly property bool isDying: !isAlive

    property color pillColor: Qt.rgba(255, 255, 255, 0.08)
    property color pillBorderColor: "transparent"
    property color hoverColor: "transparent"
    property color pressColor: "transparent"
    property color hoverBorderColor: "transparent"

    property bool interactive: true
    property int acceptedButtons: Qt.LeftButton | Qt.RightButton
    property int cursorShape: Qt.PointingHandCursor

    signal clicked(var mouse)
    signal rightClicked(var mouse)

    default property alias contentData: contentSlot.data

    height: pillHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    clip: pillRoot.isDying || (pillRoot.width < pillRoot.targetWidth - 2)

    width: isAlive ? targetWidth : 0
    visible: width > 0.5 || bgRect.opacity > 0.01

    // 🚀 同步外层大岛的黄金流体曲线：340ms + OutQuint
    Behavior on width {
        NumberAnimation {
            duration: 340
            easing.type: Easing.OutQuint
        }
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: pillRoot.pillRadius
        antialiasing: true

        color: {
            if (mouseArea.pressed && pillRoot.pressColor.a > 0.001) return pillRoot.pressColor;
            if (mouseArea.containsMouse && pillRoot.hoverColor.a > 0.001) return pillRoot.hoverColor;
            return pillRoot.pillColor;
        }
        border.color: {
            if (mouseArea.containsMouse && pillRoot.hoverBorderColor.a > 0.001) return pillRoot.hoverBorderColor;
            return pillRoot.pillBorderColor;
        }
        border.width: (border.color !== "transparent" && border.color.a > 0.01) ? 1 : 0

        scale: mouseArea.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        opacity: pillRoot.isDying ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        Item {
            id: contentSlot
            anchors.fill: parent

            // 🚀 让内容更晚出现、更早蒸发（阈值提升到 85%），避免在扩张初期发生视觉拥挤
            readonly property bool shouldVaporize: pillRoot.isDying || (pillRoot.width < Math.max(30, pillRoot.targetWidth * 0.85))

            opacity: shouldVaporize ? 0.0 : 1.0
            scale: shouldVaporize ? 0.75 : 1.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutQuint // 缩放也用更柔和的曲线
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            anchors.margins: -4
            enabled: pillRoot.interactive && pillRoot.isAlive
            hoverEnabled: true
            cursorShape: pillRoot.cursorShape
            acceptedButtons: pillRoot.acceptedButtons

            onClicked: (mouse) => {
                mouse.accepted = true;
                if (mouse.button === Qt.LeftButton) {
                    pillRoot.clicked(mouse);
                } else if (mouse.button === Qt.RightButton) {
                    pillRoot.rightClicked(mouse);
                }
            }
        }
    }
}