// ==========================================
// 📄 File: settings/SettingsDisplayCard.qml (已修复 TypeError 报错)
// ==========================================
import QtQuick
import QtQuick.Controls

Column {
    id: colRoot
    spacing: 14

    function getTabMeta(key) {
        if (key === "time") return { name: "时间节律", icon: "🕒", color: "#38bdf8" }
        if (key === "hardware") return { name: "硬件中控", icon: "🎛️", color: "#f59e0b" }
        if (key === "workspace") return { name: "工作区", icon: "⊞", color: "#a855f7" }
        if (key === "media") return { name: "媒体播放", icon: "🎵", color: "#22c55e" }
        if (key === "calendar") return { name: "日历日程", icon: "📅", color: "#38bdf8" }
        if (key === "timer") return { name: "专注计时", icon: "⏱️", color: "#f97316" }
        if (key === "clock") return { name: "世界时钟", icon: "🌍", color: "#f59e0b" }
        if (key === "network") return { name: "网络监控", icon: "📶", color: "#34d399" }
        if (key === "bluetooth") return { name: "蓝牙外设", icon: "🎧", color: "#60a5fa" }
        if (key === "notification") return { name: "消息归档", icon: "💬", color: "#818cf8" }
        if (key === "process") return { name: "进程服务", icon: "⚡", color: "#c084fc" }
        return { name: key, icon: "📌", color: "white" }
    }

    function isKeyEnabled(key) {
        if (typeof Config === "undefined") return true
        if (key === "time") return true
        if (key === "hardware") return Config.showHardwareTab !== false
        if (key === "workspace") return Config.showWorkspaceTab !== false
        if (key === "media") return Config.showMediaTab !== false
        if (key === "calendar") return Config.showCalendarTab !== false
        if (key === "timer") return Config.showTimerTab !== false
        if (key === "clock") return Config.showClockTab !== false
        if (key === "network") return Config.showNetworkTab !== false
        if (key === "bluetooth") return Config.showBluetoothTab !== false
        if (key === "notification") return Config.showNotificationTab !== false
        if (key === "process") return Config.showProcessTab !== false
        return true
    }

    function setKeyEnabled(key, enabled) {
        if (typeof Config === "undefined") return
        if (key === "hardware") Config.showHardwareTab = enabled
        else if (key === "workspace") Config.showWorkspaceTab = enabled
        else if (key === "media") Config.showMediaTab = enabled
        else if (key === "calendar") Config.showCalendarTab = enabled
        else if (key === "timer") Config.showTimerTab = enabled
        else if (key === "clock") Config.showClockTab = enabled
        else if (key === "network") Config.showNetworkTab = enabled
        else if (key === "bluetooth") Config.showBluetoothTab = enabled
        else if (key === "notification") Config.showNotificationTab = enabled
        else if (key === "process") Config.showProcessTab = enabled
    }

    function moveTabUp(index) {
        if (index <= 0 || typeof Config === "undefined") return
        var list = Config.tabOrder.slice()
        var temp = list[index]
        list[index] = list[index - 1]
        list[index - 1] = temp
        Config.tabOrder = list
    }

    function moveTabDown(index) {
        if (typeof Config === "undefined") return
        var list = Config.tabOrder.slice()
        if (index >= list.length - 1) return
        var temp = list[index]
        list[index] = list[index + 1]
        list[index + 1] = temp
        Config.tabOrder = list
    }

    // =========================================================================
    // 1. 展开页面展示顺序与启闭调控卡片
    // =========================================================================
    Rectangle {
        width: parent.width
        height: tabOrderCol.implicitHeight + 24
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.3)
        border.width: 1

        Column {
            id: tabOrderCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            Row {
                spacing: 6
                Text { text: "📑"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "展开页面顺序与开关调控"; color: "#f59e0b"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }

            Text {
                text: "💡 提示：点击 ↑ ↓ 调整页面在灵动岛顶部的排布顺序，关闭开关可从切页轨道中隐藏该功能。"
                color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 10
            }

            Repeater {
                model: (typeof Config !== "undefined" && Config.tabOrder) ? Config.tabOrder : []

                // 🚀【核心修复】：给 Delegate 明确的 id，彻底杜绝 parent.parent 找错层级
                Rectangle {
                    id: tabItemDelegate
                    width: tabOrderCol.width
                    height: 30
                    radius: 6
                    color: Qt.rgba(1, 1, 1, 0.04)

                    readonly property var itemMeta: colRoot.getTabMeta(modelData)
                    readonly property bool isEnabled: colRoot.isKeyEnabled(modelData)

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: 18; height: 18; radius: 4
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Text {
                                anchors.centerIn: parent
                                text: (tabItemDelegate.itemMeta && tabItemDelegate.itemMeta.icon) ? tabItemDelegate.itemMeta.icon : "📌"
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            text: (tabItemDelegate.itemMeta && tabItemDelegate.itemMeta.name) ? tabItemDelegate.itemMeta.name : modelData
                            color: tabItemDelegate.isEnabled ? "white" : Theme.textMuted
                            font.pixelSize: 11
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Rectangle {
                            width: 22; height: 20; radius: 4
                            color: index > 0 ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                            Text { anchors.centerIn: parent; text: "↑"; color: "white"; font.pixelSize: 11; opacity: index > 0 ? 1 : 0.2 }
                            MouseArea { anchors.fill: parent; enabled: index > 0; cursorShape: Qt.PointingHandCursor; onClicked: colRoot.moveTabUp(index) }
                        }

                        Rectangle {
                            width: 22; height: 20; radius: 4
                            color: index < (Config.tabOrder.length - 1) ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                            Text { anchors.centerIn: parent; text: "↓"; color: "white"; font.pixelSize: 11; opacity: index < (Config.tabOrder.length - 1) ? 1 : 0.2 }
                            MouseArea { anchors.fill: parent; enabled: index < (Config.tabOrder.length - 1); cursorShape: Qt.PointingHandCursor; onClicked: colRoot.moveTabDown(index) }
                        }

                        Switch {
                            visible: modelData !== "time"
                            checked: tabItemDelegate.isEnabled
                            scale: 0.75
                            onToggled: colRoot.setKeyEnabled(modelData, checked)
                        }

                        Rectangle {
                            width: 36; height: 16; radius: 8
                            visible: modelData === "time"
                            color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.2)
                            Text { anchors.centerIn: parent; text: "基准"; color: "#38bdf8"; font.pixelSize: 9; font.bold: true }
                        }
                    }
                }
            }
        }
    }

    // 2. 动效物理质感
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

    // 3. 胶囊常态显示项
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
}