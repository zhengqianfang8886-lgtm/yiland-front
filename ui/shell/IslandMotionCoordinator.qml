// ==========================================
// 📄 File: ui/shell/IslandMotionCoordinator.qml
// 🌟 果冻物理引擎 (防截断 + 下拉蓄力弹簧版)
// ==========================================
import QtQuick

Item {
    id: motionCoord

    property Item targetHost: null
    property var stageCtrl: null

    property real goalY: 8
    property real goalWidth: 160
    property real goalHeight: 34
    property real goalRadius: 17

    property bool isSettled: true
    property bool isTuckingInProgress: false

    signal motionStarted()
    signal motionSettled()

    // =========================================================================
    // 1. 常态流体过渡 (修复右侧截断：宽度严禁使用过冲回弹)
    // =========================================================================
    ParallelAnimation {
        id: normalPipeline

        NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.goalY; duration: 220; easing.type: Easing.OutCubic }
        // 🚀 核心修复：宽度改为绝对平滑的 OutCubic，绝不过度挤压导致内容截断！
        NumberAnimation { target: motionCoord.targetHost; property: "width"; to: motionCoord.goalWidth; duration: 240; easing.type: Easing.OutCubic }
        NumberAnimation { target: motionCoord.targetHost; property: "height"; to: motionCoord.goalHeight; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: motionCoord.targetHost; property: "capsuleRadius"; to: motionCoord.goalRadius; duration: 220; easing.type: Easing.OutCubic }

        onStarted: {
            motionCoord.isSettled = false
            settleDebounceTimer.stop()
            motionCoord.motionStarted()
        }
        onFinished: settleDebounceTimer.restart()
    }

    // =========================================================================
    // 2. 隐藏/深潜管线 (Tuck) - 🚀 新增：往下扯动蓄力 -> 真空吸顶
    // =========================================================================
    SequentialAnimation {
        id: tuckChainPipeline

        onStarted: {
            motionCoord.isTuckingInProgress = true
            motionCoord.isSettled = false
            settleDebounceTimer.stop()
            motionCoord.motionStarted()
        }

        // 🌟 阶段 A: 预期动作 (Anticipation) - 像弹簧一样先往下扯，同时压扁
        ParallelAnimation {
            // 在当前 Y 的基础上往下拽 10px
            NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.targetHost.y + 10; duration: 140; easing.type: Easing.OutSine }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 0.95; duration: 140; easing.type: Easing.OutSine }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 0.80; duration: 140; easing.type: Easing.OutSine }
        }

        // 🌟 阶段 B: 释放弹簧，极速飞升吸顶
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.goalY; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "width"; to: motionCoord.goalWidth; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }

        onFinished: {
            motionCoord.isTuckingInProgress = false
            settleDebounceTimer.restart()
        }
    }

    // =========================================================================
    // 3. 出现/触底管线 (Anchor) - 重力砸下 -> 果冻压扁 -> Q弹回拨
    // =========================================================================
    SequentialAnimation {
        id: anchorChainPipeline

        onStarted: {
            motionCoord.isTuckingInProgress = false
            motionCoord.isSettled = false
            settleDebounceTimer.stop()
            motionCoord.motionStarted()
        }

        // 阶段 A: 重力加速下坠到位
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "y"; to: motionCoord.goalY; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "width"; to: motionCoord.goalWidth; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "height"; to: motionCoord.goalHeight; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleRadius"; to: motionCoord.goalRadius; duration: 220; easing.type: Easing.OutCubic }
        }

        // 阶段 B: 触底瞬间的挤压 (Squash)
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 1.045; duration: 75; easing.type: Easing.OutQuad }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 1.065; duration: 75; easing.type: Easing.OutQuad }
        }

        // 阶段 C: 果冻张力回弹锁定
        ParallelAnimation {
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleX"; to: 1.0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
            NumberAnimation { target: motionCoord.targetHost; property: "capsuleScaleY"; to: 1.0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
        }

        onFinished: settleDebounceTimer.restart()
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

        goalY = y
        goalWidth = w
        goalHeight = h
        goalRadius = r

        normalPipeline.stop()
        tuckChainPipeline.stop()
        anchorChainPipeline.stop()

        // 🚀 核心路由重写：只要目标 Y 是负数（即往天花板上面缩，无论是右键点击还是5秒自动隐藏），
        // 强制 100% 走【下拉蓄力飞升】物理管线！
        if (y < 0) {
            tuckChainPipeline.restart()
        } 
        // 否则，如果是模式大切换且是往下落，走【砸下果冻压扁】管线
        else if (modeSwitch === true) {
            anchorChainPipeline.restart()
        } 
        // 其余情况（如秒数跳动、卡片微调），走普通流体滑管线
        else {
            if (!motionCoord.isTuckingInProgress) {
                motionCoord.targetHost.capsuleScaleX = 1.0
                motionCoord.targetHost.capsuleScaleY = 1.0
            }
            normalPipeline.restart()
        }
    }
}