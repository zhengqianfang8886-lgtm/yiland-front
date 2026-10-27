// =========================================================================
// 📄 File: ui/components/capsule/FluidPill.qml
// 🌟 纯正流体微囊 (物理参数归一化 · 消除双重缓动畸变版)
// =========================================================================
import QtQuick

Item {
    id: pillRoot

    default property alias contentData: contentHolder.data
    property int preferredWidth: 40
    property bool active: false
    property color pillColor: Qt.rgba(255, 255, 255, 0.08)
    property color pillBorderColor: "transparent"
    property int flowDirection: 1
    property string debugName: "FluidPill"

    signal clicked()

    height: 24
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    clip: true

    // 统一物理参数
    readonly property int animSpeed: (typeof Theme !== "undefined") ? Theme.animFast : 160
    readonly property var motionEasing: (typeof Theme !== "undefined") ? Theme.curveSpring : Easing.OutCubic

    width: active ? preferredWidth : 0
    visible: width > 0.5 || pillRoot.opacity > 0.01

    Behavior on width {
        NumberAnimation {
            duration: pillRoot.animSpeed
            easing.type: pillRoot.motionEasing
            easing.overshoot: 1.12
        }
    }

    Item {
        id: liquidMorphWrapper
        anchors.fill: parent

        transform: [
            Scale {
                id: morphScale
                origin.x: pillRoot.flowDirection > 0 ? 0 : liquidMorphWrapper.width
                origin.y: liquidMorphWrapper.height / 2
                xScale: pillRoot.active ? 1.0 : 0.4
                yScale: pillRoot.active ? 1.0 : 1.15

                Behavior on xScale {
                    NumberAnimation {
                        duration: pillRoot.animSpeed
                        easing.type: pillRoot.motionEasing
                    }
                }
                Behavior on yScale {
                    NumberAnimation {
                        duration: pillRoot.animSpeed
                        easing.type: Easing.OutQuad
                    }
                }
            },
            Translate {
                id: driftTranslate
                x: pillRoot.active ? 0 : (pillRoot.flowDirection * -8)
                Behavior on x {
                    NumberAnimation {
                        duration: pillRoot.animSpeed
                        easing.type: Easing.OutQuad
                    }
                }
            }
        ]

        Rectangle {
            id: bgCapsule
            anchors.fill: parent
            radius: height / 2
            color: pillHover.hovered ? Qt.lighter(pillRoot.pillColor, 1.2) : pillRoot.pillColor
            border.color: pillRoot.pillBorderColor
            border.width: pillRoot.pillBorderColor !== "transparent" ? 1 : 0

            opacity: pillRoot.active ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: pillRoot.active ? 120 : 80 } }

            Item {
                id: contentHolder
                anchors.centerIn: parent
                opacity: bgCapsule.opacity
            }

            HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: pillRoot.clicked() }
        }
    }
}