import QtQuick
import QtQuick.Controls

Item {
    id: bentoRoot
    anchors.fill: parent

    property string chosenFont: ""
    readonly property string effectiveFont: {
        if (typeof Config !== "undefined" && Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) {
            return Config.fontFamily
        }
        if (chosenFont !== "" && chosenFont.indexOf("系统默认") === -1) {
            return chosenFont
        }
        return ""
    }
    readonly property string displayFont: (effectiveFont !== "") ? effectiveFont : "Monospace"

    property var timerPageRef: null
    property string downSpeedStr: "0.0 B/s"
    property string upSpeedStr: "0.0 B/s"
    property string localIp: "127.0.0.1"

    signal openDetail(string pageKey)

    readonly property var savedClocks: (typeof Config !== "undefined" && Config.savedClocks) ? Config.savedClocks : []
    
    function getCityTime(item) {
        if (!item || !item.tz || typeof Bridge === "undefined" || !Bridge.getWorldTime) {
            return { time: "--:--", diff: "", isDay: true }
        }
        return Bridge.getWorldTime(item.tz, (typeof Config !== "undefined") ? (Config.timeFormat === "24h") : true)
    }

    Grid {
        anchors.fill: parent
        columns: 2
        spacing: 8

        // 瓦片 1：日历与世界时钟
        Rectangle {
            width: (bentoRoot.width - 8) / 2
            height: (bentoRoot.height - 8) / 2
            radius: Theme.radiusCard
            color: clockCardArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem
            border.color: clockCardArea.containsMouse ? Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.45) : Theme.borderSubtle
            border.width: 1
            scale: clockCardArea.pressed ? 0.985 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
            Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                anchors.topMargin: 7; anchors.bottomMargin: 7
                spacing: 3

                Item {
                    width: parent.width; height: 16
                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Text { text: "🌍"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "日历时钟"; color: Theme.clock; font.pixelSize: 10; font.weight: Font.Black; font.family: bentoRoot.effectiveFont }
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "↗"; color: clockCardArea.containsMouse ? "white" : Theme.clock; font.pixelSize: 12; font.weight: Font.Bold; font.family: bentoRoot.effectiveFont
                    }
                }

                Row {
                    width: parent.width; height: 20
                    spacing: 6
                    Rectangle { width: 3; height: 14; radius: 1.5; color: Theme.calendar; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: {
                            var d = new Date()
                            var days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
                            return (d.getMonth() + 1) + "月" + d.getDate() + "日 · " + days[d.getDay()]
                        }
                        color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: bentoRoot.effectiveFont
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    width: parent.width; height: 18
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter

                    Item {
                        width: (parent.width - 9) / 2; height: parent.height
                        readonly property var c1: (bentoRoot.savedClocks && bentoRoot.savedClocks.length > 0) ? bentoRoot.savedClocks[0] : null
                        readonly property var info1: bentoRoot.getCityTime(c1)
                        visible: c1 !== null

                        Row {
                            anchors.fill: parent; spacing: 3
                            Text { text: parent.parent.info1.isDay ? "☀️" : "🌙"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: parent.parent.c1 ? parent.parent.c1.name : "纽约"; color: Theme.textSecondary; font.pixelSize: 10; font.family: bentoRoot.effectiveFont; anchors.verticalCenter: parent.verticalCenter }
                            Item { width: 1 }
                            Text { text: parent.parent.info1.time || "--:--"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: bentoRoot.displayFont; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    Rectangle { width: 1; height: 10; color: Qt.rgba(1, 1, 1, 0.15); anchors.verticalCenter: parent.verticalCenter }

                    Item {
                        width: (parent.width - 9) / 2; height: parent.height
                        readonly property var c2: (bentoRoot.savedClocks && bentoRoot.savedClocks.length > 1) ? bentoRoot.savedClocks[1] : null
                        readonly property var info2: bentoRoot.getCityTime(c2)
                        visible: c2 !== null

                        Row {
                            anchors.fill: parent; spacing: 3
                            Text { text: parent.parent.info2.isDay ? "☀️" : "🌙"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: parent.parent.c2 ? parent.parent.c2.name : "马尼拉"; color: Theme.textSecondary; font.pixelSize: 10; font.family: bentoRoot.effectiveFont; anchors.verticalCenter: parent.verticalCenter }
                            Item { width: 1 }
                            Text { text: parent.parent.info2.time || "--:--"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: bentoRoot.displayFont; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            MouseArea {
                id: clockCardArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: bentoRoot.openDetail("clock")
            }
        }

        // 瓦片 2：专注倒计时
        Rectangle {
            id: timerCardRect
            width: (bentoRoot.width - 8) / 2
            height: (bentoRoot.height - 8) / 2
            radius: Theme.radiusCard
            color: timerHeaderArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem
            border.color: timerHeaderArea.containsMouse ? Qt.rgba(Theme.timer.r, Theme.timer.g, Theme.timer.b, 0.45) : Theme.borderSubtle
            border.width: 1
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
            Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                anchors.topMargin: 7; anchors.bottomMargin: 7
                spacing: 3

                Item {
                    width: parent.width; height: 16
                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Text { text: "⏱️"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: bentoRoot.timerPageRef ? (bentoRoot.timerPageRef.isCountUp ? "正向计次" : "专注倒计时") : "计时器"
                            color: Theme.timer; font.pixelSize: 10; font.weight: Font.Black; font.family: bentoRoot.effectiveFont
                        }
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "↗"; color: timerHeaderArea.containsMouse ? "white" : Theme.timer; font.pixelSize: 12; font.weight: Font.Bold; font.family: bentoRoot.effectiveFont
                    }
                }

                Row {
                    width: parent.width; height: 42
                    spacing: 6

                    Column {
                        width: parent.width - 76
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: bentoRoot.timerPageRef ? bentoRoot.timerPageRef.formattedTime : "25:00"
                            color: "white"
                            font.pixelSize: 22
                            font.weight: Font.Black
                            font.family: bentoRoot.displayFont
                            anchors.left: parent.left
                        }

                        Rectangle {
                            width: parent.width - 6; height: 3.5; radius: 2; color: Qt.rgba(1, 1, 1, 0.12)
                            anchors.left: parent.left
                            Rectangle {
                                height: parent.height; radius: 2; color: Theme.timer
                                width: parent.width * (bentoRoot.timerPageRef ? bentoRoot.timerPageRef.progress : 1.0)
                                Behavior on width { NumberAnimation { duration: 150 } }
                            }
                        }
                    }

                    Column {
                        width: 70
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Rectangle {
                            width: parent.width; height: 19; radius: 9.5
                            color: p25Area.pressed ? Qt.rgba(Theme.timer.r, Theme.timer.g, Theme.timer.b, 0.45) : Qt.rgba(Theme.timer.r, Theme.timer.g, Theme.timer.b, 0.2)
                            border.color: Theme.timer; border.width: 1
                            scale: p25Area.pressed ? 0.94 : 1.0

                            Text { anchors.centerIn: parent; text: "25m 专注"; color: "white"; font.pixelSize: 9; font.weight: Font.Bold; font.family: bentoRoot.effectiveFont }
                            MouseArea {
                                id: p25Area; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: if (bentoRoot.timerPageRef) bentoRoot.timerPageRef.startPreset(1500, "focus")
                            }
                        }

                        Rectangle {
                            width: parent.width; height: 19; radius: 9.5
                            readonly property bool isRun: bentoRoot.timerPageRef && bentoRoot.timerPageRef.isRunning
                            color: pToggleArea.pressed ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: Theme.borderSubtle; border.width: 1
                            scale: pToggleArea.pressed ? 0.94 : 1.0

                            Text {
                                anchors.centerIn: parent
                                text: bentoRoot.timerPageRef ? (bentoRoot.timerPageRef.isRunning ? "暂停" : (bentoRoot.timerPageRef.isPaused ? "继续" : "重置")) : "开始"
                                color: "white"; font.pixelSize: 9; font.weight: Font.Bold; font.family: bentoRoot.effectiveFont
                            }
                            MouseArea {
                                id: pToggleArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!bentoRoot.timerPageRef) return
                                    if (bentoRoot.timerPageRef.isRunning || bentoRoot.timerPageRef.isPaused) bentoRoot.timerPageRef.togglePause()
                                    else bentoRoot.timerPageRef.resetTimer()
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: timerHeaderArea
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; height: 32
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: bentoRoot.openDetail("timer")
            }
        }

        // 瓦片 3：网络监控
        Rectangle {
            width: (bentoRoot.width - 8) / 2
            height: (bentoRoot.height - 8) / 2
            radius: Theme.radiusCard
            color: netCardArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem
            border.color: netCardArea.containsMouse ? Qt.rgba(Theme.network.r, Theme.network.g, Theme.network.b, 0.45) : Theme.borderSubtle
            border.width: 1
            scale: netCardArea.pressed ? 0.985 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
            Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                anchors.topMargin: 7; anchors.bottomMargin: 7
                spacing: 4

                Item {
                    width: parent.width; height: 16
                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Text { text: "📶"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "网络监控"; color: Theme.network; font.pixelSize: 10; font.weight: Font.Black; font.family: bentoRoot.effectiveFont }
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "↗"; color: netCardArea.containsMouse ? "white" : Theme.network; font.pixelSize: 12; font.weight: Font.Bold; font.family: bentoRoot.effectiveFont
                    }
                }

                Row {
                    width: parent.width; height: 20
                    spacing: 14
                    Row {
                        spacing: 3; anchors.verticalCenter: parent.verticalCenter
                        Text { text: "↓"; color: Theme.calendar; font.pixelSize: 11; font.weight: Font.Black; font.family: bentoRoot.effectiveFont }
                        Text { text: bentoRoot.downSpeedStr; color: "white"; font.pixelSize: 12; font.weight: Font.Black; font.family: bentoRoot.displayFont }
                    }
                    Row {
                        spacing: 3; anchors.verticalCenter: parent.verticalCenter
                        Text { text: "↑"; color: Theme.network; font.pixelSize: 11; font.weight: Font.Black; font.family: bentoRoot.effectiveFont }
                        Text { text: bentoRoot.upSpeedStr; color: "white"; font.pixelSize: 12; font.weight: Font.Black; font.family: bentoRoot.displayFont }
                    }
                }

                Text {
                    text: "内网 IP: " + bentoRoot.localIp
                    color: Theme.textSecondary; font.pixelSize: 10; font.family: bentoRoot.displayFont
                }
            }

            MouseArea {
                id: netCardArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: bentoRoot.openDetail("network")
            }
        }

        // 瓦片 4：蓝牙外设
        Rectangle {
            width: (bentoRoot.width - 8) / 2
            height: (bentoRoot.height - 8) / 2
            radius: Theme.radiusCard
            color: btCardArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem
            border.color: btCardArea.containsMouse ? Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.45) : Theme.borderSubtle
            border.width: 1
            scale: btCardArea.pressed ? 0.985 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
            Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                anchors.topMargin: 7; anchors.bottomMargin: 7
                spacing: 4

                Item {
                    width: parent.width; height: 16
                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Text { text: "🎧"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "蓝牙外设"; color: Theme.bluetooth; font.pixelSize: 10; font.weight: Font.Black; font.family: bentoRoot.effectiveFont }
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "↗"; color: btCardArea.containsMouse ? "white" : Theme.bluetooth; font.pixelSize: 12; font.weight: Font.Bold; font.family: bentoRoot.effectiveFont
                    }
                }

                Row {
                    width: parent.width
                    height: 38
                    spacing: 8

                    Text { text: "ᛒ"; font.pixelSize: 20; color: Theme.bluetooth; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        width: parent.width - 28
                        spacing: 2
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: (typeof Bridge !== "undefined" && Bridge.isBluetoothPowered && !Bridge.isBluetoothPowered()) ? "蓝牙已关闭" : "设备控制器已就绪"
                            color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: bentoRoot.effectiveFont
                            elide: Text.ElideRight; width: parent.width
                        }
                        Text {
                            text: "点击进入配对管理 ↗"
                            color: Theme.textMuted; font.pixelSize: 9; font.family: bentoRoot.effectiveFont
                            elide: Text.ElideRight; width: parent.width
                        }
                    }
                }
            }

            MouseArea {
                id: btCardArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: bentoRoot.openDetail("bluetooth")
            }
        }
    }
}