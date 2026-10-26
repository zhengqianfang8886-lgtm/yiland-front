// =========================================================================
// 📄 File: ui/components/compact/CompactTimerView.qml
// 🌟 纯正苹果级机械槽位计时器 (等宽定死 · 零抖动 · 极致紧凑版)
// =========================================================================
import QtQuick

Item {
    id: timerViewRoot

    property string fontFam: "Monospace"
    property int pixelSize: 11
    property color textColor: "#fdba74"
    property int totalSeconds: 0

    // 计算分秒拆解
    readonly property int m: Math.floor(totalSeconds / 60)
    readonly property int s: totalSeconds % 60

    readonly property string minStr: (m < 10 ? "0" : "") + m
    readonly property string secStr: (s < 10 ? "0" : "") + s

    readonly property string mTen: minStr.charAt(0)
    readonly property string mUnit: minStr.charAt(1)
    readonly property string sTen: secStr.charAt(0)
    readonly property string sUnit: secStr.charAt(1)

    // =========================================================================
    // 🚀【核心测模引擎】：计算 0-9 中最宽的物理字模，槽位定死，杜绝 1 和 8 宽度差
    // =========================================================================
    property int singleDigitWidth: 7
    property int colonWidth: 4

    TextMetrics {
        id: metricProbe
        font.family: timerViewRoot.fontFam
        font.pixelSize: timerViewRoot.pixelSize
        font.weight: Font.Bold
    }

    function recomputeMetrics() {
        var maxW = 0;
        for (var i = 0; i <= 9; i++) {
            metricProbe.text = "" + i;
            if (metricProbe.width > maxW) {
                maxW = metricProbe.width;
            }
        }
        metricProbe.text = ":";
        colonWidth = Math.max(3, Math.ceil(metricProbe.width));
        // 单个数字槽位严格定死，留出 0.5px 精密呼吸边缘
        singleDigitWidth = Math.max(6, Math.ceil(maxW));
    }

    onFontFamChanged: recomputeMetrics()
    onPixelSizeChanged: recomputeMetrics()
    Component.onCompleted: recomputeMetrics()

    // 整个计时器控件的自然内容宽度：4个数字槽 + 1个冒号槽 + 微间距
    implicitWidth: singleDigitWidth * 4 + colonWidth + 2
    implicitHeight: 24

    Row {
        anchors.centerIn: parent
        spacing: 0  // 🚀 极致紧凑，字与字之间零多余间隙

        // 分 - 十位
        Item {
            width: timerViewRoot.singleDigitWidth
            height: timerViewRoot.implicitHeight

            Text {
                anchors.centerIn: parent
                text: timerViewRoot.mTen
                color: timerViewRoot.textColor
                font.family: timerViewRoot.fontFam
                font.pixelSize: timerViewRoot.pixelSize
                font.weight: Font.Bold
                renderType: Text.QtRendering
            }
        }

        // 分 - 个位
        Item {
            width: timerViewRoot.singleDigitWidth
            height: timerViewRoot.implicitHeight

            Text {
                anchors.centerIn: parent
                text: timerViewRoot.mUnit
                color: timerViewRoot.textColor
                font.family: timerViewRoot.fontFam
                font.pixelSize: timerViewRoot.pixelSize
                font.weight: Font.Bold
                renderType: Text.QtRendering
            }
        }

        // 冒号槽位 (紧凑内缩)
        Item {
            width: timerViewRoot.colonWidth + 2
            height: timerViewRoot.implicitHeight

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -0.5
                text: ":"
                color: Qt.rgba(timerViewRoot.textColor.r, timerViewRoot.textColor.g, timerViewRoot.textColor.b, 0.75)
                font.family: timerViewRoot.fontFam
                font.pixelSize: timerViewRoot.pixelSize
                font.weight: Font.Bold
                renderType: Text.QtRendering
            }
        }

        // 秒 - 十位
        Item {
            width: timerViewRoot.singleDigitWidth
            height: timerViewRoot.implicitHeight

            Text {
                anchors.centerIn: parent
                text: timerViewRoot.sTen
                color: timerViewRoot.textColor
                font.family: timerViewRoot.fontFam
                font.pixelSize: timerViewRoot.pixelSize
                font.weight: Font.Bold
                renderType: Text.QtRendering
            }
        }

        // 秒 - 个位
        Item {
            width: timerViewRoot.singleDigitWidth
            height: timerViewRoot.implicitHeight

            Text {
                anchors.centerIn: parent
                text: timerViewRoot.sUnit
                color: timerViewRoot.textColor
                font.family: timerViewRoot.fontFam
                font.pixelSize: timerViewRoot.pixelSize
                font.weight: Font.Bold
                renderType: Text.QtRendering
            }
        }
    }
}