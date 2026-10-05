// ==========================================
// 📄 File: TimeDetailPage.qml (黄金比例·彻底根绝截断·自洽逻辑版)
// ==========================================
import QtQuick
import QtQuick.Shapes

Item {
    id: timeDetailRoot
    anchors.fill: parent

    property string chosenFont: ""

    readonly property string textFont: {
        if (typeof Config !== "undefined" && Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) {
            return Config.fontFamily
        }
        if (chosenFont !== "" && chosenFont.indexOf("系统默认") === -1) {
            return chosenFont
        }
        return ""
    }
    readonly property string displayFont: (textFont !== "") ? textFont : "Monospace"

    property var currentTime: new Date()

    Timer {
        interval: 1000
        running: timeDetailRoot.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: timeDetailRoot.currentTime = new Date()
    }

    readonly property bool isDay: {
        var h = timeDetailRoot.currentTime.getHours()
        return h >= 6 && h < 18
    }

    // 1. 今日流逝与倒数 (逻辑自洽：分清已过与剩余)
    readonly property var dayInfo: {
        var d = timeDetailRoot.currentTime
        var h = d.getHours(), m = d.getMinutes(), s = d.getSeconds()
        var passedSec = h * 3600 + m * 60 + s
        var totalSec = 86400
        var remSec = Math.max(0, totalSec - passedSec)
        var remH = Math.floor(remSec / 3600)
        var remM = Math.floor((remSec % 3600) / 60)
        var passedRatio = passedSec / totalSec
        var remPercent = Math.max(0, Math.min(100, Math.round((1.0 - passedRatio) * 100)))

        return {
            passedProgress: passedRatio,
            remPercentStr: remPercent + "%",
            remH: remH,
            remM: remM,
            passedStr: "已过 " + h + "小时" + m + "分"
        }
    }

    // 2. 本周信息
    readonly property var weekInfo: {
        var d = timeDetailRoot.currentTime
        var dayOfWeek = d.getDay()
        var currentIdx = (dayOfWeek === 0) ? 6 : (dayOfWeek - 1)
        var daysToWeekend = Math.max(0, 5 - currentIdx)
        var isWeekend = (currentIdx >= 5)
        var dayNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return {
            currentIdx: currentIdx,
            isWeekend: isWeekend,
            todayName: dayNames[currentIdx],
            daysToWeekend: daysToWeekend,
            subNotice: isWeekend ? "休整蓄能中" : ("距周末 " + daysToWeekend + " 天"),
            passedNotice: "工作日第 " + (currentIdx + 1) + "/5 天"
        }
    }

    // 3. 年度信息 (逻辑自洽：倒计与剩余自洽)
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
        var passedRatio = dayOfYear / totalDays
        var remPercent = Math.max(0, Math.min(100, Math.round((1.0 - passedRatio) * 100)))

        return {
            daysLeft: daysLeft,
            day: dayOfYear,
            totalDays: totalDays,
            week: weekNum,
            passedProgress: passedRatio,
            remPercentStr: remPercent + "%"
        }
    }

    // 4. 作息节律
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
        spacing: 10

        // =====================================================================
        // 1. 左侧大看板 (微调至 130px，紧凑聚拢，释放右侧宝贵空间)
        // =====================================================================
        Rectangle {
            width: 130
            height: parent.height
            radius: Theme.radiusCard
            color: Theme.bgCardItem
            border.color: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.28)
            border.width: 1
            clip: true

            Column {
                anchors.centerIn: parent
                spacing: 5
                width: parent.width - 12

                // 标头
                Row {
                    spacing: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle {
                        width: 5; height: 5; radius: 2.5
                        color: Theme.calendar
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "LOCAL TIME"
                        font.pixelSize: 9
                        font.weight: Font.Black
                        color: Theme.calendar
                        font.letterSpacing: 0.8
                        font.family: timeDetailRoot.textFont
                    }
                }

                // 时间大字
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    height: 40

                    Text {
                        text: {
                            var h = timeDetailRoot.currentTime.getHours()
                            return (h < 10 ? "0" : "") + h
                        }
                        color: "white"
                        font.pixelSize: 34
                        font.weight: Font.Black
                        font.family: timeDetailRoot.displayFont
                        font.features: { "tnum": 1 }
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        width: 5

                        Rectangle { width: 3.2; height: 3.2; radius: 1.6; color: Theme.calendar; anchors.horizontalCenter: parent.horizontalCenter }
                        Rectangle { width: 3.2; height: 3.2; radius: 1.6; color: Theme.calendar; anchors.horizontalCenter: parent.horizontalCenter }

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite; running: true
                            NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                        }
                    }

                    Text {
                        text: {
                            var m = timeDetailRoot.currentTime.getMinutes()
                            return (m < 10 ? "0" : "") + m
                        }
                        color: "white"
                        font.pixelSize: 34
                        font.weight: Font.Black
                        font.family: timeDetailRoot.displayFont
                        font.features: { "tnum": 1 }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // 秒数胶囊
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 56; height: 18; radius: 9
                    color: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.12)
                    border.color: Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.35)
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            text: {
                                var s = timeDetailRoot.currentTime.getSeconds()
                                return (s < 10 ? "0" : "") + s
                            }
                            color: "white"
                            font.pixelSize: 11
                            font.weight: Font.Black
                            font.family: timeDetailRoot.displayFont
                            font.features: { "tnum": 1 }
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "SEC"
                            color: Theme.calendar
                            font.pixelSize: 8
                            font.weight: Font.Black
                            font.family: timeDetailRoot.textFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                Item { height: 1 }

                // 日期
                Text {
                    text: {
                        var d = timeDetailRoot.currentTime
                        var days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
                        return (d.getMonth() + 1) + "月" + d.getDate() + "日 · " + days[d.getDay()]
                    }
                    color: "white"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.family: timeDetailRoot.textFont
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // 时区
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 16
                    width: tzRow.implicitWidth + 10
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.05)

                    Row {
                        id: tzRow
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: {
                                var offsetMin = -timeDetailRoot.currentTime.getTimezoneOffset()
                                var h = Math.floor(Math.abs(offsetMin) / 60)
                                var sign = offsetMin >= 0 ? "+" : "-"
                                return "UTC" + sign + h
                            }
                            color: Theme.textSecondary
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.family: timeDetailRoot.displayFont
                        }
                        Text {
                            text: "本地"
                            color: Theme.textMuted
                            font.pixelSize: 9
                            font.family: timeDetailRoot.textFont
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2. 右侧 4 卡 Bento 网格 (拓宽至 258px，单卡 125px，彻底容纳文字)
        // =====================================================================
        Grid {
            width: parent.width - 140
            height: parent.height
            columns: 2
            spacing: 8

            // -----------------------------------------------------------------
            // 卡片 1：今日剩余 (逻辑自洽：右上角标“剩 31%”)
            // -----------------------------------------------------------------
            Rectangle {
                width: (parent.width - 8) / 2
                height: (parent.height - 8) / 2
                radius: 12
                color: c1Hover.hovered ? Theme.bgCardHover : Theme.bgCardItem
                border.color: c1Hover.hovered ? Qt.rgba(Theme.calendar.r, Theme.calendar.g, Theme.calendar.b, 0.45) : Theme.borderSubtle
                border.width: 1

                HoverHandler { id: c1Hover }

                Column {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 3

                    Item {
                        width: parent.width; height: 16
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Rectangle { width: 3; height: 10; radius: 1.5; color: Theme.calendar; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "今日剩余"; color: Theme.textSecondary; font.pixelSize: 11; font.weight: Font.Bold; font.family: timeDetailRoot.textFont }
                        }
                        // 🚀【自洽】：明确显示“余 xx%”
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: "余 " + timeDetailRoot.dayInfo.remPercentStr
                            color: Theme.calendar; font.pixelSize: 10; font.weight: Font.Bold; font.family: timeDetailRoot.displayFont
                        }
                    }

                    Row {
                        spacing: 2
                        anchors.left: parent.left

                        Text {
                            id: remHNum
                            text: timeDetailRoot.dayInfo.remH
                            color: "white"
                            font.pixelSize: 20
                            font.weight: Font.Black
                            font.family: timeDetailRoot.displayFont
                            font.features: { "tnum": 1 }
                        }
                        Text {
                            text: "h"
                            color: Theme.calendar
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.family: timeDetailRoot.textFont
                            anchors.baseline: remHNum.baseline
                            rightPadding: 2
                        }
                        Text {
                            id: remMNum
                            text: (timeDetailRoot.dayInfo.remM < 10 ? "0" : "") + timeDetailRoot.dayInfo.remM
                            color: "white"
                            font.pixelSize: 20
                            font.weight: Font.Black
                            font.family: timeDetailRoot.displayFont
                            font.features: { "tnum": 1 }
                            anchors.baseline: remHNum.baseline
                        }
                        Text {
                            text: "m"
                            color: Theme.calendar
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.family: timeDetailRoot.textFont
                            anchors.baseline: remHNum.baseline
                        }
                    }

                    Rectangle {
                        width: parent.width; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.10)
                        Rectangle {
                            height: parent.height; radius: 1.5; color: Theme.calendar
                            width: parent.width * timeDetailRoot.dayInfo.passedProgress
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                    }

                    Text {
                        text: timeDetailRoot.dayInfo.passedStr
                        color: Theme.textMuted
                        font.pixelSize: 10
                        font.family: timeDetailRoot.textFont
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            // -----------------------------------------------------------------
            // 卡片 2：本周状态 (彻底根除截断，上下层次分明)
            // -----------------------------------------------------------------
            Rectangle {
                width: (parent.width - 8) / 2
                height: (parent.height - 8) / 2
                radius: 12
                color: c2Hover.hovered ? Theme.bgCardHover : Theme.bgCardItem
                border.color: c2Hover.hovered ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.45) : Theme.borderSubtle
                border.width: 1

                HoverHandler { id: c2Hover }

                Column {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 3

                    Item {
                        width: parent.width; height: 16
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Rectangle { width: 3; height: 10; radius: 1.5; color: Theme.workspace; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "本周状态"; color: Theme.textSecondary; font.pixelSize: 11; font.weight: Font.Bold; font.family: timeDetailRoot.textFont }
                        }
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: "W" + timeDetailRoot.yearInfo.week
                            color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 10; font.family: timeDetailRoot.displayFont; font.weight: Font.Bold
                        }
                    }

                    // 🚀【彻底重塑】：主视觉大字独占清晰位置，不再强行塞在一行导致切字
                    Row {
                        spacing: 6
                        anchors.left: parent.left
                        width: parent.width

                        Text {
                            text: timeDetailRoot.weekInfo.isWeekend ? timeDetailRoot.weekInfo.todayName : "工作日"
                            color: timeDetailRoot.weekInfo.isWeekend ? "#f43f5e" : "white"
                            font.pixelSize: 18
                            font.weight: Font.Black
                            font.family: timeDetailRoot.textFont
                        }

                        // 极精致小徽标，替代挤扁的长文字
                        Rectangle {
                            height: 16
                            width: tagNoticeText.implicitWidth + 8
                            radius: 4
                            color: timeDetailRoot.weekInfo.isWeekend ? Qt.rgba(244 / 255, 63 / 94, 0.16) : Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.16)
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: tagNoticeText
                                anchors.centerIn: parent
                                text: timeDetailRoot.weekInfo.subNotice
                                color: timeDetailRoot.weekInfo.isWeekend ? "#f43f5e" : Theme.workspace
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.family: timeDetailRoot.textFont
                            }
                        }
                    }

                    Item { height: 1 }

                    Text {
                        text: timeDetailRoot.weekInfo.isWeekend ? "周末休整 · 蓄能焕新" : timeDetailRoot.weekInfo.passedNotice
                        color: Theme.textMuted
                        font.pixelSize: 10
                        font.family: timeDetailRoot.textFont
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            // -----------------------------------------------------------------
            // 卡片 3：年度倒计 (逻辑自洽：右上角标“余 24%”)
            // -----------------------------------------------------------------
            Rectangle {
                width: (parent.width - 8) / 2
                height: (parent.height - 8) / 2
                radius: 12
                color: c3Hover.hovered ? Theme.bgCardHover : Theme.bgCardItem
                border.color: c3Hover.hovered ? Qt.rgba(16, 185, 129, 0.45) : Theme.borderSubtle
                border.width: 1

                HoverHandler { id: c3Hover }

                Column {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 3

                    Item {
                        width: parent.width; height: 16
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Rectangle { width: 3; height: 10; radius: 1.5; color: "#10b981"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "年度倒计"; color: Theme.textSecondary; font.pixelSize: 11; font.weight: Font.Bold; font.family: timeDetailRoot.textFont }
                        }
                        // 🚀【自洽】：清晰指明“余 xx%”
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: "余 " + timeDetailRoot.yearInfo.remPercentStr
                            color: "#10b981"; font.pixelSize: 10; font.weight: Font.Bold; font.family: timeDetailRoot.displayFont
                        }
                    }

                    Row {
                        spacing: 2
                        anchors.left: parent.left

                        Text {
                            id: yearDayNum
                            text: timeDetailRoot.yearInfo.daysLeft
                            color: "white"
                            font.pixelSize: 20
                            font.weight: Font.Black
                            font.family: timeDetailRoot.displayFont
                            font.features: { "tnum": 1 }
                        }

                        Text {
                            text: "天"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.family: timeDetailRoot.textFont
                            anchors.baseline: yearDayNum.baseline
                            leftPadding: 2
                        }
                    }

                    Rectangle {
                        width: parent.width; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.10)
                        Rectangle {
                            height: parent.height; radius: 1.5; color: "#10b981"
                            width: parent.width * timeDetailRoot.yearInfo.passedProgress
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                    }

                    Text {
                        text: "已过 " + timeDetailRoot.yearInfo.day + " 天 · 全年 " + timeDetailRoot.yearInfo.totalDays + " 天"
                        color: Theme.textMuted
                        font.pixelSize: 10
                        font.family: timeDetailRoot.textFont
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            // -----------------------------------------------------------------
            // 卡片 4：作息节律
            // -----------------------------------------------------------------
            Rectangle {
                width: (parent.width - 8) / 2
                height: (parent.height - 8) / 2
                radius: 12
                color: c4Hover.hovered ? Theme.bgCardHover : Theme.bgCardItem
                border.color: c4Hover.hovered ? Qt.rgba(timeDetailRoot.rhythmInfo.color.r, timeDetailRoot.rhythmInfo.color.g, timeDetailRoot.rhythmInfo.color.b, 0.45) : Theme.borderSubtle
                border.width: 1

                HoverHandler { id: c4Hover }

                Column {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 3

                    Item {
                        width: parent.width; height: 16
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Rectangle { width: 3; height: 10; radius: 1.5; color: timeDetailRoot.rhythmInfo.color; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "作息节律"; color: Theme.textSecondary; font.pixelSize: 11; font.weight: Font.Bold; font.family: timeDetailRoot.textFont }
                        }
                        Text {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            text: timeDetailRoot.isDay ? "DAY" : "NIGHT"
                            color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 0.8; font.family: timeDetailRoot.displayFont
                        }
                    }

                    Text {
                        text: timeDetailRoot.rhythmInfo.hero
                        color: "white"
                        font.pixelSize: 16
                        font.weight: Font.Black
                        font.family: timeDetailRoot.textFont
                    }

                    Item { height: 1 }

                    Text {
                        text: timeDetailRoot.rhythmInfo.tip
                        color: timeDetailRoot.rhythmInfo.color
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: timeDetailRoot.textFont
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }
        }
    }
}