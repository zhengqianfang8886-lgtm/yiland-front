// ==========================================
// 📄 File: ui/components/pages/WorldClockPage.qml
// 🌟 世界时钟页 (集成懒加载防孵化中断报错版)
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: worldClockRoot
    anchors.fill: parent

    property string chosenFont: ""
    readonly property string effectiveFont: chosenFont !== "" ? chosenFont : Theme.activeFont
    readonly property string displayFont: Theme.displayMonoFont

    property bool is24h: true
    property bool timeTick: false
    property bool dropdownOpen: false
    property string filterKeyword: ""

    readonly property var cityDb: (typeof WorldCities !== "undefined" && WorldCities && WorldCities.length > 0)
        ? WorldCities
        : ((typeof Config !== "undefined" && Config.worldCities) ? Config.worldCities : [])

    Timer {
        interval: 1000
        running: worldClockRoot.visible
        repeat: true
        onTriggered: worldClockRoot.timeTick = !worldClockRoot.timeTick
    }

    property var availableCities: {
        var activeMap = {}
        var currentClocks = (typeof Config !== "undefined" && Config.savedClocks) ? Config.savedClocks : []
        for (var i = 0; i < currentClocks.length; i++) {
            if (currentClocks[i] && currentClocks[i].name) {
                activeMap[currentClocks[i].name] = true
            }
        }
        var kw = filterKeyword.trim().toLowerCase()
        return cityDb.filter(function(c) {
            if (activeMap[c.name]) return false
            if (!kw) return true
            return (c.name && c.name.indexOf(kw) !== -1) ||
                   (c.pinyin && c.pinyin.indexOf(kw) !== -1) ||
                   (c.py && c.py.indexOf(kw) !== -1) ||
                   (c.country && c.country.indexOf(kw) !== -1) ||
                   (c.en && c.en.toLowerCase().indexOf(kw) !== -1)
        })
    }

    function addClock(item) {
        if (typeof Config === "undefined") return
        var list = (Config.savedClocks || []).slice()
        list.push(item)
        Config.savedClocks = list
        dropdownOpen = false
        filterKeyword = ""
    }

    function removeClock(idx) {
        if (typeof Config === "undefined") return
        var list = (Config.savedClocks || []).slice()
        if (list.length <= 1) return
        list.splice(idx, 1)
        Config.savedClocks = list
    }

    function formatTzOffset(tz) {
        if (!tz) return ""
        if (typeof Bridge !== "undefined" && Bridge.getTzOffsetStr) {
            return Bridge.getTzOffsetStr(tz)
        }
        return tz
    }

    function getTimeInfo(item, tick) {
        if (!item) return { time: "--:--", diff: "", isDay: true, isWorking: false }
        var tz = item.tz || ""
        if (typeof Bridge !== "undefined" && Bridge.getWorldTime) {
            var info = Bridge.getWorldTime(tz, worldClockRoot.is24h)
            if (info && info.time) return info
        }
        return { time: "--:--", diff: "", isDay: true, isWorking: false }
    }

    MouseArea {
        anchors.fill: parent
        visible: worldClockRoot.dropdownOpen
        z: 85
        onClicked: {
            worldClockRoot.dropdownOpen = false
            worldClockRoot.filterKeyword = ""
        }
    }

    Column {
        anchors.fill: parent
        spacing: 8

        Item {
            id: topHeader
            width: parent.width
            height: 24

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: Theme.clock
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "WORLD TIME"
                    font.pixelSize: 10
                    font.weight: Font.Black
                    font.letterSpacing: 0.8
                    color: Theme.clock
                    font.family: worldClockRoot.effectiveFont
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: countText.implicitWidth + 10
                    height: 18; radius: 9
                    color: Qt.rgba(1, 1, 1, 0.08)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: (Config.savedClocks ? Config.savedClocks.length : 0) + " 城市"
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: worldClockRoot.effectiveFont
                    }
                }
            }

            Rectangle {
                id: addBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 24
                width: addRow.implicitWidth + 16
                radius: 12
                color: worldClockRoot.dropdownOpen ?
                       Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.28) :
                       (addHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06))
                border.color: worldClockRoot.dropdownOpen ? Theme.clock : Theme.borderSubtle
                border.width: 1

                Row {
                    id: addRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text { text: "+"; color: Theme.clock; font.pixelSize: 13; font.weight: Font.Black; font.family: worldClockRoot.effectiveFont }
                    Text { text: "添加城市"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: worldClockRoot.effectiveFont }
                    Text {
                        text: worldClockRoot.dropdownOpen ? "▲" : "▼"
                        color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 8
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: worldClockRoot.dropdownOpen = !worldClockRoot.dropdownOpen
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - 32

            Flickable {
                id: gridFlickable
                anchors.fill: parent
                contentWidth: width
                contentHeight: clockGrid.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    width: 3
                    policy: gridFlickable.contentHeight > gridFlickable.height ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 1.5; color: Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.4) }
                }

                Grid {
                    id: clockGrid
                    width: parent.width - (gridFlickable.contentHeight > gridFlickable.height ? 6 : 0)
                    columns: 2
                    spacing: 8

                    Repeater {
                        model: (typeof Config !== "undefined" && Config.savedClocks) ? Config.savedClocks : []

                        Rectangle {
                            id: cityCard
                            width: (clockGrid.width - 8) / 2
                            height: 66
                            radius: 12
                            color: cardHover.hovered ? Theme.bgCardHover : Theme.bgCardItem
                            border.color: cardHover.hovered ? Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.45) : Theme.borderSubtle
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

                            HoverHandler { id: cardHover }

                            property var info: worldClockRoot.getTimeInfo(modelData, worldClockRoot.timeTick)

                            Column {
                                anchors.fill: parent
                                anchors.leftMargin: 11; anchors.rightMargin: 11
                                anchors.topMargin: 8; anchors.bottomMargin: 8
                                spacing: 4

                                Item {
                                    width: parent.width
                                    height: 20

                                    Row {
                                        id: leftInfoRow
                                        anchors.left: parent.left
                                        anchors.right: rightBadgeRow.left
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        Rectangle {
                                            width: 3; height: 11; radius: 1.5
                                            color: cityCard.info.isWorking ? "#10b981" : (cityCard.info.isDay ? Theme.clock : "#818cf8")
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: modelData.name || "城市"
                                            color: "white"
                                            font.pixelSize: 15
                                            font.weight: Font.Black
                                            font.family: worldClockRoot.effectiveFont
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: modelData.country || ""
                                            color: Theme.textSecondary
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            font.family: worldClockRoot.effectiveFont
                                            elide: Text.ElideRight
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Row {
                                        id: rightBadgeRow
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Rectangle {
                                            height: 18
                                            width: diffText.implicitWidth + 10
                                            radius: 9
                                            color: Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.16)
                                            border.color: Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.35)
                                            border.width: 1
                                            visible: !delBtn.visible

                                            Text {
                                                id: diffText
                                                anchors.centerIn: parent
                                                text: cityCard.info.diff || ""
                                                color: Theme.clock
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                font.family: worldClockRoot.displayFont
                                            }
                                        }

                                        Rectangle {
                                            id: delBtn
                                            width: 18; height: 18; radius: 9
                                            color: delHover.hovered ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.35) : Qt.rgba(1, 1, 1, 0.10)
                                            border.color: delHover.hovered ? Theme.danger : Theme.borderSubtle
                                            border.width: 1
                                            visible: cardHover.hovered && (Config.savedClocks && Config.savedClocks.length > 1)
                                            scale: delTap.pressed ? 0.9 : 1.0

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                color: delHover.hovered ? Theme.danger : Qt.rgba(1, 1, 1, 0.7)
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                                font.family: worldClockRoot.effectiveFont
                                            }

                                            HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                                            TapHandler {
                                                id: delTap
                                                onTapped: worldClockRoot.removeClock(index)
                                            }
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: 26

                                    Row {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 5

                                        Rectangle {
                                            width: 5; height: 5; radius: 2.5
                                            color: cityCard.info.isWorking ? "#10b981" : (cityCard.info.isDay ? Theme.clock : "#818cf8")
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: (cityCard.info.isDay ? "白昼" : "夜幕") + " · " + (cityCard.info.isWorking ? "工作中" : "休整中")
                                            color: cityCard.info.isWorking ? "#34d399" : Theme.textSecondary
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            font.family: worldClockRoot.effectiveFont
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: cityCard.info.time || "--:--"
                                        color: "white"
                                        font.pixelSize: 24
                                        font.weight: Font.Black
                                        font.family: worldClockRoot.displayFont
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: dropdownMenu
        anchors.top: parent.top
        anchors.topMargin: 30
        anchors.right: parent.right
        width: parent.width
        height: 136
        radius: 10
        color: Qt.rgba(20 / 255, 20 / 255, 26 / 255, 0.98)
        border.color: Theme.clock
        border.width: 1
        visible: worldClockRoot.dropdownOpen
        z: 100
        clip: true

        Column {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 5

            Rectangle {
                width: parent.width
                height: 26
                radius: 6
                color: Qt.rgba(1, 1, 1, 0.08)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8; anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "SEARCH"
                        font.pixelSize: 9
                        font.weight: Font.Black
                        color: Theme.clock
                        font.family: worldClockRoot.effectiveFont
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: filterInput
                        width: parent.width - 56
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"
                        font.pixelSize: 11
                        font.family: worldClockRoot.effectiveFont
                        text: worldClockRoot.filterKeyword
                        onTextChanged: worldClockRoot.filterKeyword = text

                        Text {
                            text: "输入城市中文名、拼音缩写或英文..."
                            color: Qt.rgba(1, 1, 1, 0.4)
                            font.pixelSize: 11
                            font.family: worldClockRoot.effectiveFont
                            visible: !filterInput.text
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            ListView {
                id: dropListView
                width: parent.width
                height: parent.height - 32
                // 🚀【核心修复】：仅在下拉面板展开时才挂载列表模型，从根源杜绝切页孵化中断报错
                model: worldClockRoot.dropdownOpen ? worldClockRoot.availableCities : []
                clip: true

                ScrollBar.vertical: ScrollBar {
                    width: 3
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 1.5; color: Qt.rgba(1, 1, 1, 0.35) }
                }

                delegate: Rectangle {
                    width: dropListView.width - 6
                    height: 28
                    radius: 5
                    color: dropItemArea.containsMouse ? Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.22) : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: modelData.name + " (" + modelData.country + ")"
                            color: "white"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.family: worldClockRoot.effectiveFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: worldClockRoot.formatTzOffset(modelData.tz)
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.pixelSize: 10
                            font.family: worldClockRoot.displayFont
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: dropItemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: worldClockRoot.addClock(modelData)
                    }
                }
            }
        }
    }
}