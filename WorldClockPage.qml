import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.LocalStorage 2.0

Item {
    id: worldClockRoot
    anchors.fill: parent

    property string chosenFont: ""
    property bool is24h: true
    property bool timeTick: false
    property bool dropdownOpen: false
    property string filterKeyword: ""

    // 默认关注城市
    property var defaultClocks: [
        { name: "伦敦", country: "英国", offset: 0, dst: "EU" },
        { name: "纽约", country: "美国东部", offset: -5, dst: "US" },
        { name: "旧金山", country: "美国西部", offset: -8, dst: "US" },
        { name: "东京", country: "日本", offset: 9, dst: "NONE" }
    ]

    property var myClocks: []

    // ==========================================
    // 本地持久化存储 (SQLite)
    // ==========================================
    function getStorageDb() {
        return LocalStorage.openDatabaseSync("AlcoveIslandClockDB", "1.0", "World Clock Storage", 100000)
    }

    function loadSavedClocks() {
        try {
            var db = getStorageDb()
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS Clocks(key TEXT UNIQUE, val TEXT)')
                var rs = tx.executeSql('SELECT val FROM Clocks WHERE key = "saved_list"')
                if (rs.rows.length > 0) {
                    var parsed = JSON.parse(rs.rows.item(0).val)
                    if (parsed && Array.isArray(parsed) && parsed.length > 0) {
                        worldClockRoot.myClocks = parsed
                        return
                    }
                }
                worldClockRoot.myClocks = defaultClocks.slice()
            })
        } catch(e) {
            worldClockRoot.myClocks = defaultClocks.slice()
        }
    }

    function saveClocksToStorage() {
        try {
            var db = getStorageDb()
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS Clocks(key TEXT UNIQUE, val TEXT)')
                tx.executeSql('INSERT OR REPLACE INTO Clocks VALUES("saved_list", ?)', [JSON.stringify(worldClockRoot.myClocks)])
            })
        } catch(e) {}
    }

    // 每秒驱动走字
    Timer {
        interval: 1000
        running: worldClockRoot.visible
        repeat: true
        onTriggered: worldClockRoot.timeTick = !worldClockRoot.timeTick
    }

    property var availableCities: {
        var activeMap = {}
        for (var i = 0; i < myClocks.length; i++) {
            activeMap[myClocks[i].name] = true
        }
        var kw = filterKeyword.trim().toLowerCase()
        return cityDb.filter(function(c) {
            if (activeMap[c.name]) return false
            if (!kw) return true
            return c.name.indexOf(kw) !== -1 ||
                   (c.pinyin && c.pinyin.indexOf(kw) !== -1) ||
                   (c.py && c.py.indexOf(kw) !== -1) ||
                   (c.country && c.country.indexOf(kw) !== -1) ||
                   (c.en && c.en.toLowerCase().indexOf(kw) !== -1)
        })
    }

    function addClock(item) {
        var list = myClocks.slice()
        list.push(item)
        myClocks = list
        dropdownOpen = false
        filterKeyword = ""
        saveClocksToStorage()
    }

    function removeClock(idx) {
        if (myClocks.length <= 1) return
        var list = myClocks.slice()
        list.splice(idx, 1)
        myClocks = list
        saveClocksToStorage()
    }

    // 夏令时(DST)推算
    function getEffectiveOffset(baseOffset, dstType, now) {
        if (!dstType || dstType === "NONE") return baseOffset
        var year = now.getFullYear()
        var month = now.getMonth() // 0-11, 10月为 9

        if (dstType === "US") {
            // 美国夏令时：3月第2个周日至11月第1个周日 (+1小时)
            if (month > 2 && month < 10) return baseOffset + 1
            if (month === 2) {
                var firstDayMar = new Date(year, 2, 1).getDay()
                var secondSun = (firstDayMar === 0) ? 8 : (15 - firstDayMar)
                if (now.getDate() >= secondSun) return baseOffset + 1
            } else if (month === 10) {
                var firstDayNov = new Date(year, 10, 1).getDay()
                var firstSun = (firstDayNov === 0) ? 1 : (8 - firstDayNov)
                if (now.getDate() < firstSun) return baseOffset + 1
            }
            return baseOffset
        } else if (dstType === "EU") {
            // 欧洲夏令时：3月最后周日至10月最后周日 (+1小时)
            if (month > 2 && month < 9) return baseOffset + 1
            if (month === 2) {
                var lastSunMar = 31 - new Date(year, 2, 31).getDay()
                if (now.getDate() >= lastSunMar) return baseOffset + 1
            } else if (month === 9) { // 10月
                var lastSunOct = 31 - new Date(year, 9, 31).getDay()
                if (now.getDate() < lastSunOct) return baseOffset + 1
            }
            return baseOffset
        } else if (dstType === "AU") {
            // 澳洲夏令时：10月第1个周日至次年4月第1个周日 (+1小时)
            if (month > 9 || month < 3) return baseOffset + 1
            if (month === 9) {
                var firstDayOct = new Date(year, 9, 1).getDay()
                var firstSunOct = (firstDayOct === 0) ? 1 : (8 - firstDayOct)
                if (now.getDate() >= firstSunOct) return baseOffset + 1
            } else if (month === 3) {
                var firstDayApr = new Date(year, 3, 1).getDay()
                var firstSunApr = (firstDayApr === 0) ? 1 : (8 - firstDayApr)
                if (now.getDate() < firstSunApr) return baseOffset + 1
            }
            return baseOffset
        }
        return baseOffset
    }

    // ==============================================================
    // 核心算法：以本机当前系统时间为锚点，绝对精准平移时差
    // ==============================================================
    function getTimeInfo(item, tick) {
        if (!item) return { time: "--:--", diff: "", isDay: true, isWorking: false }

        var now = new Date()
        var baseOff = (item.offset !== undefined) ? item.offset : 0
        var targetOffset = getEffectiveOffset(baseOff, item.dst, now)

        // 1. 本机本地时区偏移（小时）
        // 如中国标准时间 getTimezoneOffset() 为 -480 分钟，localOffsetHours = +8
        var localOffsetHours = -now.getTimezoneOffset() / 60.0

        // 2. 目标城市相对本机的相对时差（小时）
        var diffHours = targetOffset - localOffsetHours

        // 3. 基于本机当前时间戳平移时差，得到目标城市当下的绝对时间对象
        var targetDate = new Date(now.getTime() + diffHours * 3600000)

        var h = targetDate.getHours()
        var m = targetDate.getMinutes()

        var hStr = h
        var period = ""
        if (!worldClockRoot.is24h) {
            period = h >= 12 ? " PM" : " AM"
            hStr = h % 12
            hStr = hStr ? hStr : 12
        }
        var formattedTime = (hStr < 10 ? "0" : "") + hStr + ":" + (m < 10 ? "0" : "") + m + period

        // 4. 判定跨天
        var localDay = now.getDate()
        var targetDay = targetDate.getDate()
        var dayDiff = targetDay - localDay
        if (dayDiff > 1) dayDiff = -1
        if (dayDiff < -1) dayDiff = 1

        var dayStr = (dayDiff === 0) ? "今天" : (dayDiff > 0 ? "明天" : "昨天")
        var diffRound = Math.round(diffHours * 10) / 10
        var diffStr = ""
        if (diffRound === 0) {
            diffStr = "与本地同时"
        } else if (diffRound > 0) {
            diffStr = "快 " + diffRound + "h · " + dayStr
        } else {
            diffStr = "慢 " + Math.abs(diffRound) + "h · " + dayStr
        }

        var isDay = (h >= 6 && h < 18)
        var isWorking = (h >= 9 && h < 18)

        return {
            time: formattedTime,
            diff: diffStr,
            isDay: isDay,
            isWorking: isWorking
        }
    }

    // 全球城市库
    property var cityDb: [
        { name: "北京", country: "中国", pinyin: "beijing", py: "bj", offset: 8, dst: "NONE" },
        { name: "上海", country: "中国", pinyin: "shanghai", py: "sh", offset: 8, dst: "NONE" },
        { name: "广州", country: "中国", pinyin: "guangzhou", py: "gz", offset: 8, dst: "NONE" },
        { name: "深圳", country: "中国", pinyin: "shenzhen", py: "sz", offset: 8, dst: "NONE" },
        { name: "香港", country: "中国香港", pinyin: "xianggang", py: "xg", offset: 8, dst: "NONE" },
        { name: "台北", country: "中国台湾", pinyin: "taibei", py: "tb", offset: 8, dst: "NONE" },
        { name: "东京", country: "日本", pinyin: "dongjing", py: "dj", offset: 9, dst: "NONE" },
        { name: "大阪", country: "日本", pinyin: "daban", py: "db", offset: 9, dst: "NONE" },
        { name: "首尔", country: "韩国", pinyin: "shouer", py: "se", offset: 9, dst: "NONE" },
        { name: "新加坡", country: "新加坡", pinyin: "xinjiapo", py: "xjp", offset: 8, dst: "NONE" },
        { name: "吉隆坡", country: "马来西亚", pinyin: "jilongpo", py: "jlp", offset: 8, dst: "NONE" },
        { name: "曼谷", country: "泰国", pinyin: "mangu", py: "mg", offset: 7, dst: "NONE" },
        { name: "雅加达", country: "印度尼西亚", pinyin: "yajiada", py: "yjd", offset: 7, dst: "NONE" },
        { name: "马尼拉", country: "菲律宾", pinyin: "manila", py: "mnl", offset: 8, dst: "NONE" },
        { name: "胡志明市", country: "越南", pinyin: "huzhimingshi", py: "hzms", offset: 7, dst: "NONE" },
        { name: "新德里", country: "印度", pinyin: "xindeli", py: "xdl", offset: 5.5, dst: "NONE" },
        { name: "迪拜", country: "阿联酋", pinyin: "dibai", py: "db", offset: 4, dst: "NONE" },
        { name: "利雅得", country: "沙特阿拉伯", pinyin: "liyade", py: "lyd", offset: 3, dst: "NONE" },
        { name: "伊斯坦布尔", country: "土耳其", pinyin: "yisitanbuer", py: "ystbe", offset: 3, dst: "NONE" },
        { name: "伦敦", country: "英国", pinyin: "lundun", py: "ld", offset: 0, dst: "EU" },
        { name: "巴黎", country: "法国", pinyin: "bali", py: "bl", offset: 1, dst: "EU" },
        { name: "柏林", country: "德国", pinyin: "bolin", py: "bl", offset: 1, dst: "EU" },
        { name: "法兰克福", country: "德国", pinyin: "falankefu", py: "flkf", offset: 1, dst: "EU" },
        { name: "阿姆斯特丹", country: "荷兰", pinyin: "amusitedan", py: "amstd", offset: 1, dst: "EU" },
        { name: "苏黎世", country: "瑞士", pinyin: "sulishi", py: "sls", offset: 1, dst: "EU" },
        { name: "罗马", country: "意大利", pinyin: "luoma", py: "lm", offset: 1, dst: "EU" },
        { name: "马德里", country: "西班牙", pinyin: "madeli", py: "mdl", offset: 1, dst: "EU" },
        { name: "莫斯科", country: "俄罗斯", pinyin: "mosike", py: "msk", offset: 3, dst: "NONE" },
        { name: "斯德哥尔摩", country: "瑞典", pinyin: "sidegeermo", py: "sdgem", offset: 1, dst: "EU" },
        { name: "纽约", country: "美国东部", pinyin: "niuyue", py: "ny", offset: -5, dst: "US" },
        { name: "波士顿", country: "美国东部", pinyin: "boshidun", py: "bsd", offset: -5, dst: "US" },
        { name: "芝加哥", country: "美国中部", pinyin: "zhijiage", py: "zjg", offset: -6, dst: "US" },
        { name: "旧金山", country: "美国西部", pinyin: "jiujinshan", py: "jjs", offset: -8, dst: "US" },
        { name: "洛杉矶", country: "美国西部", pinyin: "luoshanji", py: "lsj", offset: -8, dst: "US" },
        { name: "西雅图", country: "美国西部", pinyin: "xiyatu", py: "xyt", offset: -8, dst: "US" },
        { name: "多伦多", country: "加拿大", pinyin: "duolunduo", py: "dld", offset: -5, dst: "US" },
        { name: "温哥华", country: "加拿大", pinyin: "wengehua", py: "wgh", offset: -8, dst: "US" },
        { name: "悉尼", country: "澳大利亚", pinyin: "xini", py: "xn", offset: 10, dst: "AU" },
        { name: "墨尔本", country: "澳大利亚", pinyin: "moerben", py: "meb", offset: 10, dst: "AU" },
        { name: "奥克兰", country: "新西兰", pinyin: "aokelan", py: "akl", offset: 12, dst: "AU" },
        { name: "开罗", country: "埃及", pinyin: "kailuo", py: "kl", offset: 2, dst: "NONE" }
    ]

    Component.onCompleted: {
        loadSavedClocks()
    }

    // 点击空白处收起下拉菜单 (z: 85)
    MouseArea {
        anchors.fill: parent
        visible: worldClockRoot.dropdownOpen
        z: 85
        onClicked: {
            worldClockRoot.dropdownOpen = false
            worldClockRoot.filterKeyword = ""
        }
    }

    // ==========================================
    // 1. 顶部触发按钮
    // ==========================================
    Rectangle {
        id: dropdownBtn
        anchors.top: parent.top
        width: parent.width
        height: 26
        radius: 7
        color: dropdownBtnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
        border.color: worldClockRoot.dropdownOpen ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        z: 80

        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: "➕"
                font.pixelSize: 10
                color: "#38bdf8"
            }
            Text {
                text: "选择并添加世界城市时钟..."
                color: Qt.rgba(1, 1, 1, 0.8)
                font.pixelSize: 11
                font.family: worldClockRoot.chosenFont
            }
            Text {
                text: worldClockRoot.dropdownOpen ? "▲" : "▼"
                color: Qt.rgba(1, 1, 1, 0.4)
                font.pixelSize: 8
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: dropdownBtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: worldClockRoot.dropdownOpen = !worldClockRoot.dropdownOpen
        }
    }

    // ==========================================
    // 2. 下拉弹层 (根级 z: 95，点击100%生效)
    // ==========================================
    Rectangle {
        id: dropdownMenu
        anchors.top: dropdownBtn.bottom
        anchors.topMargin: 4
        width: parent.width
        height: 136
        radius: 8
        color: Qt.rgba(0.12, 0.12, 0.16, 0.98)
        border.color: "#38bdf8"
        border.width: 1
        visible: worldClockRoot.dropdownOpen
        z: 95
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            // 搜索过滤栏
            Rectangle {
                width: parent.width
                height: 24
                radius: 5
                color: Qt.rgba(1, 1, 1, 0.08)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 6; anchors.rightMargin: 6
                    spacing: 4

                    Text { text: "🔍"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }

                    TextInput {
                        id: filterInput
                        width: parent.width - 24
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"
                        font.pixelSize: 10
                        font.family: worldClockRoot.chosenFont
                        text: worldClockRoot.filterKeyword
                        onTextChanged: worldClockRoot.filterKeyword = text

                        Text {
                            text: "输入城市首字母或中文快速过滤..."
                            color: Qt.rgba(1, 1, 1, 0.35)
                            font.pixelSize: 10
                            font.family: worldClockRoot.chosenFont
                            visible: !filterInput.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            ListView {
                id: dropListView
                width: parent.width
                height: parent.height - 28
                model: worldClockRoot.availableCities
                clip: true

                ScrollBar.vertical: ScrollBar {
                    width: 4
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.35) }
                }

                delegate: Rectangle {
                    width: dropListView.width - 6
                    height: 26
                    radius: 4
                    color: dropItemArea.containsMouse ? Qt.rgba(56, 189, 248, 0.22) : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: modelData.name + " (" + modelData.country + ")"
                            color: "white"
                            font.pixelSize: 11
                            font.family: worldClockRoot.chosenFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: modelData.offset >= 0 ? ("UTC+" + modelData.offset) : ("UTC" + modelData.offset)
                            color: Qt.rgba(1, 1, 1, 0.4)
                            font.pixelSize: 9
                            font.family: "Monospace"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: dropItemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            worldClockRoot.addClock(modelData)
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // 3. 窄行条带时钟列表
    // ==========================================
    ListView {
        id: clockListView
        anchors.top: dropdownBtn.bottom
        anchors.topMargin: 6
        width: parent.width
        height: parent.height - 32
        clip: true
        spacing: 4
        model: worldClockRoot.myClocks

        ScrollBar.vertical: ScrollBar {
            id: listVBar
            width: 4
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                radius: 2
                color: listVBar.pressed ? "#38bdf8" : (listVBar.hovered ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.22))
            }
        }

        delegate: Rectangle {
            id: clockRow
            width: clockListView.width - (listVBar.visible ? 8 : 0)
            height: 32
            radius: 7
            color: (rowHover.hovered || delArea.containsMouse) ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }

            HoverHandler {
                id: rowHover
            }

            property var info: worldClockRoot.getTimeInfo(modelData, worldClockRoot.timeTick)

            // 左侧信息直接靠左
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {
                        text: clockRow.info.isDay ? "☀️" : "🌙"
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        width: 5; height: 5; radius: 2.5
                        color: clockRow.info.isWorking ? "#22c55e" : Qt.rgba(1, 1, 1, 0.2)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {
                        text: modelData.name
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                        font.family: worldClockRoot.chosenFont
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "· " + modelData.country
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.pixelSize: 10
                        font.family: worldClockRoot.chosenFont
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: clockRow.info.diff
                    color: Qt.rgba(56, 189, 248, 0.8)
                    font.pixelSize: 10
                    font.family: worldClockRoot.chosenFont
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // 右侧时间与删除按钮直接靠右
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: clockRow.info.time
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    font.family: (worldClockRoot.chosenFont !== "") ? worldClockRoot.chosenFont : "Monospace"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: delArea.containsMouse ? "#ef4444" : (rowHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
                    opacity: worldClockRoot.myClocks.length > 1 ? 1.0 : 0.0
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: delArea.containsMouse ? "white" : Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 14
                        font.bold: true
                    }

                    MouseArea {
                        id: delArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: worldClockRoot.removeClock(index)
                    }
                }
            }
        }
    }
}