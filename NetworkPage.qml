import QtQuick

Item {
    id: netRoot

    property string chosenFont: ""
    property string downSpeed: "0.0 B/s"
    property string upSpeed: "0.0 B/s"
    property string localIp: "127.0.0.1"
    property string netStatus: "已连接"

    Row {
        anchors.fill: parent
        spacing: 14

        // 1. 左侧下行速率大卡片
        Rectangle {
            width: (parent.width - 14) / 2
            height: parent.height
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(56, 189, 248, 0.2)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 6

                Row {
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle { width: 6; height: 6; radius: 3; color: "#38bdf8"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "DOWNLOAD"; font.pixelSize: 10; font.weight: Font.Black; color: "#38bdf8"; font.family: netRoot.chosenFont; font.letterSpacing: 0.8 }
                }

                Text {
                    text: netRoot.downSpeed
                    color: "white"
                    font.pixelSize: 24
                    font.weight: Font.Black
                    font.family: (netRoot.chosenFont !== "") ? netRoot.chosenFont : "Monospace"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "实时下行带宽"
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.family: netRoot.chosenFont
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // 2. 右侧上行速率大卡片
        Rectangle {
            width: (parent.width - 14) / 2
            height: parent.height
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(52, 211, 153, 0.2)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 6

                Row {
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle { width: 6; height: 6; radius: 3; color: "#34d399"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "UPLOAD"; font.pixelSize: 10; font.weight: Font.Black; color: "#34d399"; font.family: netRoot.chosenFont; font.letterSpacing: 0.8 }
                }

                Text {
                    text: netRoot.upSpeed
                    color: "white"
                    font.pixelSize: 24
                    font.weight: Font.Black
                    font.family: (netRoot.chosenFont !== "") ? netRoot.chosenFont : "Monospace"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                        text: "IP: " + netRoot.localIp
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.family: (netRoot.chosenFont !== "") ? netRoot.chosenFont : "Monospace"
                    }
                }
            }
        }
    }
}