// ==========================================
// 📄 File: ui/components/compact/CompactClockView.qml
// 🌟 纯正苹果数字排版 · 同级合法基线吸附无警告版
// ==========================================
import QtQuick

Row {
    id: clockRoot
    spacing: 5
    height: 22
    anchors.verticalCenter: parent.verticalCenter

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property bool isCapsLock: false
    property string displayDate: ""
    property string displayTime: "00:00"
    property string displaySeconds: ""
    property string displayPeriod: ""

    readonly property bool hasDate: (typeof Config !== "undefined" && Config.showDate) && clockRoot.displayDate !== ""
    readonly property bool hasSec: (typeof Config !== "undefined" && Config.showSeconds) && clockRoot.displaySeconds !== ""
    readonly property bool hasPeriod: (typeof Config !== "undefined" && Config.timeFormat === "12h") && clockRoot.displayPeriod !== ""

    readonly property int allocatedWidth: {
        var base = 52;
        if (clockRoot.hasDate) base += 76;
        if (clockRoot.hasSec) base += 24;
        if (clockRoot.hasPeriod) base += 18;
        if (clockRoot.isCapsLock) base += 10;
        return base;
    }

    // 1. 公历日期 (低饱和灰阶)
    Row {
        id: dateBox
        visible: clockRoot.hasDate
        spacing: 5
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: clockRoot.displayDate
            color: Qt.rgba(255, 255, 255, 0.50)
            font.family: clockRoot.effectiveFont
            font.pixelSize: 11
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            width: 2.5; height: 2.5; radius: 1.25
            color: Qt.rgba(255, 255, 255, 0.20)
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // 2. CapsLock 琥珀微晶点
    Item {
        id: capsBox
        visible: clockRoot.isCapsLock
        width: 6
        height: 14
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.centerIn: parent
            width: 4.5; height: 4.5; radius: 2.25
            color: "#f59e0b"
            antialiasing: true
        }
    }

    // 3. 核心时间 (直接作为同级节点，方便兄弟元素合法基线对齐)
    Text {
        id: timeText
        anchors.verticalCenter: parent.verticalCenter
        text: clockRoot.displayTime
        color: "#ffffff"
        font.family: clockRoot.displayFont
        font.pixelSize: 15
        font.weight: Font.Bold
        font.letterSpacing: 0.4
        font.features: { "tnum": 1 }
        renderType: Text.QtRendering
    }

    // 4. 秒数指示 (同级兄弟节点，合法 baseline 吸附)
    Text {
        id: secText
        visible: clockRoot.hasSec
        text: ":" + clockRoot.displaySeconds.replace(/^:/, "")
        color: Qt.rgba(255, 255, 255, 0.45)
        font.family: clockRoot.displayFont
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        anchors.baseline: timeText.baseline
        renderType: Text.QtRendering
    }

    // 5. 12小时制 AM/PM 微标 (同级兄弟节点，合法 baseline 吸附)
    Text {
        id: periodBox
        visible: clockRoot.hasPeriod
        text: clockRoot.displayPeriod
        color: Qt.rgba(255, 255, 255, 0.35)
        font.family: clockRoot.effectiveFont
        font.pixelSize: 8
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        anchors.baseline: timeText.baseline
        renderType: Text.QtRendering
    }
}