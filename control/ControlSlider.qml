import QtQuick

Rectangle {
    id: sliderRoot

    property int currentValue: 50
    property string iconType: "volume"
    property color activeColor: Theme.bluetooth
    property bool isMuted: false
    property string labelText: ""
    property string chosenFont: ""
    property int minValue: 0
    property int maxValue: 100

    signal valueAdjusted(int delta)
    signal iconClicked()
    signal interactionStarted()

    // 🚀 高度设为 25px，在 34px 小岛中上下留白舒适自然
    height: 25
    radius: 12.5
    color: Qt.rgba(1, 1, 1, 0.06)
    border.color: trackHover.hovered ? Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.45) : Qt.rgba(1, 1, 1, 0.1)
    border.width: 1
    clip: true

    // 流体填充条
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.min(1.0, Math.max(0.0, sliderRoot.isMuted ? 0 : ((sliderRoot.currentValue - sliderRoot.minValue) / (sliderRoot.maxValue - sliderRoot.minValue))))
        radius: 12.5
        color: sliderRoot.isMuted ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.35) : Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.35)
        Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
    }

    // 左侧图标
    Item {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14

        ControlCenterIcon {
            anchors.fill: parent
            iconType: sliderRoot.iconType
            iconColor: sliderRoot.isMuted ? Theme.danger : "white"
            isMuted: sliderRoot.isMuted
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sliderRoot.iconClicked()
        }
    }

    // 右侧百分比读数
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: sliderRoot.labelText ? sliderRoot.labelText : (sliderRoot.currentValue + "%")
        color: sliderRoot.isMuted ? Theme.danger : "white"
        font.family: (sliderRoot.chosenFont !== "") ? sliderRoot.chosenFont : "Monospace"
        font.pixelSize: 10
        font.weight: Font.Black
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
            var delta = wheel.angleDelta.y > 0 ? 5 : -5
            sliderRoot.valueAdjusted(delta)
        }
    }
}