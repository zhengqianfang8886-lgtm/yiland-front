import QtQuick
import QtQuick.Controls

Item {
    id: worldClockRoot
    anchors.fill: parent

    property string chosenFont: ""
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

    // 1. 顶部触发按钮
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

    // 2. 下拉选择弹层
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
                            text: "输入城市名称、拼音缩写或英文快速过滤..."
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
                            text: worldClockRoot.formatTzOffset(modelData.tz)
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

    // 3. 条带时钟列表
    ListView {
        id: clockListView
        anchors.top: dropdownBtn.bottom
        anchors.topMargin: 6
        width: parent.width
        height: parent.height - 32
        clip: true
        spacing: 4
        model: (typeof Config !== "undefined" && Config.savedClocks) ? Config.savedClocks : []

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
                        text: modelData.name || ""
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                        font.family: worldClockRoot.chosenFont
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "· " + (modelData.country || "")
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.pixelSize: 10
                        font.family: worldClockRoot.chosenFont
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: clockRow.info.diff || ""
                    color: Qt.rgba(56, 189, 248, 0.8)
                    font.pixelSize: 10
                    font.family: worldClockRoot.chosenFont
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    text: clockRow.info.time || "--:--"
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
                    opacity: (Config.savedClocks && Config.savedClocks.length > 1) ? 1.0 : 0.0
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