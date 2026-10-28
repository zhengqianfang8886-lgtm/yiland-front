// ==========================================
// 📄 File: ui/components/compact/CompactNetSpeedView.qml
// 🌟 平衡可视型实时网速 (清晰柔光82%白 · 完整保留/s · 稳固零频闪版)
// ==========================================
import QtQuick

Item {
    id: netRoot
    width: 56  // 🚀 完整容纳带 /s 的单位，宽度设定为 56px
    height: 24 // 高度严格锁死 24px 不变

    property string fontFam: "Monospace"
    property string downVal: "0"
    property string downUnit: "B/s"
    property string upVal: "0"
    property string upUnit: "B/s"
    property string downCompact: "0B"
    property string upCompact: "0B"

    // 内部平滑展示值
    property string dispUpVal: "0"
    property string dispUpUnit: "B/s"
    property string dispDownVal: "0"
    property string dispDownUnit: "B/s"

    property real lastUpNum: 0
    property string lastUpUnitStr: ""
    property real lastDownNum: 0
    property string lastDownUnitStr: ""

    // =========================================================================
    // 🚀 平滑过滤器：底噪过滤 + 完整保留 /s
    // =========================================================================
    function updateSpeedFiltered(rawVal, rawUnit, isDown) {
        var v = parseFloat(rawVal) || 0;
        
        // 🚀 完整保留带 /s 的标准规范单位
        var u = "B/s";
        if (rawUnit.indexOf("G") !== -1) u = "G/s";
        else if (rawUnit.indexOf("M") !== -1) u = "M/s";
        else if (rawUnit.indexOf("K") !== -1) u = "K/s";

        // 杂讯睡眠：小于 2.0 KB/s 的系统微弱杂讯归为 0 B/s，避免无意义数字跳变
        if (u === "B/s" || (u === "K/s" && v < 2.0)) {
            v = 0;
            u = "B/s";
        }

        var lastV = isDown ? lastDownNum : lastUpNum;
        var lastU = isDown ? lastDownUnitStr : lastUpUnitStr;

        // 波动小于 35% 且没跨量级时平滑保持，兼顾实时性与视觉安定
        var delta = Math.abs(v - lastV);
        var ratio = delta / Math.max(lastV, 1.0);

        if (u !== lastU || ratio > 0.35 || (v === 0 && lastV !== 0) || (v > 0 && lastV === 0)) {
            var formatted = Math.round(v).toString();
            if (isDown) {
                lastDownNum = v;
                lastDownUnitStr = u;
                dispDownVal = formatted;
                dispDownUnit = u;
            } else {
                lastUpNum = v;
                lastUpUnitStr = u;
                dispUpVal = formatted;
                dispUpUnit = u;
            }
        }
    }

    onUpValChanged: updateSpeedFiltered(upVal, upUnit, false)
    onDownValChanged: updateSpeedFiltered(downVal, downUnit, true)

    // =========================================================================
    // 🚀 平衡亮度方案：82% 纯白数值清晰可见，辅以 60% / 48% 层次阶梯
    // =========================================================================
    readonly property color numColor: Qt.rgba(255, 255, 255, 0.82)   // 数值：82% 柔光白，清晰舒适不刺眼
    readonly property color arrowColor: Qt.rgba(255, 255, 255, 0.60) // 箭头：60% 清晰可见
    readonly property color unitColor: Qt.rgba(255, 255, 255, 0.48)  // 单位：48% 优雅呈现 /s

    Column {
        anchors.centerIn: parent
        spacing: 0

        // =====================================================================
        // 上传 (TX) - 骨架位置严格锁死，永无横向抽搐
        // =====================================================================
        Item {
            width: netRoot.width
            height: 11

            // 1. 箭头锚定在最左侧
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "↑"
                font.family: netRoot.fontFam
                font.pixelSize: 9 // 纯整数
                font.weight: Font.Bold
                color: netRoot.arrowColor
                renderType: Text.QtRendering
            }

            // 2. 数值槽位定宽 26px，右对齐，等宽数字
            Item {
                anchors.left: parent.left
                anchors.leftMargin: 8
                width: 26
                height: parent.height

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: netRoot.dispUpVal
                    font.family: netRoot.fontFam
                    font.pixelSize: 11 // 纯整数
                    font.weight: Font.Black
                    font.features: { "tnum": 1 } // 等宽锁死
                    color: netRoot.numColor
                    renderType: Text.QtRendering
                }
            }

            // 3. 单位完整呈现 /s，锚定在右侧
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: netRoot.dispUpUnit
                font.family: netRoot.fontFam
                font.pixelSize: 8 // 纯整数
                font.weight: Font.DemiBold
                color: netRoot.unitColor
                renderType: Text.QtRendering
            }
        }

        // =====================================================================
        // 下载 (RX) - 骨架位置严格锁死
        // =====================================================================
        Item {
            width: netRoot.width
            height: 11

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "↓"
                font.family: netRoot.fontFam
                font.pixelSize: 9 // 纯整数
                font.weight: Font.Bold
                color: netRoot.arrowColor
                renderType: Text.QtRendering
            }

            Item {
                anchors.left: parent.left
                anchors.leftMargin: 8
                width: 26
                height: parent.height

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: netRoot.dispDownVal
                    font.family: netRoot.fontFam
                    font.pixelSize: 11 // 纯整数
                    font.weight: Font.Black
                    font.features: { "tnum": 1 }
                    color: netRoot.numColor
                    renderType: Text.QtRendering
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: netRoot.dispDownUnit
                font.family: netRoot.fontFam
                font.pixelSize: 8 // 纯整数
                font.weight: Font.DemiBold
                color: netRoot.unitColor
                renderType: Text.QtRendering
            }
        }
    }
}