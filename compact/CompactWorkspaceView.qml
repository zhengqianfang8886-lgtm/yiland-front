// ==========================================
// 📄 File: compact/CompactWorkspaceView.qml
// ==========================================
import QtQuick

Item {
    id: wsRoot
    anchors.fill: parent

    property string chosenFont: ""
    property string wsName: ""
    property int displayWsNumber: 1
    property int wsTotal: 4
    property int activeSlotIndex: 0
    property bool hasZeroWs: false

    onDisplayWsNumberChanged: {
        numBounceAnim.restart()
        textSlideAnim.restart()
    }

    // =========================================================================
    // 1. 左侧：带微弹性冲击与光晕脉冲的数字方块 (绝对位置死锁)
    // =========================================================================
    Rectangle {
        id: numBox
        width: 22
        height: 22
        radius: 7
        anchors.left: parent.left
        anchors.leftMargin: 12
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
                id: numText
                anchors.centerIn: parent
                text: wsRoot.displayWsNumber
                color: "white"
                font.pixelSize: 12
                font.weight: Font.Black
                font.family: (wsRoot.chosenFont !== "") ? wsRoot.chosenFont : "Monospace"
                renderType: Text.QtRendering
            }
        }

        SequentialAnimation {
            id: numBounceAnim
            ParallelAnimation {
                NumberAnimation { target: numBox; property: "scale"; from: 1.0; to: 0.86; duration: 60; easing.type: Easing.OutQuad }
                NumberAnimation { target: numText; property: "opacity"; from: 0.3; to: 1.0; duration: 100 }
                NumberAnimation { target: numText; property: "y"; from: numSlot.height / 2 + 4; to: (numSlot.height - numText.height) / 2; duration: 120; easing.type: Easing.OutCubic }
                NumberAnimation { target: pulseRing; property: "scale"; from: 1.0; to: 1.45; duration: 220; easing.type: Easing.OutQuad }
                NumberAnimation { target: pulseRing; property: "opacity"; from: 0.8; to: 0.0; duration: 220; easing.type: Easing.OutQuad }
            }
            NumberAnimation { target: numBox; property: "scale"; to: 1.08; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: numBox; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
    }

    // =========================================================================
    // 2. 中间：真实穿梭的液态水银游标导轨 (Liquid Mercury Slider)
    // =========================================================================
    Rectangle {
        id: trackCapsule
        height: 18
        radius: 9
        readonly property int dotPitch: 10
        readonly property int safeTotal: Math.min(8, Math.max(2, wsRoot.wsTotal))
        width: (safeTotal - 1) * dotPitch + 22

        anchors.left: numBox.right
        anchors.leftMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        clip: true

        Row {
            anchors.centerIn: parent
            spacing: trackCapsule.dotPitch - 4

            Repeater {
                model: trackCapsule.safeTotal
                Rectangle {
                    width: 4; height: 4; radius: 2
                    color: Qt.rgba(1, 1, 1, 0.22)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Rectangle {
            id: mercuryThumb
            height: 5
            radius: 2.5
            color: Theme.workspace
            anchors.verticalCenter: parent.verticalCenter

            readonly property real targetX: 6 + Math.max(0, Math.min(trackCapsule.safeTotal - 1, wsRoot.activeSlotIndex)) * trackCapsule.dotPitch - (width - 4) / 2
            x: targetX

            // 🚀【修复报错点】：直接读取具体的 NumberAnimation 对象，安全规整为布尔
            readonly property bool inMotion: (typeof thumbXAnim !== "undefined" && thumbXAnim.running) ? true : false
            width: inMotion ? 18 : 12

            Behavior on width {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            Behavior on x {
                NumberAnimation {
                    id: thumbXAnim  // 👈 id 绑定在动画对象上
                    duration: 240
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.35
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 0.5
                height: 1.5
                radius: 0.75
                color: Qt.rgba(1, 1, 1, 0.55)
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (typeof Bridge === "undefined") return
                var clickIdx = Math.round((mouse.x - 11) / trackCapsule.dotPitch)
                var safeIdx = Math.max(0, Math.min(trackCapsule.safeTotal - 1, clickIdx))
                Bridge.switchWorkspace(wsRoot.hasZeroWs ? safeIdx : (safeIdx + 1))
            }
        }
    }

    // =========================================================================
    // 3. 右侧：视差景深飞入文本区
    // =========================================================================
    Item {
        id: nameArea
        anchors.left: trackCapsule.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 20
        clip: true

        Text {
            id: wsNameText
            anchors.verticalCenter: parent.verticalCenter
            text: wsRoot.wsName ? wsRoot.wsName : ("桌面 " + wsRoot.displayWsNumber)
            color: "white"
            font.family: wsRoot.chosenFont
            font.pixelSize: 12
            font.weight: Font.Black
            font.letterSpacing: 0.4
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
                from: 0.2
                to: 1.0
                duration: 160
                easing.type: Easing.OutQuad
            }
        }
    }
}