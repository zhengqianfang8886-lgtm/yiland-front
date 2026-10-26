// ==========================================
// 📄 File: ui/components/compact/CompactClockView.qml
// 🌟 实用大字号高饱满度时钟 (17px醒目时间 · 紧凑机械次级秒数 · 零虚浮空间)
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
        spacing: 5

        // =====================================================================
        // 1. 日期槽位 (放大到 12.5px，清晰饱满)
        // =====================================================================
        Row {
            visible: clockRoot.hasDate
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: clockRoot.displayDate
                color: Qt.rgba(255, 255, 255, 0.78)
                font.family: clockRoot.effectiveFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.QtRendering
            }

            Rectangle {
                width: 2.5; height: 2.5; radius: 1.25
                color: Qt.rgba(255, 255, 255, 0.35)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // 2. CapsLock 指示灯
        Item {
            visible: clockRoot.isCapsLock
            width: 6; height: 16
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.centerIn: parent
                width: 4; height: 4; radius: 2
                color: "#f59e0b"
            }
        }

        // =====================================================================
        // 3. 主时间 (放大到 17px，醒目实用，一眼即知)
        // =====================================================================
        Text {
            id: mainTime
            anchors.verticalCenter: parent.verticalCenter
            text: clockRoot.displayTime
            color: "#ffffff"
            font.family: clockRoot.displayFont
            font.pixelSize: 17
            font.weight: Font.Black
            font.letterSpacing: 0.2
            font.features: { "tnum": 1 }
            renderType: Text.QtRendering
        }

        // =====================================================================
        // 4. 次级秒数：字号稍小(10.5px)，但紧紧贴在主时间旁边，间距极度紧凑
        // =====================================================================
        Row {
            visible: clockRoot.hasSec
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 0.5
            spacing: 0

            // 微型冒号
            Text {
                text: ":"
                color: Qt.rgba(255, 255, 255, 0.40)
                font.family: clockRoot.displayFont
                font.pixelSize: 11
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
                renderType: Text.QtRendering
            }

            // 十位槽 (定宽 6.5px)
            Item {
                width: 7; height: 14
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: clockRoot.secTen
                    color: Qt.rgba(255, 255, 255, 0.55)
                    font.family: clockRoot.displayFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    renderType: Text.QtRendering
                }
            }

            // 个位槽 (定宽 6.5px)
            Item {
                width: 7; height: 14
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: clockRoot.secUnit
                    color: Qt.rgba(255, 255, 255, 0.55)
                    font.family: clockRoot.displayFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    renderType: Text.QtRendering
                }
            }
        }

        // 5. AM/PM 微标
        Text {
            visible: clockRoot.hasPeriod
            anchors.verticalCenter: parent.verticalCenter
            text: clockRoot.displayPeriod
            color: Qt.rgba(255, 255, 255, 0.45)
            font.family: clockRoot.effectiveFont
            font.pixelSize: 9
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            renderType: Text.QtRendering
        }
    }
}