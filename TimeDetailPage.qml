import QtQuick

Item {
    id: timeDetailRoot
    anchors.fill: parent

    property string chosenFont: ""
    property var currentTime: new Date()

    Timer {
        interval: 1000
        running: timeDetailRoot.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: timeDetailRoot.currentTime = new Date()
    }

    // 🚀 核心修复 1：把 isDay 提升到根级作用域，彻底根治“白天误报夜幕”的 Bug
    readonly property bool isDay: {
        var h = timeDetailRoot.currentTime.getHours()
        return h >= 6 && h < 18
    }

    // 今日流逝进度计算 (0.0 ~ 1.0)
    readonly property real dayProgress: {
        var d = timeDetailRoot.currentTime
        var totalSec = d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds()
        return totalSec / 86400.0
    }

    // 年度流逝与周数计算
    readonly property var yearInfo: {
        var now = timeDetailRoot.currentTime
        var start = new Date(now.getFullYear(), 0, 1)
        var diff = now - start
        var oneDay = 1000 * 60 * 60 * 24
        var dayOfYear = Math.floor(diff / oneDay) + 1
        var isLeap = (now.getFullYear() % 4 === 0 && now.getFullYear() % 100 !== 0) || (now.getFullYear() % 400 === 0)
        var totalDays = isLeap ? 366 : 365
        var weekNum = Math.ceil((dayOfYear + start.getDay()) / 7)
        return {
            day: dayOfYear,
            totalDays: totalDays,
            week: weekNum,
            progress: dayOfYear / totalDays
        }
    }

    Row {
        anchors.fill: parent
        spacing: 12

        // =====================================================================
        // 1. 左侧大看板：超大数字时钟 + 紧凑字间距
        // =====================================================================
        Rectangle {
            width: 148
            height: parent.height
            radius: Theme.radiusCard
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.25)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 3
                width: parent.width - 16

                Row {
                    spacing: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle { width: 6; height: 6; radius: 3; color: Theme.calendar; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "LOCAL TIME"; font.pixelSize: 9; font.weight: Font.Black; color: Theme.calendar; font.letterSpacing: 0.8 }
                }

                // 大字时钟（紧凑字偶间距，数字不松散）
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 1

                    Text {
                        text: {
                            var h = timeDetailRoot.currentTime.getHours()
                            return (h < 10 ? "0" : "") + h
                        }
                        color: "white"
                        font.pixelSize: 34
                        font.weight: Font.Black
                        font.family: (timeDetailRoot.chosenFont !== "") ? timeDetailRoot.chosenFont : "Monospace"
                    }
                    Text {
                        text: ":"
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 30
                        font.weight: Font.Black
                        font.family: "Monospace"
                        y: -1
                    }
                    Text {
                        text: {
                            var m = timeDetailRoot.currentTime.getMinutes()
                            return (m < 10 ? "0" : "") + m
                        }
                        color: "white"
                        font.pixelSize: 34
                        font.weight: Font.Black
                        font.family: (timeDetailRoot.chosenFont !== "") ? timeDetailRoot.chosenFont : "Monospace"
                    }
                }

                // 独立秒数指示
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 44; height: 18; radius: 9
                    color: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.16)

                    Text {
                        anchors.centerIn: parent
                        text: {
                            var s = timeDetailRoot.currentTime.getSeconds()
                            return (s < 10 ? ":0" : ":") + s
                        }
                        color: Theme.calendar
                        font.pixelSize: 11
                        font.weight: Font.Black
                        font.family: "Monospace"
                    }
                }

                Item { height: 2 }

                Text {
                    text: {
                        var d = timeDetailRoot.currentTime
                        var days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
                        return (d.getMonth() + 1) + "月" + d.getDate() + "日 · " + days[d.getDay()]
                    }
                    color: "white"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.family: timeDetailRoot.chosenFont
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: {
                        var offsetMin = -timeDetailRoot.currentTime.getTimezoneOffset()
                        var h = Math.floor(Math.abs(offsetMin) / 60)
                        var sign = offsetMin >= 0 ? "+" : "-"
                        return "UTC" + sign + h + " 本地时区"
                    }
                    color: Theme.textMuted
                    font.pixelSize: 9
                    font.family: "Monospace"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // =====================================================================
        // 2. 右侧 4 卡 Bento 网格
        // =====================================================================
        Grid {
            width: parent.width - 160
            height: parent.height
            columns: 2
            spacing: 8

            // 卡片 1：今日时间流逝（带精准时分已过）
            Rectangle {
                width: (parent.width - 8) / 2
                height: (parent.height - 8) / 2
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Theme.borderSubtle
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 3

                    Row {
                        spacing: 4
                        Text { text: "⏳"; font.pixelSize: 10 }
                        Text { text: "今日流逝"; color: Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: timeDetailRoot.chosenFont }
                    }

                    Text {
                        text: Math.round(timeDetailRoot.dayProgress * 100) + "%"
                        color: "white"
                        font.pixelSize: 18
                        font.weight: Font.Black
                        font.family: "Monospace"
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.12)

                        Rectangle {
                            height: parent.height
                            radius: 2
                            color: Theme.calendar
                            width: parent.width * timeDetailRoot.dayProgress
                        }
                    }

                    // 🚀 核心修复 2：显示时分已过，告别生硬粗暴截断
                    Text {
                        text: {
                            var h = timeDetailRoot.currentTime.getHours()
                            var m = timeDetailRoot.currentTime.getMinutes()
                            return h + "小时" + m + "分已过 · 24h"
                        }
                        color: Theme.textMuted
                        font.pixelSize: 9
                        font.family: timeDetailRoot.chosenFont
                    }
                }
            }

            // 卡片 2：年度进度与周数
            Rectangle {
                width: (parent.width - 8) / 2
                height: (parent.height - 8) / 2
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Theme.borderSubtle
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 3

                    Row {
                        spacing: 4
                        Text { text: "📅"; font.pixelSize: 10 }
                        Text { text: "年度进度"; color: Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: timeDetailRoot.chosenFont }
                    }

                    Text {
                        text: Math.round(timeDetailRoot.yearInfo.progress * 100) + "%"
                        color: "white"
                        font.pixelSize: 18
                        font.weight: Font.Black
                        font.family: "Monospace"
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.12)

                        Rectangle {
                            height: parent.height
                            radius: 2
                            color: "#10b981"
                            width: parent.width * timeDetailRoot.yearInfo.progress
                        }
                    }

                    Text {
                        text: "第 " + timeDetailRoot.yearInfo.week + " 周 · 第 " + timeDetailRoot.yearInfo.day + " 天"
                        color: Theme.textMuted
                        font.pixelSize: 9
                        font.family: timeDetailRoot.chosenFont
                    }
                }
            }

            // 卡片 3：Unix 纪元时间戳 (规范全名)
            Rectangle {
                id: timestampCard
                width: (parent.width - 8) / 2
                height: (parent.height - 8) / 2
                radius: 12
                color: tsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                border.color: tsMouse.containsMouse ? Theme.network : Theme.borderSubtle
                border.width: 1
                scale: tsMouse.pressed ? 0.96 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2

                    Item {
                        width: parent.width
                        height: 14

                        Text {
                            // 🚀 核心修复 3：规范标头全名
                            text: "⏱️ UNIX 时间戳"
                            color: Theme.textMuted
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.family: timeDetailRoot.chosenFont
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "📋 复制"
                            color: Theme.network
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            visible: tsMouse.containsMouse
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item { height: 2 }

                    Text {
                        text: Math.floor(timeDetailRoot.currentTime.getTime() / 1000)
                        color: "white"
                        font.pixelSize: 14
                        font.weight: Font.Black
                        font.family: "Monospace"
                    }

                    Text {
                        text: "点击直接复制秒级戳"
                        color: Theme.textMuted
                        font.pixelSize: 9
                        font.family: timeDetailRoot.chosenFont
                    }
                }

                MouseArea {
                    id: tsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var ts = String(Math.floor(timeDetailRoot.currentTime.getTime() / 1000))
                        if (typeof Bridge !== "undefined" && Bridge.clipboardTriggered) {
                            Bridge.clipboardTriggered("📋", "时间戳", "已复制到剪贴板: " + ts, 1500)
                        }
                    }
                }
            }

            // 卡片 4：昼夜节律与状态（彻底消除白天报夜幕 Bug）
            Rectangle {
                width: (parent.width - 8) / 2
                height: (parent.height - 8) / 2
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Theme.borderSubtle
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2

                    Row {
                        spacing: 4
                        // 🚀 核心修复 4：直接引用全局确定的 isDay
                        Text { text: timeDetailRoot.isDay ? "☀️" : "🌙"; font.pixelSize: 11 }
                        Text { text: timeDetailRoot.isDay ? "白昼时段" : "夜幕时段"; color: "white"; font.pixelSize: 11; font.weight: Font.Black; font.family: timeDetailRoot.chosenFont }
                    }

                    Item { height: 2 }

                    Text {
                        text: {
                            var h = timeDetailRoot.currentTime.getHours()
                            if (h >= 9 && h < 18) return "💼 核心工作专注期"
                            if (h >= 18 && h < 23) return "🍵 晚间自由休整期"
                            return "💤 深度睡眠恢复期"
                        }
                        color: Theme.textSecondary
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: timeDetailRoot.chosenFont
                    }

                    Text {
                        text: "自然昼夜节律感知"
                        color: Theme.textMuted
                        font.pixelSize: 9
                        font.family: timeDetailRoot.chosenFont
                    }
                }
            }
        }
    }
}