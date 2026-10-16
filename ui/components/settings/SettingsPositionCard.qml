// ==========================================
// 📄 File: settings/SettingsPositionCard.qml
// ==========================================
import QtQuick
import QtQuick.Controls

Rectangle {
    id: cardRoot
    height: positionCol.implicitHeight + 24
    radius: 12
    color: Qt.rgba(1, 1, 1, 0.05)
    border.color: Qt.rgba(56, 189, 248, 0.35)
    border.width: 1

    Column {
        id: positionCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Row {
            spacing: 6
            Text { text: "📐"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "悬浮位置与手势灵敏度"; color: "#38bdf8"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
        }

        // 鼠标悬停自动展开开关
        Item {
            width: parent.width; height: 30
            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Text { text: "👆"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "鼠标悬停自动展开灵动岛"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
            }
            Switch {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                checked: (typeof Config !== "undefined" && Config.hoverExpandEnabled !== undefined) ? Config.hoverExpandEnabled : true
                onToggled: if (typeof Config !== "undefined") Config.hoverExpandEnabled = checked
            }
        }

        // 1. 顶部距离滑块
        Column {
            width: parent.width
            spacing: 4

            Item {
                width: parent.width; height: 16
                Text { text: "顶部距离 (Top Margin)"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; anchors.left: parent.left }
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

        // 2. 悬停展开延时滑块
        Column {
            width: parent.width
            spacing: 4
            visible: (typeof Config !== "undefined" && Config.hoverExpandEnabled !== false)

            Item {
                width: parent.width; height: 16
                Text { text: "鼠标悬停展开延时 (Dwell Time)"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; anchors.left: parent.left }
                Text {
                    text: ((typeof Config !== "undefined") ? Config.hoverDwellTime : 240) + " ms"
                    color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Black; font.family: "Monospace"; anchors.right: parent.right
                }
            }

            Slider {
                id: dwellSlider
                width: parent.width; height: 22
                from: 80; to: 600; stepSize: 10
                value: (typeof Config !== "undefined") ? Config.hoverDwellTime : 240
                onMoved: if (typeof Config !== "undefined") Config.hoverDwellTime = Math.round(value)

                background: Rectangle {
                    x: dwellSlider.leftPadding
                    y: dwellSlider.topPadding + dwellSlider.availableHeight / 2 - height / 2
                    width: dwellSlider.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12)
                    Rectangle { width: dwellSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#38bdf8" }
                }
                handle: Rectangle {
                    x: dwellSlider.leftPadding + dwellSlider.visualPosition * (dwellSlider.availableWidth - width)
                    y: dwellSlider.topPadding + dwellSlider.availableHeight / 2 - height / 2
                    width: 14; height: 14; radius: 7; color: dwellSlider.pressed ? "#7dd3fc" : "#38bdf8"; border.color: "#ffffff"; border.width: 1.5
                }
            }
        }

        // 3. 主胶囊右键隐藏时长
        Column {
            width: parent.width
            spacing: 6

            Item {
                width: parent.width; height: 16
                Text { text: "主胶囊右键隐藏时长 (Auto-hide)"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; anchors.left: parent.left }
                Text {
                    text: ((typeof Config !== "undefined" && Config.autoHideDurationSeconds !== undefined) ? Config.autoHideDurationSeconds : 5) + " 秒"
                    color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Black; font.family: "Monospace"; anchors.right: parent.right
                }
            }

            Slider {
                id: autoHideSlider
                width: parent.width; height: 22
                from: 1; to: 30; stepSize: 1
                value: (typeof Config !== "undefined" && Config.autoHideDurationSeconds !== undefined) ? Config.autoHideDurationSeconds : 5
                onMoved: if (typeof Config !== "undefined") Config.autoHideDurationSeconds = Math.round(value)

                background: Rectangle {
                    x: autoHideSlider.leftPadding
                    y: autoHideSlider.topPadding + autoHideSlider.availableHeight / 2 - height / 2
                    width: autoHideSlider.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12)
                    Rectangle { width: autoHideSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#38bdf8" }
                }
                handle: Rectangle {
                    x: autoHideSlider.leftPadding + autoHideSlider.visualPosition * (autoHideSlider.availableWidth - width)
                    y: autoHideSlider.topPadding + autoHideSlider.availableHeight / 2 - height / 2
                    width: 14; height: 14; radius: 7; color: autoHideSlider.pressed ? "#7dd3fc" : "#38bdf8"; border.color: "#ffffff"; border.width: 1.5
                }
            }

            Row {
                spacing: 6
                Repeater {
                    model: [3, 5, 10, 15]
                    Rectangle {
                        width: 44; height: 20; radius: 10
                        readonly property bool isSel: (typeof Config !== "undefined" && Config.autoHideDurationSeconds === modelData)
                        color: isSel ? Qt.rgba(56, 189, 248, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: isSel ? "#38bdf8" : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData + "s"
                            color: parent.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5)
                            font.pixelSize: 10; font.weight: Font.Bold
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: if (typeof Config !== "undefined") Config.autoHideDurationSeconds = modelData
                        }
                    }
                }
            }

            Text {
                text: "💡 右键点击主胶囊可让全岛完全淡出穿透，时间到达后自动复原，触碰屏幕顶端也可唤醒。"
                color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 9
            }
        }
    }
}