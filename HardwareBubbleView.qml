import QtQuick
import QtQuick.Shapes

Rectangle {
    id: hwBubbleRoot

    property bool active: true
    readonly property bool isHovered: bubbleHover.hovered

    // 0: 音量 (Volume) | 1: 屏幕亮度 (Brightness) | 2: 麦克风 (Microphone)
    property int currentMode: 0

    // 状态缓存
    property bool isVolMuted: false
    property bool isMicMuted: false

    signal modeChanged(int newMode)
    signal wheelAdjusted(int mode, int delta)
    signal toggleMuteTriggered(int mode)

    width: 44
    height: 34
    radius: 17
    clip: true
    transformOrigin: Item.Center

    color: Theme.bgCapsule
    border.width: 1
    border.color: hwBubbleRoot.isHovered ?
                  Qt.rgba(currentThemeColor.r, currentThemeColor.g, currentThemeColor.b, 0.85) :
                  (isCurrentMuted ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.6) : Qt.rgba(currentThemeColor.r, currentThemeColor.g, currentThemeColor.b, 0.35))
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    visible: active
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    // 统一 Spring 物理曲线
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: Theme.animSpring; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershootNormal } }

    readonly property color currentThemeColor: {
        if (currentMode === 0) return Theme.bluetooth
        if (currentMode === 1) return Theme.clock
        return Theme.workspace
    }

    readonly property bool isCurrentMuted: {
        if (currentMode === 0) return isVolMuted
        if (currentMode === 2) return isMicMuted
        return false
    }

    Timer {
        id: autoRevertTimer
        interval: 8000
        repeat: false
        onTriggered: {
            if (hwBubbleRoot.currentMode !== 0) {
                switchAnimation.restart()
                hwBubbleRoot.currentMode = 0
            }
        }
    }

    function resetActivity() {
        if (hwBubbleRoot.currentMode !== 0) {
            autoRevertTimer.restart()
        }
    }

    SequentialAnimation {
        id: switchAnimation
        NumberAnimation { target: iconContainer; property: "scale"; to: 0.65; duration: Theme.animInstant; easing.type: Easing.InQuad }
        NumberAnimation { target: iconContainer; property: "scale"; to: 1.0; duration: Theme.animNormal; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershootFirm }
    }

    SequentialAnimation {
        id: muteShakeAnimation
        NumberAnimation { target: iconContainer; property: "rotation"; to: -10; duration: 45 }
        NumberAnimation { target: iconContainer; property: "rotation"; to: 10; duration: 45 }
        NumberAnimation { target: iconContainer; property: "rotation"; to: 0; duration: 45 }
    }

    // 背景微光呼吸槽
    Rectangle {
        anchors.centerIn: parent
        width: 24; height: 24; radius: 12
        color: isCurrentMuted ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.22) : Qt.rgba(currentThemeColor.r, currentThemeColor.g, currentThemeColor.b, 0.16)
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // 严谨定位的 16x16 黄金微视网膜光栅容器
    Item {
        id: iconContainer
        anchors.centerIn: parent
        width: 16; height: 16

        // 1. 手绘音量
        Item {
            anchors.fill: parent
            visible: hwBubbleRoot.currentMode === 0

            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    fillColor: hwBubbleRoot.isVolMuted ? Theme.danger : (hwBubbleRoot.isHovered ? "white" : Qt.rgba(1, 1, 1, 0.95))
                    strokeColor: hwBubbleRoot.isVolMuted ? Theme.danger : (hwBubbleRoot.isHovered ? "white" : Qt.rgba(1, 1, 1, 0.95))
                    strokeWidth: 0.8
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    startX: 1.5; startY: 5.8
                    PathLine { x: 4.2; y: 5.8 }
                    PathLine { x: 8.0; y: 2.2 }
                    PathLine { x: 8.0; y: 13.8 }
                    PathLine { x: 4.2; y: 10.2 }
                    PathLine { x: 1.5; y: 10.2 }
                    PathLine { x: 1.5; y: 5.8 }
                }
            }

            Shape {
                anchors.fill: parent
                visible: !hwBubbleRoot.isVolMuted
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    strokeColor: hwBubbleRoot.isHovered ? "white" : Qt.rgba(1, 1, 1, 0.95)
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    startX: 10.5; startY: 5.5
                    PathArc { x: 10.5; y: 10.5; radiusX: 3.5; radiusY: 3.5; useLargeArc: false }
                }

                ShapePath {
                    strokeColor: hwBubbleRoot.isHovered ? "white" : Qt.rgba(1, 1, 1, 0.95)
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    startX: 13.2; startY: 3.5
                    PathArc { x: 13.2; y: 12.5; radiusX: 6.5; radiusY: 6.5; useLargeArc: false }
                }
            }

            Shape {
                anchors.fill: parent
                visible: hwBubbleRoot.isVolMuted
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    strokeColor: Theme.danger
                    strokeWidth: 1.6
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    startX: 10.8; startY: 6.0
                    PathLine { x: 14.8; y: 10.0 }
                    PathMove { x: 14.8; y: 6.0 }
                    PathLine { x: 10.8; y: 10.0 }
                }
            }
        }

        // 2. 手绘屏幕亮度
        Item {
            anchors.fill: parent
            visible: hwBubbleRoot.currentMode === 1

            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    fillColor: hwBubbleRoot.isHovered ? "white" : "#fbbf24"
                    strokeColor: "transparent"

                    startX: 8.0; startY: 4.8
                    PathArc { x: 8.0; y: 11.2; radiusX: 3.2; radiusY: 3.2; useLargeArc: false }
                    PathArc { x: 8.0; y: 4.8; radiusX: 3.2; radiusY: 3.2; useLargeArc: false }
                }

                ShapePath {
                    strokeColor: hwBubbleRoot.isHovered ? "white" : "#fbbf24"
                    strokeWidth: 1.4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    startX: 8.0; startY: 0.8
                    PathLine { x: 8.0; y: 2.8 }
                    PathMove { x: 8.0; y: 13.2 }
                    PathLine { x: 8.0; y: 15.2 }
                    PathMove { x: 0.8; y: 8.0 }
                    PathLine { x: 2.8; y: 8.0 }
                    PathMove { x: 13.2; y: 8.0 }
                    PathLine { x: 15.2; y: 8.0 }
                    PathMove { x: 2.9; y: 2.9 }
                    PathLine { x: 4.3; y: 4.3 }
                    PathMove { x: 13.1; y: 2.9 }
                    PathLine { x: 11.7; y: 4.3 }
                    PathMove { x: 2.9; y: 13.1 }
                    PathLine { x: 4.3; y: 11.7 }
                    PathMove { x: 13.1; y: 13.1 }
                    PathLine { x: 11.7; y: 11.7 }
                }
            }
        }

        // 3. 手绘麦克风
        Item {
            anchors.fill: parent
            visible: hwBubbleRoot.currentMode === 2

            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    fillColor: hwBubbleRoot.isMicMuted ? Qt.rgba(1, 1, 1, 0.45) : (hwBubbleRoot.isHovered ? "white" : "#c084fc")
                    strokeColor: "transparent"

                    startX: 5.8; startY: 3.5
                    PathArc { x: 10.2; y: 3.5; radiusX: 2.2; radiusY: 2.2; useLargeArc: false }
                    PathLine { x: 10.2; y: 7.5 }
                    PathArc { x: 5.8; y: 7.5; radiusX: 2.2; radiusY: 2.2; useLargeArc: false }
                    PathLine { x: 5.8; y: 3.5 }
                }

                ShapePath {
                    strokeColor: hwBubbleRoot.isMicMuted ? Qt.rgba(1, 1, 1, 0.45) : (hwBubbleRoot.isHovered ? "white" : "#c084fc")
                    strokeWidth: 1.4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    startX: 3.8; startY: 6.2
                    PathLine { x: 3.8; y: 7.4 }
                    PathArc { x: 12.2; y: 7.4; radiusX: 4.2; radiusY: 4.2; useLargeArc: false }
                    PathLine { x: 12.2; y: 6.2 }
                    PathMove { x: 8.0; y: 11.6 }
                    PathLine { x: 8.0; y: 14.5 }
                    PathMove { x: 5.2; y: 14.5 }
                    PathLine { x: 10.8; y: 14.5 }
                }
            }

            Shape {
                anchors.fill: parent
                visible: hwBubbleRoot.isMicMuted
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    strokeColor: Theme.danger
                    strokeWidth: 1.6
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    startX: 2.5; startY: 2.5
                    PathLine { x: 13.5; y: 13.5 }
                }
            }
        }
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            muteShakeAnimation.restart()
            hwBubbleRoot.resetActivity()
            hwBubbleRoot.toggleMuteTriggered(hwBubbleRoot.currentMode)
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            switchAnimation.restart()
            hwBubbleRoot.currentMode = (hwBubbleRoot.currentMode + 1) % 3
            hwBubbleRoot.resetActivity()
            hwBubbleRoot.modeChanged(hwBubbleRoot.currentMode)
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            event.accepted = true
            hwBubbleRoot.resetActivity()
            var delta = event.angleDelta.y > 0 ? 5 : -5
            hwBubbleRoot.wheelAdjusted(hwBubbleRoot.currentMode, delta)
        }
    }
}