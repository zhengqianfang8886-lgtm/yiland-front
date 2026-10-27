// =========================================================================
// 📄 File: ui/components/compact/CompactTimerView.qml
// 🌟 极简灵动岛大号计时器 (纯净大字 · 超时正向带加号 · 零抖动等宽版)
// =========================================================================
import QtQuick

Item {
    id: timerViewRoot

    property string fontFam: "Monospace"
    property int pixelSize: 15
    property color textColor: "#FF9F0A"
    property int totalSeconds: 0
    property bool isPaused: false
    property bool isOvertime: false  // 🚀 是否处于超时模式

    // 时分秒分解
    readonly property int h: Math.floor(totalSeconds / 3600)
    readonly property int m: Math.floor((totalSeconds % 3600) / 60)
    readonly property int s: totalSeconds % 60
    readonly property bool hasHours: h > 0

    readonly property string hStr: (h < 10 ? "0" : "") + h
    readonly property string minStr: (m < 10 ? "0" : "") + m
    readonly property string secStr: (s < 10 ? "0" : "") + s

    readonly property string hTen: hStr.charAt(0)
    readonly property string hUnit: hStr.charAt(1)
    readonly property string mTen: minStr.charAt(0)
    readonly property string mUnit: minStr.charAt(1)
    readonly property string sTen: secStr.charAt(0)
    readonly property string sUnit: secStr.charAt(1)

    // 精密测模
    property int singleDigitWidth: 9
    property int colonWidth: 4
    property int plusWidth: 9

    TextMetrics {
        id: metricProbe
        font.family: timerViewRoot.fontFam
        font.pixelSize: timerViewRoot.pixelSize
        font.weight: Font.Black
    }

    function recomputeMetrics() {
        var maxW = 0;
        for (var i = 0; i <= 9; i++) {
            metricProbe.text = "" + i;
            if (metricProbe.width > maxW) maxW = metricProbe.width;
        }
        metricProbe.text = ":";
        colonWidth = Math.max(4, Math.ceil(metricProbe.width));
        metricProbe.text = "+";
        plusWidth = Math.max(8, Math.ceil(metricProbe.width));
        singleDigitWidth = Math.max(9, Math.ceil(maxW));
    }

    onFontFamChanged: recomputeMetrics()
    onPixelSizeChanged: recomputeMetrics()
    Component.onCompleted: recomputeMetrics()

    implicitHeight: 26
    implicitWidth: digitsRow.implicitWidth

    Row {
        id: digitsRow
        anchors.centerIn: parent
        spacing: 0
        opacity: timerViewRoot.isPaused ? 0.65 : 1.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        // 🚀【超时加号标识】：大方利落的 "+" 提示超时正向流逝
        Item {
            visible: timerViewRoot.isOvertime
            width: timerViewRoot.plusWidth + 1
            height: timerViewRoot.implicitHeight
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -0.5
                text: "+"
                color: timerViewRoot.textColor
                font.family: timerViewRoot.fontFam
                font.pixelSize: timerViewRoot.pixelSize
                font.weight: Font.Black
                renderType: Text.QtRendering
            }
        }

        // --- 小时槽位 ---
        Row {
            visible: timerViewRoot.hasHours
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter

            Item {
                width: timerViewRoot.singleDigitWidth; height: timerViewRoot.implicitHeight
                Text {
                    anchors.centerIn: parent
                    text: timerViewRoot.hTen
                    color: timerViewRoot.textColor
                    font.family: timerViewRoot.fontFam
                    font.pixelSize: timerViewRoot.pixelSize
                    font.weight: Font.Black
                    renderType: Text.QtRendering
                }
            }
            Item {
                width: timerViewRoot.singleDigitWidth; height: timerViewRoot.implicitHeight
                Text {
                    anchors.centerIn: parent
                    text: timerViewRoot.hUnit
                    color: timerViewRoot.textColor
                    font.family: timerViewRoot.fontFam
                    font.pixelSize: timerViewRoot.pixelSize
                    font.weight: Font.Black
                    renderType: Text.QtRendering
                }
            }
            Item {
                width: timerViewRoot.colonWidth + 2; height: timerViewRoot.implicitHeight
                Text {
                    anchors.centerIn: parent; anchors.verticalCenterOffset: -0.5
                    text: ":"
                    color: Qt.rgba(timerViewRoot.textColor.r, timerViewRoot.textColor.g, timerViewRoot.textColor.b, 0.65)
                    font.family: timerViewRoot.fontFam
                    font.pixelSize: timerViewRoot.pixelSize
                    font.weight: Font.Bold
                    renderType: Text.QtRendering
                }
            }
        }

        // --- 分钟 - 十位 ---
        Item {
            width: timerViewRoot.singleDigitWidth
            height: timerViewRoot.implicitHeight
            Text {
                anchors.centerIn: parent
                text: timerViewRoot.mTen
                color: timerViewRoot.textColor
                font.family: timerViewRoot.fontFam
                font.pixelSize: timerViewRoot.pixelSize
                font.weight: Font.Black
                renderType: Text.QtRendering
            }
        }

        // --- 分钟 - 个位 ---
        Item {
            width: timerViewRoot.singleDigitWidth
            height: timerViewRoot.implicitHeight
            Text {
                anchors.centerIn: parent
                text: timerViewRoot.mUnit
                color: timerViewRoot.textColor
                font.family: timerViewRoot.fontFam
                font.pixelSize: timerViewRoot.pixelSize
                font.weight: Font.Black
                renderType: Text.QtRendering
            }
        }

        // --- 冒号 ---
        Item {
            width: timerViewRoot.colonWidth + 2
            height: timerViewRoot.implicitHeight
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -0.5
                text: ":"
                color: Qt.rgba(timerViewRoot.textColor.r, timerViewRoot.textColor.g, timerViewRoot.textColor.b, 0.65)
                font.family: timerViewRoot.fontFam
                font.pixelSize: timerViewRoot.pixelSize
                font.weight: Font.Bold
                renderType: Text.QtRendering
            }
        }

        // --- 秒钟 - 十位 ---
        Item {
            width: timerViewRoot.singleDigitWidth
            height: timerViewRoot.implicitHeight
            Text {
                anchors.centerIn: parent
                text: timerViewRoot.sTen
                color: timerViewRoot.textColor
                font.family: timerViewRoot.fontFam
                font.pixelSize: timerViewRoot.pixelSize
                font.weight: Font.Black
                renderType: Text.QtRendering
            }
        }

        // --- 秒钟 - 个位 ---
        Item {
            width: timerViewRoot.singleDigitWidth
            height: timerViewRoot.implicitHeight
            Text {
                anchors.centerIn: parent
                text: timerViewRoot.sUnit
                color: timerViewRoot.textColor
                font.family: timerViewRoot.fontFam
                font.pixelSize: timerViewRoot.pixelSize
                font.weight: Font.Black
                renderType: Text.QtRendering
            }
        }
    }
}