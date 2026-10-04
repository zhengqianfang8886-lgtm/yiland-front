// ==========================================
// 📄 File: settings/SettingsDisplayCard.qml
// ==========================================
import QtQuick
import QtQuick.Controls

Column {
    id: colRoot
    spacing: 14

    // 1. 动效物理质感
    Rectangle {
        width: parent.width; height: 96; radius: 12
        color: Qt.rgba(1, 1, 1, 0.05); border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.3); border.width: 1

        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 8

            Item {
                width: parent.width; height: 16
                Text { text: "🎭 灵动岛收放物理动效"; color: Theme.workspace; font.pixelSize: 12; font.bold: true; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: (typeof Config !== "undefined" && Config.animStyle === "jelly") ? "有机果冻流" : "精密克制流"
                    color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 10; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: parent.width; height: 28; radius: 14; color: Qt.rgba(1, 1, 1, 0.08)

                Row {
                    anchors.fill: parent

                    Rectangle {
                        id: precBtn
                        width: parent.width / 2; height: parent.height; radius: 14
                        readonly property bool isSel: (typeof Config !== "undefined" && Config.animStyle !== "jelly")
                        color: precBtn.isSel ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.28) : "transparent"
                        border.color: precBtn.isSel ? Theme.workspace : "transparent"; border.width: 1

                        Row {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: "🎯"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "精密克制 (阻尼沉稳)"; color: precBtn.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (typeof Config !== "undefined") Config.animStyle = "precision" }
                    }

                    Rectangle {
                        id: jellyBtn
                        width: parent.width / 2; height: parent.height; radius: 14
                        readonly property bool isSel: (typeof Config !== "undefined" && Config.animStyle === "jelly")
                        color: jellyBtn.isSel ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.28) : "transparent"
                        border.color: jellyBtn.isSel ? Theme.workspace : "transparent"; border.width: 1

                        Row {
                            anchors.centerIn: parent; spacing: 4
                            Text { text: "🍮"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "有机果冻 (流体相位)"; color: jellyBtn.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (typeof Config !== "undefined") Config.animStyle = "jelly" }
                    }
                }
            }

            Text {
                text: (typeof Config !== "undefined" && Config.animStyle === "jelly") ? "✨ 高度先行下冲，宽度滞后 32ms 舒展，带丰满回弹。" : "✨ 极微弱超临界阻尼，单次微沉降，适合专注工作。"
                color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // 2. 胶囊常态显示项
    Rectangle {
        width: parent.width; height: 172; radius: 12
        color: Qt.rgba(1, 1, 1, 0.05); border.color: Qt.rgba(1, 1, 1, 0.1)

        Column {
            anchors.fill: parent; anchors.margins: 12; spacing: 2

            Text { text: "胶囊常态显示项"; color: "#38bdf8"; font.pixelSize: 12; font.bold: true }

            Item {
                width: parent.width; height: 32
                Text { text: "使用 24 小时制时间格式"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: (typeof Config !== "undefined" && Config.timeFormat === "24h")
                    onToggled: if (typeof Config !== "undefined") Config.timeFormat = checked ? "24h" : "12h"
                }
            }

            Item {
                width: parent.width; height: 32
                Text { text: "显示实时网速 (↓↑)"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: (typeof Config !== "undefined" && Config.showNetSpeed !== undefined) ? Config.showNetSpeed : true
                    onToggled: if (typeof Config !== "undefined") Config.showNetSpeed = checked
                }
            }

            Item {
                width: parent.width; height: 32
                Text { text: "显示当前日期"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: (typeof Config !== "undefined" && Config.showDate !== undefined) ? Config.showDate : false
                    onToggled: if (typeof Config !== "undefined") Config.showDate = checked
                }
            }

            Item {
                width: parent.width; height: 32
                Text { text: "显示时间秒数"; color: "white"; font.pixelSize: 13; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: (typeof Config !== "undefined" && Config.showSeconds !== undefined) ? Config.showSeconds : false
                    onToggled: if (typeof Config !== "undefined") Config.showSeconds = checked
                }
            }
        }
    }

    // 3. 独立界面直达开关
    Rectangle {
        width: parent.width; height: tabSwitchesCol.implicitHeight + 24; radius: 12
        color: Qt.rgba(1, 1, 1, 0.05); border.color: Qt.rgba(1, 1, 1, 0.1)

        Column {
            id: tabSwitchesCol
            anchors.fill: parent; anchors.margins: 12; spacing: 2

            Text { text: "独立界面管理 (点条轨道直达项)"; color: "#34d399"; font.pixelSize: 12; font.bold: true }

            Item {
                width: parent.width; height: 32
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Rectangle { width: 4; height: 12; radius: 2; color: Theme.workspace; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "⊞ 桌面工作区 (多桌面切页)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: (typeof Config !== "undefined" && Config.showWorkspaceTab !== undefined) ? Config.showWorkspaceTab : true
                    onToggled: if (typeof Config !== "undefined") Config.showWorkspaceTab = checked
                }
            }

            Item {
                width: parent.width; height: 32
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Rectangle { width: 4; height: 12; radius: 2; color: Theme.media; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "🎵 媒体播放器 (播放与播控)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: (typeof Config !== "undefined" && Config.showMediaTab !== undefined) ? Config.showMediaTab : true
                    onToggled: if (typeof Config !== "undefined") Config.showMediaTab = checked
                }
            }

            Item {
                width: parent.width; height: 32
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Rectangle { width: 4; height: 12; radius: 2; color: Theme.calendar; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "📅 本地日历 (Bento 风格)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: (typeof Config !== "undefined" && Config.showCalendarTab !== undefined) ? Config.showCalendarTab : true
                    onToggled: if (typeof Config !== "undefined") Config.showCalendarTab = checked
                }
            }

            Item {
                width: parent.width; height: 32
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Rectangle { width: 4; height: 12; radius: 2; color: Theme.timer; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "⏱️ 专注计时与秒表 (独立直达)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: (typeof Config !== "undefined" && Config.showTimerTab !== undefined) ? Config.showTimerTab : true
                    onToggled: if (typeof Config !== "undefined") Config.showTimerTab = checked
                }
            }

            Item {
                width: parent.width; height: 32
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Rectangle { width: 4; height: 12; radius: 2; color: Theme.clock; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "🌍 世界时钟 (跨时区换算)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: (typeof Config !== "undefined" && Config.showClockTab !== undefined) ? Config.showClockTab : true
                    onToggled: if (typeof Config !== "undefined") Config.showClockTab = checked
                }
            }

            Item {
                width: parent.width; height: 32
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Rectangle { width: 4; height: 12; radius: 2; color: Theme.network; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "📶 实时网络监控 (上下行与IP)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: (typeof Config !== "undefined" && Config.showNetworkTab !== undefined) ? Config.showNetworkTab : true
                    onToggled: if (typeof Config !== "undefined") Config.showNetworkTab = checked
                }
            }

            Item {
                width: parent.width; height: 32
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Rectangle { width: 4; height: 12; radius: 2; color: Theme.bluetooth; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "🎧 蓝牙外设管理 (电量与连接)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: (typeof Config !== "undefined" && Config.showBluetoothTab !== undefined) ? Config.showBluetoothTab : true
                    onToggled: if (typeof Config !== "undefined") Config.showBluetoothTab = checked
                }
            }

            Item {
                width: parent.width; height: 32
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Rectangle { width: 4; height: 12; radius: 2; color: Theme.notification; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "💬 消息归档中心 (未读与历史)"; color: "white"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                Switch {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: (typeof Config !== "undefined" && Config.showNotificationTab !== undefined) ? Config.showNotificationTab : true
                    onToggled: if (typeof Config !== "undefined") Config.showNotificationTab = checked
                }
            }
        }
    }
}