// ==========================================
// 📄 File: ui/components/compact/CompactClockView.qml
// 🌟 纯正苹果数字排版 · 44px 舒适可读性升级版 (实用占大头 + 零抖动)
// ==========================================
import QtQuick

Row {
    id: clockRoot
    spacing: 7
    height: 26
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

    // =========================================================================
    // 1. 纯真非等宽字模度量引擎 (任意字体自适应 12px 秒数槽位)
    // =========================================================================
    property int maxDigitWidth: 8
    property int colonWidth: 4

    TextMetrics {
        id: secMeasurer
        font.family: clockRoot.displayFont
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    function updateSecMetrics() {
        var maxW = 0;
        for (var i = 0; i <= 9; i++) {
            secMeasurer.text = "" + i;
            if (secMeasurer.width > maxW) {
                maxW = secMeasurer.width;
            }
        }
        secMeasurer.text = ":";
        colonWidth = Math.max(3, Math.ceil(secMeasurer.width));
        maxDigitWidth = Math.max(7, Math.ceil(maxW));
    }

    onDisplayFontChanged: updateSecMetrics()
    Component.onCompleted: updateSecMetrics()

    readonly property string cleanSeconds: {
        if (!clockRoot.displaySeconds) return "00";
        var s = clockRoot.displaySeconds.replace(/^:/, "").trim();
        if (s.length === 0) return "00";
        if (s.length === 1) return "0" + s;
        return s.slice(-2);
    }
    readonly property string secTen: cleanSeconds.charAt(0)
    readonly property string secUnit: cleanSeconds.charAt(1)

    // 适配放大后的物理占宽
    readonly property int allocatedWidth: {
        var base = 62;
        if (clockRoot.hasDate) base += 86;
        if (clockRoot.hasSec) base += (clockRoot.colonWidth + clockRoot.maxDigitWidth * 2 + clockRoot.spacing);
        if (clockRoot.hasPeriod) base += 22;
        if (clockRoot.isCapsLock) base += 12;
        return base;
    }

    // =========================================================================
    // 2. 公历日期 (放大至 12.5px，增强实用性)
    // =========================================================================
    Row {
        id: dateBox
        visible: clockRoot.hasDate
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: clockRoot.displayDate
            color: Qt.rgba(255, 255, 255, 0.65)
            font.family: clockRoot.effectiveFont
            font.pixelSize: 13
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            width: 3; height: 3; radius: 1.5
            color: Qt.rgba(255, 255, 255, 0.25)
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // =========================================================================
    // 3. CapsLock 琥珀微晶点
    // =========================================================================
    Item {
        id: capsBox
        visible: clockRoot.isCapsLock
        width: 8
        height: 16
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.centerIn: parent
            width: 5; height: 5; radius: 2.5
            color: "#f59e0b"
            antialiasing: true
        }
    }

    // =========================================================================
    // 4. 核心时间 (放大至 18px，突出第一视觉焦点)
    // =========================================================================
    Text {
        id: timeText
        anchors.verticalCenter: parent.verticalCenter
        text: clockRoot.displayTime
        color: "#ffffff"
        font.family: clockRoot.displayFont
        font.pixelSize: 18
        font.weight: Font.Bold
        font.letterSpacing: 0.5
        renderType: Text.QtRendering
    }

    // =========================================================================
    // 5. 秒数机械槽位 (升级至 12px，槽位自适应定死，零抖动)
    // =========================================================================
    Row {
        id: secContainer
        visible: clockRoot.hasSec
        spacing: 0
        anchors.baseline: timeText.baseline
        baselineOffset: dummySecText.baselineOffset > 0 ? dummySecText.baselineOffset : 10

        Text {
            id: dummySecText
            visible: false
            text: "0"
            font.family: clockRoot.displayFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            renderType: Text.QtRendering
        }

        Text {
            width: clockRoot.colonWidth
            height: dummySecText.height
            horizontalAlignment: Text.AlignHCenter
            text: ":"
            color: Qt.rgba(255, 255, 255, 0.45)
            font: dummySecText.font
            renderType: Text.QtRendering
        }

        Text {
            width: clockRoot.maxDigitWidth
            height: dummySecText.height
            horizontalAlignment: Text.AlignHCenter
            text: clockRoot.secTen
            color: Qt.rgba(255, 255, 255, 0.45)
            font: dummySecText.font
            renderType: Text.QtRendering
        }

        Text {
            width: clockRoot.maxDigitWidth
            height: dummySecText.height
            horizontalAlignment: Text.AlignHCenter
            text: clockRoot.secUnit
            color: Qt.rgba(255, 255, 255, 0.45)
            font: dummySecText.font
            renderType: Text.QtRendering
        }
    }

    // =========================================================================
    // 6. 12小时制 AM/PM 微标
    // =========================================================================
    Text {
        id: periodBox
        visible: clockRoot.hasPeriod
        text: clockRoot.displayPeriod
        color: Qt.rgba(255, 255, 255, 0.40)
        font.family: clockRoot.effectiveFont
        font.pixelSize: 9
        font.weight: Font.Bold
        font.capitalization: Font.AllUppercase
        anchors.baseline: timeText.baseline
        renderType: Text.QtRendering
    }
}