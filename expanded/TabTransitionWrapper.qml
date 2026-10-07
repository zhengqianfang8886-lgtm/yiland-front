// ==========================================
// 📄 File: expanded/TabTransitionWrapper.qml (动量接管转场包装器)
// ==========================================
import QtQuick

Item {
    id: wrapper
    anchors.fill: parent

    property bool active: false
    property int slideDirection: 1
    property bool isFastWheeling: false
    property real offsetDistance: 26

    default property alias content: wrapper.data

    visible: opacity > 0.001
    clip: true

    // 1. 进场动效
    ParallelAnimation {
        id: enterAnim

        NumberAnimation {
            target: wrapper
            property: "x"
            to: 0
            duration: wrapper.isFastWheeling ? Theme.animFast : Theme.animNormal
            easing.type: Theme.curveDecel
        }

        NumberAnimation {
            target: wrapper
            property: "scale"
            from: 0.95
            to: 1.0
            duration: wrapper.isFastWheeling ? Theme.animFast : Theme.animNormal
            easing.type: wrapper.isFastWheeling ? Theme.curveDecel : Theme.curveSpring
            easing.overshoot: wrapper.isFastWheeling ? 1.0 : Theme.springOvershootSubtle
        }

        NumberAnimation {
            target: wrapper
            property: "opacity"
            to: 1.0
            duration: wrapper.isFastWheeling ? Theme.animInstant : Theme.animFast
            easing.type: Theme.curveFluid
        }
    }

    // 2. 退场动效
    ParallelAnimation {
        id: exitAnim

        NumberAnimation {
            target: wrapper
            property: "x"
            to: (wrapper.slideDirection === 0) ? 0 : (-wrapper.slideDirection * (wrapper.offsetDistance * 0.75))
            duration: wrapper.isFastWheeling ? Theme.animInstant : Theme.animFast
            easing.type: Easing.InQuad
        }

        NumberAnimation {
            target: wrapper
            property: "scale"
            to: 0.96
            duration: wrapper.isFastWheeling ? Theme.animInstant : Theme.animFast
            easing.type: Easing.InQuad
        }

        NumberAnimation {
            target: wrapper
            property: "opacity"
            to: 0.0
            duration: wrapper.isFastWheeling ? (Theme.animInstant * 0.7) : Theme.animFast
            easing.type: Theme.curveFluid
        }
    }

    onActiveChanged: {
        if (active) {
            exitAnim.stop()
            wrapper.x = (slideDirection === 0) ? 0 : (slideDirection * offsetDistance)
            wrapper.scale = 0.95
            wrapper.opacity = 0.0
            enterAnim.restart()
        } else {
            enterAnim.stop()
            exitAnim.restart()
        }
    }

    Component.onCompleted: {
        if (active) {
            wrapper.x = 0
            wrapper.scale = 1.0
            wrapper.opacity = 1.0
        } else {
            wrapper.opacity = 0.0
            wrapper.scale = 0.96
        }
    }
}