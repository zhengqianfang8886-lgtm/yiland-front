// =========================================================================
// 📄 File: ui/components/compact/CompactNetSpeedView.qml
// 🌟 双层微堆叠网速药丸 (零抖动 · 等宽字模 · 智能降噪高空间利用率版)
// =========================================================================
import QtQuick

Item {
    id: netRoot
    width: 46
    height: 22

    property string fontFam: "Monospace"
    property string downCompact: "0B"
    property string upCompact: "0B"

    // 智能流量活跃判定：若上下行皆为 0B 或极低，进入低对比度静默态
    readonly property bool isTrafficActive: (downCompact !== "0B" && downCompact !== "0K") || 
                                           (upCompact !== "0B" && upCompact !== "0K")

    signal clicked()

    Rectangle {
        id: bgPill
        anchors.fill: parent
        radius: 11
        antialiasing: true

        // 活跃时带微弱青绿内衬，静默时为深黑微透明
        color: netRoot.isTrafficActive ? Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.09) : Qt.rgba(255, 255, 255, 0.05)
        border.color: netHover.hovered ? "#34d399" : (netRoot.isTrafficActive ? Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.28) : Qt.rgba(255, 255, 255, 0.10))
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // =====================================================================
        // 上层：下载通道 (RX) - 翠绿 #34d399
        // =====================================================================
        Item {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 11

            Row {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text: "↓"
                    color: netRoot.isTrafficActive ? "#34d399" : Qt.rgba(255, 255, 255, 0.35)
                    font.family: netRoot.fontFam
                    font.pixelSize: 8
                    font.weight: Font.Black
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.QtRendering
                }

                Text {
                    text: netRoot.downCompact
                    color: netRoot.isTrafficActive ? "#34d399" : Qt.rgba(255, 255, 255, 0.45)
                    font.family: netRoot.fontFam
                    font.pixelSize: 9
                    font.weight: Font.Black
                    font.features: { "tnum": 1 } // 🚀 严格等宽数字，彻底根除跳动
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.QtRendering
                }
            }
        }

        // =====================================================================
        // 下层：上传通道 (TX) - 冰蓝 #38bdf8
        // =====================================================================
        Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 11

            Row {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text: "↑"
                    color: netRoot.isTrafficActive ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.30)
                    font.family: netRoot.fontFam
                    font.pixelSize: 8
                    font.weight: Font.Black
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.QtRendering
                }

                Text {
                    text: netRoot.upCompact
                    color: netRoot.isTrafficActive ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.40)
                    font.family: netRoot.fontFam
                    font.pixelSize: 9
                    font.weight: Font.Black
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.QtRendering
                }
            }
        }

        HoverHandler { id: netHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: netRoot.clicked() }
    }
}