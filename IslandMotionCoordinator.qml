// ==========================================
// 📄 File: IslandMotionCoordinator.qml (严格接力·可打断动画链引擎)
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

    signal motionStarted()
    signal motionSettled()

    // 标志当前是否正处于隐藏收缩中（用于保护视口内容不被提前剪裁）
    property bool isTuckingInProgress: false

    // =========================================================================
    // 1. 常规平滑重排管线（宽度/高度常规流体变化）
    // =========================================================================
    ParallelAnimation {
        id: normalPipeline

        NumberAnimation {
            target: motionCoord.targetHost; property: "y"
            to: motionCoord.goalY
            duration: Theme.animNormal
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
            motionCoord.isSettled = false
            settleDebounceTimer.stop()
            motionCoord.motionStarted()
        }

        onFinished: settleDebounceTimer.restart()
    }

    // =========================================================================
    // 2. 🚀【可打断动画链 A】：点击隐藏（严丝合缝阶段链）
    // 必须 Phase 1 按下收缩完整播完 -> 紧接着启动 Phase 2 流水位移
    // =========================================================================
    SequentialAnimation {
        id: tuckChainPipeline

        onStarted: {
            motionCoord.isTuckingInProgress = true
            motionCoord.isSettled = false
            settleDebounceTimer.stop()
            motionCoord.motionStarted()
        }

        // --- 阶段 1：受力按压收紧 (Squish 80ms) ---
        ParallelAnimation {
            NumberAnimation {
                target: motionCoord.targetHost; property: "capsuleScaleX"
                to: 0.92; duration: 80; easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: motionCoord.targetHost; property: "capsuleScaleY"
                to: 0.90; duration: 80; easing.type: Easing.OutQuad
            }
        }

        // --- 阶段 2：反弹恢复蓄势 (Rebound 90ms) ---
        ParallelAnimation {
            NumberAnimation {
                target: motionCoord.targetHost; property: "capsuleScaleX"
                to: 1.0; duration: 90; easing.type: Easing.OutBack; easing.overshoot: 1.15
            }
            NumberAnimation {
                target: motionCoord.targetHost; property: "capsuleScaleY"
                to: 1.0; duration: 90; easing.type: Easing.OutBack; easing.overshoot: 1.15
            }
        }

        // --- 阶段 3：前两段完全就绪后，如流水般顺滑升顶滑入天花板 (Glide Up 240ms) ---
        ParallelAnimation {
            NumberAnimation {
                target: motionCoord.targetHost; property: "y"
                to: motionCoord.goalY
                duration: 240
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: motionCoord.targetHost; property: "width"
                to: motionCoord.goalWidth
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        onFinished: {
            motionCoord.isTuckingInProgress = false
            settleDebounceTimer.restart()
        }
    }

    // =========================================================================
    // 3. 🚀【可打断动画链 B】：点击固定（流水着陆 -> 触地膨胀 -> 阻尼锁定）
    // =========================================================================
    SequentialAnimation {
        id: anchorChainPipeline

        onStarted: {
            motionCoord.isTuckingInProgress = false
            motionCoord.isSettled = false
            settleDebounceTimer.stop()
            motionCoord.motionStarted()
        }

        // --- 阶段 1：流水般下落到位 (Drop Down 220ms) ---
        ParallelAnimation {
            NumberAnimation {
                target: motionCoord.targetHost; property: "y"
                to: motionCoord.goalY
                duration: 220
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: motionCoord.targetHost; property: "width"
                to: motionCoord.goalWidth
                duration: 220
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: motionCoord.targetHost; property: "height"
                to: motionCoord.goalHeight
                duration: 220
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: motionCoord.targetHost; property: "capsuleRadius"
                to: motionCoord.goalRadius
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        // --- 阶段 2：着陆瞬间惯性微膨胀 (Swell 80ms) ---
        ParallelAnimation {
            NumberAnimation {
                target: motionCoord.targetHost; property: "capsuleScaleX"
                to: 1.05; duration: 80; easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: motionCoord.targetHost; property: "capsuleScaleY"
                to: 1.06; duration: 80; easing.type: Easing.OutQuad
            }
        }

        // --- 阶段 3：果冻弹性回弹锁定 (Settle 120ms) ---
        ParallelAnimation {
            NumberAnimation {
                target: motionCoord.targetHost; property: "capsuleScaleX"
                to: 1.0; duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.15
            }
            NumberAnimation {
                target: motionCoord.targetHost; property: "capsuleScaleY"
                to: 1.0; duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.15
            }
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

    // 🚀【随时可打断的安全重定向】：停止当前链，平滑过渡
    function syncAndAnimate(y, w, h, r, modeSwitch) {
        if (!targetHost) return

        goalY = y
        goalWidth = w
        goalHeight = h
        goalRadius = r

        // 强行打断先前的流水线（实现零阶跃重定向）
        normalPipeline.stop()
        tuckChainPipeline.stop()
        anchorChainPipeline.stop()

        if (modeSwitch === true) {
            if (y < 0) {
                tuckChainPipeline.restart()
            } else {
                anchorChainPipeline.restart()
            }
        } else {
            // 普通重排如果不在收缩阶段，复位 scale
            if (!motionCoord.isTuckingInProgress) {
                motionCoord.targetHost.capsuleScaleX = 1.0
                motionCoord.targetHost.capsuleScaleY = 1.0
            }
            normalPipeline.restart()
        }
    }
}