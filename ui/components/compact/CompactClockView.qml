// =========================================================================
// 📄 File: ui/components/compact/CompactClockView.qml
// 🌟 纯正苹果级舒适时钟 (黄金律动间距 · 光学字距微调 · 呼吸感排版)
// =========================================================================
import QtQuick

Item {
    id: clockRoot

    // =========================================================================
    // 1. 黄金视觉律动参数 (已精确标定在舒适平衡区间)
    // =========================================================================
    readonly property int mainPixelSize: 18         // 主时间字号
    readonly property int secPixelSize: 11          // 秒数字号

    // 🚀【舒适间距中枢调谐】
    property int digitSlotWidth: 11                 // 数字槽宽 (11px 为标准舒适字宽)
    property int digitSpacing: 1                    // 两位数内部字距 (1px 自然呼吸感，绝不撞字)
    property int colonSlotWidth: 5                  // 冒号槽宽 (舒适包容冒号，不松不挤)
    property int colonSpacing: 2                    // 冒号前后间距 (时、冒号、分之间舒适隔开 3.5px 墨水距离)
    property real colonOpticalOffset: -0.8          // 冒号垂直光学微移 (修正字体重心)
    
    property int secLeadingGap: 4                   // 主时间与秒数之间的层级过渡间距 (清晰分层且不脱节)
    property int secSlotWidth: 7                    // 秒数数字槽宽
    property int secColonWidth: 4                   // 秒数冒号槽宽
    property int secDigitSpacing: 1                 // 秒数两位数内部字距

    // =========================================================================
    // 2. 外部状态与字体绑定
    // =========================================================================
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

    // =========================================================================
    // 3. 时间字符拆解
    // =========================================================================
    readonly property var parsedTime: {
        var raw = (clockRoot.displayTime || "00:00").trim();
        var colonIdx = raw.indexOf(":");
        var h = (colonIdx !== -1) ? raw.substring(0, colonIdx) : raw;
        var m = (colonIdx !== -1) ? raw.substring(colonIdx + 1) : "00";

        var h1 = h.length >= 2 ? h.charAt(0) : "";
        var h2 = h.length >= 2 ? h.charAt(1) : (h.length === 1 ? h.charAt(0) : "0");
        var m1 = m.length >= 2 ? m.charAt(0) : "0";
        var m2 = m.length >= 2 ? m.charAt(1) : (m.length === 1 ? m.charAt(0) : "0");

        return {
            hasTenHour: (h1 !== ""),
            hTen: h1,
            hUnit: h2,
            mTen: m1,
            mUnit: m2
        };
    }

    readonly property string cleanSeconds: {
        if (!clockRoot.displaySeconds) return "";
        var s = clockRoot.displaySeconds.replace(/^:/, "").trim();
        return s.length === 1 ? ("0" + s) : s;
    }
    readonly property string secTen: cleanSeconds.length >= 2 ? cleanSeconds.charAt(0) : "0"
    readonly property string secUnit: cleanSeconds.length >= 2 ? cleanSeconds.charAt(1) : (cleanSeconds.charAt(0) || "0")

    // =========================================================================
    // 4. 几何排版骨架
    // =========================================================================
    height: 24
    implicitHeight: 24
    implicitWidth: Math.round(contentRow.implicitWidth)

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        // --- A. 日期槽位 ---
        Row {
            visible: clockRoot.hasDate
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: clockRoot.displayDate
                color: Qt.rgba(255, 255, 255, 0.85)
                font.family: clockRoot.effectiveFont
                font.pixelSize: 12
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

        // --- B. CapsLock 状态指示灯 ---
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

        // --- C. 主时间组 + 次级秒数组 (舒适分层) ---
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: clockRoot.secLeadingGap // 🚀 主时间与秒数之间 4px 舒适过渡

            // 1. 主时间容器 (时 : 分)
            Row {
                id: mainTimeGroup
                anchors.verticalCenter: parent.verticalCenter
                spacing: clockRoot.colonSpacing // 🚀 冒号与两边数字各留出 2px + 槽宽余量

                // [小时组]
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: clockRoot.digitSpacing

                    // 小时 - 十位 (数字 1 仅做 1px 光学校准微移，不再死贴边)
                    Item {
                        visible: clockRoot.parsedTime.hasTenHour
                        width: clockRoot.digitSlotWidth
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: (clockRoot.parsedTime.hTen === "1") ? 1.0 : 0.0
                            text: clockRoot.parsedTime.hTen
                            color: "#ffffff"
                            font.family: clockRoot.displayFont
                            font.pixelSize: clockRoot.mainPixelSize
                            font.weight: Font.Black
                            renderType: Text.QtRendering
                        }
                    }

                    // 小时 - 个位
                    Item {
                        width: clockRoot.digitSlotWidth
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: clockRoot.parsedTime.hUnit
                            color: "#ffffff"
                            font.family: clockRoot.displayFont
                            font.pixelSize: clockRoot.mainPixelSize
                            font.weight: Font.Black
                            renderType: Text.QtRendering
                        }
                    }
                }

                // [主冒号] (5px 适度定宽 + 舒适光学居中)
                Item {
                    width: clockRoot.colonSlotWidth
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: clockRoot.colonOpticalOffset
                        text: ":"
                        color: Qt.rgba(255, 255, 255, 0.70)
                        font.family: clockRoot.displayFont
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        renderType: Text.QtRendering
                    }
                }

                // [分钟组]
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: clockRoot.digitSpacing

                    // 分钟 - 十位
                    Item {
                        width: clockRoot.digitSlotWidth
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: clockRoot.parsedTime.mTen
                            color: "#ffffff"
                            font.family: clockRoot.displayFont
                            font.pixelSize: clockRoot.mainPixelSize
                            font.weight: Font.Black
                            renderType: Text.QtRendering
                        }
                    }

                    // 分钟 - 个位 (数字 1 仅做 -1px 微调)
                    Item {
                        width: clockRoot.digitSlotWidth
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: (clockRoot.parsedTime.mUnit === "1") ? -1.0 : 0.0
                            text: clockRoot.parsedTime.mUnit
                            color: "#ffffff"
                            font.family: clockRoot.displayFont
                            font.pixelSize: clockRoot.mainPixelSize
                            font.weight: Font.Black
                            renderType: Text.QtRendering
                        }
                    }
                }
            }

            // 2. 次级秒数组 (紧凑自然依附)
            Row {
                visible: clockRoot.hasSec
                anchors.verticalCenter: parent.verticalCenter
                spacing: clockRoot.secDigitSpacing

                // 秒数小冒号
                Item {
                    width: clockRoot.secColonWidth
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -0.5
                        text: ":"
                        color: Qt.rgba(255, 255, 255, 0.45)
                        font.family: clockRoot.displayFont
                        font.pixelSize: clockRoot.secPixelSize
                        font.weight: Font.Bold
                        renderType: Text.QtRendering
                    }
                }

                // 秒数 - 十位
                Item {
                    width: clockRoot.secSlotWidth
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: clockRoot.secTen
                        color: Qt.rgba(255, 255, 255, 0.65)
                        font.family: clockRoot.displayFont
                        font.pixelSize: clockRoot.secPixelSize
                        font.weight: Font.Bold
                        renderType: Text.QtRendering
                    }
                }

                // 秒数 - 个位
                Item {
                    width: clockRoot.secSlotWidth
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: clockRoot.secUnit
                        color: Qt.rgba(255, 255, 255, 0.65)
                        font.family: clockRoot.displayFont
                        font.pixelSize: clockRoot.secPixelSize
                        font.weight: Font.Bold
                        renderType: Text.QtRendering
                    }
                }
            }
        }

        // --- D. 12小时制 AM / PM 徽标 ---
        Text {
            visible: clockRoot.hasPeriod
            anchors.verticalCenter: parent.verticalCenter
            text: clockRoot.displayPeriod
            color: Qt.rgba(255, 255, 255, 0.5)
            font.family: clockRoot.effectiveFont
            font.pixelSize: 10
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            renderType: Text.QtRendering
        }
    }
}