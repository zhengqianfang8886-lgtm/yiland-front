// ==========================================
// 📄 File: capsule/CapsuleSpecularGlint.qml (极致克制·彻底消除白线)
// ==========================================
import QtQuick

Item {
    id: glintCanvas
    anchors.fill: parent
    clip: false
    z: 3
    enabled: false

    property bool isPureIdle: false
    property real capsuleWidth: parent.width
    property real capsuleHeight: parent.height
    property real capsuleRadius: 17
    property color accentColor: "transparent"
    property bool hasAccent: false

    // 不画任何硬线，仅在微纯空闲态下保留极轻微的微光呼吸
    Rectangle {
        anchors.fill: parent
        radius: glintCanvas.capsuleRadius
        color: "transparent"
        opacity: glintCanvas.hasAccent ? 0.15 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Rectangle {
            anchors.fill: parent
            radius: glintCanvas.capsuleRadius
            color: glintCanvas.accentColor
        }
    }
}