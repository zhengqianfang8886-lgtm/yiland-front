// =========================================================================
// 📄 File: ui/core/PhysicsMotionPod.qml
// 🌟 外框物理形变引擎 (死区滤波 · 动量顺滑减速版)
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

    readonly property bool isMoving: animY.running || animW.running || animH.running

    signal motionStarted()
    signal motionSettled()

    onIsMovingChanged: {
        if (isMoving) {
            motionStarted();
        } else {
            motionSettled();
        }
    }

    Behavior on y {
        NumberAnimation {
            id: animY
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    Behavior on width {
        NumberAnimation {
            id: animW
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Behavior on height {
        NumberAnimation {
            id: animH
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    Behavior on currentRadius {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    function expressGeometry(newY, newW, newH, newR) {
        var cleanW = Math.round(newW / 2) * 2;
        var cleanH = Math.round(newH / 2) * 2;
        var cleanY = Math.round(newY);

        var deltaW = Math.abs(targetWidth - cleanW);
        var deltaY = Math.abs(targetY - cleanY);
        var deltaH = Math.abs(targetHeight - cleanH);

        // 🚀【P0 核心修复】：即使因死区不触发过渡动画，也必须发射 settled 信号，驱动外部掩码立即落实
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