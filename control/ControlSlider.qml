// ==========================================
// 📄 File: control/ControlSlider.qml
// ==========================================
import QtQuick

Rectangle {
    id: sliderRoot

    property int currentValue: 50
    property string iconType: "volume" // "volume" | "brightness"
    property bool isMuted: false
    property string labelText: ""
    property string chosenFont: ""
    property int minValue: 0
    property int maxValue: 100

    property int stepSize: (iconType === "volume" && typeof Config !== "undefined" && Config.volumeStep !== undefined) ? Config.volumeStep : 5

    signal valueAdjusted(int delta)
    signal iconClicked()
    signal interactionStarted()

    height: 26
    radius: 13
    clip: true

    // 半透明极简外底槽
    color: trackHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
    border.color: trackHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(1, 1, 1, 0.09)
    border.width: 1

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    // 进度比例 (0.0 ~ 1.0)
    readonly property real progressRatio: {
        if (sliderRoot.isMuted) return 0.0
        var span = sliderRoot.maxValue - sliderRoot.minValue
        if (span <= 0) return 0.0
        return Math.min(1.0, Math.max(0.0, (sliderRoot.currentValue - sliderRoot.minValue) / span))
    }

    readonly property color accentColor: {
        if (sliderRoot.isMuted) return Theme.danger
        if (sliderRoot.iconType === "brightness") return "#fbbf24" // 日光金
        return "#38bdf8" // 科技电光蓝
    }

    // =========================================================================
    // 1. 左侧：紧凑型图标 + 数值胶囊组合（大幅腾出右侧滑轨空间！）
    // =========================================================================
    Row {
        id: leftMetaRow
        anchors.left: parent.left
        anchors.leftMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Item {
            width: 13; height: 13
            anchors.verticalCenter: parent.verticalCenter

            ControlCenterIcon {
                anchors.fill: parent
                iconType: sliderRoot.iconType
                iconColor: sliderRoot.isMuted ? Theme.danger : (trackHover.hovered ? "white" : Qt.rgba(1, 1, 1, 0.85))
                isMuted: sliderRoot.isMuted
            }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: sliderRoot.iconClicked()
            }
        }

        Text {
            id: valText
            text: sliderRoot.labelText ? sliderRoot.labelText : (sliderRoot.currentValue + "%")
            color: sliderRoot.isMuted ? Theme.danger : (trackHover.hovered ? "white" : Qt.rgba(1, 1, 1, 0.85))
            font.family: (sliderRoot.chosenFont !== "") ? sliderRoot.chosenFont : "Monospace"
            font.pixelSize: 9
            font.weight: Font.Bold
            renderType: Text.QtRendering
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // =========================================================================
    // 2. 右侧：超长开阔滑动区（行程提升至 50~65px！）
    // =========================================================================
    Item {
        id: trackArea
        anchors.left: leftMetaRow.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        // 2.1 底层微光导轨
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 3
            radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.16)
        }

        // 2.2 激活高亮进度线
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: 3
            radius: 1.5
            width: Math.round(trackArea.width * sliderRoot.progressRatio)
            color: sliderRoot.accentColor

            Behavior on width {
                enabled: !dragMouse.pressed
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }
        }

        // 2.3 纯白圆形滑块手柄 (Thumb)
        Rectangle {
            id: thumbKnob
            width: 10; height: 10; radius: 5
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(trackArea.width - width, Math.round(trackArea.width * sliderRoot.progressRatio - width / 2)))

            color: "#ffffff"
            border.color: Qt.rgba(0, 0, 0, 0.3)
            border.width: 0.8

            scale: dragMouse.pressed ? 1.3 : (trackHover.hovered ? 1.15 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on x {
                enabled: !dragMouse.pressed
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }
        }
    }

    HoverHandler { id: trackHover }

    // =========================================================================
    // 3. 全局热区捕获：点哪跟哪，拖哪走哪，滚轮顺滑
    // =========================================================================
    MouseArea {
        id: dragMouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onPressed: (mouse) => {
            sliderRoot.interactionStarted()
            updateValue(mouse.x)
        }
        onPositionChanged: (mouse) => {
            if (pressed) {
                sliderRoot.interactionStarted()
                updateValue(mouse.x)
            }
        }
        onWheel: (wheel) => {
            wheel.accepted = true
            sliderRoot.interactionStarted()
            var delta = wheel.angleDelta.y > 0 ? sliderRoot.stepSize : -sliderRoot.stepSize
            sliderRoot.valueAdjusted(delta)
        }

        function updateValue(mouseX) {
            // 精确换算到 trackArea 的有效物理行程内
            var localX = mouseX - trackArea.x
            var ratio = Math.max(0.0, Math.min(1.0, localX / trackArea.width))
            var target = Math.round(sliderRoot.minValue + ratio * (sliderRoot.maxValue - sliderRoot.minValue))
            sliderRoot.valueAdjusted(target - sliderRoot.currentValue)
        }
    }
}