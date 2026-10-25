// =========================================================================
// 📄 File: ui/core/IslandFsm.qml
// 🌟 核心状态机 (空安全防护 · 悬停与被动弹窗高优先级融合版)
// =========================================================================
import QtQuick

QtObject {
    id: fsm

    enum State {
        Hidden,         // 0
        Compact,        // 1
        Interacting,    // 2
        Overlay,        // 3
        Expanded        // 4
    }

    function stateName(s) {
        switch(s) {
            case 0: return "Hidden";
            case 1: return "Compact";
            case 2: return "Interacting";
            case 3: return "Overlay";
            case 4: return "Expanded";
            default: return "Unknown(" + s + ")";
        }
    }

    readonly property var priorityTable: ({
        "CALL": 100,
        "VOICE_INPUT": 80,
        "VOICE": 80,
        "SEDENTARY": 60,
        "ALERT": 40,
        "OSD": 30,
        "WORKSPACE": 20,
        "MEDIA_PEEK": 10
    })

    property int currentState: IslandFsm.State.Compact
    property int previousState: IslandFsm.State.Compact

    property string activeTransientKey: ""
    property var activePayload: ({})
    property int activePriority: 0
    property bool isTuckedPreference: false

    // 实时同步鼠标当前是否正停留在灵动岛或走廊范围内
    property bool isHovering: false

    signal stateChanged(int oldState, int newState, var context)

    function transitionTo(targetState, context) {
        if (currentState === targetState && targetState !== IslandFsm.State.Overlay) {
            return;
        }

        var oldState = currentState;
        previousState = oldState;
        currentState = targetState;

        fsm.stateChanged(oldState, currentState, context || {});
    }

    function postTransient(key, payload, durationMs) {
        var prio = priorityTable[key] || 0;

        if (currentState === IslandFsm.State.Overlay && prio < activePriority) {
            return false;
        }

        activeTransientKey = key;
        activePayload = payload || {};
        activePriority = prio;

        if (currentState !== IslandFsm.State.Interacting && currentState !== IslandFsm.State.Expanded) {
            transitionTo(IslandFsm.State.Overlay, { reason: "postTransient(" + key + ")" });
        } else {
            fsm.stateChanged(currentState, currentState, { key: key, payload: activePayload });
        }

        if (durationMs > 0) {
            transientTimer.interval = durationMs;
            transientTimer.restart();
        } else {
            transientTimer.stop();
        }

        return true;
    }

    function dismissTransient(key) {
        if (key && activeTransientKey !== key) return;

        transientTimer.stop();
        activeTransientKey = "";
        activePayload = ({});
        activePriority = 0;

        if (currentState === IslandFsm.State.Expanded) {
            return;
        }

        if (isTuckedPreference) {
            if (fsm.isHovering) {
                transitionTo(IslandFsm.State.Interacting, { reason: "dismissTransient_keep_hover" });
            } else {
                transitionTo(IslandFsm.State.Hidden, { reason: "dismissTransient_tucked" });
            }
        } else {
            transitionTo(IslandFsm.State.Compact, { reason: "dismissTransient_compact" });
        }
    }

    function handleIntent(intent, args) {
        var src = (args && args.source) ? args.source : "Unknown";
        console.log("[IslandFsm] 收到指令 -> intent: " + intent + " | 来源: " + src + " | 当前状态: " + stateName(currentState));

        switch (intent) {
            case "USER_ACTIVE":
                if (currentState === IslandFsm.State.Hidden || currentState === IslandFsm.State.Compact || currentState === IslandFsm.State.Overlay) {
                    transitionTo(IslandFsm.State.Interacting, { reason: "intent_USER_ACTIVE", source: src });
                }
                break;

            case "USER_IDLE":
                if (currentState === IslandFsm.State.Interacting || currentState === IslandFsm.State.Overlay) {
                    if (activeTransientKey !== "" && transientTimer.running) {
                        transitionTo(IslandFsm.State.Overlay, { reason: "idle_to_overlay", source: src });
                    } else if (isTuckedPreference) {
                        transitionTo(IslandFsm.State.Hidden, { reason: "idle_to_hidden", source: src });
                    } else {
                        transitionTo(IslandFsm.State.Compact, { reason: "idle_to_compact", source: src });
                    }
                }
                break;

            case "EXPAND":
                dismissTransient();
                transitionTo(IslandFsm.State.Expanded, { reason: "intent_EXPAND", source: src });
                break;

            case "COLLAPSE":
                if (currentState === IslandFsm.State.Expanded) {
                    console.log("[IslandFsm] 🚀 执行收回 COLLAPSE (来源: " + src + ")");
                    transitionTo(isTuckedPreference ? IslandFsm.State.Hidden : IslandFsm.State.Compact, { reason: "intent_COLLAPSE", source: src });
                }
                break;

            case "TOGGLE_TUCK":
                isTuckedPreference = !isTuckedPreference;
                dismissTransient();
                transitionTo(isTuckedPreference ? IslandFsm.State.Hidden : IslandFsm.State.Compact, { reason: "intent_TOGGLE_TUCK", source: src });
                break;
        }
    }

    property Timer transientTimer: Timer {
        repeat: false
        onTriggered: fsm.dismissTransient()
    }
}