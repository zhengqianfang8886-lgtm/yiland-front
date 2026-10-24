// ==========================================
// 📄 File: ui/shell/IslandMotionCoordinator.qml
// 🌟 液态动力学协调器 (管线驱动状态机重构版)
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
    // 🚀【架构重构】：引入显式管线状态枚举，彻底告别布尔值乱飞
    property string activePipeline: "NONE"
    readonly property bool isAnimating: activePipeline !== "NONE"

    signal motionStarted()
    signal motionSettled()

    ParallelAnimation {
        id: normalPipeline
        onStarted: { motionCoord.activePipeline = "NORMAL"; motionCoord.isSettled = false; settleDebounceTimer.stop(); motionCoord.motionStarted() }
        NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.goalY; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { 
            target: motionCoord.targetHost; 
            property: "width"; 
            to: motionCoord.goalWidth; 
            duration: 300; 
            easing.type: (motionCoord.targetHost && motionCoord.goalWidth > motionCoord.targetHost.width) ? Easing.OutBack : Easing.OutCubic; 
            easing.overshoot: 1.06 
        }
        NumberAnimation { target: motionCoord.targetHost; property: "height"; to: motionCoord.goalHeight; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: motionCoord.targetHost; property: "capsuleRadius"; to: motionCoord.goalRadius; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 1.0; duration: 180; easing.type: Easing.OutQuad }
        NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 1.0; duration: 180; easing.type: Easing.OutQuad }
        onFinished: { motionCoord.activePipeline = "NONE"; settleDebounceTimer.restart() }
    }

    ParallelAnimation {
        id: tuckedResizePipeline
        onStarted: { motionCoord.activePipeline = "TUCKED_RESIZE"; motionCoord.isSettled = false; settleDebounceTimer.stop(); motionCoord.motionStarted() }
        NumberAnimation { target: motionCoord.targetHost; property: "width"; to: motionCoord.goalWidth; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: motionCoord.targetHost; property: "capsuleRadius"; to: motionCoord.goalRadius; duration: 260; easing.type: Easing.OutCubic }
        onFinished: { motionCoord.activePipeline = "NONE"; settleDebounceTimer.restart() }
    }

    // 常态小胶囊下沉蓄力回收动画
    SequentialAnimation {
        id: tuckChainPipeline
        onStarted: { motionCoord.activePipeline = "TUCK"; motionCoord.isSettled = false; settleDebounceTimer.stop(); motionCoord.motionStarted() }
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.targetHost ? (motionCoord.targetHost.y + 10) : 18; duration: 130; easing.type: Easing.OutSine }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 0.95; duration: 130; easing.type: Easing.OutSine }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 0.80; duration: 130; easing.type: Easing.OutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.goalY; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "width"; to: motionCoord.goalWidth; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "height"; to: motionCoord.goalHeight; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleRadius"; to: motionCoord.goalRadius; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }
        onFinished: { motionCoord.activePipeline = "NONE"; settleDebounceTimer.restart() }
    }

    // 🚀【新增】：严格的大卡片 -> 隐藏天花板的【两段式动画链】
    SequentialAnimation {
        id: expandToTuckPipeline
        onStarted: { motionCoord.activePipeline = "EXPAND_TO_TUCK"; motionCoord.isSettled = false; settleDebounceTimer.stop(); motionCoord.motionStarted() }
        
        // 阶段一：平滑收缩回标准胶囊形状 (停靠在普通胶囊的高度位)
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.targetHost ? motionCoord.targetHost.normalTopMargin : 8; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "width"; to: motionCoord.goalWidth; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "height"; to: motionCoord.goalHeight; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleRadius"; to: motionCoord.goalRadius; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 1.0; duration: 240; easing.type: Easing.OutQuad }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 1.0; duration: 240; easing.type: Easing.OutQuad }
        }
        
        // 阶段二：紧接着无缝钻入天花板隐藏
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.goalY; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "width"; to: motionCoord.goalWidth; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "height"; to: motionCoord.goalHeight; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleRadius"; to: motionCoord.goalRadius; duration: 180; easing.type: Easing.InCubic }
        }
        onFinished: { motionCoord.activePipeline = "NONE"; settleDebounceTimer.restart() }
    }

    SequentialAnimation {
        id: anchorChainPipeline
        onStarted: { motionCoord.activePipeline = "ANCHOR"; motionCoord.isSettled = false; settleDebounceTimer.stop(); motionCoord.motionStarted() }
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
        onFinished: { motionCoord.activePipeline = "NONE"; settleDebounceTimer.restart() }
    }

    Timer {
        id: settleDebounceTimer
        interval: 60
        repeat: false
        onTriggered: {
            motionCoord.isSettled = true
            motionCoord.motionSettled()
        }
    }

    function syncAndAnimate(y, w, h, r, modeSwitch) {
        if (!targetHost) return

        var isShrinking = (targetHost.width > w || targetHost.height > h)
        var isFromExpanded = (targetHost.height > 100) 
        var isTargetTucked = (y < 0)

        if (!modeSwitch && !isShrinking &&
            Math.abs(goalY - y) < 0.5 && Math.abs(goalWidth - w) < 0.5 && 
            Math.abs(goalHeight - h) < 0.5 && Math.abs(goalRadius - r) < 0.5 && 
            isSettled) {
            return
        }

        goalY = y; goalWidth = w; goalHeight = h; goalRadius = r

        if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) {
            Bridge.openFullCorridorForMotion()
        }

        normalPipeline.stop(); tuckChainPipeline.stop(); tuckedResizePipeline.stop()
        anchorChainPipeline.stop(); expandToTuckPipeline.stop()

        var isAlreadyAtCeiling = (targetHost.y < 0 && Math.abs(targetHost.y - y) <= 2.0)

        if (isTargetTucked) {
            if (isAlreadyAtCeiling) {
                tuckedResizePipeline.restart()
            } else if (isFromExpanded) {
                expandToTuckPipeline.restart()
            } else {
                tuckChainPipeline.restart()
            }
        } else if (modeSwitch === true) {
            anchorChainPipeline.restart()
        } else {
            normalPipeline.restart()
        }
    }
}