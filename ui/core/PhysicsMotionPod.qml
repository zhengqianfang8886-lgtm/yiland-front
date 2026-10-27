// =========================================================================
// 📄 File: ui/core/PhysicsMotionPod.qml
// 🌟 纯正流体动力学引擎 (单调递增膨胀 · 彻底根除反向收缩版)
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
    readonly property int motionDuration: (typeof Theme !== "undefined") ? Theme.animNormal : 220
    readonly property real springOvershoot: (typeof Theme !== "undefined") ? Theme.springOvershootFirm : 1.10

    signal motionStarted()
    signal motionSettled()

    onIsMovingChanged: {
        if (isMoving) motionStarted();
        else motionSettled();
    }

    // =========================================================================
    // 🚀【管线 A】：真·深潜破土展开 (仅在胶囊 Y 轴真正在天花板外负坐标时触发)
    // 阶段 1: Y 轴 70ms 闪电落入视野零点 (维持当前宽度，绝不缩小！)
    // 阶段 2: 单调流畅向 420x240 膨胀
    // =========================================================================
    SequentialAnimation {
        id: emergePipelineAnim

        ParallelAnimation {
            NumberAnimation { target: pod; property: "y"; to: pod.targetY; duration: 75; easing.type: Easing.OutCubic }
            NumberAnimation { target: pod; property: "currentRadius"; to: 18; duration: 75 }
        }

        ParallelAnimation {
            NumberAnimation {
                target: pod; property: "width"; to: pod.targetWidth
                duration: pod.motionDuration
                easing.type: pod.isJelly ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: pod.springOvershoot
            }
            NumberAnimation {
                target: pod; property: "height"; to: pod.targetHeight
                duration: pod.motionDuration
                easing.type: pod.isJelly ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: pod.isJelly ? 1.08 : 1.0
            }
            NumberAnimation { target: pod; property: "currentRadius"; to: pod.targetRadius; duration: pod.motionDuration; easing.type: Easing.OutQuad }
        }
    }

    // =========================================================================
    // 🚀【管线 B】：标准单调统一运动管线 (从当前尺寸直达目标尺寸，无任何中间反向缩水)
    // =========================================================================
    ParallelAnimation {
        id: unifiedMotionAnim

        NumberAnimation {
            id: animY; target: pod; property: "y"
            duration: pod.motionDuration; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: animW; target: pod; property: "width"
            duration: pod.motionDuration
            easing.type: pod.isJelly ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: pod.springOvershoot
        }
        NumberAnimation {
            id: animH; target: pod; property: "height"
            duration: pod.motionDuration
            easing.type: pod.isJelly ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: pod.isJelly ? 1.08 : 1.0
        }
        NumberAnimation {
            id: animR; target: pod; property: "currentRadius"
            duration: pod.motionDuration; easing.type: Easing.OutQuad
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

        // 核心法则：只有当物理坐标确实处于负值（屏幕外）且目标是展开时，才走破土降落
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