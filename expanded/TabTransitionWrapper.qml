import QtQuick

Item {
    id: wrapper
    anchors.fill: parent

    // 状态控制
    property bool active: false
    property int slideDirection: 1       // +1: 从右入, -1: 从左入, 0: 原地景深微浮现
    property bool isFastWheeling: false  // 快速连滚状态标志
    property real offsetDistance: 26     // 微视差位移距离 (px)

    // 默认把所有子组件装载到本容器内部
    default property alias content: wrapper.data

    // GPU 剔除：透明度趋近于 0 时彻底关闭可见性，不占任何渲染流水线
    visible: opacity > 0.001
    clip: true

    // =========================================================================
    // 1. 进场动效：柔和、弹簧微回弹（OutBack 1.06）、空间感充盈
    // =========================================================================
    ParallelAnimation {
        id: enterAnim

        NumberAnimation {
            target: wrapper
            property: "x"
            to: 0
            duration: wrapper.isFastWheeling ? 110 : 190
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: wrapper
            property: "scale"
            from: 0.95
            to: 1.0
            duration: wrapper.isFastWheeling ? 110 : 210
            easing.type: wrapper.isFastWheeling ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: wrapper.isFastWheeling ? 1.0 : 1.06
        }

        NumberAnimation {
            target: wrapper
            property: "opacity"
            to: 1.0
            duration: wrapper.isFastWheeling ? 90 : 160
            easing.type: Easing.OutQuad
        }
    }

    // =========================================================================
    // 2. 退场动效：快速、决绝（85ms）、绝不拖泥带水
    // =========================================================================
    ParallelAnimation {
        id: exitAnim

        NumberAnimation {
            target: wrapper
            property: "x"
            to: (wrapper.slideDirection === 0) ? 0 : (-wrapper.slideDirection * (wrapper.offsetDistance * 0.75))
            duration: wrapper.isFastWheeling ? 50 : 90
            easing.type: Easing.InQuad
        }

        NumberAnimation {
            target: wrapper
            property: "scale"
            to: 0.96
            duration: wrapper.isFastWheeling ? 50 : 90
            easing.type: Easing.InQuad
        }

        NumberAnimation {
            target: wrapper
            property: "opacity"
            to: 0.0
            duration: wrapper.isFastWheeling ? 45 : 85
            easing.type: Easing.OutQuad
        }
    }

    // 核心物理位姿重置：激活瞬间将元素归位到待入场边缘，杜绝任何位移突跳
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