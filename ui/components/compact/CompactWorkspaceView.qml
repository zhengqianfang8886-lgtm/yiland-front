// ==========================================
// 📄 File: compact/CompactWorkspaceView.qml
// 🌟 纯正苹果美学 · 双翼对称全景感知版 (彻底消灭右侧大黑洞)
// ==========================================
import QtQuick

Item {
    id: wsRoot
    anchors.fill: parent

    // =========================================================================
    // 1. 公共属性与接口
    // =========================================================================
    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property string wsName: ""
    property int displayWsNumber: 0
    property int wsTotal: 4
    property var wsList: []

    property bool isScrubbing: false
    property bool isScrubCanceling: false

    // 焦点连续浮点索引 (0.0 ~ totalSlots - 1)
    property real smoothCursor: displayWsNumber
    property int peakIndex: displayWsNumber
    readonly property alias scrubHoverIndex: wsRoot.peakIndex

    Behavior on smoothCursor {
        enabled: !wsRoot.isScrubbing
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    // =========================================================================
    // 2. 数据模型规范化 (0-Based 自适应)
    // =========================================================================
    readonly property var workspaceItems: {
        if (wsList && wsList.length > 0) {
            var res = []
            for (var i = 0; i < wsList.length; i++) {
                var item = wsList[i]
                var title = ""
                var tid = i
                if (typeof item === "object" && item !== null) {
                    title = item.name || ("桌面 " + (item.id !== undefined ? item.id : i))
                    tid = item.id !== undefined ? item.id : i
                } else if (typeof item === "string") {
                    title = item
                } else {
                    title = "桌面 " + i
                }
                res.push({ index: i, id: tid, name: title })
            }
            return res
        }
        var defs = []
        var total = Math.max(1, wsTotal)
        for (var k = 0; k < total; k++) {
            defs.push({ index: k, id: k, name: "桌面 " + k })
        }
        return defs
    }

    readonly property int totalSlots: workspaceItems.length

    // 🚀【核心排版算式】：计算黄金内容宽度 (左边距14 + 左翼 + 中间呼吸间隔20 + 右翼点阵 + 右边距14)
    readonly property int contentImplicitWidth: {
        if (isScrubbing) return 300
        var leftW = 22 + 8 + wsNameText.implicitWidth
        var rightW = dotsRow.implicitWidth
        return Math.round(14 + leftW + 20 + rightW + 14)
    }
    implicitWidth: contentImplicitWidth

    // =========================================================================
    // 3. 拖拽凸透镜包络算法 (保留原有防穿模引擎)
    // =========================================================================
    readonly property real minSafeX: 12.0
    readonly property real maxSafeX: wsRoot.width - 12.0
    readonly property real safeSpan: Math.max(10.0, maxSafeX - minSafeX)
    readonly property real minPillW: Math.max(7.0, Math.min(10.0, 72.0 / Math.max(4, totalSlots)))
    readonly property real maxPillW: 76.0
    readonly property real itemGap: Math.max(4.0, Math.min(6.0, 36.0 / Math.max(3, totalSlots)))

    function getSwell(idx) {
        var dist = Math.abs(idx - smoothCursor)
        if (dist >= 1.5) return 0.0
        return Math.exp(- (dist * dist) / 0.72)
    }

    function getItemWidth(idx) {
        return minPillW + (maxPillW - minPillW) * getSwell(idx)
    }

    readonly property real totalClusterWidth: {
        var sum = 0
        for (var i = 0; i < totalSlots; i++) sum += getItemWidth(i)
        return sum + Math.max(0, totalSlots - 1) * itemGap
    }

    function getItemCenterX(idx) {
        var focusRatio = totalSlots > 1 ? Math.max(0.0, Math.min(1.0, smoothCursor / (totalSlots - 1))) : 0.5
        var clusterW = totalClusterWidth
        var startX = minSafeX
        if (clusterW < safeSpan) startX = minSafeX + focusRatio * (safeSpan - clusterW)
        var offset = startX
        for (var j = 0; j < idx; j++) offset += (getItemWidth(j) + itemGap)
        return offset + getItemWidth(idx) / 2.0
    }

    function updateCursorByMouseX(mouseX) {
        if (totalSlots <= 1) { smoothCursor = 0.0; return }
        var clampedX = Math.max(minSafeX, Math.min(maxSafeX, mouseX))
        var ratio = (clampedX - minSafeX) / safeSpan
        smoothCursor = ratio * (totalSlots - 1)
    }

    function updatePeakSelection() {
        if (totalSlots <= 0) { peakIndex = 0; return }
        var candidate = Math.max(0, Math.min(totalSlots - 1, Math.round(smoothCursor)))
        if (candidate === peakIndex) return
        if (Math.abs(smoothCursor - peakIndex) > 0.52) peakIndex = candidate
    }

    onSmoothCursorChanged: updatePeakSelection()
    function snapToNearest() { smoothCursor = peakIndex }

    onIsScrubbingChanged: {
        if (isScrubbing) {
            var curr = Math.max(0, Math.min(totalSlots - 1, displayWsNumber))
            peakIndex = curr
            smoothCursor = curr
        }
    }

    // =========================================================================
    // 4. 视图 A：常态工作区瞬态横幅 (🚀 重构：纯正双翼对称黄金布局)
    // =========================================================================
    Item {
        id: normalNotifyView
        anchors.fill: parent
        visible: opacity > 0.001
        opacity: wsRoot.isScrubbing ? 0.0 : 1.0
        scale: wsRoot.isScrubbing ? 0.90 : 1.0

        Behavior on opacity { NumberAnimation { duration: Theme.animInstant; easing.type: Theme.curveFluid } }
        Behavior on scale { NumberAnimation { duration: Theme.animInstant; easing.type: Theme.curveDecel } }

        // 🌟【左翼】：身份微型徽标 + 空间名称 (剔除生硬分割竖线，采用纯净空气感留白)
        Row {
            id: leftClusterRow
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // 空间编号微晶体
            Rectangle {
                id: numBox
                width: 22
                height: 22
                radius: 6
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.24)
                border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.85)
                border.width: 1.2

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -0.5
                    text: wsRoot.displayWsNumber
                    color: "white"
                    font.pixelSize: 11
                    font.weight: Font.Black
                    font.family: wsRoot.displayFont
                }
            }

            // 空间名称 (Dev, Code, Web 等)
            Text {
                id: wsNameText
                anchors.verticalCenter: parent.verticalCenter
                text: wsRoot.wsName ? wsRoot.wsName : ("桌面 " + wsRoot.displayWsNumber)
                color: "#ffffff"
                font.family: wsRoot.effectiveFont
                font.pixelSize: 12
                font.weight: Font.Black
                font.letterSpacing: 0.4
                elide: Text.ElideRight
                renderType: Text.QtRendering
            }
        }

        // 🌟【右翼】：桌面全景晶体微点阵列 (提供位置感知，瞬间消除右侧大黑洞！)
        Row {
            id: dotsRow
            anchors.right: parent.right
            anchors.rightMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: wsRoot.workspaceItems

                Rectangle {
                    readonly property bool isCurrent: (index === wsRoot.displayWsNumber)
                    width: isCurrent ? 10 : 4
                    height: 4
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter

                    color: isCurrent ? Theme.workspace : Qt.rgba(1, 1, 1, 0.25)

                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }
        }
    }

    // =========================================================================
    // 5. 视图 B：流体连续凸透镜标尺 (拖拽切换态)
    // =========================================================================
    Item {
        id: lensContainer
        anchors.fill: parent
        visible: opacity > 0.001
        opacity: wsRoot.isScrubbing ? 1.0 : 0.0
        scale: wsRoot.isScrubbing ? 1.0 : 0.94

        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveFluid } }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.animFast
                easing.type: Theme.curveSpring
                easing.overshoot: Theme.springOvershootNormal
            }
        }

        Rectangle {
            anchors.left: parent.left; anchors.leftMargin: wsRoot.minSafeX
            anchors.right: parent.right; anchors.rightMargin: wsRoot.minSafeX
            anchors.verticalCenter: parent.verticalCenter
            height: 1.5; radius: 0.75
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        Repeater {
            model: wsRoot.workspaceItems

            Item {
                id: lensItem
                readonly property real swell: wsRoot.getSwell(index)
                readonly property real itemW: wsRoot.getItemWidth(index)
                readonly property real itemCenterX: wsRoot.getItemCenterX(index)

                width: itemW
                height: 14.0 + 10.0 * swell
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -swell * 1.5
                x: itemCenterX - itemW / 2.0
                z: Math.round(swell * 50)

                readonly property bool isCurrentWs: (index === wsRoot.displayWsNumber)
                readonly property bool isHoverLocked: (index === wsRoot.peakIndex)

                Rectangle {
                    id: slateBody
                    anchors.fill: parent
                    radius: height / 2.0
                    antialiasing: true

                    color: {
                        if (wsRoot.isScrubCanceling) return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.22 + lensItem.swell * 0.38)
                        if (lensItem.isHoverLocked) return Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.32 + lensItem.swell * 0.28)
                        return Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.10 + lensItem.swell * 0.20)
                    }

                    border.color: {
                        if (wsRoot.isScrubCanceling) return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.6 + lensItem.swell * 0.4)
                        if (lensItem.isHoverLocked) return Theme.workspace
                        if (lensItem.isCurrentWs) return Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.45 + lensItem.swell * 0.45)
                        return Qt.rgba(255, 255, 255, 0.12 + lensItem.swell * 0.25)
                    }
                    border.width: 0.9 + lensItem.swell * 0.5

                    Behavior on color { ColorAnimation { duration: 60 } }
                    Behavior on border.color { ColorAnimation { duration: 60 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        clip: true
                        opacity: Math.max(0.0, Math.min(1.0, (lensItem.swell - 0.40) / 0.45))
                        visible: opacity > 0.001

                        Rectangle {
                            width: 12; height: 12; radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            color: lensItem.isCurrentWs ? "#34d399" : (wsRoot.isScrubCanceling ? Theme.danger : Qt.rgba(255, 255, 255, 0.28))

                            Text {
                                anchors.centerIn: parent
                                text: modelData.index
                                color: "white"
                                font.family: wsRoot.displayFont
                                font.pixelSize: 8
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            text: modelData.name
                            color: "#ffffff"
                            font.family: wsRoot.effectiveFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            width: Math.max(10, slateBody.width - 26)
                            anchors.verticalCenter: parent.verticalCenter
                            renderType: Text.QtRendering
                        }
                    }
                }
            }
        }
    }
}