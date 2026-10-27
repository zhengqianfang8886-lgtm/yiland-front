// =========================================================================
// 📄 File: ui/core/PhysicsMotionPod.qml
// 🌟 统一物理动力学引擎 (多轴严格等时同步 · 深度激活 Theme 果冻模式版)
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

    readonly property bool isMoving: animY.running || animW.running || animH.running || animRadius.running

    // 🚀 核心：从 Theme 获取物理参数，真正激活“果冻/精确”模式切换
    readonly property bool isJelly: (typeof Theme !== "undefined") ? Theme.isJellyMode : false
    readonly property int motionDuration: (typeof Theme !== "undefined") ? Theme.animNormal : 220
    readonly property real springOvershoot: (typeof Theme !== "undefined") ? Theme.springOvershootFirm : 1.10

    signal motionStarted()
    signal motionSettled()

    onIsMovingChanged: {
        if (isMoving) {
            motionStarted();
        } else {
            motionSettled();
        }
    }

    // =========================================================================
    // 🚀【核心对齐】：Y、W、H、Radius 4 轴共享严格相同的时长与阻尼方程，杜绝时差挤压
    // =========================================================================
    Behavior on y {
        NumberAnimation {
            id: animY
            duration: pod.motionDuration
            easing.type: pod.isJelly ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: pod.springOvershoot
        }
    }

    Behavior on width {
        NumberAnimation {
            id: animW
            duration: pod.motionDuration
            easing.type: pod.isJelly ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: pod.springOvershoot
        }
    }

    Behavior on height {
        NumberAnimation {
            id: animH
            duration: pod.motionDuration
            easing.type: pod.isJelly ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: pod.springOvershoot
        }
    }

    Behavior on currentRadius {
        NumberAnimation {
            id: animRadius
            duration: pod.motionDuration
            easing.type: pod.isJelly ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: pod.springOvershoot
        }
    }

    function expressGeometry(newY, newW, newH, newR) {
        var cleanW = Math.round(newW / 2) * 2;
        var cleanH = Math.round(newH / 2) * 2;
        var cleanY = Math.round(newY);

        var deltaW = Math.abs(targetWidth - cleanW);
        var deltaY = Math.abs(targetY - cleanY);
        var deltaH = Math.abs(targetHeight - cleanH);

        if (deltaW <= 2 && deltaY <= 1 && deltaH <= 1) {
            targetRadius = newR;
            pod.currentRadius = newR;
            pod.motionSettled();
            return;
        }

        targetY = cleanY;
        targetWidth = cleanW;
        targetHeight = cleanH;
        targetRadius = newR;

        pod.y = cleanY;
        pod.width = cleanW;
        pod.height = cleanH;
        pod.currentRadius = newR;
    }
}