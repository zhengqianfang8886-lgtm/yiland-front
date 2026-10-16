// ==========================================
// 📄 File: IslandStateMachine.qml
// 🌟 动静分离权威状态机
// ==========================================
import QtQuick

Item {
    id: fsm

    property string stateName: "NORMAL"
    property bool isSettled: true
    property bool isBlockedByTransient: false

    property bool tuckLockout: false

    signal stateChangedTo(string newState)

    // 动作 1: 吸顶
    function evRightClickHide() {
        tuckLockout = true
        tuckLockoutTimer.restart()
        peekRetractTimer.stop()
        hoverGraceTimer.stop()

        isSettled = false
        stateName = "TUCKED"
        stateChangedTo(stateName)
    }

    // 动作 2: 碰触顶端微弧探头
    function evHoverPeek() {
        if (tuckLockout) return
        hoverGraceTimer.stop()

        if (stateName === "TUCKED") {
            peekRetractTimer.stop()
            isSettled = false
            stateName = "PEEKING"
            stateChangedTo(stateName)
        }
    }

    // 动作 3: 鼠标离开探头
    function evHoverLeave() {
        if (stateName === "PEEKING") {
            hoverGraceTimer.restart()
        }
    }

    // 动作 4: 鼠标保持
    function evHoverKeep() {
        hoverGraceTimer.stop()
        peekRetractTimer.stop()
    }

    // 动作 5: 钉住/复原常态
    function evLeftClickPin() {
        tuckLockout = false
        tuckLockoutTimer.stop()
        peekRetractTimer.stop()
        hoverGraceTimer.stop()

        if (stateName !== "NORMAL") {
            isSettled = false
            stateName = "NORMAL"
            stateChangedTo(stateName)
        }
    }

    // 动作 6: 展开大卡片
    function evExpandCard() {
        tuckLockout = false
        peekRetractTimer.stop()
        hoverGraceTimer.stop()

        if (stateName !== "EXPANDED") {
            isSettled = false
            stateName = "EXPANDED"
            stateChangedTo(stateName)
        }
    }

    // 动作 7: 收起大卡片
    function evCollapseCard() {
        if (stateName !== "NORMAL") {
            isSettled = false
            stateName = "NORMAL"
            stateChangedTo(stateName)
        }
    }

    function reportMotionStart() {
        isSettled = false
    }

    function reportMotionSettled() {
        settleDebounceTimer.restart()
    }

    // 🚀【绝对稳定滤波】：确保动画曲线完全走完（包括弹簧 overshoot）之后，才允许结算遮罩
    Timer {
        id: settleDebounceTimer
        interval: 60
        repeat: false
        onTriggered: {
            fsm.isSettled = true
        }
    }

    Timer {
        id: tuckLockoutTimer
        interval: 320
        repeat: false
        onTriggered: fsm.tuckLockout = false
    }

    Timer {
        id: hoverGraceTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (fsm.stateName === "PEEKING") {
                peekRetractTimer.restart()
            }
        }
    }

    Timer {
        id: peekRetractTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (fsm.stateName === "PEEKING") {
                fsm.isSettled = false
                fsm.stateName = "TUCKED"
                fsm.stateChangedTo(fsm.stateName)
            }
        }
    }
}