import QtQuick
import QtQuick.Shapes
import "control"

Rectangle {
    id: hwBubbleRoot

    readonly property string displayFont: (typeof Config !== "undefined") ? Config.numberFont : "Monospace"
    readonly property string textFont: (typeof Config !== "undefined") ? Config.activeFont : ""

    readonly property int dwellTime: (typeof Config !== "undefined" && Config.hoverDwellTime !== undefined) ? Config.hoverDwellTime : 240
    readonly property int leaveGraceTime: 200

    property bool active: true
    readonly property bool isHovered: bubbleHover.hovered

    // 🚀 底层硬件状态实时同步
    property int currentVolume: (typeof Bridge !== "undefined" && Bridge.currentVolume !== undefined) ? Bridge.currentVolume : 50
    property int currentBrightness: (typeof Bridge !== "undefined" && Bridge.currentBrightness !== undefined) ? Bridge.currentBrightness : 100
    property bool isVolMuted: false
    property bool isMicMuted: false

    property bool isExpanded: false
    property bool isInteracting: false

    signal modeChanged(int newMode)
    signal wheelAdjusted(int mode, int delta)
    signal toggleMuteTriggered(int mode)
    signal requestSettings()

    readonly property int collapsedWidth: 44
    readonly property int expandedWidth: 278
    readonly property int islandHeight: 34

    width: isExpanded ? expandedWidth : collapsedWidth
    height: islandHeight
    radius: 17
    clip: false
    transformOrigin: Item.Left

    color: Theme.bgCapsule
    border.width: 1.2
    border.color: isExpanded ?
                  Qt.rgba(1, 1, 1, 0.28) :
                  (hwBubbleRoot.isHovered ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.12))

    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    visible: active
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    Behavior on width {
        NumberAnimation {
            duration: Theme.animSpring
            easing.type: Easing.OutBack
            easing.overshoot: Theme.springOvershootSubtle
        }
    }
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: Theme.animSpring; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershootNormal } }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onHardwareMuteStateChanged(volMuted, micMuted) {
            hwBubbleRoot.isVolMuted = volMuted
            hwBubbleRoot.isMicMuted = micMuted
        }
        function onVolumeChanged(val) {
            hwBubbleRoot.currentVolume = val
        }
        function onBrightnessChanged(val) {
            hwBubbleRoot.currentBrightness = val
        }
        function onOsdTriggered(icon, label, val) {
            if (label === "Volume") hwBubbleRoot.currentVolume = val
            else if (label === "Display") hwBubbleRoot.currentBrightness = val
        }
    }

    Timer {
        id: hoverDwellTimer
        interval: hwBubbleRoot.dwellTime
        repeat: false
        onTriggered: {
            if (hwBubbleRoot.isHovered && !hwBubbleRoot.isExpanded) {
                hwBubbleRoot.isExpanded = true
            }
        }
    }

    Timer {
        id: mouseLeaveTimer
        interval: hwBubbleRoot.leaveGraceTime
        repeat: false
        onTriggered: {
            if (!hwBubbleRoot.isHovered && !hwBubbleRoot.isInteracting && hwBubbleRoot.isExpanded) {
                hwBubbleRoot.isExpanded = false
            }
        }
    }

    Timer {
        id: resetInteractTimer
        interval: 600
        repeat: false
        onTriggered: hwBubbleRoot.isInteracting = false
    }

    function resetActivity() {
        mouseLeaveTimer.stop()
        hwBubbleRoot.isInteracting = true
        resetInteractTimer.restart()
    }

    // =========================================================================
    // 1. 常态：控制中心双滑块图标（收起态）
    // =========================================================================
    Item {
        id: collapsedItem
        anchors.left: parent.left
        width: hwBubbleRoot.collapsedWidth
        height: parent.height
        visible: !hwBubbleRoot.isExpanded
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        Rectangle {
            anchors.centerIn: parent
            width: 24; height: 24; radius: 12
            color: hwBubbleRoot.isHovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
        }

        ControlCenterIcon {
            anchors.centerIn: parent
            width: 14; height: 14
            iconType: "controlCenter"
            iconColor: hwBubbleRoot.isHovered ? "white" : Qt.rgba(1, 1, 1, 0.82)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                hoverDwellTimer.stop()
                mouseLeaveTimer.stop()
                hwBubbleRoot.isExpanded = true
            }
        }
    }

    // =========================================================================
    // 2. 展开态：高级感轻量微光控制流
    // =========================================================================
    Row {
        id: expandedControlRow
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 5
        visible: hwBubbleRoot.isExpanded
        opacity: visible ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        // 组件 1：音量流体滑轨 (86px，高级透光白)
        ControlSlider {
            width: 86
            anchors.verticalCenter: parent.verticalCenter
            currentValue: hwBubbleRoot.currentVolume
            iconType: "volume"
            isMuted: hwBubbleRoot.isVolMuted
            labelText: hwBubbleRoot.isVolMuted ? "静音" : ""
            chosenFont: hwBubbleRoot.isVolMuted ? hwBubbleRoot.textFont : hwBubbleRoot.displayFont
            onValueAdjusted: (delta) => hwBubbleRoot.wheelAdjusted(0, delta)
            onIconClicked: hwBubbleRoot.toggleMuteTriggered(0)
            onInteractionStarted: hwBubbleRoot.resetActivity()
        }

        // 组件 2：屏幕亮度流体滑轨 (76px，淡香槟微暖白)
        ControlSlider {
            width: 76
            anchors.verticalCenter: parent.verticalCenter
            currentValue: hwBubbleRoot.currentBrightness
            iconType: "brightness"
            chosenFont: hwBubbleRoot.displayFont
            minValue: 5
            onValueAdjusted: (delta) => hwBubbleRoot.wheelAdjusted(1, delta)
            onInteractionStarted: hwBubbleRoot.resetActivity()
        }

        // 组件 3：麦克风胶囊键 (常态保持冷白低调，仅静音时珊瑚红警示)
        Rectangle {
            width: 26; height: 26; radius: 13
            anchors.verticalCenter: parent.verticalCenter
            color: micTap.pressed ? Qt.rgba(1, 1, 1, 0.22) :
                   (hwBubbleRoot.isMicMuted ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.24) :
                   (micHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)))
            border.color: hwBubbleRoot.isMicMuted ? Theme.danger : (micHover.hovered ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.08))
            border.width: 1
            scale: micTap.pressed ? 0.92 : 1.0

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            ControlCenterIcon {
                anchors.centerIn: parent
                width: 12; height: 12
                iconType: "mic"
                iconColor: hwBubbleRoot.isMicMuted ? Theme.danger : Qt.rgba(1, 1, 1, 0.85)
                isMuted: hwBubbleRoot.isMicMuted
            }

            HoverHandler { id: micHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: micTap
                onTapped: {
                    hwBubbleRoot.resetActivity()
                    hwBubbleRoot.toggleMuteTriggered(2)
                }
            }
        }

        // 组件 4：偏好设置按键 (纯净磨砂圆钮)
        Rectangle {
            width: 26; height: 26; radius: 13
            anchors.verticalCenter: parent.verticalCenter
            color: setTap.pressed ? Qt.rgba(1, 1, 1, 0.22) : (setHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
            border.color: setHover.hovered ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            scale: setTap.pressed ? 0.92 : 1.0

            Behavior on color { ColorAnimation { duration: 120 } }

            ControlCenterIcon {
                anchors.centerIn: parent
                width: 12; height: 12
                iconType: "settings"
                iconColor: setHover.hovered ? "white" : Qt.rgba(1, 1, 1, 0.75)
            }

            HoverHandler { id: setHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: setTap
                onTapped: {
                    hwBubbleRoot.isExpanded = false
                    hwBubbleRoot.requestSettings()
                }
            }
        }

        // 组件 5：纯矢量收起微胶囊按键
        Rectangle {
            width: 20; height: 26; radius: 10
            anchors.verticalCenter: parent.verticalCenter
            color: collapseTap.pressed ? Qt.rgba(1, 1, 1, 0.18) : (collapseHover.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent")
            scale: collapseTap.pressed ? 0.92 : 1.0

            Behavior on color { ColorAnimation { duration: 120 } }

            ControlCenterIcon {
                anchors.centerIn: parent
                width: 10; height: 10
                iconType: "chevron"
                iconColor: collapseHover.hovered ? "white" : Qt.rgba(1, 1, 1, 0.55)
            }

            HoverHandler { id: collapseHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: collapseTap
                onTapped: {
                    hoverDwellTimer.stop()
                    hwBubbleRoot.isExpanded = false
                }
            }
        }
    }

    HoverHandler {
        id: bubbleHover
        cursorShape: hwBubbleRoot.isExpanded ? Qt.ArrowCursor : Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered) {
                mouseLeaveTimer.stop()
                if (!hwBubbleRoot.isExpanded) {
                    hoverDwellTimer.restart()
                }
            } else {
                hoverDwellTimer.stop()
                if (hwBubbleRoot.isExpanded) {
                    mouseLeaveTimer.restart()
                }
            }
        }
    }
}