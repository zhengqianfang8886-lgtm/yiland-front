// ==========================================
// 📄 File: ui/components/settings/SettingsPositionCard.qml
// 🌟 悬浮位置与胶囊高度调控卡片 (集成深潜隐形开关)
// ==========================================
import QtQuick
import QtQuick.Controls

Rectangle {
    id: cardRoot
    height: positionCol.implicitHeight + 24
    radius: 12
    color: Qt.rgba(1, 1, 1, 0.05)
    border.color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.35)
    border.width: 1

    Column {
        id: positionCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Row {
            spacing: 6
            Text { text: "📐"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "悬浮几何与物理高度档位"; color: "#38bdf8"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
        }

        // 胶囊高度档位选择
        Column {
            width: parent.width
            spacing: 6

            Item {
                width: parent.width; height: 16
                Text { text: "胶囊基准高度 (Capsule Height)"; color: "white"; font.pixelSize: 11; font.bold: true; anchors.left: parent.left }
                Text {
                    text: ((typeof Config !== "undefined") ? Config.capsuleHeight : 36) + " px"
                    color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Black; font.family: "Monospace"; anchors.right: parent.right
                }
            }

            Row {
                spacing: 8
                Repeater {
                    model: [
                        { label: "32px 极简精巧", sub: "适合小屏幕/笔记本", val: 32 },
                        { label: "36px 平衡推荐", sub: "黄金比例长宽比", val: 36 },
                        { label: "42px 醒目大屏", sub: "触控/4K大显示器", val: 42 }
                    ]

                    Rectangle {
                        width: (positionCol.width - 16) / 3
                        height: 48
                        radius: 8
                        readonly property bool isSel: (typeof Config !== "undefined" && Config.capsuleHeight === modelData.val)
                        color: isSel ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: isSel ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.12)
                        border.width: isSel ? 1.5 : 1

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                text: modelData.label
                                color: parent.parent.isSel ? "white" : Qt.rgba(1, 1, 1, 0.7)
                                font.pixelSize: 11; font.bold: parent.parent.isSel
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: modelData.sub
                                color: Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 9
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: if (typeof Config !== "undefined") Config.capsuleHeight = modelData.val
                        }
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

        // 顶部距离滑块
        Column {
            width: parent.width
            spacing: 4

            Item {
                width: parent.width; height: 16
                Text { text: "屏幕顶部间距 (Top Margin)"; color: "white"; font.pixelSize: 11; font.bold: true; anchors.left: parent.left }
                Text {
                    text: ((typeof Config !== "undefined") ? Config.topMargin : 0) + " px"
                    color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Black; font.family: "Monospace"; anchors.right: parent.right
                }
            }

            Slider {
                id: topMarginSlider
                width: parent.width; height: 22
                from: 0; to: 40; stepSize: 1
                value: (typeof Config !== "undefined") ? Config.topMargin : 0
                onMoved: if (typeof Config !== "undefined") Config.topMargin = Math.round(value)

                background: Rectangle {
                    x: topMarginSlider.leftPadding
                    y: topMarginSlider.topPadding + topMarginSlider.availableHeight / 2 - height / 2
                    width: topMarginSlider.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12)
                    Rectangle { width: topMarginSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#38bdf8" }
                }
                handle: Rectangle {
                    x: topMarginSlider.leftPadding + topMarginSlider.visualPosition * (topMarginSlider.availableWidth - width)
                    y: topMarginSlider.topPadding + topMarginSlider.availableHeight / 2 - height / 2
                    width: 14; height: 14; radius: 7; color: topMarginSlider.pressed ? "#7dd3fc" : "#38bdf8"; border.color: "#ffffff"; border.width: 1.5
                }
            }
        }

        // 鼠标悬停自动展开开关
        Item {
            width: parent.width; height: 30
            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Text { text: "👆"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "鼠标光标悬停自动展开大卡片"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
            }
            Switch {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                checked: (typeof Config !== "undefined" && Config.hoverExpandEnabled !== undefined) ? Config.hoverExpandEnabled : true
                onToggled: if (typeof Config !== "undefined") Config.hoverExpandEnabled = checked
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

        // 🚀【新增：深潜完全隐形开关】
        Item {
            width: parent.width; height: 36
            Column {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                Row {
                    spacing: 6
                    Text { text: "👻"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "深潜完全隐形 (Stealth Mode)"; color: "white"; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }
                Text {
                    text: "隐藏时彻底消除边缘微缝与呼吸光，鼠标推至顶端仍可顺畅唤醒"
                    color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 9
                }
            }

            Switch {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                checked: (typeof Config !== "undefined" && Config.stealthTuckEnabled !== undefined) ? Config.stealthTuckEnabled : false
                onToggled: if (typeof Config !== "undefined") Config.stealthTuckEnabled = checked
            }
        }
    }
}