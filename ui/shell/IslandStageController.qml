// ==========================================
// 📄 File: IslandStageController.qml (零抽搐·瞬时物理走廊打通版)
// ==========================================
import QtQuick

Item {
    id: stageCtrl

    readonly property int tierNORMAL: 0
    readonly property int tierEXPANDED: 1
    readonly property int tierTUCKED: 2
    property int currentBaseTier: tierNORMAL

    readonly property int subTierDEEP: 0
    readonly property int subTierUSER: 1
    readonly property int subTierPASSIVE: 2
    property int submergedSubTier: subTierDEEP

    IslandTransientHub {
        id: transientHub
        onGeometryInvalidated: stageCtrl.stageGeometryRequested(false)
    }

    readonly property alias hub: transientHub
    readonly property alias activeOverlayKey: transientHub.activeKey
    readonly property alias activePayload: transientHub.activePayload

    // 武装标志：初始与常态下为 true
    property bool tuckArmed: true

    Timer {
        id: tuckArmTimer
        interval: 350
        repeat: false
        onTriggered: stageCtrl.tuckArmed = true
    }

    signal stageGeometryRequested(bool isModeSwitch)
    signal modeSwitchTriggered(bool isAnchored)

    function pushTransient(key, customDurationMs, payload) {
        if (currentBaseTier === tierEXPANDED && key !== "CALL") return false

        if (currentBaseTier === tierTUCKED) {
            if (submergedSubTier !== subTierUSER) {
                submergedSubTier = subTierPASSIVE
            }
        }

        var ok = transientHub.push(key, customDurationMs, payload)
        stageGeometryRequested(false)
        return ok
    }

    function popTransient(key) {
        transientHub.dismiss(key)

        if (currentBaseTier === tierTUCKED && submergedSubTier === subTierPASSIVE) {
            submergedSubTier = subTierDEEP
        }
        stageGeometryRequested(false)
    }

    Connections {
        target: transientHub
        function onTransientDismissed(key) {
            if (stageCtrl.currentBaseTier === stageCtrl.tierTUCKED && stageCtrl.submergedSubTier === stageCtrl.subTierPASSIVE) {
                stageCtrl.submergedSubTier = stageCtrl.subTierDEEP
                stageCtrl.stageGeometryRequested(false)
            }
        }
    }

    // 🚀【核心修复点 1】：探头第 0 毫秒立刻解除物理裁剪，鼠标往下走绝不穿透
    function userHoverEnter() {
        if (currentBaseTier !== tierTUCKED || !tuckArmed) return
        if (submergedSubTier === subTierUSER) return

        userLeaveTimer.stop()

        // 立即向后端开启全域走廊，彻底杜绝 8px Mask 导致的虚假 Exited 抽搐
        if (typeof Bridge !== "undefined") {
            Bridge.openFullCorridorForMotion()
        }

        submergedSubTier = subTierUSER
        stageGeometryRequested(false)
    }

    function userHoverKeep() {
        if (currentBaseTier !== tierTUCKED) return
        userLeaveTimer.stop()
    }

    function userHoverLeave() {
        if (currentBaseTier !== tierTUCKED) return
        // 移出感应区后自动充能武装，准备迎接下一次移入
        tuckArmed = true
        userLeaveTimer.restart()
    }

    // 🚀【核心修复点 2】：140ms 人体工学迟滞滤波，消除边缘微抖动
    Timer {
        id: userLeaveTimer
        interval: 140
        repeat: false
        onTriggered: {
            if (stageCtrl.currentBaseTier === stageCtrl.tierTUCKED) {
                if (stageCtrl.submergedSubTier !== stageCtrl.subTierDEEP) {
                    stageCtrl.submergedSubTier = stageCtrl.subTierDEEP
                    stageCtrl.hub.dismiss()
                    stageCtrl.stageGeometryRequested(false)
                }
            }
        }
    }

    function requestExpand() {
        if (currentBaseTier === tierTUCKED) return
        popTransient()
        currentBaseTier = tierEXPANDED
        stageGeometryRequested(false)
    }

    function requestCollapse() {
        popTransient()
        currentBaseTier = tierNORMAL
        stageGeometryRequested(false)
    }

    function toggleTuck() {
        popTransient()
        userLeaveTimer.stop()

        var willBeAnchored = (currentBaseTier === tierTUCKED)

        if (willBeAnchored) {
            currentBaseTier = tierNORMAL
            submergedSubTier = subTierDEEP
            tuckArmed = true
        } else {
            currentBaseTier = tierTUCKED
            submergedSubTier = subTierDEEP
            // 右键隐藏瞬间关闭武装，防止光标停在原地自碰自弹
            tuckArmed = false
            tuckArmTimer.restart()
        }

        modeSwitchTriggered(willBeAnchored)
        stageGeometryRequested(true)
    }
}