import QtQuick
import QtQuick.Shapes

Rectangle {
    id: hwBubbleRoot

    property bool active: true
    readonly property bool isHovered: bubbleHover.hovered

    // 0: 音量 (Volume) | 1: 屏幕亮度 (Brightness) | 2: 麦克风 (Microphone)
    property int currentMode: 0

    // 状态缓存与当前音量读数
    property int currentVolume: (typeof Bridge !== "undefined" && Bridge.currentVolume !== undefined) ? Bridge.currentVolume : 50
    property bool isVolMuted: false
    property bool isMicMuted: false

    // 下拉展开状态机
    property bool isExpanded: false

    signal modeChanged(int newMode)
    signal wheelAdjusted(int mode, int delta)
    signal toggleMuteTriggered(int mode)
    signal requestSettings()

    readonly property int collapsedHeight: 34
    readonly property int expandedHeight: 152

    width: 44
    height: isExpanded ? expandedHeight : collapsedHeight
    radius: isExpanded ? 22 : 17
    clip: true
    transformOrigin: Item.Top

    color: Theme.bgCapsule
    border.width: 1
    border.color: isExpanded ?
                  Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.75) :
                  (hwBubbleRoot.isHovered ?
                  Qt.rgba(currentThemeColor.r, currentThemeColor.g, currentThemeColor.b, 0.85) :
                  (isCurrentMuted ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.6) : Qt.rgba(currentThemeColor.r, currentThemeColor.g, currentThemeColor.b, 0.35)))
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    visible: active
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    Behavior on height {
        NumberAnimation {
            duration: Theme.animSpring
            easing.type: Easing.OutBack
            easing.overshoot: Theme.springOvershootSubtle
        }
    }
    Behavior on radius { NumberAnimation { duration: Theme.animFast } }
    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: Theme.animSpring; easing.type: Easing.OutBack; easing.overshoot: Theme.springOvershootNormal } }

    readonly property color currentThemeColor: {
        if (currentMode === 0) return Theme.bluetooth
        if (currentMode === 1) return Theme.clock
        return Theme.workspace
    }

    readonly property bool isCurrentMuted: {
        if (currentMode === 0) return isVolMuted || currentVolume === 0
        if (currentMode === 2) return isMicMuted
        return false
    }

    // 监听底层硬件变化（OSD 与 静音）
    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onHardwareMuteStateChanged(volMuted, micMuted) {
            hwBubbleRoot.isVolMuted = volMuted
            hwBubbleRoot.isMicMuted = micMuted
        }
        function onOsdTriggered(icon, label, val) {
            if (label === "Volume") {
                hwBubbleRoot.currentVolume = val
            }
        }
    }

    Timer {
        id: mouseLeaveTimer
        interval: 240
        repeat: false
        onTriggered: {
            if (!hwBubbleRoot.isHovered && hwBubbleRoot.isExpanded) {
                hwBubbleRoot.isExpanded = false
            }
        }
    }

    Timer {
        id: autoCollapseTimer
        interval: 8000
        repeat: false
        onTriggered: hwBubbleRoot.isExpanded = false
    }

    function resetActivity() {
        mouseLeaveTimer.stop()
        if (hwBubbleRoot.isExpanded) {
            autoCollapseTimer.restart()
        }
    }

    // =========================================================================
    // 1. 常态单一微药丸视图（收起状态）
    // =========================================================================
    Item {
        id: collapsedItem
        anchors.top: parent.top
        width: parent.width
        height: hwBubbleRoot.collapsedHeight
        visible: !hwBubbleRoot.isExpanded
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        Rectangle {
            anchors.centerIn: parent
            width: 24
            height: 24
            radius: 12
            color: hwBubbleRoot.isCurrentMuted ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.22) : Qt.rgba(currentThemeColor.r, currentThemeColor.g, currentThemeColor.b, 0.16)
        }

        Item {
            anchors.centerIn: parent
            // 🚀 核心升级为 18×18，确保 3 道声波拥有完整呼吸空间
            width: 18
            height: 18

            Loader {
                anchors.fill: parent
                active: hwBubbleRoot.currentMode === 0
                sourceComponent: volumeIconComp
            }
            Loader {
                anchors.fill: parent
                active: hwBubbleRoot.currentMode === 1
                sourceComponent: brightnessIconComp
            }
            Loader {
                anchors.fill: parent
                active: hwBubbleRoot.currentMode === 2
                sourceComponent: micIconComp
            }
        }
    }

    // =========================================================================
    // 2. 纵向长胶囊展开流
    // =========================================================================
    Flickable {
        id: scrollContainer
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        visible: hwBubbleRoot.isExpanded
        opacity: visible ? 1.0 : 0.0
        clip: true

        contentWidth: width
        contentHeight: slotColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        Column {
            id: slotColumn
            width: parent.width
            spacing: 4

            // 插槽 1：音量控制
            Rectangle {
                width: 36
                height: 32
                radius: 16
                anchors.horizontalCenter: parent.horizontalCenter
                color: volHover.hovered ? Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.25) : "transparent"
                border.color: volHover.hovered ? Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.4) : "transparent"
                border.width: 1
                scale: volTap.pressed ? 0.92 : (volHover.hovered ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                Behavior on color { ColorAnimation { duration: Theme.animInstant } }

                Item {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    Loader { anchors.fill: parent; sourceComponent: volumeIconComp }
                }

                HoverHandler { id: volHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: volTap
                    acceptedButtons: Qt.LeftButton
                    onTapped: {
                        hwBubbleRoot.resetActivity()
                        hwBubbleRoot.currentMode = 0
                        hwBubbleRoot.toggleMuteTriggered(0)
                    }
                }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        event.accepted = true
                        hwBubbleRoot.resetActivity()
                        hwBubbleRoot.currentMode = 0
                        var step = (typeof Config !== "undefined" && Config.volumeStep !== undefined) ? Config.volumeStep : 5
                        var delta = event.angleDelta.y > 0 ? step : -step
                        hwBubbleRoot.wheelAdjusted(0, delta)
                    }
                }
            }

            // 插槽 2：屏幕亮度
            Rectangle {
                width: 36
                height: 32
                radius: 16
                anchors.horizontalCenter: parent.horizontalCenter
                color: brightHover.hovered ? Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.25) : "transparent"
                border.color: brightHover.hovered ? Qt.rgba(Theme.clock.r, Theme.clock.g, Theme.clock.b, 0.4) : "transparent"
                border.width: 1
                scale: brightTap.pressed ? 0.92 : (brightHover.hovered ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                Behavior on color { ColorAnimation { duration: Theme.animInstant } }

                Item {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    Loader { anchors.fill: parent; sourceComponent: brightnessIconComp }
                }

                HoverHandler { id: brightHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: brightTap
                    acceptedButtons: Qt.LeftButton
                    onTapped: {
                        hwBubbleRoot.resetActivity()
                        hwBubbleRoot.currentMode = 1
                        hwBubbleRoot.toggleMuteTriggered(1)
                    }
                }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        event.accepted = true
                        hwBubbleRoot.resetActivity()
                        hwBubbleRoot.currentMode = 1
                        var delta = event.angleDelta.y > 0 ? 5 : -5
                        hwBubbleRoot.wheelAdjusted(1, delta)
                    }
                }
            }

            // 插槽 3：麦克风控制
            Rectangle {
                width: 36
                height: 32
                radius: 16
                anchors.horizontalCenter: parent.horizontalCenter
                color: micHover.hovered ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.25) : "transparent"
                border.color: micHover.hovered ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.4) : "transparent"
                border.width: 1
                scale: micTap.pressed ? 0.92 : (micHover.hovered ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                Behavior on color { ColorAnimation { duration: Theme.animInstant } }

                Item {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    Loader { anchors.fill: parent; sourceComponent: micIconComp }
                }

                HoverHandler { id: micHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: micTap
                    acceptedButtons: Qt.LeftButton
                    onTapped: {
                        hwBubbleRoot.resetActivity()
                        hwBubbleRoot.currentMode = 2
                        hwBubbleRoot.toggleMuteTriggered(2)
                    }
                }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        event.accepted = true
                        hwBubbleRoot.resetActivity()
                        hwBubbleRoot.currentMode = 2
                        var delta = event.angleDelta.y > 0 ? 5 : -5
                        hwBubbleRoot.wheelAdjusted(2, delta)
                    }
                }
            }

            // 插槽 4：设置界面
            Rectangle {
                width: 36
                height: 32
                radius: 16
                anchors.horizontalCenter: parent.horizontalCenter
                color: setHover.hovered ? Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.3) : Qt.rgba(1, 1, 1, 0.06)
                border.color: setHover.hovered ? Theme.workspace : Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                scale: setTap.pressed ? 0.90 : (setHover.hovered ? 1.06 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                Behavior on color { ColorAnimation { duration: Theme.animInstant } }

                Text {
                    anchors.centerIn: parent
                    text: "⚙"
                    font.pixelSize: 15
                    color: setHover.hovered ? "white" : Qt.rgba(1, 1, 1, 0.75)
                    Behavior on color { ColorAnimation { duration: Theme.animInstant } }
                }

                HoverHandler { id: setHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: setTap
                    acceptedButtons: Qt.LeftButton
                    onTapped: {
                        hwBubbleRoot.isExpanded = false
                        hwBubbleRoot.requestSettings()
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        anchors.horizontalCenter: parent.horizontalCenter
        width: 12
        height: 2
        radius: 1
        color: Qt.rgba(1, 1, 1, 0.3)
        visible: hwBubbleRoot.isExpanded && (scrollContainer.contentHeight > scrollContainer.height)
    }

    // =========================================================================
    // 3. 矢量图标组件库（精密同心圆声波，绝对不切角）
    // =========================================================================

    Component {
        id: volumeIconComp
        Item {
            anchors.fill: parent

            readonly property bool isMutedState: hwBubbleRoot.isVolMuted || hwBubbleRoot.currentVolume <= 0

            // 0: 静音, 1: 低音量 (1~33%), 2: 中音量 (34~66%), 3: 高音量 (67~100%)
            readonly property int volLevel: {
                if (isMutedState) return 0
                if (hwBubbleRoot.currentVolume <= 33) return 1
                if (hwBubbleRoot.currentVolume <= 66) return 2
                return 3
            }

            // 1. 喇叭锥体底座 (18x18 严格居中校准)
            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    fillColor: hwBubbleRoot.isVolMuted ? Theme.danger : "white"
                    strokeColor: hwBubbleRoot.isVolMuted ? Theme.danger : "white"
                    strokeWidth: 0.8
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    startX: 1.5
                    startY: 6.5
                    PathLine { x: 4.5; y: 6.5 }
                    PathLine { x: 8.5; y: 3.0 }
                    PathLine { x: 8.5; y: 15.0 }
                    PathLine { x: 4.5; y: 11.5 }
                    PathLine { x: 1.5; y: 11.5 }
                    PathLine { x: 1.5; y: 6.5 }
                }
            }

            // 2. 声波 1（微弧，半径 5.5，绝不溢出）
            Shape {
                anchors.fill: parent
                visible: !isMutedState
                opacity: volLevel >= 1 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 90 } }
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeColor: "white"
                    strokeWidth: 1.4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 10.2
                    startY: 6.1
                    PathArc { x: 10.2; y: 11.9; radiusX: 5.5; radiusY: 5.5; useLargeArc: false }
                }
            }

            // 3. 声波 2（中弧，半径 8.0，同心对称）
            Shape {
                anchors.fill: parent
                visible: !isMutedState
                opacity: volLevel >= 2 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 90 } }
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeColor: "white"
                    strokeWidth: 1.4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 12.1
                    startY: 4.5
                    PathArc { x: 12.1; y: 13.5; radiusX: 8.0; radiusY: 8.0; useLargeArc: false }
                }
            }

            // 4. 声波 3（大弧，半径 10.5，最高点 x=16.0 距边界留 2px 安全裕量，绝对圆润完整）
            Shape {
                anchors.fill: parent
                visible: !isMutedState
                opacity: volLevel >= 3 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 90 } }
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeColor: "white"
                    strokeWidth: 1.4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 14.0
                    startY: 2.8
                    PathArc { x: 14.0; y: 15.2; radiusX: 10.5; radiusY: 10.5; useLargeArc: false }
                }
            }

            // 5. 静音叉号 ✕（静音态或 0% 时清晰居中）
            Shape {
                anchors.fill: parent
                visible: isMutedState
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeColor: hwBubbleRoot.isVolMuted ? Theme.danger : Qt.rgba(1, 1, 1, 0.6)
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 11.0
                    startY: 6.5
                    PathLine { x: 15.5; y: 11.5 }
                    PathMove { x: 15.5; y: 6.5 }
                    PathLine { x: 11.0; y: 11.5 }
                }
            }
        }
    }

    // 屏幕亮度组件
    Component {
        id: brightnessIconComp
        Item {
            anchors.fill: parent
            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    fillColor: "#fbbf24"
                    strokeColor: "transparent"
                    startX: 8.0
                    startY: 4.8
                    PathArc { x: 8.0; y: 11.2; radiusX: 3.2; radiusY: 3.2; useLargeArc: false }
                    PathArc { x: 8.0; y: 4.8; radiusX: 3.2; radiusY: 3.2; useLargeArc: false }
                }

                ShapePath {
                    strokeColor: "#fbbf24"
                    strokeWidth: 1.4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    startX: 8.0
                    startY: 0.8
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
    }

    // 麦克风组件
    Component {
        id: micIconComp
        Item {
            anchors.fill: parent
            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    fillColor: hwBubbleRoot.isMicMuted ? Qt.rgba(1, 1, 1, 0.45) : "#c084fc"
                    strokeColor: "transparent"
                    startX: 5.8
                    startY: 3.5
                    PathArc { x: 10.2; y: 3.5; radiusX: 2.2; radiusY: 2.2; useLargeArc: false }
                    PathLine { x: 10.2; y: 7.5 }
                    PathArc { x: 5.8; y: 7.5; radiusX: 2.2; radiusY: 2.2; useLargeArc: false }
                    PathLine { x: 5.8; y: 3.5 }
                }

                ShapePath {
                    strokeColor: hwBubbleRoot.isMicMuted ? Qt.rgba(1, 1, 1, 0.45) : "#c084fc"
                    strokeWidth: 1.4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    startX: 3.8
                    startY: 6.2
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

                    startX: 2.5
                    startY: 2.5
                    PathLine { x: 13.5; y: 13.5 }
                }
            }
        }
    }

    HoverHandler {
        id: bubbleHover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered) {
                hwBubbleRoot.resetActivity()
            } else {
                if (hwBubbleRoot.isExpanded) {
                    mouseLeaveTimer.restart()
                }
            }
        }
    }

    TapHandler {
        enabled: !hwBubbleRoot.isExpanded
        acceptedButtons: Qt.LeftButton
        onTapped: hwBubbleRoot.toggleMuteTriggered(hwBubbleRoot.currentMode)
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            hwBubbleRoot.isExpanded = !hwBubbleRoot.isExpanded
            hwBubbleRoot.resetActivity()
        }
    }

    WheelHandler {
        enabled: !hwBubbleRoot.isExpanded
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            event.accepted = true
            var step = (hwBubbleRoot.currentMode === 0 && typeof Config !== "undefined" && Config.volumeStep !== undefined) ? Config.volumeStep : 5
            var delta = event.angleDelta.y > 0 ? step : -step
            hwBubbleRoot.wheelAdjusted(hwBubbleRoot.currentMode, delta)
        }
    }
}