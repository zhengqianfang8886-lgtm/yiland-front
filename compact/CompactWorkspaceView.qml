// ==========================================
// 📄 File: compact/CompactWorkspaceView.qml
// 🌟 纯正 macOS 流体凸透镜 (Adaptive Envelope Fisheye) · 绝对安全无穿模版
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

    // 磁吸捕获的整数目标
    property int peakIndex: displayWsNumber
    readonly property alias scrubHoverIndex: wsRoot.peakIndex

    // 仅在松手磁吸吸附（非手动拖拽中）启用平滑归位动画
    Behavior on smoothCursor {
        enabled: !wsRoot.isScrubbing
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
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
    readonly property int contentImplicitWidth: isScrubbing ? 300 : Math.round(14 + numBox.width + 8 + divider.width + 8 + wsNameText.implicitWidth + 14)
    implicitWidth: contentImplicitWidth

    // =========================================================================
    // 3. 绝对安全物理包络线算法 (Adaptive Envelope Engine)
    // =========================================================================
    // 左右绝对物理安全内边距（灵动岛内弧安全线）
    readonly property real minSafeX: 12.0
    readonly property real maxSafeX: wsRoot.width - 12.0
    readonly property real safeSpan: Math.max(10.0, maxSafeX - minSafeX)

    readonly property real minPillW: Math.max(7.0, Math.min(10.0, 72.0 / Math.max(4, totalSlots)))
    readonly property real maxPillW: 76.0
    readonly property real itemGap: Math.max(4.0, Math.min(6.0, 36.0 / Math.max(3, totalSlots)))

    // 膨胀系数（由连续焦点与当前项距离决定）
    function getSwell(idx) {
        var dist = Math.abs(idx - smoothCursor)
        if (dist >= 1.5) return 0.0
        return Math.exp(- (dist * dist) / 0.72)
    }

    function getItemWidth(idx) {
        return minPillW + (maxPillW - minPillW) * getSwell(idx)
    }

    // 实时计算透镜队列总占用宽度
    readonly property real totalClusterWidth: {
        var sum = 0
        for (var i = 0; i < totalSlots; i++) {
            sum += getItemWidth(i)
        }
        return sum + Math.max(0, totalSlots - 1) * itemGap
    }

    // 🚀【核心修复】：自适应包络线定位，两端数学上绝对不越界
    function getItemCenterX(idx) {
        var focusRatio = totalSlots > 1 ? Math.max(0.0, Math.min(1.0, smoothCursor / (totalSlots - 1))) : 0.5
        var clusterW = totalClusterWidth

        // 计算队列起始 X 坐标：在可用安全区间内平滑流动，两端永远贴齐安全内壁
        var startX = minSafeX
        if (clusterW < safeSpan) {
            startX = minSafeX + focusRatio * (safeSpan - clusterW)
        }

        var offset = startX
        for (var j = 0; j < idx; j++) {
            offset += (getItemWidth(j) + itemGap)
        }
        return offset + getItemWidth(idx) / 2.0
    }

    // 拖拽手势映射
    function updateCursorByMouseX(mouseX) {
        if (totalSlots <= 1) {
            smoothCursor = 0.0
            return
        }
        var clampedX = Math.max(minSafeX, Math.min(maxSafeX, mouseX))
        var ratio = (clampedX - minSafeX) / safeSpan
        smoothCursor = ratio * (totalSlots - 1)
    }

    // 磁吸滞后防抖
    function updatePeakSelection() {
        if (totalSlots <= 0) {
            peakIndex = 0
            return
        }
        var candidate = Math.max(0, Math.min(totalSlots - 1, Math.round(smoothCursor)))
        if (candidate === peakIndex) return

        if (Math.abs(smoothCursor - peakIndex) > 0.52) {
            peakIndex = candidate
        }
    }

    onSmoothCursorChanged: updatePeakSelection()

    function snapToNearest() {
        smoothCursor = peakIndex
    }

    onIsScrubbingChanged: {
        if (isScrubbing) {
            var curr = Math.max(0, Math.min(totalSlots - 1, displayWsNumber))
            peakIndex = curr
            smoothCursor = curr
        }
    }

    // =========================================================================
    // 4. 视图 A：常态工作区信息横幅 (静态空闲模式)
    // =========================================================================
    Item {
        id: normalNotifyView
        anchors.fill: parent
        visible: opacity > 0.001
        opacity: wsRoot.isScrubbing ? 0.0 : 1.0
        scale: wsRoot.isScrubbing ? 0.90 : 1.0

        Behavior on opacity { NumberAnimation { duration: Theme.animInstant; easing.type: Theme.curveFluid } }
        Behavior on scale { NumberAnimation { duration: Theme.animInstant; easing.type: Theme.curveDecel } }

        Rectangle {
            id: numBox
            width: 24; height: 22; radius: 7
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.22)
            border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.85)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: wsRoot.displayWsNumber
                color: "white"
                font.pixelSize: 12
                font.weight: Font.Black
                font.family: wsRoot.displayFont
            }
        }

        Rectangle {
            id: divider
            width: 1; height: 10; radius: 1
            anchors.left: numBox.right; anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(1, 1, 1, 0.16)
        }

        Item {
            id: nameArea
            anchors.left: divider.right; anchors.leftMargin: 8
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 22; clip: true

            Text {
                id: wsNameText
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                text: wsRoot.wsName ? wsRoot.wsName : ("桌面 " + wsRoot.displayWsNumber)
                color: "white"
                font.family: wsRoot.effectiveFont
                font.pixelSize: 13
                font.weight: Font.Black
                font.letterSpacing: 0.5
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    // =========================================================================
    // 5. 视图 B：流体连续凸透镜标尺 (安全包裹版)
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

        // 底层光学微导轨
        Rectangle {
            anchors.left: parent.left; anchors.leftMargin: wsRoot.minSafeX
            anchors.right: parent.right; anchors.rightMargin: wsRoot.minSafeX
            anchors.verticalCenter: parent.verticalCenter
            height: 1.5
            radius: 0.75
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // 凸透镜桌面项阵列
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

                // 实体微胶囊
                Rectangle {
                    id: slateBody
                    anchors.fill: parent
                    radius: height / 2.0
                    antialiasing: true
                    smooth: true

                    color: {
                        if (wsRoot.isScrubCanceling) {
                            return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.22 + lensItem.swell * 0.38)
                        }
                        if (lensItem.isHoverLocked) {
                            return Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.32 + lensItem.swell * 0.28)
                        }
                        return Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.10 + lensItem.swell * 0.20)
                    }

                    border.color: {
                        if (wsRoot.isScrubCanceling) {
                            return Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.6 + lensItem.swell * 0.4)
                        }
                        if (lensItem.isHoverLocked) {
                            return Theme.workspace
                        }
                        if (lensItem.isCurrentWs) {
                            return Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.45 + lensItem.swell * 0.45)
                        }
                        return Qt.rgba(255, 255, 255, 0.12 + lensItem.swell * 0.25)
                    }
                    border.width: 0.9 + lensItem.swell * 0.5

                    Behavior on color { ColorAnimation { duration: 60 } }
                    Behavior on border.color { ColorAnimation { duration: 60 } }

                    // 顶层微光反光线
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 0.6
                        radius: parent.radius
                        color: "transparent"
                        border.color: Qt.rgba(255, 255, 255, 0.35)
                        border.width: 0.6
                        opacity: lensItem.swell
                    }

                    // 1. 未聚焦压缩态：仅以纤细药丸呈现自身（彻底剔除内部小白点，消除重叠叠影）

                    // 2. 焦点膨胀态：编号徽标 + 桌面名 (随空间拉伸流体渐入)
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