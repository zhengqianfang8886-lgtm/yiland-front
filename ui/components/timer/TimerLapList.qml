// ==========================================
// 📄 File: timer/TimerLapList.qml (正向计时打点列表)
// ==========================================
import QtQuick

Item {
    id: lapListRoot
    width: parent.width
    height: 78

    property var laps: []
    property string textFont: ""
    property string displayFont: "Monospace"

    Column {
        anchors.centerIn: parent
        spacing: 4
        visible: lapListRoot.laps.length === 0

        Text {
            text: "正向连续计时"
            color: "white"
            font.pixelSize: 12
            font.weight: Font.Bold
            font.family: lapListRoot.textFont
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "支持随时暂停、重置与打点标记"
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: 10
            font.family: lapListRoot.textFont
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Column {
        anchors.fill: parent
        spacing: 4
        visible: lapListRoot.laps.length > 0

        Repeater {
            model: lapListRoot.laps
            Rectangle {
                width: parent.width
                height: 22
                radius: 6
                color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.12)

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 8

                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "计次 " + modelData.id
                        color: "#38bdf8"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: lapListRoot.textFont
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.time
                        color: "white"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.family: lapListRoot.displayFont
                    }
                }
            }
        }
    }
}