// ==========================================
// 📄 File: compact/CompactClockView.qml
// 🌟 剥离内层动画 · 彻底消灭高频震颤版
// ==========================================
import QtQuick

Row {
    id: clockRoot
    spacing: 7
    leftPadding: 8
    rightPadding: 8
    anchors.verticalCenter: parent.verticalCenter

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

    // 🚀 保持测量活性，仅做纯粹的透明度淡入淡出，严禁销毁布局导致测算跳水
    opacity: clockRoot.isClockActive ? 1.0 : 0.0
    scale: 1.0

    Behavior on opacity { NumberAnimation { duration: clockRoot.isClockActive ? 140 : 80; easing.type: Easing.OutQuad } }

    // 极限测算假体 (不可见)
    Text {
        id: timeMetricDummy
        text: "88:88"
        font.family: clockRoot.displayFont
        font.pixelSize: 17
        font.weight: Font.Black
        font.letterSpacing: 0.3
        visible: false
    }

    Text {
        id: secMetricDummy
        text: ":88"
        font.family: clockRoot.displayFont
        font.pixelSize: 11
        font.weight: Font.Bold
        visible: false
    }

    Text {
        id: periodMetricDummy
        text: "PM"
        font.family: clockRoot.effectiveFont
        font.pixelSize: 8
        font.weight: Font.Black
        font.capitalization: Font.AllUppercase
        visible: false
    }

    // 1. CAPS LOCK (一步到位，严禁逐帧变宽)
    Rectangle {
        id: capsLockBadge
        height: 18
        radius: 9
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        visible: width > 0
        width: clockRoot.isCapsLock ? 42 : 0
        opacity: clockRoot.isCapsLock ? 1.0 : 0.0

        color: Qt.rgba(1, 1, 1, 0.09)
        border.color: Qt.rgba(255, 255, 255, 0.16)
        border.width: 0.8

        Row {
            anchors.centerIn: parent
            spacing: 2.5

            Text {
                text: "⇪"
                color: "#38bdf8"
                font.pixelSize: 10
                font.weight: Font.Black
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "CAPS"
                color: Qt.rgba(1, 1, 1, 0.9)
                font.pixelSize: 8
                font.weight: Font.Black
                font.letterSpacing: 0.6
                font.family: clockRoot.displayFont
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // 2. NUM LOCK (一步到位，严禁逐帧变宽)
    Rectangle {
        id: numLockBadge
        height: 18
        radius: 9
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        visible: width > 0
        width: clockRoot.isNumLock ? 40 : 0
        opacity: clockRoot.isNumLock ? 1.0 : 0.0

        color: Qt.rgba(1, 1, 1, 0.09)
        border.color: Qt.rgba(255, 255, 255, 0.16)
        border.width: 0.8

        Row {
            anchors.centerIn: parent
            spacing: 3

            Rectangle {
                width: 4
                height: 4
                radius: 2
                color: "#34d399"
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: 7; height: 7; radius: 3.5
                    color: Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.28)
                }
            }

            Text {
                text: "NUM"
                color: Qt.rgba(1, 1, 1, 0.92)
                font.pixelSize: 8
                font.weight: Font.Black
                font.letterSpacing: 0.6
                font.family: clockRoot.displayFont
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // 3. 实时网速 (死锁 46px，严禁逐帧变宽)
    Rectangle {
        id: netSpeedItem
        height: 18
        radius: 4
        anchors.verticalCenter: parent.verticalCenter
        color: "transparent"
        clip: true

        visible: width > 0
        width: clockRoot.showNetSpeed ? 46 : 0
        opacity: clockRoot.showNetSpeed ? 1.0 : 0.0

        Column {
            anchors.centerIn: parent
            spacing: 0.5

            Row {
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    text: "↓"
                    font.pixelSize: 8
                    font.weight: Font.Black
                    color: Qt.rgba(1, 1, 1, 0.45)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: clockRoot.downCompact
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    font.family: clockRoot.displayFont
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Row {
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    text: "↑"
                    font.pixelSize: 8
                    font.weight: Font.Black
                    color: Qt.rgba(1, 1, 1, 0.45)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: clockRoot.upCompact
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    font.family: clockRoot.displayFont
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // 4. 纯净自然悬浮日期 (一步到位，严禁逐帧变宽)
    Item {
        id: dateItem
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter

        readonly property bool shouldShow: (typeof Config !== "undefined" && Config.showDate) && clockRoot.displayDate !== ""
        visible: width > 0
        width: shouldShow ? Math.ceil(dateText.implicitWidth + 3) : 0
        opacity: shouldShow ? 1.0 : 0.0

        Text {
            id: dateText
            anchors.centerIn: parent
            text: clockRoot.displayDate
            color: Qt.rgba(1, 1, 1, 0.65)
            font.family: clockRoot.effectiveFont
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.2
            renderType: Text.QtRendering
        }
    }

    // 5. 视网膜微圆点
    Rectangle {
        id: dateDot
        width: 3
        height: 3
        radius: 1.5
        color: Qt.rgba(1, 1, 1, 0.22)
        anchors.verticalCenter: parent.verticalCenter
        visible: dateItem.visible && (typeof Config !== "undefined" && Config.showDate) && clockRoot.displayDate !== ""
        opacity: dateItem.opacity
    }

    // 6. 核心时间行
    Row {
        id: timeRow
        spacing: 2
        anchors.verticalCenter: parent.verticalCenter

        Item {
            id: mainTimeSlot
            width: Math.ceil(timeMetricDummy.implicitWidth)
            height: 20
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: mainTimeText
                anchors.centerIn: parent
                text: clockRoot.displayTime
                color: "#ffffff"
                font.family: clockRoot.displayFont
                font.pixelSize: 17
                font.weight: Font.Black
                font.letterSpacing: 0.3
                font.features: { "tnum": 1 }
                renderType: Text.QtRendering
            }
        }

        Item {
            id: secSlot
            visible: (typeof Config !== "undefined" && Config.showSeconds) && clockRoot.displaySeconds !== ""
            width: visible ? Math.ceil(secMetricDummy.implicitWidth + 2) : 0
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            Row {
                id: secRow
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
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
                    color: Qt.rgba(1, 1, 1, 0.52)
                    font.family: clockRoot.displayFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item {
            id: periodSlot
            visible: (typeof Config !== "undefined" && Config.timeFormat === "12h") && clockRoot.displayPeriod !== ""
            width: visible ? Math.ceil(periodMetricDummy.implicitWidth + 2) : 0
            height: 20
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: periodText
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                text: clockRoot.displayPeriod
                color: Qt.rgba(1, 1, 1, 0.40)
                font.family: clockRoot.effectiveFont
                font.pixelSize: 8
                font.weight: Font.Black
                font.capitalization: Font.AllUppercase
            }
        }
    }
}