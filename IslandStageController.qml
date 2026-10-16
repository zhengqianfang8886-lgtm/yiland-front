// ==========================================
// 📄 File: IslandStageController.qml (多状态精准出水与回潜版)
// ==========================================
import QtQuick

Item {
    id: stageCtrl

    // --- 1. 底态枚举 (Base Tier) ---
    readonly property int tierNORMAL: 0
    readonly property int tierEXPANDED: 1
    readonly property int tierTUCKED: 2
    property int currentBaseTier: tierNORMAL

    // --- 2. 潜航隐藏态下的三级子状态 ---
    readonly property int subTierDEEP: 0     // 完全潜航吸顶（露微弧）
    readonly property int subTierUSER: 1     // 用户鼠标主动探出/查看中
    readonly property int subTierPASSIVE: 2  // 事件临时出水展示中（受租约控制，到期回潜）
    property int submergedSubTier: subTierDEEP

    // 挂载抽象瞬态调度中枢
    IslandTransientHub {
        id: transientHub
        onGeometryInvalidated: stageCtrl.stageGeometryRequested()
    }

    readonly property alias hub: transientHub
    readonly property alias activeOverlayKey: transientHub.activeKey
    readonly property alias activePayload: transientHub.activePayload

    property bool tuckLockout: false
    property bool tuckArmed: false

    signal stageGeometryRequested()

    // =========================================================================
    // 瞬态触发接口（支持隐藏状态下出水展示）
    // =========================================================================
    function pushTransient(key, customDurationMs, payload) {
        if (currentBaseTier === tierEXPANDED && key !== "CALL") return false

        // 🚀【核心机制 1】：如果在隐藏潜航状态下收到事件，启动被动出水！
        if (currentBaseTier === tierTUCKED) {
            if (submergedSubTier !== subTierUSER) {
                submergedSubTier = subTierPASSIVE
            }
        }

        var ok = transientHub.push(key, customDurationMs, payload)
        stageGeometryRequested()
        return ok
    }

    // 瞬态结束
    function popTransient(key) {
        transientHub.dismiss(key)

        // 🚀【核心机制 2】：若在隐藏模式下被动展示结束（非鼠标主动接管），平滑缩回天花板隐藏！
        if (currentBaseTier === tierTUCKED && submergedSubTier === subTierPASSIVE) {
            submergedSubTier = subTierDEEP
        }
        stageGeometryRequested()
    }

    // =========================================================================
    // 租约倒计时器（到期自动结算）
    // =========================================================================
    Connections {
        target: transientHub
        function onTransientDismissed(key) {
            if (stageCtrl.currentBaseTier === stageCtrl.tierTUCKED && stageCtrl.submergedSubTier === stageCtrl.subTierPASSIVE) {
                stageCtrl.submergedSubTier = stageCtrl.subTierDEEP
                stageCtrl.stageGeometryRequested()
            }
        }
    }

    // =========================================================================
    // 鼠标在天花板主动探头交互
    // =========================================================================
    function userHoverEnter() {
        if (currentBaseTier !== tierTUCKED || tuckLockout || !tuckArmed) return
        userLeaveTimer.stop()
        submergedSubTier = subTierUSER
        stageGeometryRequested()
    }

    function userHoverKeep() {
        if (currentBaseTier !== tierTUCKED) return
        userLeaveTimer.stop()
    }

    function userHoverLeave() {
        if (currentBaseTier !== tierTUCKED) return
        tuckArmed = true
        userLeaveTimer.restart()
    }

    // 鼠标离开天花板区域的隐藏防抖
    Timer {
        id: userLeaveTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (stageCtrl.currentBaseTier === stageCtrl.tierTUCKED) {
                stageCtrl.submergedSubTier = stageCtrl.subTierDEEP
                stageCtrl.hub.dismiss()
                stageCtrl.stageGeometryRequested()
            }
        }
    }

    // =========================================================================
    // 底态流转控制
    // =========================================================================
    function requestExpand() {
        if (currentBaseTier === tierTUCKED) return
        popTransient()
        currentBaseTier = tierEXPANDED
        stageGeometryRequested()
    }

    function requestCollapse() {
        popTransient()
        currentBaseTier = tierNORMAL
        stageGeometryRequested()
    }

    function toggleTuck() {
        if (tuckLockout) return
        tuckLockout = true
        tuckLockTimer.restart()
        popTransient()
        userLeaveTimer.stop()

        currentBaseTier = (currentBaseTier === tierTUCKED) ? tierNORMAL : tierTUCKED
        submergedSubTier = subTierDEEP
        tuckArmed = false
        stageGeometryRequested()
    }

    Timer {
        id: tuckLockTimer
        interval: 450
        repeat: false
        onTriggered: stageCtrl.tuckLockout = false
    }
}