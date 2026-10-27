// =========================================================================
// 📄 File: ui/components/compact/CompactNetSpeedView.qml
// 🌟 纯结构化微堆叠网速药丸 (零 JS 解析 · 绝对等宽对齐 · 纳秒级响应版)
// =========================================================================
import QtQuick

Item {
    id: netRoot
    width: 68
    height: 24

    property string fontFam: "Monospace"

    // 🚀【直连结构化字段】：不再需要任何 trim/split/substring 操作
    property string downVal: "0"
    property string downUnit: "B/s"
    property string upVal: "0"
    property string upUnit: "B/s"
    property string downCompact: "0B"
    property string upCompact: "0B"

    readonly property bool isTrafficActive: (downCompact !== "0B" && downCompact !== "0K") || 
                                           (upCompact !== "0B" && upCompact !== "0K")

    signal clicked()

    Rectangle {
        id: bgPill
        anchors.fill: parent
        radius: 12
        antialiasing: true

        color: netRoot.isTrafficActive ? Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
        border.color: netHover.hovered ? "#34d399" : (netRoot.isTrafficActive ? Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.25) : "transparent")
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        Column {
            anchors.centerIn: parent
            spacing: 0

            // =================================================================
            // 上层：上传 (TX) - 冰蓝 #38bdf8
            // =================================================================
            Item {
                width: netRoot.width
                height: 11

                Row {
                    anchors.centerIn: parent
                    spacing: 0

                    // 箭头指示
                    Item {
                        width: 10; height: 11
                        Text {
                            anchors.centerIn: parent
                            text: "↑"
                            color: netRoot.isTrafficActive ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.35)
                            font.family: netRoot.fontFam
                            font.pixelSize: 8
                            font.weight: Font.Black
                            renderType: Text.QtRendering
                        }
                    }

                    Item { width: 2; height: 11 }

                    // 数值槽位 (定宽 30px 右对齐，等宽字模)
                    Item {
                        width: 30; height: 11
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: netRoot.upVal
                            color: netRoot.isTrafficActive ? "#f0f9ff" : Qt.rgba(255, 255, 255, 0.45)
                            font.family: netRoot.fontFam
                            font.pixelSize: 10
                            font.weight: Font.Black
                            font.features: { "tnum": 1 }
                            renderType: Text.QtRendering
                        }
                    }

                    Item { width: 2; height: 11 }

                    // 单位槽位 (定宽 20px 左对齐)
                    Item {
                        width: 20; height: 11
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: netRoot.upUnit
                            color: netRoot.isTrafficActive ? Qt.rgba(125 / 255, 211 / 255, 252 / 255, 0.75) : Qt.rgba(255, 255, 255, 0.30)
                            font.family: netRoot.fontFam
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            renderType: Text.QtRendering
                        }
                    }
                }
            }

            // =================================================================
            // 下层：下载 (RX) - 翠绿 #34d399
            // =================================================================
            Item {
                width: netRoot.width
                height: 11

                Row {
                    anchors.centerIn: parent
                    spacing: 0

                    Item {
                        width: 10; height: 11
                        Text {
                            anchors.centerIn: parent
                            text: "↓"
                            color: netRoot.isTrafficActive ? "#34d399" : Qt.rgba(255, 255, 255, 0.35)
                            font.family: netRoot.fontFam
                            font.pixelSize: 8
                            font.weight: Font.Black
                            renderType: Text.QtRendering
                        }
                    }

                    Item { width: 2; height: 11 }

                    Item {
                        width: 30; height: 11
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: netRoot.downVal
                            color: netRoot.isTrafficActive ? "#ecfdf5" : Qt.rgba(255, 255, 255, 0.50)
                            font.family: netRoot.fontFam
                            font.pixelSize: 10
                            font.weight: Font.Black
                            font.features: { "tnum": 1 }
                            renderType: Text.QtRendering
                        }
                    }

                    Item { width: 2; height: 11 }

                    Item {
                        width: 20; height: 11
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: netRoot.downUnit
                            color: netRoot.isTrafficActive ? Qt.rgba(110 / 255, 231 / 255, 183 / 255, 0.75) : Qt.rgba(255, 255, 255, 0.30)
                            font.family: netRoot.fontFam
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            renderType: Text.QtRendering
                        }
                    }
                }
            }
        }

        HoverHandler { id: netHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: netRoot.clicked() }
    }
}