// ==========================================
// 📄 File: ui/shell/IslandStageController.qml
// 🌟 正交分层舞台控制器 (彻底解耦鼠标探出与系统被动通知)
// ==========================================
import QtQuick

Item {
    id: stageCtrl

    // 1. 底模态 (Base Mode) - 用户的常态偏好
    readonly property int modeNORMAL: 0
    readonly property int modeTUCKED: 1
    property int baseMode: modeNORMAL

    // 2. 呈现模态 (Presentation State) - 视窗呈现目标
    readonly property int stateREST: 0      // 常态静止
    readonly property int statePEEK: 1      // 用户光标主动在天花板探出
    readonly property int stateOVERLAY: 2   // 系统被动弹窗 (通知/计时完成/OSD/呼叫)
    readonly property int stateEXPANDED: 3  // 全卡片展开
    property int presentState: stateREST

    IslandTransientHub {
        id: transientHub
        onGeometryInvalidated: stageCtrl.stageGeometryRequested(false)
        onTransientDismissed: (key) => {
            // 当弹窗自然超时结束，平滑回到 REST 状态
            if (stageCtrl.presentState === stageCtrl.stateOVERLAY) {
                stageCtrl.presentState = stageCtrl.stateREST
                stageCtrl.stageGeometryRequested(false)
            }
        }
    }

    readonly property alias hub: transientHub
    readonly property alias activeOverlayKey: transientHub.activeKey
    readonly property alias activePayload: transientHub.activePayload

    property bool tuckArmed: true
    Timer {
        id: tuckArmTimer
        interval: 350
        repeat: false
        onTriggered: stageCtrl.tuckArmed = true
    }

    signal stageGeometryRequested(bool isModeSwitch)
    signal modeSwitchTriggered(bool isAnchored)

    // =========================================================================
    // 🚀【核心通道 1】：被动事件入栈 (通知 / 计时结束 / OSD / 通话)
    // =========================================================================
    function pushTransient(key, customDurationMs, payload) {
        if (presentState === stateEXPANDED && key !== "CALL") return false

        // 立即切断任何正在计时的鼠标离开定时器
        userLeaveTimer.stop()

        // 硬件级安全视口打通
        if (typeof Bridge !== "undefined") {
            if (Bridge.openFullCorridorForMotion) Bridge.openFullCorridorForMotion()
            if (Bridge.forceRaise) Bridge.forceRaise()
        }

        // 切换为独立弹窗状态
        presentState = stateOVERLAY
        var ok = transientHub.push(key, customDurationMs, payload)
        stageGeometryRequested(false)
        return ok
    }

    function popTransient(key) {
        transientHub.dismiss(key)
        if (presentState === stateOVERLAY) {
            presentState = stateREST
            stageGeometryRequested(false)
        }
    }

    // =========================================================================
    // 🚀【核心通道 2】：主动鼠标感应 (仅对用户 PEEK 生效，严禁干扰 OVERLAY)
    // =========================================================================
    function userHoverEnter() {
        if (baseMode !== modeTUCKED || !tuckArmed) return
        if (presentState === stateOVERLAY || presentState === stateEXPANDED) return
        if (presentState === statePEEK) return

        userLeaveTimer.stop()
        if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) {
            Bridge.openFullCorridorForMotion()
        }

        presentState = statePEEK
        stageGeometryRequested(false)
    }

    function userHoverKeep() {
        if (presentState === statePEEK) {
            userLeaveTimer.stop()
        }
    }

    function userHoverLeave() {
        if (presentState === statePEEK) {
            tuckArmed = true
            userLeaveTimer.restart()
        }
    }

    // 🚀 物理级隔离：定时器仅当且仅当处于 PEEK 状态时才执行复原
    Timer {
        id: userLeaveTimer
        interval: 160
        repeat: false
        onTriggered: {
            if (stageCtrl.presentState === stageCtrl.statePEEK) {
                stageCtrl.presentState = stageCtrl.stateREST
                stageCtrl.stageGeometryRequested(false)
            }
        }
    }

    // =========================================================================
    // 🚀【核心通道 3】：大卡片展开 / 隐藏切换
    // =========================================================================
    function requestExpand() {
        if (baseMode === modeTUCKED && presentState === stateREST) return
        popTransient()
        userLeaveTimer.stop()
        if (typeof Bridge !== "undefined") {
            if (Bridge.openFullCorridorForMotion) Bridge.openFullCorridorForMotion()
            if (Bridge.forceRaise) Bridge.forceRaise()
        }
        presentState = stateEXPANDED
        stageGeometryRequested(false)
    }

    function requestCollapse() {
        popTransient()
        userLeaveTimer.stop()
        presentState = stateREST
        stageGeometryRequested(false)
    }

    function toggleTuck() {
        popTransient()
        userLeaveTimer.stop()

        var willBeAnchored = (baseMode === modeTUCKED)
        baseMode = willBeAnchored ? modeNORMAL : modeTUCKED
        presentState = stateREST

        if (willBeAnchored) {
            tuckArmed = true
        } else {
            tuckArmed = false
            tuckArmTimer.restart()
        }

        modeSwitchTriggered(willBeAnchored)
        stageGeometryRequested(true)
    }
}