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

    // 昼夜判定
    readonly property bool isDay: {
        var h = timeDetailRoot.currentTime.getHours()
        return h >= 6 && h < 18
    }

    // 1. 今日核心流逝与倒数（实用为主：算清今天到底还剩几小时几分）
    readonly property var dayInfo: {
        var d = timeDetailRoot.currentTime
        var h = d.getHours(), m = d.getMinutes(), s = d.getSeconds()
        var passedSec = h * 3600 + m * 60 + s
        var totalSec = 86400
        var remSec = Math.max(0, totalSec - passedSec)
        var remH = Math.floor(remSec / 3600)
        var remM = Math.floor((remSec % 3600) / 60)
        return {
            progress: passedSec / totalSec,
            percent: Math.round((passedSec / totalSec) * 100),
            // 核心大字：直接显示剩余时间
            heroRemaining: remH + "h " + (remM < 10 ? "0" : "") + remM + "m",
            passedStr: "已过 " + h + "小时" + m + "分"
        }
    }

    // 2. 本周工作日/周末倒计时（实用为主：清晰掌握本周阶段）
    readonly property var weekInfo: {
        var d = timeDetailRoot.currentTime
        var dayOfWeek = d.getDay() // 0 是周日，1 是周一...
        var currentIdx = (dayOfWeek === 0) ? 6 : (dayOfWeek - 1)
        var daysToWeekend = Math.max(0, 5 - currentIdx)
        var isWeekend = (currentIdx >= 5)
        var dayNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return {
            currentIdx: currentIdx,
            isWeekend: isWeekend,
            todayName: dayNames[currentIdx],
            // 核心大字：周末显示放假状态，工作日直接显示倒数天数
            heroText: isWeekend ? (currentIdx === 5 ? "周六 · 周末" : "周日 · 周末") : ("距周末 " + daysToWeekend + " 天"),
            subText: isWeekend ? "享受自由休整时光" : ("工作日已过 " + (currentIdx + 1) + " 天")
        }
    }

    // 3. 年度倒计时（实用为主：直接看今年剩余天数）
    readonly property var yearInfo: {
        var now = timeDetailRoot.currentTime
        var year = now.getFullYear()
        var start = new Date(year, 0, 1)
        var diff = now - start
        var dayOfYear = Math.floor(diff / 86400000) + 1
        var isLeap = (year % 4 === 0 && year % 100 !== 0) || (year % 400 === 0)
        var totalDays = isLeap ? 366 : 365
        var daysLeft = Math.max(0, totalDays - dayOfYear)
        var startDay = start.getDay() === 0 ? 6 : start.getDay() - 1
        var weekNum = Math.ceil((dayOfYear + startDay) / 7)
        return {
            daysLeft: daysLeft,
            day: dayOfYear,
            totalDays: totalDays,
            week: weekNum,
            progress: dayOfYear / totalDays,
            percent: Math.round((dayOfYear / totalDays) * 100),
            // 核心大字：直接显示剩余天数
            heroRemaining: daysLeft + " 天",
            subText: "第 " + dayOfYear + " 天 · " + Math.round((dayOfYear / totalDays) * 100) + "%"
        }
    }

    // 4. 真实作息节律（实用为主：提供切实的日常作息阶段建议，杜绝空洞语录）
    readonly property var rhythmInfo: {
        var h = timeDetailRoot.currentTime.getHours()
        if (h >= 6 && h < 9) {
            return { tag: "晨起激活", hero: "晨起唤醒期", tip: "接触日光 · 适度补水", color: "#fbbf24" }
        } else if (h >= 9 && h < 12) {
            return { tag: "黄金专注", hero: "深度心流期", tip: "思维敏锐 · 攻坚重点", color: "#38bdf8" }
        } else if (h >= 12 && h < 14) {
            return { tag: "午间蓄能", hero: "午餐小憩期", tip: "餐后休整 · 闭目养神", color: "#34d399" }
        } else if (h >= 14 && h < 18) {
            return { tag: "高效产出", hero: "逻辑攻坚期", tip: "精力充沛 · 推进事务", color: "#818cf8" }
        } else if (h >= 18 && h < 22) {
            return { tag: "晚间充电", hero: "自由休整期", tip: "脱离压力 · 适度阅读", color: "#c084fc" }
        } else {
            return { tag: "深度安眠", hero: "生理修复期", tip: "建议熄屏 · 保持安睡", color: "#6366f1" }
        }
    }

    Row {
        anchors.fill: parent
        spacing: 12

        // =====================================================================
        // 1. 左侧大看板：超大数字时钟与本地时区
        // =====================================================================
        Rectangle {
            width: 140
            height: parent.height
            radius: Theme.radiusCard
            color: Theme.bgCardItem
            border.color: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.22)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 4
                width: parent.width - 16

                Row {
                    spacing: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.calendar; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "LOCAL TIME"; font.pixelSize: 9; font.weight: Font.Black; color: Theme.calendar; font.letterSpacing: 0.8 }
                }

                // 大字时钟
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
                        color: Qt.rgba(1, 1, 1, 0.5)
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
                    color: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.14)

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
                        return "UTC" + sign + h + " 本地区"
                    }
                    color: Theme.textMuted
                    font.pixelSize: 9
                    font.family: "Monospace"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        // =====================================================================
        // 2. 右侧 4 卡 Bento 网格（大字体、高实用性、硬核时钟数据）
        // =====================================================================
        Grid {
            width: parent.width - 152
            height: parent.height
            columns: 2
            spacing: 8

            // -------------------------------------------------------------
            // 卡片 1：今日剩余可用时间（大字：余 5h 04m）
            // -------------------------------------------------------------
            Rectangle {
                width: (parent.width - 8) / 2
                height: (parent.height - 8) / 2
                radius: 12
                color: c1Hover.hovered ? Theme.bgCardHover : Theme.bgCardItem
                border.color: Theme.borderSubtle
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animInstant } }
                HoverHandler { id: c1Hover }

                Column {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 4

                    Item {
                        width: parent.width; height: 16
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Rectangle { width: 3; height: 10; radius: 1.5; color: Theme.calendar; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "今日剩余"; color: Theme.textSecondary; font.pixelSize: 11; font.weight: Font.Bold; font.family: timeDetailRoot.chosenFont }
                        }
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: timeDetailRoot.dayInfo.percent + "%"
                            color: Theme.calendar; font.pixelSize: 10; font.weight: Font.Bold; font.family: "Monospace"
                        }
                    }

                    // 🚀 大字直显今日剩余时长（实用第一）
                    Text {
                        text: timeDetailRoot.dayInfo.heroRemaining
                        color: "white"
                        font.pixelSize: 19
                        font.weight: Font.Black
                        font.family: "Monospace"
                    }

                    Rectangle {
                        width: parent.width
                        height: 3
                        radius: 1.5
                        color: Qt.rgba(1, 1, 1, 0.10)

                        Rectangle {
                            height: parent.height
                            radius: 1.5
                            color: Theme.calendar
                            width: parent.width * timeDetailRoot.dayInfo.progress
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                    }

                    Text {
                        text: timeDetailRoot.dayInfo.passedStr
                        color: Theme.textMuted
                        font.pixelSize: 10
                        font.family: timeDetailRoot.chosenFont
                    }
                }
            }

            // -------------------------------------------------------------
            // 卡片 2：本周状态与假期倒数（大字：周六·周末 / 距周末2天）
            // -------------------------------------------------------------
            Rectangle {
                width: (parent.width - 8) / 2
                height: (parent.height - 8) / 2
                radius: 12
                color: c2Hover.hovered ? Theme.bgCardHover : Theme.bgCardItem
                border.color: Theme.borderSubtle
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animInstant } }
                HoverHandler { id: c2Hover }

                Column {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 4

                    Item {
                        width: parent.width; height: 16
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Rectangle { width: 3; height: 10; radius: 1.5; color: Theme.workspace; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "本周状态"; color: Theme.textSecondary; font.pixelSize: 11; font.weight: Font.Bold; font.family: timeDetailRoot.chosenFont }
                        }
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: "W" + timeDetailRoot.yearInfo.week
                            color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 10; font.family: "Monospace"; font.weight: Font.Bold
                        }
                    }

                    // 🚀 大字直显放假/工作日核心状态
                    Text {
                        text: timeDetailRoot.weekInfo.heroText
                        color: timeDetailRoot.weekInfo.isWeekend ? "#f43f5e" : "white"
                        font.pixelSize: 18
                        font.weight: Font.Black
                        font.family: timeDetailRoot.chosenFont
                    }

                    Item { height: 1 }

                    Text {
                        text: timeDetailRoot.weekInfo.subText
                        color: Theme.textMuted
                        font.pixelSize: 10
                        font.family: timeDetailRoot.chosenFont
                    }
                }
            }

            // -------------------------------------------------------------
            // 卡片 3：年度倒计（大字：余 89 天）
            // -------------------------------------------------------------
            Rectangle {
                width: (parent.width - 8) / 2
                height: (parent.height - 8) / 2
                radius: 12
                color: c3Hover.hovered ? Theme.bgCardHover : Theme.bgCardItem
                border.color: Theme.borderSubtle
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animInstant } }
                HoverHandler { id: c3Hover }

                Column {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 4

                    Item {
                        width: parent.width; height: 16
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Rectangle { width: 3; height: 10; radius: 1.5; color: "#10b981"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "年度倒计"; color: Theme.textSecondary; font.pixelSize: 11; font.weight: Font.Bold; font.family: timeDetailRoot.chosenFont }
                        }
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: timeDetailRoot.yearInfo.percent + "%"
                            color: "#10b981"; font.pixelSize: 10; font.family: "Monospace"; font.weight: Font.Bold
                        }
                    }

                    // 🚀 大字直显今年还剩多少天
                    Text {
                        text: timeDetailRoot.yearInfo.heroRemaining
                        color: "white"
                        font.pixelSize: 19
                        font.weight: Font.Black
                        font.family: "Monospace"
                    }

                    Rectangle {
                        width: parent.width
                        height: 3
                        radius: 1.5
                        color: Qt.rgba(1, 1, 1, 0.10)

                        Rectangle {
                            height: parent.height
                            radius: 1.5
                            color: "#10b981"
                            width: parent.width * timeDetailRoot.yearInfo.progress
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                    }

                    Text {
                        text: timeDetailRoot.yearInfo.subText
                        color: Theme.textMuted
                        font.pixelSize: 10
                        font.family: timeDetailRoot.chosenFont
                    }
                }
            }

            // -------------------------------------------------------------
            // 卡片 4：生理作息时相与指引（拒绝鸡汤，切实作息提示）
            // -------------------------------------------------------------
            Rectangle {
                width: (parent.width - 8) / 2
                height: (parent.height - 8) / 2
                radius: 12
                color: c4Hover.hovered ? Theme.bgCardHover : Theme.bgCardItem
                border.color: Theme.borderSubtle
                border.width: 1
                Behavior on color { ColorAnimation { duration: Theme.animInstant } }
                HoverHandler { id: c4Hover }

                Column {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 4

                    Item {
                        width: parent.width; height: 16
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Rectangle { width: 3; height: 10; radius: 1.5; color: timeDetailRoot.rhythmInfo.color; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "作息节律"; color: Theme.textSecondary; font.pixelSize: 11; font.weight: Font.Bold; font.family: timeDetailRoot.chosenFont }
                        }
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: timeDetailRoot.isDay ? "DAY" : "NIGHT"
                            color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 0.8
                        }
                    }

                    // 🚀 大字直显当前时相
                    Text {
                        text: timeDetailRoot.rhythmInfo.hero
                        color: "white"
                        font.pixelSize: 17
                        font.weight: Font.Black
                        font.family: timeDetailRoot.chosenFont
                    }

                    Item { height: 1 }

                    // 🚀 真实的作息指引（清晰 10px，不折断、无省略号）
                    Text {
                        text: timeDetailRoot.rhythmInfo.tip
                        color: timeDetailRoot.rhythmInfo.color
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: timeDetailRoot.chosenFont
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }
        }
    }
}