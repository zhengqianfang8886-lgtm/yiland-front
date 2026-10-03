import QtQuick

Row {
    id: osdRoot
    spacing: 8

    property string chosenFont: ""
    property string osdIcon: "🔊"
    property int osdValue: 50
    property int parentWidth: 100

    readonly property bool isHardwareMuted: (osdIcon === "🔇" || osdIcon === "🚫")

    Rectangle {
        width: Math.max(54, Math.min(94, osdRoot.parentWidth - 64))
        height: 5; radius: 2.5; color: Qt.rgba(1, 1, 1, 0.16)
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        Rectangle {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            height: parent.height; radius: parent.radius
            color: osdRoot.isHardwareMuted ? Theme.danger : "white"
            width: osdRoot.isHardwareMuted ? 0 : Math.round(parent.width * Math.min(1.0, Math.max(0.0, osdRoot.osdValue / 100.0)))
            Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    Text {
        text: osdRoot.isHardwareMuted ? "静音" : (Math.min(100, Math.max(0, osdRoot.osdValue)) + "%")
        color: osdRoot.isHardwareMuted ? Theme.danger : "white"
        font.family: osdRoot.isHardwareMuted ? osdRoot.chosenFont : "Monospace"
        font.pixelSize: 12; font.weight: Font.Black; font.letterSpacing: 0.3
        anchors.verticalCenter: parent.verticalCenter
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}