// ==========================================
// 📄 File: IslandStateMachine.qml
// 🌟 解决右键后自碰自弹 · 加入隐藏保护期版
// ==========================================
import QtQuick

Item {
    id: fsm

    readonly property string stateNORMAL: "NORMAL"       // 常态驻留
    readonly property string stateEXPANDED: "EXPANDED"   // 大卡片展开
    readonly property string stateTUCKED: "TUCKED"       // 天花板静默潜航
    readonly property string statePEEKING: "PEEKING"     // 主动意图：鼠标悬停探出中
    readonly property string statePASSIVE: "PASSIVE_5S"  // 被动事件：5秒展示中

    property string stateName: stateNORMAL
    property bool manualLocked: false
    property bool isSettled: true

    // 🚀【核心机制】：隐藏保护期锁（防止收缩过程中探头撞上光标自弹）
    property bool tuckLockout: false

    Timer {
        id: tuckLockoutTimer
        interval: 700 // 700ms 保护期，覆盖完整收缩动效与光标停留
        repeat: false
        onTriggered: fsm.tuckLockout = false
    }

    signal stateChangedTo(string newState)
    signal clearTransientRequested()

    // =========================================================================
    // 1. 唯一永久切换锁：鼠标右键
    // =========================================================================
    function evRightClickToggle() {
        if (tuckLockout) return

        passiveTimer.stop()
        hoverGraceTimer.stop()
        fsm.clearTransientRequested()

        // 启动 700ms 保护锁，封死任何误触
        tuckLockout = true
        tuckLockoutTimer.restart()

        if (manualLocked || stateName === stateTUCKED || stateName === statePEEKING || stateName === statePASSIVE) {
            manualLocked = false
            isSettled = false
            stateName = stateNORMAL
            stateChangedTo(stateName)
        } else {
            manualLocked = true
            isSettled = false
            stateName = stateTUCKED
            stateChangedTo(stateName)
        }
    }

    // =========================================================================
    // 2. 主动意图通道：鼠标悬停（受保护期严密防护）
    // =========================================================================
    function evHoverPeek() {
        // 🚀 保护期内绝对不准探出！
        if (!manualLocked || tuckLockout) return

        hoverGraceTimer.stop()

        if (stateName === statePASSIVE) {
            passiveTimer.stop()
        }

        if (stateName === stateTUCKED || stateName === statePASSIVE) {
            isSettled = false
            stateName = statePEEKING
            stateChangedTo(stateName)
        }
    }

    function evHoverKeep() {
        if (!manualLocked || tuckLockout) return
        hoverGraceTimer.stop()
    }

    function evHoverLeave() {
        if (!manualLocked) return
        if (stateName === statePEEKING) {
            hoverGraceTimer.restart()
        }
    }

    // =========================================================================
    // 3. 被动事件通道：5 秒倒计时出水
    // =========================================================================
    function evPassiveSurface() {
        if (!manualLocked || tuckLockout) return
        if (stateName === statePEEKING) return

        passiveTimer.interval = 5000
        passiveTimer.restart()

        if (stateName !== statePASSIVE) {
            isSettled = false
            stateName = statePASSIVE
            stateChangedTo(stateName)
        }
    }

    // =========================================================================
    // 4. 大卡片展开控制
    // =========================================================================
    function evExpandCard() {
        if (manualLocked || stateName === stateTUCKED || stateName === statePEEKING || stateName === statePASSIVE) {
            return
        }
        if (stateName !== stateEXPANDED) {
            isSettled = false
            stateName = stateEXPANDED
            stateChangedTo(stateName)
        }
    }

    function evCollapseCard() {
        fsm.clearTransientRequested()
        if (manualLocked) {
            isSettled = false
            stateName = stateTUCKED
            stateChangedTo(stateName)
        } else if (stateName !== stateNORMAL) {
            isSettled = false
            stateName = stateNORMAL
            stateChangedTo(stateName)
        }
    }

    // =========================================================================
    // 5. 定时器
    // =========================================================================
    Timer {
        id: passiveTimer
        repeat: false
        onTriggered: {
            if (fsm.stateName === fsm.statePASSIVE) {
                fsm.clearTransientRequested()
                fsm.isSettled = false
                fsm.stateName = fsm.stateTUCKED
                fsm.stateChangedTo(fsm.stateName)
            }
        }
    }

    Timer {
        id: hoverGraceTimer
        interval: 160
        repeat: false
        onTriggered: {
            if (fsm.stateName === fsm.statePEEKING) {
                fsm.clearTransientRequested()
                fsm.isSettled = false
                fsm.stateName = fsm.stateTUCKED
                fsm.stateChangedTo(fsm.stateName)
            }
        }
    }

    Timer {
        id: settleDebounceTimer
        interval: 80
        repeat: false
        onTriggered: fsm.isSettled = true
    }

    function reportMotionStart() { isSettled = false }
    function reportMotionSettled() { settleDebounceTimer.restart() }
}