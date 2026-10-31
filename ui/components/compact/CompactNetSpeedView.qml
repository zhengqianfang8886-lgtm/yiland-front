// ==========================================
// 📄 File: ui/components/compact/CompactNetSpeedView.qml
// 🌟 纯净大字醒目网速 (大字号 · 恒定高对比度 · 零颜色变化版)
// ==========================================
import QtQuick

Item {
    id: netRoot
    width: 58
    height: 24

    property string fontFam: "Monospace"
    property string downVal: "0"
    property string downUnit: "B/s"
    property string upVal: "0"
    property string upUnit: "B/s"

    // 🚀【恒定高对比度配色】：清晰醒目，但全周期物理锁定，绝无明暗呼吸闪烁
    readonly property color numColor: Qt.rgba(255, 255, 255, 0.88)   // 88% 亮白数值，大字醒目
    readonly property color arrowColor: Qt.rgba(255, 255, 255, 0.65) // 65% 锐利箭头
    readonly property color unitColor: Qt.rgba(255, 255, 255, 0.52)  // 52% 清晰单位

    Column {
        anchors.centerIn: parent
        spacing: 0

        // =====================================================================
        // 上传 (TX)
        // =====================================================================
        Item {
            width: netRoot.width
            height: 12

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "↑"
                font.family: netRoot.fontFam
                font.pixelSize: 10 // 放大醒目
                font.weight: Font.Bold
                color: netRoot.arrowColor
                renderType: Text.QtRendering
            }

            Item {
                anchors.left: parent.left
                anchors.leftMargin: 8
                width: 29 // 扩宽容纳大字
                height: parent.height

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: netRoot.upVal
                    font.family: netRoot.fontFam
                    font.pixelSize: 12 // 🚀 大字号加粗
                    font.weight: Font.Black
                    font.features: { "tnum": 1 } // 等宽锁死
                    color: netRoot.numColor
                    renderType: Text.QtRendering
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: netRoot.upUnit
                font.family: netRoot.fontFam
                font.pixelSize: 9 // 放大
                font.weight: Font.Bold
                color: netRoot.unitColor
                renderType: Text.QtRendering
            }
        }

        // =====================================================================
        // 下载 (RX)
        // =====================================================================
        Item {
            width: netRoot.width
            height: 12

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "↓"
                font.family: netRoot.fontFam
                font.pixelSize: 10 // 放大醒目
                font.weight: Font.Bold
                color: netRoot.arrowColor
                renderType: Text.QtRendering
            }

            Item {
                anchors.left: parent.left
                anchors.leftMargin: 8
                width: 29
                height: parent.height

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: netRoot.downVal
                    font.family: netRoot.fontFam
                    font.pixelSize: 12 // 🚀 大字号加粗
                    font.weight: Font.Black
                    font.features: { "tnum": 1 }
                    color: netRoot.numColor
                    renderType: Text.QtRendering
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: netRoot.downUnit
                font.family: netRoot.fontFam
                font.pixelSize: 9
                font.weight: Font.Bold
                color: netRoot.unitColor
                renderType: Text.QtRendering
            }
        }
    }
}