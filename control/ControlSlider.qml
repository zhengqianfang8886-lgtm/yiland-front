import QtQuick

Rectangle {
    id: sliderRoot

    property int currentValue: 50
    property string iconType: "volume"
    property color activeColor: Qt.rgba(1, 1, 1, 0.22) // 默认高级透光微白
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
    color: Qt.rgba(1, 1, 1, 0.05)
    border.color: trackHover.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
    clip: true

    Behavior on border.color { ColorAnimation { duration: 120 } }

    // 🚀 通透微光磨砂流体填充（彻底告别土黄与脏蓝）
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.min(1.0, Math.max(0.0, sliderRoot.isMuted ? 0 : ((sliderRoot.currentValue - sliderRoot.minValue) / (sliderRoot.maxValue - sliderRoot.minValue))))
        radius: 13

        // 音量为水银微光冷白，亮度为极淡月光暖白，静音为珊瑚红微光
        color: sliderRoot.isMuted ?
               Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.35) :
               (sliderRoot.iconType === "brightness" ?
                Qt.rgba(254 / 255, 240 / 255, 138 / 255, 0.26) :
                Qt.rgba(1, 1, 1, 0.20))

        Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // 左侧图标
    Item {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14

        ControlCenterIcon {
            anchors.fill: parent
            iconType: sliderRoot.iconType
            iconColor: sliderRoot.isMuted ? Theme.danger : Qt.rgba(1, 1, 1, 0.88)
            isMuted: sliderRoot.isMuted
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sliderRoot.iconClicked()
        }
    }

    // 🚀 核心修复：font.pixelSize 规范为合法整数 10
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: sliderRoot.labelText ? sliderRoot.labelText : (sliderRoot.currentValue + "%")
        color: sliderRoot.isMuted ? Theme.danger : Qt.rgba(1, 1, 1, 0.85)
        font.family: (sliderRoot.chosenFont !== "") ? sliderRoot.chosenFont : "Monospace"
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 0.2
    }

    HoverHandler { id: trackHover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: (mouse) => {
            sliderRoot.interactionStarted()
            var ratio = Math.max(0.0, Math.min(1.0, mouse.x / parent.width))
            var target = Math.round(sliderRoot.minValue + ratio * (sliderRoot.maxValue - sliderRoot.minValue))
            sliderRoot.valueAdjusted(target - sliderRoot.currentValue)
        }
        onPositionChanged: (mouse) => {
            if (pressed) {
                sliderRoot.interactionStarted()
                var ratio = Math.max(0.0, Math.min(1.0, mouse.x / parent.width))
                var target = Math.round(sliderRoot.minValue + ratio * (sliderRoot.maxValue - sliderRoot.minValue))
                sliderRoot.valueAdjusted(target - sliderRoot.currentValue)
            }
        }
        onWheel: (wheel) => {
            wheel.accepted = true
            sliderRoot.interactionStarted()
            var step = sliderRoot.stepSize > 0 ? sliderRoot.stepSize : 5
            var delta = wheel.angleDelta.y > 0 ? step : -step
            sliderRoot.valueAdjusted(delta)
        }
    }
}