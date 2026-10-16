// ==========================================
// 📄 File: IslandStageController.qml (零延时·纯物理意图接管版)
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
    readonly property int subTierUSER: 1     // 用户鼠标主动探出/操作中
    readonly property int subTierPASSIVE: 2  // 事件临时出水展示中
    property int submergedSubTier: subTierDEEP

    // 挂载瞬态调度中枢
    IslandTransientHub {
        id: transientHub
        onGeometryInvalidated: stageCtrl.stageGeometryRequested(false)
    }

    readonly property alias hub: transientHub
    readonly property alias activeOverlayKey: transientHub.activeKey
    readonly property alias activePayload: transientHub.activePayload

    // 🚀【核心设计】：彻底废除 700ms 倒计时锁！采用纯物理位移“武装标志”
    // 刚右键收起时为 false，鼠标不移走绝不误弹；移走后物理武装，随时探头
    property bool tuckArmed: true

    signal stageGeometryRequested(bool isModeSwitch)
    signal modeSwitchTriggered(bool isAnchored)

    // =========================================================================
    // 瞬态触发接口
    // =========================================================================
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

    // =========================================================================
    // 🚀【真正的物理鼠标意图交互】：0延迟判定，完全不卡手
    // =========================================================================
    function userHoverEnter() {
        // 如果未武装（鼠标收起后还没移开），坚决不自碰自弹！
        if (currentBaseTier !== tierTUCKED || !tuckArmed) return
        userLeaveTimer.stop()
        submergedSubTier = subTierUSER
        stageGeometryRequested(false)
    }

    function userHoverKeep() {
        if (currentBaseTier !== tierTUCKED) return
        userLeaveTimer.stop()
    }

    function userHoverLeave() {
        if (currentBaseTier !== tierTUCKED) return
        // 鼠标一旦离开过感应区，立即自动武装完毕，随时等候下一次意图靠近
        tuckArmed = true
        userLeaveTimer.restart()
    }

    // 鼠标真正离开天花板感应区后的退潜防抖（60ms 极轻微手势防虚抖）
    Timer {
        id: userLeaveTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (stageCtrl.currentBaseTier === stageCtrl.tierTUCKED) {
                stageCtrl.submergedSubTier = stageCtrl.subTierDEEP
                stageCtrl.hub.dismiss()
                stageCtrl.stageGeometryRequested(false)
            }
        }
    }

    // =========================================================================
    // 底态流转控制（0ms 极速响应）
    // =========================================================================
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

    // 🚀【瞬间切换】：用户点击右键的瞬间，0 延迟切换，同时进入“原位休眠”状态
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
            // 关键：刚收起时关闭武装，鼠标在原处停着绝不自弹！
            tuckArmed = false
        }

        modeSwitchTriggered(willBeAnchored)
        stageGeometryRequested(true)
    }
}