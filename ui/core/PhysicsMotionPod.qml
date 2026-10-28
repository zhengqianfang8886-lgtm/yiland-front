// =========================================================================
// 📄 File: ui/core/PhysicsMotionPod.qml
// 🌟 纯正流体动力学引擎 (苹果级 OutQuint 五次方丝滑水滴版)
// =========================================================================
import QtQuick

Item {
    id: pod

    y: 8
    width: 200
    height: 44

    property real targetY: 8
    property real targetWidth: 200
    property real targetHeight: 44
    property real targetRadius: 22

    readonly property int currentY: Math.round(pod.y)
    readonly property int currentWidth: Math.round(pod.width)
    readonly property int currentHeight: Math.round(pod.height)
    property real currentRadius: targetRadius

    readonly property bool isMoving: emergePipelineAnim.running || unifiedMotionAnim.running

    readonly property bool isJelly: (typeof Theme !== "undefined") ? Theme.isJellyMode : false
    
    // 🚀 核心流体参数：340ms 黄金时长 + OutQuint 极长尾缓出
    readonly property int motionDuration: isJelly ? 380 : 340
    readonly property var fluidCurve: Easing.OutQuint
    readonly property real springOvershoot: (typeof Theme !== "undefined") ? Theme.springOvershootFirm : 1.10

    signal motionStarted()
    signal motionSettled()

    onIsMovingChanged: {
        if (isMoving) motionStarted();
        else motionSettled();
    }

    SequentialAnimation {
        id: emergePipelineAnim

        ParallelAnimation {
            NumberAnimation { target: pod; property: "y"; to: pod.targetY; duration: 90; easing.type: Easing.OutCubic }
            NumberAnimation { target: pod; property: "currentRadius"; to: 18; duration: 90 }
        }

        ParallelAnimation {
            NumberAnimation {
                target: pod; property: "width"; to: pod.targetWidth
                duration: pod.motionDuration
                easing.type: pod.isJelly ? Easing.OutBack : pod.fluidCurve
                easing.overshoot: pod.springOvershoot
            }
            NumberAnimation {
                target: pod; property: "height"; to: pod.targetHeight
                duration: pod.motionDuration
                easing.type: pod.isJelly ? Easing.OutBack : pod.fluidCurve
                easing.overshoot: pod.isJelly ? 1.08 : 1.0
            }
            NumberAnimation { target: pod; property: "currentRadius"; to: pod.targetRadius; duration: pod.motionDuration; easing.type: pod.fluidCurve }
        }
    }

    // 🚀【标准单调统一运动管线：纯正流体塌缩/舒展】
    ParallelAnimation {
        id: unifiedMotionAnim

        NumberAnimation {
            id: animY; target: pod; property: "y"
            duration: pod.motionDuration; easing.type: pod.fluidCurve
        }
        NumberAnimation {
            id: animW; target: pod; property: "width"
            duration: pod.motionDuration
            easing.type: pod.isJelly ? Easing.OutBack : pod.fluidCurve
            easing.overshoot: pod.springOvershoot
        }
        NumberAnimation {
            id: animH; target: pod; property: "height"
            duration: pod.motionDuration
            easing.type: pod.isJelly ? Easing.OutBack : pod.fluidCurve
            easing.overshoot: pod.isJelly ? 1.05 : 1.0
        }
        NumberAnimation {
            id: animR; target: pod; property: "currentRadius"
            duration: pod.motionDuration; easing.type: pod.fluidCurve
        }
    }

    function expressGeometry(newY, newW, newH, newR, routeType) {
        var cleanW = Math.round(newW / 2) * 2;
        var cleanH = Math.round(newH / 2) * 2;
        var cleanY = Math.round(newY);

        targetY = cleanY;
        targetWidth = cleanW;
        targetHeight = cleanH;
        targetRadius = newR;

        emergePipelineAnim.stop();
        unifiedMotionAnim.stop();

        if (routeType === "EMERGE_AND_EXPAND" && pod.y < -5) {
            emergePipelineAnim.restart();
        } else {
            animY.to = cleanY;
            animW.to = cleanW;
            animH.to = cleanH;
            animR.to = newR;

            animY.duration = pod.motionDuration;
            animW.duration = pod.motionDuration;
            animH.duration = pod.motionDuration;

            unifiedMotionAnim.restart();
        }
    }
}