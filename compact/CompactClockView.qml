// ==========================================
// 📄 File: compact/CompactClockView.qml (苹果灵动岛呼吸比例版)
// ==========================================
import QtQuick

Row {
    id: clockRoot
    spacing: 6
    leftPadding: 8
    rightPadding: 8

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property bool isCapsLock: false
    property bool isNumLock: false
    property bool showNetSpeed: true
    property string downCompact: "0K"
    property string upCompact: "0K"
    property string displayDate: ""
    property string displayTime: "04:53"
    property string displaySeconds: ""
    property string displayPeriod: "pm"
    property bool isClockActive: true

    visible: opacity > 0.001
    opacity: clockRoot.isClockActive ? 1.0 : 0.0
    scale: clockRoot.isClockActive ? 1.0 : 0.94

    Behavior on opacity { NumberAnimation { duration: clockRoot.isClockActive ? 150 : 80; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: clockRoot.isClockActive ? 170 : 80; easing.type: Easing.OutCubic } }

    // =========================================================================
    // 1. 大写锁定微胶囊 (CAPS LOCK - 19px 极简微悬浮)
    // =========================================================================
    Rectangle {
        id: capsLockBadge
        height: 19
        radius: 5
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        width: clockRoot.isCapsLock ? 45 : 0
        opacity: clockRoot.isCapsLock ? 1.0 : 0.0
        scale: clockRoot.isCapsLock ? 1.0 : 0.75

        color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.14)
        border.color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.40)
        border.width: 1

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: clockRoot.isCapsLock ? 140 : 90 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Row {
            anchors.centerIn: parent
            spacing: 3

            Text {
                text: "⇪"
                color: "#38bdf8"
                font.pixelSize: 10
                font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "CAPS"
                color: "white"
                font.pixelSize: 8
                font.weight: Font.Black
                font.letterSpacing: 0.6
                font.family: clockRoot.displayFont
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // =========================================================================
    // 2. 数字键盘锁定微胶囊 (NUM LOCK - 19px 薄荷微光)
    // =========================================================================
    Rectangle {
        id: numLockBadge
        height: 19
        radius: 5
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        width: clockRoot.isNumLock ? 45 : 0
        opacity: clockRoot.isNumLock ? 1.0 : 0.0
        scale: clockRoot.isNumLock ? 1.0 : 0.75

        color: Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.14)
        border.color: Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.40)
        border.width: 1

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: clockRoot.isNumLock ? 140 : 90 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Row {
            anchors.centerIn: parent
            spacing: 3

            Text {
                text: "123"
                color: "#34d399"
                font.pixelSize: 9
                font.weight: Font.Black
                font.family: clockRoot.displayFont
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "NUM"
                color: "white"
                font.pixelSize: 8
                font.weight: Font.Black
                font.letterSpacing: 0.6
                font.family: clockRoot.displayFont
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // =========================================================================
    // 3. 实时网速微卡片 (19px 高度统一)
    // =========================================================================
    Rectangle {
        id: netSpeedItem
        height: 19
        radius: 5
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        width: clockRoot.showNetSpeed ? 46 : 0
        opacity: clockRoot.showNetSpeed ? 1.0 : 0.0
        scale: clockRoot.showNetSpeed ? 1.0 : 0.80

        color: Qt.rgba(1, 1, 1, 0.055)
        border.color: Qt.rgba(1, 1, 1, 0.11)
        border.width: 1

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 130 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Column {
            anchors.centerIn: parent
            spacing: 0

            Row {
                spacing: 3; anchors.left: parent.left; anchors.leftMargin: 3
                Text { text: "↓"; font.pixelSize: 8; font.weight: Font.Black; color: Theme.network; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: clockRoot.downCompact
                    color: "white"; font.pixelSize: 8; font.weight: Font.Black
                    font.family: clockRoot.displayFont
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Row {
                spacing: 3; anchors.left: parent.left; anchors.leftMargin: 3
                Text { text: "↑"; font.pixelSize: 8; font.weight: Font.Black; color: Theme.calendar; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: clockRoot.upCompact
                    color: "white"; font.pixelSize: 8; font.weight: Font.Black
                    font.family: clockRoot.displayFont
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // =========================================================================
    // 4. 纯净日期卡片 (19px 灵动微岛风格)
    // =========================================================================
    Rectangle {
        id: dateCard
        height: 19
        radius: 5
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        readonly property bool shouldShow: (typeof Config !== "undefined" && Config.showDate) && clockRoot.displayDate !== ""
        width: shouldShow ? (dateText.implicitWidth + 14) : 0
        opacity: shouldShow ? 1.0 : 0.0
        scale: shouldShow ? 1.0 : 0.80

        color: Qt.rgba(1, 1, 1, 0.055)
        border.color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Text {
            id: dateText
            anchors.centerIn: parent
            text: clockRoot.displayDate
            color: Qt.rgba(1, 1, 1, 0.85)
            font.family: clockRoot.effectiveFont
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 0.2
        }
    }

    // =========================================================================
    // 5. 日期与时间之间的微细分割线
    // =========================================================================
    Rectangle {
        id: dateDivider
        width: 1
        height: 10
        radius: 0.5
        color: Qt.rgba(1, 1, 1, 0.16)
        anchors.verticalCenter: parent.verticalCenter
        visible: (typeof Config !== "undefined" && Config.showDate) && clockRoot.displayDate !== ""
        opacity: dateCard.opacity

        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    // =========================================================================
    // 6. 核心时间行 (时间样式完全不变)
    // =========================================================================
    Row {
        spacing: 1
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: clockRoot.displayTime
            color: "white"
            font.family: clockRoot.displayFont
            font.pixelSize: 18
            font.weight: Font.Black
            font.features: { "tnum": 1 }
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            visible: (typeof Config !== "undefined" && Config.showSeconds) && clockRoot.displaySeconds !== ""
            width: visible ? 20 : 0
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            Row {
                anchors.centerIn: parent
                spacing: 0
                Text {
                    text: ":"
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.family: clockRoot.displayFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: clockRoot.displaySeconds.replace(/^:/, "")
                    color: Theme.network
                    font.family: clockRoot.displayFont
                    font.pixelSize: 11
                    font.weight: Font.Black
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Text {
            text: clockRoot.displayPeriod
            color: Qt.rgba(1, 1, 1, 0.55)
            font.family: clockRoot.effectiveFont
            font.pixelSize: 9
            font.weight: Font.Black
            font.capitalization: Font.AllUppercase
            visible: (typeof Config !== "undefined" && Config.timeFormat === "12h") && clockRoot.displayPeriod !== ""
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 2
        }
    }

    Component.onCompleted: printClockItemWidths()

    // 当大写锁、数字锁、日期变化时重新打印
    onIsCapsLockChanged: printClockItemWidths()
    onIsNumLockChanged: printClockItemWidths()

    function printClockItemWidths() {
        console.log("------ [CLOCK VIEW 各项宽度细分] ------")
        console.log("  Row 总 implicitWidth : " + clockRoot.implicitWidth)
        console.log("  Row 内部间距 (spacing): " + clockRoot.spacing + " | leftPadding: " + clockRoot.leftPadding + " | rightPadding: " + clockRoot.rightPadding)
        console.log("  1. 大写锁徽章 (capsLockBadge) : width=" + capsLockBadge.width + ", visible=" + capsLockBadge.visible)
        console.log("  2. 数字锁徽章 (numLockBadge)  : width=" + numLockBadge.width + ", visible=" + numLockBadge.visible)
        console.log("  3. 实时网速项 (netSpeedItem)  : width=" + netSpeedItem.width + ", visible=" + netSpeedItem.visible)
        console.log("  4. 日期卡片项 (dateCard)      : width=" + dateCard.width + ", visible=" + dateCard.visible)
        console.log("  5. 日期分割线 (dateDivider)   : width=" + dateDivider.width + ", visible=" + dateDivider.visible)
        console.log("-----------------------------------------")
    }
}