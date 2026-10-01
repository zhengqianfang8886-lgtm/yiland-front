import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Window {
    id: settingsWin
    title: "Alcove Island 偏好设置"
    width: 380
    height: 690
    minimumWidth: 380
    minimumHeight: 690
    maximumWidth: 380
    maximumHeight: 690
    color: "#18181b"
    flags: Qt.Dialog | Qt.WindowCloseButtonHint

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        Text {
            text: "⚙️ 灵动岛模块与偏好设置"
            color: "white"
            font.pixelSize: 16
            font.bold: true
        }

        // 分组 1：多岛排布方向与副岛间距控制
        Rectangle {
            width: parent.width
            height: 136
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.05)
            border.color: Qt.rgba(129, 140, 248, 0.3)

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // 1. 扩展方向标题栏
                Item {
                    width: parent.width
                    height: 16

                    Text {
                        text: "多副岛扩展方向"
                        color: "#818cf8"
                        font.pixelSize: 12
                        font.bold: true
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: (typeof Config !== "undefined" && Config.multiIslandExpandDirection === "left") ? "当前：向左延伸" : "当前：向右延伸"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.pixelSize: 10
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // 分段选择胶囊
                Rectangle {
                    width: parent.width
                    height: 26
                    radius: 13
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Row {
                        anchors.fill: parent
                        Rectangle {
                            width: parent.width / 2; height: parent.height; radius: 13
                            color: (typeof Config !== "undefined" && Config.multiIslandExpandDirection === "left") ? Qt.rgba(129, 140, 248, 0.25) : "transparent"
                            border.color: (typeof Config !== "undefined" && Config.multiIslandExpandDirection === "left") ? "#818cf8" : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "⬅️ 优先向左扩展"
                                color: (typeof Config !== "undefined" && Config.multiIslandExpandDirection === "left") ? "white" : Qt.rgba(1, 1, 1, 0.5)
                                font.pixelSize: 10; font.weight: Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: if (typeof Config !== "undefined") Config.multiIslandExpandDirection = "left"
                            }
                        }

                        Rectangle {
                            width: parent.width / 2; height: parent.height; radius: 13
                            color: (typeof Config !== "undefined" && Config.multiIslandExpandDirection !== "left") ? Qt.rgba(129, 140, 248, 0.25) : "transparent"
                            border.color: (typeof Config !== "undefined" && Config.multiIslandExpandDirection !== "left") ? "#818cf8" : "transparent"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "➡️ 优先向右扩展"
                                color: (typeof Config !== "undefined" && Config.multiIslandExpandDirection !== "left") ? "white" : Qt.rgba(1, 1, 1, 0.5)
                                font.pixelSize: 10; font.weight: Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: if (typeof Config !== "undefined") Config.multiIslandExpandDirection = "right"
                            }
                        }
                    }
                }

                // 2. 岛与岛之间的间距调节 (splitGap)
                Item {
                    width: parent.width
                    height: 16

                    Text {
                        text: "主副岛呼吸间距"
                        color: "#818cf8"
                        font.pixelSize: 12
                        font.bold: true
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: ((typeof Config !== "undefined" && Config.splitGap !== undefined) ? Config.splitGap : 8) + " px"
                        color: "#38bdf8"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.family: "Monospace"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // 自定义沉浸式深色滑块
                Slider {
                    id: gapSlider
                    width: parent.width
                    height: 22
                    from: 2
                    to: 24
                    stepSize: 1
                    value: (typeof Config !== "undefined" && Config.splitGap !== undefined) ? Config.splitGap : 8
                    onMoved: if (typeof Config !== "undefined") Config.splitGap = Math.round(value)

                    background: Rectangle {
                        x: gapSlider.leftPadding
                        y: gapSlider.topPadding + gapSlider.availableHeight / 2 - height / 2
                        width: gapSlider.availableWidth
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.12)

                        Rectangle {
                            width: gapSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: "#818cf8"
                        }
                    }

                    handle: Rectangle {
                        x: gapSlider.leftPadding + gapSlider.visualPosition * (gapSlider.availableWidth - width)
                        y: gapSlider.topPadding + gapSlider.availableHeight / 2 - height / 2
                        width: 16
                        height: 16
                        radius: 8
                        color: gapSlider.pressed ? "#a5b4fc" : "#818cf8"
                        border.color: "#ffffff"
                        border.width: 1.5
                    }
                }
            }
        }

        // 分组 2：常态胶囊显示项
        Rectangle {
            width: parent.width
            height: 140
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.05)
            border.color: Qt.rgba(1, 1, 1, 0.1)

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 2

                Text { text: "胶囊常态显示项"; color: "#38bdf8"; font.pixelSize: 12; font.bold: true }

                Item {
                    width: parent.width; height: 32
                    Text { text: "显示实时网速 (↓↑)"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                    Switch {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        checked: (typeof Config !== "undefined" && Config.showNetSpeed !== undefined) ? Config.showNetSpeed : true
                        onToggled: if (typeof Config !== "undefined" && Config.showNetSpeed !== undefined) Config.showNetSpeed = checked
                    }
                }

                Item {
                    width: parent.width; height: 32
                    Text { text: "显示当前日期"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                    Switch {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        checked: (typeof Config !== "undefined" && Config.showDate !== undefined) ? Config.showDate : false
                        onToggled: if (typeof Config !== "undefined" && Config.showDate !== undefined) Config.showDate = checked
                    }
                }

                Item {
                    width: parent.width; height: 32
                    Text { text: "显示时间秒数"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                    Switch {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        checked: (typeof Config !== "undefined" && Config.showSeconds !== undefined) ? Config.showSeconds : false
                        onToggled: if (typeof Config !== "undefined" && Config.showSeconds !== undefined) Config.showSeconds = checked
                    }
                }
            }
        }

        // 分组 3：展开大卡片模块
        Rectangle {
            width: parent.width
            height: 240
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.05)
            border.color: Qt.rgba(1, 1, 1, 0.1)

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 2

                Text { text: "展开卡片模块 (Tab 栏)"; color: "#34d399"; font.pixelSize: 12; font.bold: true }

                Item {
                    width: parent.width; height: 32
                    Text { text: "🎵 媒体卡片 (播放/播控)"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                    Switch {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        checked: (typeof Config !== "undefined" && Config.showMediaTab !== undefined) ? Config.showMediaTab : true
                        onToggled: if (typeof Config !== "undefined" && Config.showMediaTab !== undefined) Config.showMediaTab = checked
                    }
                }

                Item {
                    width: parent.width; height: 32
                    Text { text: "📅 日历卡片 (Bento 风格)"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                    Switch {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        checked: (typeof Config !== "undefined" && Config.showCalendarTab !== undefined) ? Config.showCalendarTab : true
                        onToggled: if (typeof Config !== "undefined" && Config.showCalendarTab !== undefined) Config.showCalendarTab = checked
                    }
                }

                Item {
                    width: parent.width; height: 32
                    Text { text: "🎧 蓝牙卡片 (设备/电量/连接)"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                    Switch {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        checked: (typeof Config !== "undefined" && Config.showBluetoothTab !== undefined) ? Config.showBluetoothTab : true
                        onToggled: if (typeof Config !== "undefined" && Config.showBluetoothTab !== undefined) Config.showBluetoothTab = checked
                    }
                }

                Item {
                    width: parent.width; height: 32
                    Text { text: "📶 实时网络详情面板"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                    Switch {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        checked: (typeof Config !== "undefined" && Config.showNetworkTab !== undefined) ? Config.showNetworkTab : true
                        onToggled: if (typeof Config !== "undefined" && Config.showNetworkTab !== undefined) Config.showNetworkTab = checked
                    }
                }

                Item {
                    width: parent.width; height: 32
                    Text { text: "🌍 世界时钟面板"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                    Switch {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        checked: (typeof Config !== "undefined" && Config.showClockTab !== undefined) ? Config.showClockTab : true
                        onToggled: if (typeof Config !== "undefined" && Config.showClockTab !== undefined) Config.showClockTab = checked
                    }
                }
            }
        }

        Text {
            text: "💡 提示：间距拖动实时生效，设置自动写入本地配置。"
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: 11
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}