// ==========================================
// 📄 File: ui/components/compact/CompactCpuView.qml
// 🌟 纯粹的内容展示层 (外观与行为已彻底解耦至 FluidSlotPod)
// ==========================================
import QtQuick

Item {
    id: cpuRoot
    anchors.fill: parent

    property int cpuPercent: 0
    property string fontFam: "Monospace"

    readonly property color riskColor: {
        if (cpuPercent < 50) return "#30D158";
        if (cpuPercent < 70) return "#FFD60A";
        if (cpuPercent < 90) return "#FF9F0A";
        return "#FF453A";
    }

    Row {
        anchors.centerIn: parent
        spacing: 5

        Item {
            width: 12; height: 12 
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: cpuRoot.riskColor
                border.width: 1.5; radius: 3
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Rectangle {
                    anchors.centerIn: parent
                    width: 4; height: 4 
                    radius: 1; color: cpuRoot.riskColor
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    SequentialAnimation on opacity {
                        running: cpuRoot.cpuPercent >= 90
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.15; duration: 400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.00; duration: 400; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        Item {
            width: 26; height: 14
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: cpuRoot.cpuPercent + "%"
                color: cpuRoot.riskColor
                font.family: cpuRoot.fontFam
                font.pixelSize: 11 
                font.weight: Font.Bold
                font.features: { "tnum": 1 } 
                horizontalAlignment: Text.AlignRight
                renderType: Text.QtRendering
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }
}