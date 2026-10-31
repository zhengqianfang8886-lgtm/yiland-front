// =========================================================================
// 📄 File: ui/components/compact/CompactTimerView.qml
// 🌟 纯正刚体定宽时钟 (每个字符独立定宽槽位 · 绝对零抖动 · 对齐CPU版)
// =========================================================================
import QtQuick

Item {
    id: timerViewRoot
    anchors.fill: parent

    property string fontFam: "Monospace"
    property int pixelSize: 11 // 默认 11px 对齐 CPU
    property color textColor: "#FF9F0A"
    property int totalSeconds: 0
    property bool isPaused: false
    property bool isOvertime: false

    // =========================================================================
    // 1. 时分秒数据严格拆解
    // =========================================================================
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

    // =========================================================================
    // 2. 🚀【核心：每个字符物理定宽测模】(动态探测 0~9 最大宽度，强制锁死槽位)
    // =========================================================================
    property int singleDigitWidth: 7
    property int colonWidth: 4
    property int plusWidth: 7

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
            if (metricProbe.width > maxW) maxW = metricProbe.width;
        }
        metricProbe.text = ":";
        colonWidth = Math.max(3, Math.ceil(metricProbe.width));
        metricProbe.text = "+";
        plusWidth = Math.max(6, Math.ceil(metricProbe.width));
        singleDigitWidth = Math.max(7, Math.ceil(maxW)); // 找到0~9中最宽的一个作为所有数字槽位统一基准
    }

    onFontFamChanged: recomputeMetrics()
    onPixelSizeChanged: recomputeMetrics()
    Component.onCompleted: recomputeMetrics()

    Row {
        anchors.centerIn: parent
        spacing: 5 // 🚀 与 CPU 保持 5px 间距

        // =====================================================================
        // A. 左侧 12×12 微表盘 (与 CPU 芯片框同等线宽 1.5px)
        // =====================================================================
        Item {
            width: 12
            height: 12
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: timerViewRoot.textColor
                border.width: 1.5
                radius: 6
                Behavior on border.color { ColorAnimation { duration: 150 } }

                // 表冠凸起
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: -2
                    width: 3; height: 1.5; radius: 0.5
                    color: timerViewRoot.textColor
                }

                // 中心核心点 (超时模式下同频呼吸)
                Rectangle {
                    anchors.centerIn: parent
                    width: 3.5
                    height: 3.5
                    radius: 1.75
                    color: timerViewRoot.textColor
                    Behavior on color { ColorAnimation { duration: 150 } }

                    SequentialAnimation on opacity {
                        running: timerViewRoot.isOvertime
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.15; duration: 400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.00; duration: 400; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        // =====================================================================
        // B. 右侧数值流：🚀【每一个字符独立定宽槽位，绝无半个像素抖动】
        // =====================================================================
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            opacity: timerViewRoot.isPaused ? 0.6 : 1.0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            // 1. 超时前置加号 [+] 独立槽位
            Item {
                visible: timerViewRoot.isOvertime
                width: timerViewRoot.plusWidth + 1
                height: 14
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -0.5
                    text: "+"
                    color: timerViewRoot.textColor
                    font.family: timerViewRoot.fontFam
                    font.pixelSize: timerViewRoot.pixelSize
                    font.weight: Font.Bold
                    renderType: Text.QtRendering
                }
            }

            // 2. 小时组 [HH:] (仅大于1小时显示)
            Row {
                visible: timerViewRoot.hasHours
                spacing: 0
                anchors.verticalCenter: parent.verticalCenter

                Item {
                    width: timerViewRoot.singleDigitWidth; height: 14
                    Text { anchors.centerIn: parent; text: timerViewRoot.hTen; color: timerViewRoot.textColor; font.family: timerViewRoot.fontFam; font.pixelSize: timerViewRoot.pixelSize; font.weight: Font.Bold; renderType: Text.QtRendering }
                }
                Item {
                    width: timerViewRoot.singleDigitWidth; height: 14
                    Text { anchors.centerIn: parent; text: timerViewRoot.hUnit; color: timerViewRoot.textColor; font.family: timerViewRoot.fontFam; font.pixelSize: timerViewRoot.pixelSize; font.weight: Font.Bold; renderType: Text.QtRendering }
                }
                Item {
                    width: timerViewRoot.colonWidth + 1; height: 14
                    Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -0.5; text: ":"; color: timerViewRoot.textColor; font.family: timerViewRoot.fontFam; font.pixelSize: timerViewRoot.pixelSize; font.weight: Font.Bold; renderType: Text.QtRendering }
                }
            }

            // 3. 分钟-十位 独立定宽槽
            Item {
                width: timerViewRoot.singleDigitWidth
                height: 14
                anchors.verticalCenter: parent.verticalCenter

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

            // 4. 分钟-个位 独立定宽槽
            Item {
                width: timerViewRoot.singleDigitWidth
                height: 14
                anchors.verticalCenter: parent.verticalCenter

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

            // 5. 分秒分隔冒号 [:] 独立定宽槽
            Item {
                width: timerViewRoot.colonWidth + 1
                height: 14
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -0.5
                    text: ":"
                    color: timerViewRoot.textColor
                    font.family: timerViewRoot.fontFam
                    font.pixelSize: timerViewRoot.pixelSize
                    font.weight: Font.Bold
                    renderType: Text.QtRendering
                }
            }

            // 6. 秒钟-十位 独立定宽槽
            Item {
                width: timerViewRoot.singleDigitWidth
                height: 14
                anchors.verticalCenter: parent.verticalCenter

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

            // 7. 秒钟-个位 独立定宽槽
            Item {
                width: timerViewRoot.singleDigitWidth
                height: 14
                anchors.verticalCenter: parent.verticalCenter

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
}