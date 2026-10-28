// ==========================================
// 📄 File: ui/components/compact/CompactClockView.qml
// 🌟 紧凑饱满大字号时钟 (主时间18px · 纯整数字号 · 零虚浮间距版)
// ==========================================
import QtQuick

Item {
    id: clockRoot

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property bool isCapsLock: false
    property string displayDate: ""
    property string displayTime: "00:00"
    property string displaySeconds: ""
    property string displayPeriod: ""

    readonly property bool hasDate: (typeof Config !== "undefined" && Config.showDate !== false) && clockRoot.displayDate !== ""
    readonly property bool hasSec: (typeof Config !== "undefined" && Config.showSeconds !== false) && clockRoot.displaySeconds !== ""
    readonly property bool hasPeriod: (typeof Config !== "undefined" && Config.timeFormat === "12h") && clockRoot.displayPeriod !== ""

    readonly property string cleanSeconds: {
        if (!clockRoot.displaySeconds) return "";
        var s = clockRoot.displaySeconds.replace(/^:/, "").trim();
        return s.length === 1 ? ("0" + s) : s;
    }
    readonly property string secTen: cleanSeconds.length >= 2 ? cleanSeconds.charAt(0) : "0"
    readonly property string secUnit: cleanSeconds.length >= 2 ? cleanSeconds.charAt(1) : (cleanSeconds.charAt(0) || "0")

    height: 24
    implicitHeight: 24
    implicitWidth: Math.round(contentRow.implicitWidth)

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4 // 紧凑咬合，避免松散

        // =====================================================================
        // 1. 日期槽位 (清晰饱满的整型 12px)
        // =====================================================================
        Row {
            visible: clockRoot.hasDate
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: clockRoot.displayDate
                color: Qt.rgba(255, 255, 255, 0.85)
                font.family: clockRoot.effectiveFont
                font.pixelSize: 12 // 🚀 严格纯整数字号
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.QtRendering
            }

            Rectangle {
                width: 2; height: 2; radius: 1
                color: Qt.rgba(255, 255, 255, 0.4)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // 2. CapsLock 指示灯
        Item {
            visible: clockRoot.isCapsLock
            width: 5; height: 16
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.centerIn: parent
                width: 4; height: 4; radius: 2
                color: "#f59e0b"
            }
        }

        // =====================================================================
        // 3. 主时间 (饱满放大至纯整型 18px，高度完全处于24px安全内)
        // =====================================================================
        Text {
            id: mainTime
            anchors.verticalCenter: parent.verticalCenter
            text: clockRoot.displayTime
            color: "#ffffff"
            font.family: clockRoot.displayFont
            font.pixelSize: 18 // 🚀 严格纯整数字号，醒目大字
            font.weight: Font.Black
            font.letterSpacing: 0
            font.features: { "tnum": 1 }
            renderType: Text.QtRendering
        }

        // =====================================================================
        // 4. 次级秒数 (纯整型 11px，紧贴主时间，定宽防抖)
        // =====================================================================
        Row {
            visible: clockRoot.hasSec
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                text: ":"
                color: Qt.rgba(255, 255, 255, 0.45)
                font.family: clockRoot.displayFont
                font.pixelSize: 11 // 🚀 严格整型
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.QtRendering
            }

            Item {
                width: 7; height: 14
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: clockRoot.secTen
                    color: Qt.rgba(255, 255, 255, 0.65)
                    font.family: clockRoot.displayFont
                    font.pixelSize: 11 // 🚀 严格整型
                    font.weight: Font.Bold
                    renderType: Text.QtRendering
                }
            }

            Item {
                width: 7; height: 14
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: clockRoot.secUnit
                    color: Qt.rgba(255, 255, 255, 0.65)
                    font.family: clockRoot.displayFont
                    font.pixelSize: 11 // 🚀 严格整型
                    font.weight: Font.Bold
                    renderType: Text.QtRendering
                }
            }
        }

        // =====================================================================
        // 5. AM/PM 徽标 (整型 10px)
        // =====================================================================
        Text {
            visible: clockRoot.hasPeriod
            anchors.verticalCenter: parent.verticalCenter
            text: clockRoot.displayPeriod
            color: Qt.rgba(255, 255, 255, 0.5)
            font.family: clockRoot.effectiveFont
            font.pixelSize: 10 // 🚀 严格整型
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            renderType: Text.QtRendering
        }
    }
}