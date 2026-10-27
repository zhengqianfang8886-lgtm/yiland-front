// =========================================================================
// 📄 File: ui/core/IslandFsm.qml
// 🌟 生产级有限状态机 (纯 QtObject 根对象 · 彻底移除洗牌锁定版)
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
        "OSD": 35,
        "WORKSPACE": 20,
        "MEDIA_PEEK": 10
    })

    property int currentState: IslandFsm.State.Compact
    property int previousState: IslandFsm.State.Compact

    property string activeTransientKey: ""
    property var activePayload: ({})
    property int activePriority: 0
    property real currentStartTime: 0
    property real currentDurationMs: 0

    property bool isTuckedPreference: false
    property bool isHovering: false
    property var transientStack: []

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

        if (activeTransientKey !== "") {
            if (prio < activePriority) {
                transientStack.push({
                    key: key,
                    payload: payload || {},
                    remainingMs: durationMs,
                    priority: prio
                });
                return false;
            }

            var elapsed = Date.now() - currentStartTime;
            var remain = Math.max(0, currentDurationMs - elapsed);
            if (currentDurationMs > 0 && remain > 800) {
                transientStack.push({
                    key: activeTransientKey,
                    payload: activePayload,
                    remainingMs: remain,
                    priority: activePriority
                });
            }
            transientTimer.stop();
        }

        activeTransientKey = key;
        activePayload = payload || {};
        activePriority = prio;
        currentStartTime = Date.now();
        currentDurationMs = durationMs;

        if (currentState !== IslandFsm.State.Expanded) {
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
        if (key && activeTransientKey !== key) {
            for (var i = transientStack.length - 1; i >= 0; i--) {
                if (transientStack[i].key === key) {
                    transientStack.splice(i, 1);
                    break;
                }
            }
            return;
        }

        transientTimer.stop();
        activeTransientKey = "";
        activePayload = ({});
        activePriority = 0;
        currentDurationMs = 0;

        if (transientStack.length > 0) {
            transientStack.sort(function(a, b) { return a.priority - b.priority; });
            var resumed = transientStack.pop();
            postTransient(resumed.key, resumed.payload, resumed.remainingMs);
            return;
        }

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
                transientTimer.stop();
                activeTransientKey = "";
                activePayload = ({});
                activePriority = 0;
                currentDurationMs = 0;
                transientStack = [];

                var targetTab = (args && args.tab) ? args.tab : "workspace";
                transitionTo(IslandFsm.State.Expanded, { reason: "intent_EXPAND", source: src, tab: targetTab });
                break;

            case "COLLAPSE":
                if (currentState === IslandFsm.State.Expanded) {
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