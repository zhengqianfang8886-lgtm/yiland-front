// ==========================================
// 📄 File: IslandMotionCoordinator.qml (动静分离·平稳单次结算版)
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

    // 核心标志：当前是否处于绝对静止稳定状态
    property bool isSettled: true

    signal motionStarted()
    signal motionSettled()

    ParallelAnimation {
        id: masterPipeline

        NumberAnimation {
            target: motionCoord.targetHost; property: "y"
            to: motionCoord.goalY
            duration: (stageCtrl && stageCtrl.currentBaseTier === stageCtrl.tierTUCKED) ? 180 : Theme.animNormal
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: motionCoord.targetHost; property: "width"
            to: motionCoord.goalWidth
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: motionCoord.targetHost; property: "height"
            to: motionCoord.goalHeight
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: motionCoord.targetHost; property: "capsuleRadius"
            to: motionCoord.goalRadius
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
        }

        onStarted: {
            // 🚀【核心机制 1】：动画只要开跑，立即标记未稳定，并全开通道，绝不中途裁切计算掩码！
            motionCoord.isSettled = false
            settleDebounceTimer.stop()
            motionCoord.motionStarted()
        }

        onFinished: {
            // 动画轴向全部走完，开启 50ms 阻尼平息
            settleDebounceTimer.restart()
        }
    }

    Timer {
        id: settleDebounceTimer
        interval: 50
        repeat: false
        onTriggered: {
            // 🚀【核心机制 2】：完全平息且静止后，才允许进行全局唯一一次的最终掩码计算！
            motionCoord.isSettled = true
            motionCoord.motionSettled()
        }
    }

    function syncAndAnimate(y, w, h, r) {
        if (!targetHost) return

        // 终点完全一致且已稳定时，直接跳过
        if (goalY === y && goalWidth === w && goalHeight === h && goalRadius === r && isSettled) {
            return
        }

        goalY = y
        goalWidth = w
        goalHeight = h
        goalRadius = r

        masterPipeline.restart()
    }
}