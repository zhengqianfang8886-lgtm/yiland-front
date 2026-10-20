// ==========================================
// 📄 File: ui/shell/IslandMotionCoordinator.qml
// 🌟 液态水银动力学协调器 (注入乐观掩码引擎 · 彻底治愈悬停抽搐)
// ==========================================
import QtQuick

Item {
    id: motionCoord

    property Item targetHost: null
    property var stageCtrl: null

    property real goalY: 8
    property real goalWidth: 180
    property real goalHeight: 38
    property real goalRadius: 19

    property bool isSettled: true
    property bool isTuckingInProgress: false

    signal motionStarted()
    signal motionSettled()

    function _forceResetScalesImmediately() {
        if (!targetHost) return
        targetHost.capsuleScaleX = 1.0
        targetHost.capsuleScaleY = 1.0
        motionCoord.isTuckingInProgress = false
    }

    ParallelAnimation {
        id: normalPipeline
        NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.goalY; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: motionCoord.targetHost; property: "width"; to: motionCoord.goalWidth; duration: 320; easing.type: (motionCoord.targetHost && motionCoord.goalWidth > motionCoord.targetHost.width) ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 1.06 }
        NumberAnimation { target: motionCoord.targetHost; property: "height"; to: motionCoord.goalHeight; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: motionCoord.targetHost; property: "capsuleRadius"; to: motionCoord.goalRadius; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 1.0; duration: 200; easing.type: Easing.OutQuad }
        NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 1.0; duration: 200; easing.type: Easing.OutQuad }

        onStarted: { motionCoord.isSettled = false; settleDebounceTimer.stop(); motionCoord.motionStarted() }
        onFinished: { motionCoord.isTuckingInProgress = false; settleDebounceTimer.restart() }
    }

    ParallelAnimation {
        id: tuckedResizePipeline
        NumberAnimation { target: motionCoord.targetHost; property: "width"; to: motionCoord.goalWidth; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: motionCoord.targetHost; property: "capsuleRadius"; to: motionCoord.goalRadius; duration: 260; easing.type: Easing.OutCubic }
        onStarted: { motionCoord.isSettled = false; settleDebounceTimer.stop(); motionCoord.motionStarted() }
        onFinished: { motionCoord.isTuckingInProgress = false; settleDebounceTimer.restart() }
    }

    SequentialAnimation {
        id: tuckChainPipeline
        onStarted: { motionCoord.isTuckingInProgress = true; motionCoord.isSettled = false; settleDebounceTimer.stop(); motionCoord.motionStarted() }
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.targetHost ? (motionCoord.targetHost.y + 10) : 18; duration: 130; easing.type: Easing.OutSine }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 0.95; duration: 130; easing.type: Easing.OutSine }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 0.80; duration: 130; easing.type: Easing.OutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.goalY; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "width"; to: motionCoord.goalWidth; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }
        onFinished: { motionCoord.isTuckingInProgress = false; settleDebounceTimer.restart() }
    }

    SequentialAnimation {
        id: anchorChainPipeline
        onStarted: { motionCoord.isTuckingInProgress = false; motionCoord.isSettled = false; settleDebounceTimer.stop(); motionCoord.motionStarted() }
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.goalY; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "width"; to: motionCoord.goalWidth; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "height"; to: motionCoord.goalHeight; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleRadius"; to: motionCoord.goalRadius; duration: 240; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 1.045; duration: 75; easing.type: Easing.OutQuad }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 1.065; duration: 75; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 1.0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 1.0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }
        onFinished: { motionCoord.isTuckingInProgress = false; settleDebounceTimer.restart() }
    }

    Timer {
        id: settleDebounceTimer
        interval: 40
        repeat: false
        onTriggered: {
            motionCoord.isSettled = true
            motionCoord.motionSettled()
        }
    }

    function syncAndAnimate(y, w, h, r, modeSwitch) {
        if (!targetHost) return

        if (!modeSwitch && 
            Math.abs(goalY - y) < 0.5 && 
            Math.abs(goalWidth - w) < 0.5 && 
            Math.abs(goalHeight - h) < 0.5 && 
            Math.abs(goalRadius - r) < 0.5 && 
            isSettled) {
            return
        }

        goalY = y
        goalWidth = w
        goalHeight = h
        goalRadius = r

        // 🚀【乐观掩码机制】：只要目标变宽，瞬间把底层透明点击区撑开，彻底杜绝悬停抽搐！
        if (targetHost && goalWidth > targetHost.width) {
            if (typeof targetHost.commitMaskTarget === "function") {
                targetHost.commitMaskTarget(goalWidth, goalHeight)
            }
        }

        normalPipeline.stop()
        tuckChainPipeline.stop()
        tuckedResizePipeline.stop()
        anchorChainPipeline.stop()

        var isAlreadyAtCeiling = (targetHost.y < 0 && Math.abs(targetHost.y - y) <= 2.0)

        if (y < 0) {
            if (isAlreadyAtCeiling) {
                motionCoord.isTuckingInProgress = false
                tuckedResizePipeline.restart()
            } else {
                tuckChainPipeline.restart()
            }
        } else if (modeSwitch === true) {
            motionCoord.isTuckingInProgress = false
            anchorChainPipeline.restart()
        } else {
            motionCoord.isTuckingInProgress = false
            normalPipeline.restart()
        }
    }
}