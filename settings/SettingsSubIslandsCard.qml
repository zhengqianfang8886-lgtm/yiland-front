// ==========================================
// 📄 File: settings/SettingsSubIslandsCard.qml
// ==========================================
import QtQuick
import QtQuick.Controls

Rectangle {
    id: cardRoot
    height: dockSettingsCol.implicitHeight + 24
    radius: 12
    color: Qt.rgba(1, 1, 1, 0.05)
    border.color: Qt.rgba(129, 140, 248, 0.3)
    border.width: 1

    function getIslandName(key) {
        if (key === "memory") return "💾 内存监控"
        if (key === "music") return "🎵 媒体/打字"
        if (key === "hardware") return "🔊 硬件控制"
        if (key === "timer") return "⏱️ 专注计时"
        if (key === "notification") return "💬 未读通知"
        return key
    }

    function moveIslandUp(side, index) {
        if (index <= 0) return
        var list = (side === "left" ? Config.subIslandsLeft : Config.subIslandsRight).slice()
        var temp = list[index]
        list[index] = list[index - 1]
        list[index - 1] = temp
        if (side === "left") Config.subIslandsLeft = list
        else Config.subIslandsRight = list
    }

    function moveIslandDown(side, index) {
        var list = (side === "left" ? Config.subIslandsLeft : Config.subIslandsRight).slice()
        if (index >= list.length - 1) return
        var temp = list[index]
        list[index] = list[index + 1]
        list[index + 1] = temp
        if (side === "left") Config.subIslandsLeft = list
        else Config.subIslandsRight = list
    }

    function switchIslandSide(fromSide, index) {
        var left = (Config.subIslandsLeft || []).slice()
        var right = (Config.subIslandsRight || []).slice()
        if (fromSide === "left") {
            var item = left.splice(index, 1)[0]
            right.push(item)
        } else {
            var item = right.splice(index, 1)[0]
            left.push(item)
        }
        Config.subIslandsLeft = left
        Config.subIslandsRight = right
    }

    Column {
        id: dockSettingsCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Row {
            spacing: 6
            Text { text: "🧩"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "副岛排列与间距控制"; color: "#818cf8"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
        }

        // 左侧副岛列表
        Rectangle {
            width: parent.width; height: leftIslandCol.implicitHeight + 16
            radius: 8; color: Qt.rgba(1, 1, 1, 0.04); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

            Column {
                id: leftIslandCol
                anchors.fill: parent; anchors.margins: 8; spacing: 4
                Text { text: "⬅️ 左侧小岛 (胶囊左侧排布)"; color: "#38bdf8"; font.pixelSize: 10; font.bold: true }

                Repeater {
                    model: Config.subIslandsLeft || []
                    Rectangle {
                        width: parent.width; height: 28; radius: 6; color: Qt.rgba(1, 1, 1, 0.06)

                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            text: cardRoot.getIslandName(modelData); color: "white"; font.pixelSize: 11; font.bold: true
                        }

                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 4

                            Rectangle {
                                width: 22; height: 20; radius: 4; color: index > 0 ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                Text { anchors.centerIn: parent; text: "↑"; color: "white"; font.pixelSize: 11; opacity: index > 0 ? 1 : 0.2 }
                                MouseArea { anchors.fill: parent; enabled: index > 0; cursorShape: Qt.PointingHandCursor; onClicked: cardRoot.moveIslandUp("left", index) }
                            }

                            Rectangle {
                                width: 22; height: 20; radius: 4; color: index < (Config.subIslandsLeft.length - 1) ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                Text { anchors.centerIn: parent; text: "↓"; color: "white"; font.pixelSize: 11; opacity: index < (Config.subIslandsLeft.length - 1) ? 1 : 0.2 }
                                MouseArea { anchors.fill: parent; enabled: index < (Config.subIslandsLeft.length - 1); cursorShape: Qt.PointingHandCursor; onClicked: cardRoot.moveIslandDown("left", index) }
                            }

                            Rectangle {
                                width: 32; height: 20; radius: 4; color: Qt.rgba(56, 189, 248, 0.2)
                                Text { anchors.centerIn: parent; text: "⇄ 右"; color: "#38bdf8"; font.pixelSize: 9; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cardRoot.switchIslandSide("left", index) }
                            }
                        }
                    }
                }
            }
        }

        // 右侧副岛列表
        Rectangle {
            width: parent.width; height: rightIslandCol.implicitHeight + 16
            radius: 8; color: Qt.rgba(1, 1, 1, 0.04); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

            Column {
                id: rightIslandCol
                anchors.fill: parent; anchors.margins: 8; spacing: 4
                Text { text: "➡️ 右侧小岛 (胶囊右侧排布)"; color: "#34d399"; font.pixelSize: 10; font.bold: true }

                Repeater {
                    model: Config.subIslandsRight || []
                    Rectangle {
                        width: parent.width; height: 28; radius: 6; color: Qt.rgba(1, 1, 1, 0.06)

                        Text {
                            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            text: cardRoot.getIslandName(modelData); color: "white"; font.pixelSize: 11; font.bold: true
                        }

                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; spacing: 4

                            Rectangle {
                                width: 22; height: 20; radius: 4; color: index > 0 ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                Text { anchors.centerIn: parent; text: "↑"; color: "white"; font.pixelSize: 11; opacity: index > 0 ? 1 : 0.2 }
                                MouseArea { anchors.fill: parent; enabled: index > 0; cursorShape: Qt.PointingHandCursor; onClicked: cardRoot.moveIslandUp("right", index) }
                            }

                            Rectangle {
                                width: 22; height: 20; radius: 4; color: index < (Config.subIslandsRight.length - 1) ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                Text { anchors.centerIn: parent; text: "↓"; color: "white"; font.pixelSize: 11; opacity: index < (Config.subIslandsRight.length - 1) ? 1 : 0.2 }
                                MouseArea { anchors.fill: parent; enabled: index < (Config.subIslandsRight.length - 1); cursorShape: Qt.PointingHandCursor; onClicked: cardRoot.moveIslandDown("right", index) }
                            }

                            Rectangle {
                                width: 32; height: 20; radius: 4; color: Qt.rgba(52, 211, 153, 0.2)
                                Text { anchors.centerIn: parent; text: "左 ⇄"; color: "#34d399"; font.pixelSize: 9; font.bold: true }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cardRoot.switchIslandSide("right", index) }
                            }
                        }
                    }
                }
            }
        }

        // 呼吸间距滑块
        Column {
            width: parent.width; spacing: 6

            Item {
                width: parent.width; height: 16
                Text { text: "主副岛呼吸间距"; color: "#818cf8"; font.pixelSize: 12; font.bold: true; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: ((typeof Config !== "undefined" && Config.splitGap !== undefined) ? Config.splitGap : 8) + " px"
                    color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Bold; font.family: "Monospace"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                }
            }

            Slider {
                id: gapSlider
                width: parent.width; height: 22; from: 2; to: 24; stepSize: 1
                value: (typeof Config !== "undefined" && Config.splitGap !== undefined) ? Config.splitGap : 8
                onMoved: if (typeof Config !== "undefined") Config.splitGap = Math.round(value)

                background: Rectangle {
                    x: gapSlider.leftPadding; y: gapSlider.topPadding + gapSlider.availableHeight / 2 - height / 2
                    width: gapSlider.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12)
                    Rectangle { width: gapSlider.visualPosition * parent.width; height: parent.height; radius: 2; color: "#818cf8" }
                }
                handle: Rectangle {
                    x: gapSlider.leftPadding + gapSlider.visualPosition * (gapSlider.availableWidth - width)
                    y: gapSlider.topPadding + gapSlider.availableHeight / 2 - height / 2
                    width: 16; height: 16; radius: 8; color: gapSlider.pressed ? "#a5b4fc" : "#818cf8"; border.color: "#ffffff"; border.width: 1.5
                }
            }
        }
    }
}