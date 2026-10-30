// =========================================================================
// 📄 File: ui/core/IslandActionBus.qml
// 🌟 统一动作语义分发总线 (手势与底层解耦 · 意图路由 · 结构化日志)
// =========================================================================
import QtQuick
import "IslandLogger.js" as Logger

QtObject {
    id: actionBus

    property var bridge: null
    property var fsm: null

    function triggerAction(intent, context) {
        var ctx = context || {};
        Logger.action(intent, JSON.stringify(ctx));

        switch (intent) {
            case "TRIGGER_DESKTOP_GRID":
                if (bridge && bridge.toggleDesktopGrid) {
                    bridge.toggleDesktopGrid();
                }
                break;

            case "WORKSPACE_PREV":
                if (bridge && bridge.switchWorkspacePrev) {
                    bridge.switchWorkspacePrev();
                }
                break;

            case "WORKSPACE_NEXT":
                if (bridge && bridge.switchWorkspaceNext) {
                    bridge.switchWorkspaceNext();
                }
                break;

            case "EXPAND_CARD":
                var tab = ctx.tab || "calendar";
                if (fsm) {
                    fsm.handleIntent("EXPAND", { tab: tab, source: ctx.source || "ActionBus" });
                }
                break;

            case "COLLAPSE_CARD":
                if (fsm) {
                    fsm.handleIntent("COLLAPSE", { source: ctx.source || "ActionBus" });
                }
                break;

            case "TOGGLE_TUCK":
                if (fsm) {
                    fsm.handleIntent("TOGGLE_TUCK", { source: ctx.source || "ActionBus" });
                }
                break;

            case "OPEN_SETTINGS":
                if (ctx.callback) {
                    ctx.callback();
                }
                break;

            default:
                Logger.info("ActionBus", "未识别的动作意图: " + intent);
                break;
        }
    }
}