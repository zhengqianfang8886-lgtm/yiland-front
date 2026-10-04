// ==========================================
// 📄 File: compact/CompactClockView.qml (零穿模流体排布版)
// ==========================================
import QtQuick

Row {
    id: clockRoot
    spacing: 6

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
    // 1. 大写锁定微胶囊 (Caps Lock - 冰蓝微光)
    // =========================================================================
    Rectangle {
        id: capsLockBadge
        height: 22
        radius: 6
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        // 🚀 核心优化：宽高与透明度、缩放精准同相，绝不穿模溢出
        width: clockRoot.isCapsLock ? 48 : 0
        opacity: clockRoot.isCapsLock ? 1.0 : 0.0
        scale: clockRoot.isCapsLock ? 1.0 : 0.75

        color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.18)
        border.color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.50)
        border.width: 1

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: clockRoot.isCapsLock ? 140 : 90 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Row {
            anchors.centerIn: parent
            spacing: 3
            Text { text: "⇪"; color: "#38bdf8"; font.pixelSize: 11; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "大写"; color: "white"; font.pixelSize: 9; font.weight: Font.Bold; font.family: clockRoot.effectiveFont; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // =========================================================================
    // 2. 数字锁定微胶囊 (Num Lock - 薄荷绿磨砂)
    // =========================================================================
    Rectangle {
        id: numLockBadge
        height: 22
        radius: 6
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        width: clockRoot.isNumLock ? 48 : 0
        opacity: clockRoot.isNumLock ? 1.0 : 0.0
        scale: clockRoot.isNumLock ? 1.0 : 0.75

        color: Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.18)
        border.color: Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.50)
        border.width: 1

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: clockRoot.isNumLock ? 140 : 90 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Row {
            anchors.centerIn: parent
            spacing: 3
            Text { text: "123"; color: "#34d399"; font.pixelSize: 10; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "数字"; color: "white"; font.pixelSize: 9; font.weight: Font.Bold; font.family: clockRoot.effectiveFont; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // =========================================================================
    // 3. 实时网速小卡片 (锁宽 48px，防抖退场)
    // =========================================================================
    Rectangle {
        id: netSpeedItem
        height: 22
        radius: 5
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        width: clockRoot.showNetSpeed ? 48 : 0
        opacity: clockRoot.showNetSpeed ? 1.0 : 0.0
        scale: clockRoot.showNetSpeed ? 1.0 : 0.80

        color: Qt.rgba(1, 1, 1, 0.06)
        border.color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 130 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Column {
            anchors.centerIn: parent
            spacing: 1

            Row {
                spacing: 3; anchors.left: parent.left; anchors.leftMargin: 4
                Text { text: "↓"; font.pixelSize: 8; font.weight: Font.Black; color: Theme.network; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: clockRoot.downCompact
                    color: "white"; font.pixelSize: 9; font.weight: Font.Black
                    font.family: clockRoot.displayFont
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Row {
                spacing: 3; anchors.left: parent.left; anchors.leftMargin: 4
                Text { text: "↑"; font.pixelSize: 8; font.weight: Font.Black; color: Theme.calendar; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: clockRoot.upCompact
                    color: "white"; font.pixelSize: 9; font.weight: Font.Black
                    font.family: clockRoot.displayFont
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // =========================================================================
    // 4. 日期文本与分隔
    // =========================================================================
    Text {
        text: clockRoot.displayDate
        color: Qt.rgba(1, 1, 1, 0.70)
        font.family: clockRoot.effectiveFont
        font.pixelSize: 11
        font.weight: Font.Bold
        font.letterSpacing: 0.2
        visible: (typeof Config !== "undefined" && Config.showDate) && clockRoot.displayDate !== ""
        anchors.verticalCenter: parent.verticalCenter
    }

    Rectangle {
        width: 1; height: 11; radius: 0.5; color: Qt.rgba(1, 1, 1, 0.14)
        anchors.verticalCenter: parent.verticalCenter
        visible: (typeof Config !== "undefined" && Config.showDate) && clockRoot.displayDate !== ""
    }

    // =========================================================================
    // 5. 主时间行 (等宽数字 tnum + 锁死 20px 秒数槽)
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
}