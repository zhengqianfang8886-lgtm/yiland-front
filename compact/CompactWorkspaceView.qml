// ==========================================
// 📄 File: compact/CompactWorkspaceView.qml (自适应内容宽·纯净版)
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

    // 🚀【核心暴露】：实时计算并暴露当前桌面内容所需的真实物理宽度
    readonly property int contentImplicitWidth: Math.round(14 + numBox.width + 8 + divider.width + 8 + wsNameText.implicitWidth + 14)
    implicitWidth: contentImplicitWidth

    // =========================================================================
    // 双轨滚轴数值转换状态机
    // =========================================================================
    property int prevNumber: displayWsNumber
    property int currentNumber: displayWsNumber
    property int rollDirection: 1     // 1: 向上滚, -1: 向下滚
    property real rollProgress: 1.0   // 0.0 -> 1.0 连续驱动

    onDisplayWsNumberChanged: {
        var oldVal = wsRoot.currentNumber
        var newVal = wsRoot.displayWsNumber
        if (oldVal === newVal) return

        wsRoot.rollDirection = (newVal > oldVal) ? 1 : -1
        wsRoot.prevNumber = oldVal
        wsRoot.currentNumber = newVal

        rollAnim.stop()
        wsRoot.rollProgress = 0.0
        rollAnim.start()

        boxSquashAnim.restart()
        textSlideAnim.restart()
    }

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

    // 1. 最左端数字方块
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

        Item {
            id: numSlot
            anchors.fill: parent
            clip: true

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

    // 2. 垂直分割线
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

    // 3. 桌面名称区
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