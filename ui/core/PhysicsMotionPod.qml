// =========================================================================
// 📄 File: ui/core/PhysicsMotionPod.qml
// 🌟 动力学连续物理引擎 (防亚像素抖动 · 掩码死锁断路保护版)
// =========================================================================
import QtQuick

Item {
    id: pod

    y: 8
    width: 188
    height: 38

    property real targetY: 8
    property real targetWidth: 188
    property real targetHeight: 38
    property real targetRadius: 19

    // 暴露整型离散像素，阻断频繁微米级浮点更新引发的 QML 树重排
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

    // 物理尺寸表达入口：偶数化对齐并过滤无效微小震荡
    function expressGeometry(newY, newW, newH, newR) {
        var cleanW = Math.round(newW / 2) * 2;
        var cleanH = Math.round(newH / 2) * 2;
        var cleanY = Math.round(newY);

        var willChange = (Math.abs(targetY - cleanY) >= 1.0 ||
                          Math.abs(targetWidth - cleanW) >= 1.0 ||
                          Math.abs(targetHeight - cleanH) >= 1.0 ||
                          Math.abs(targetRadius - newR) >= 0.5);

        targetY = cleanY;
        targetWidth = cleanW;
        targetHeight = cleanH;
        targetRadius = newR;

        // 若尺寸完全无变动且未在运动中，立刻向壳层发射就位信号以锁定硬件穿透掩码
        if (!willChange && !isMoving) {
            currentRadius = newR;
            motionSettled();
            return;
        }

        pod.y = cleanY;
        pod.width = cleanW;
        pod.height = cleanH;
        pod.currentRadius = newR;
    }
}