// ==========================================
// 📄 File: compact/CompactWorkspaceView.qml (彻底剔除顶线杂质·纯净版)
// ==========================================
import QtQuick

Item {
    id: wsRoot
    anchors.fill: parent

    property string chosenFont: ""
    property string wsName: ""
    property int displayWsNumber: 0
    property int wsTotal: 4
    property int activeSlotIndex: 0
    property bool hasZeroWs: false

    // =========================================================================
    // 双轨滚轴数值转换状态机
    // =========================================================================
    property int prevNumber: displayWsNumber
    property int currentNumber: displayWsNumber
    property int rollDirection: 1     // 1: 向上滚 (数值递增), -1: 向下滚 (数值递减)
    property real rollProgress: 1.0   // 0.0 -> 1.0 连续驱动旧字滑出、新字弹入

    onDisplayWsNumberChanged: {
        var oldVal = wsRoot.currentNumber
        var newVal = wsRoot.displayWsNumber
        if (oldVal === newVal) return

        // 智能判断滚轮方向
        wsRoot.rollDirection = (newVal > oldVal) ? 1 : -1
        wsRoot.prevNumber = oldVal
        wsRoot.currentNumber = newVal

        // 重新启动丝滑翻牌物理动画
        rollAnim.stop()
        wsRoot.rollProgress = 0.0
        rollAnim.start()

        // 联动方块微弹性触感与名称淡入
        boxSquashAnim.restart()
        textSlideAnim.restart()
    }

    // 齿轮滚轮翻牌物理曲线动画 (OutBack 带来清脆机械咬合回弹)
    NumberAnimation {
        id: rollAnim
        target: wsRoot
        property: "rollProgress"
        from: 0.0
        to: 1.0
        duration: 240
        easing.type: Easing.OutBack
        easing.overshoot: 1.3
    }

    // =========================================================================
    // 1. 最左端：物理位置 100% 死锁的数字方块 (固定 x = 14px，绝不动)
    // =========================================================================
    Rectangle {
        id: numBox
        width: 24
        height: 22
        radius: 7
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.22)
        border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.85)
        border.width: 1.2

        // 切桌面瞬间的紫色微光外扩脉冲
        Rectangle {
            id: pulseRing
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: parent.radius
            color: "transparent"
            border.color: Theme.workspace
            border.width: 1.5
            opacity: 0.0
        }

        // =====================================================================
        // 双轨双缓冲数字槽位 (彻底剔除顶线上方的横线条)
        // =====================================================================
        Item {
            id: numSlot
            anchors.fill: parent
            clip: true

            // 旧数字 (正在滑出)
            Text {
                id: textOld
                anchors.horizontalCenter: parent.horizontalCenter
                text: wsRoot.prevNumber
                color: "white"
                font.pixelSize: 12
                font.weight: Font.Black
                font.family: (wsRoot.chosenFont !== "") ? wsRoot.chosenFont : "Monospace"
                renderType: Text.QtRendering

                y: ((numSlot.height - height) / 2) - (wsRoot.rollProgress * numSlot.height * wsRoot.rollDirection)
                opacity: 1.0 - wsRoot.rollProgress
                visible: opacity > 0.01
            }

            // 新数字 (正在从反方向弹入就位)
            Text {
                id: textNew
                anchors.horizontalCenter: parent.horizontalCenter
                text: wsRoot.currentNumber
                color: "white"
                font.pixelSize: 12
                font.weight: Font.Black
                font.family: (wsRoot.chosenFont !== "") ? wsRoot.chosenFont : "Monospace"
                renderType: Text.QtRendering

                y: ((numSlot.height - height) / 2) + ((1.0 - wsRoot.rollProgress) * numSlot.height * wsRoot.rollDirection)
                opacity: Math.min(1.0, wsRoot.rollProgress * 1.5)
            }
        }

        // 方块微物理挤压动效 (Squash & Stretch)
        SequentialAnimation {
            id: boxSquashAnim
            ParallelAnimation {
                NumberAnimation { target: numBox; property: "scale"; from: 1.0; to: 0.88; duration: 60; easing.type: Easing.OutQuad }
                NumberAnimation { target: pulseRing; property: "scale"; from: 1.0; to: 1.45; duration: 220; easing.type: Easing.OutQuad }
                NumberAnimation { target: pulseRing; property: "opacity"; from: 0.8; to: 0.0; duration: 220; easing.type: Easing.OutQuad }
            }
            NumberAnimation { target: numBox; property: "scale"; to: 1.08; duration: 80; easing.type: Easing.OutQuad }
            NumberAnimation { target: numBox; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
    }

    // =========================================================================
    // 2. 秩序微光垂直分割线
    // =========================================================================
    Rectangle {
        id: divider
        width: 1
        height: 10
        radius: 0.5
        anchors.left: numBox.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(1, 1, 1, 0.16)
    }

    // =========================================================================
    // 3. 桌面名称区
    // =========================================================================
    Item {
        id: nameArea
        anchors.left: divider.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        clip: true

        Text {
            id: wsNameText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: wsRoot.wsName ? wsRoot.wsName : ("桌面 " + wsRoot.displayWsNumber)
            color: "white"
            font.family: wsRoot.chosenFont
            font.pixelSize: 13
            font.weight: Font.Black
            font.letterSpacing: 0.5
            elide: Text.ElideRight
            width: parent.width
            renderType: Text.QtRendering
        }

        ParallelAnimation {
            id: textSlideAnim
            NumberAnimation {
                target: wsNameText
                property: "x"
                from: 8
                to: 0
                duration: 180
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: wsNameText
                property: "opacity"
                from: 0.25
                to: 1.0
                duration: 160
                easing.type: Easing.OutQuad
            }
        }
    }
}