// ==========================================
// 📄 File: compact/CompactWorkspaceView.qml (自适应内容宽·动量滚轴版)
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

    readonly property int contentImplicitWidth: Math.round(14 + numBox.width + 8 + divider.width + 8 + wsNameText.implicitWidth + 14)
    implicitWidth: contentImplicitWidth

    // =========================================================================
    // 可重入双轨滚轴数值状态机
    // =========================================================================
    property int prevNumber: displayWsNumber
    property int currentNumber: displayWsNumber
    property int rollDirection: 1
    property real rollProgress: 1.0

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

        numBoxScale = 0.90
        boxResetTimer.restart()
        textSlideX = 8
        textResetTimer.restart()
    }

    NumberAnimation {
        id: rollAnim
        target: wsRoot
        property: "rollProgress"
        from: 0.0
        to: 1.0
        duration: Theme.animNormal
        easing.type: Theme.curveSpring
        easing.overshoot: Theme.springOvershootFirm
    }

    property real numBoxScale: 1.0
    Behavior on numBoxScale { NumberAnimation { duration: Theme.animInstant; easing.type: Theme.curveDecel } }
    Timer { id: boxResetTimer; interval: 35; onTriggered: wsRoot.numBoxScale = 1.0 }

    property real textSlideX: 0
    Behavior on textSlideX { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveDecel } }
    Timer { id: textResetTimer; interval: 30; onTriggered: wsRoot.textSlideX = 0 }

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
        scale: wsRoot.numBoxScale

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
            x: wsRoot.textSlideX
            opacity: 1.0 - (wsRoot.textSlideX / 16.0)
        }
    }
}