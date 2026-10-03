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

    // 下拉展开状态机
    property bool isExpanded: false

    signal modeChanged(int newMode)
    signal wheelAdjusted(int mode, int delta)
    signal toggleMuteTriggered(int mode)
    
    // 🚀 新增拉起设置界面信号
    signal requestSettings()

    readonly property int collapsedHeight: 34
    // 4 阶槽位（音量、亮度、麦克风、设置）黄金高度
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

    // 统一 Spring 物理动效
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
        if (currentMode === 0) return isVolMuted
        if (currentMode === 2) return isMicMuted
        return false
    }

    // 鼠标移出胶囊 240ms 自动平滑收起关闭
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

    // 展开状态下无操作超时兜底
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
            width: 16
            height: 16

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
    // 2. 纵向长胶囊展开流（支持滚轮滑动与无限扩展槽位）
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

            // 插槽 1：音量控制 (Mode 0)
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
                    width: 16
                    height: 16
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

            // 插槽 2：屏幕亮度 (Mode 1)
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

            // 插槽 3：麦克风控制 (Mode 2)
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

            // =================================================================
            // 🚀 插槽 4：设置界面专属触控槽位（自动展示点击，一键调出设置）
            // =================================================================
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

    // 滚动下滑指示器
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
    // 3. 矢量图标组件库
    // =========================================================================

    // 音量组件
    Component {
        id: volumeIconComp
        Item {
            anchors.fill: parent
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
                    startY: 5.8
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
                    strokeColor: "white"
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 10.5
                    startY: 5.5
                    PathArc { x: 10.5; y: 10.5; radiusX: 3.5; radiusY: 3.5; useLargeArc: false }
                }
                ShapePath {
                    strokeColor: "white"
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 13.2
                    startY: 3.5
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
                    startX: 10.8
                    startY: 6.0
                    PathLine { x: 14.8; y: 10.0 }
                    PathMove { x: 14.8; y: 6.0 }
                    PathLine { x: 10.8; y: 10.0 }
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

    // 收起状态下的全局快捷操作
    TapHandler {
        enabled: !hwBubbleRoot.isExpanded
        acceptedButtons: Qt.LeftButton
        onTapped: hwBubbleRoot.toggleMuteTriggered(hwBubbleRoot.currentMode)
    }

    // 右键一键切换“纵向长胶囊展开 / 收起”
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            hwBubbleRoot.isExpanded = !hwBubbleRoot.isExpanded
            hwBubbleRoot.resetActivity()
        }
    }

    // 收起状态下的快捷滚轮调节
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