// =========================================================================
// 📄 File: ui/windows/Island.qml
// 🌟 顶级窗口视图 (全局遮罩离开守卫 · 彻底消灭下方点击穿透失败版)
// =========================================================================
import QtQuick
import QtQml
import QtQuick.Controls
import "../core"
import "../shell"
import "../components/expanded"

Item {
    id: root
    width: 780
    height: 520
    focus: true

    readonly property bool isGridActive: (typeof Bridge !== "undefined" && Bridge.isGridActive !== undefined) ? Bridge.isGridActive : false

    onIsGridActiveChanged: {
        if (isGridActive) {
            fsm.handleIntent("COLLAPSE", { source: "Grid_Active_Force_Collapse" });
        }
    }

    opacity: isGridActive ? 0.0 : 1.0
    visible: opacity > 0.001

    Behavior on opacity {
        NumberAnimation {
            duration: root.isGridActive ? 30 : 180
            easing.type: Easing.OutQuad
        }
    }

    Component.onCompleted: {
        if (capsule) {
            capsule.resolveAndExpress();
            capsule.executeActualMaskCommit();
        }

        if (typeof Bridge !== "undefined" && Bridge.setUiActive) {
            Bridge.setUiActive(fsm.currentState !== IslandFsm.State.Hidden);
        }
        fsm.isHovering = isUserHovering;
    }

    Shortcut {
        sequence: "Escape"
        enabled: fsm.currentState === IslandFsm.State.Expanded
        onActivated: {
            fsm.handleIntent("COLLAPSE", { source: "Shortcut_Escape" });
        }
    }

    IslandFsm { id: fsm }

    IslandTimeService { 
        id: timeService 
        isTucked: (fsm.currentState === IslandFsm.State.Hidden)
    }

    IslandSedentaryService {
        id: sedentaryService
        fsm: fsm
    }

    IslandBridgeRelay { id: relay; fsm: fsm }

    Connections {
        target: fsm
        function onCurrentStateChanged() {
            var isVisible = (fsm.currentState !== IslandFsm.State.Hidden);
            if (typeof Bridge !== "undefined" && Bridge.setUiActive) {
                Bridge.setUiActive(isVisible);
            }
        }
    }

    property bool isSettingsOpen: false

    ExpandedSensorCoordinator {
        id: expandedCoordinator
        targetCapsule: capsule
        isExpanded: (fsm.currentState === IslandFsm.State.Expanded)

        onRequestCollapse: (reason) => {
            fsm.handleIntent("COLLAPSE", { source: reason });
        }
        onRequestAcquireFocus: {
            if (root.isSettingsOpen) return;
            if (typeof Bridge !== "undefined" && Bridge.requestWindowFocus) {
                Bridge.requestWindowFocus();
            }
            root.forceActiveFocus();
        }
        onRequestRestoreFocus: {
            if (root.isSettingsOpen) return;
            if (typeof Bridge !== "undefined" && Bridge.restorePreviousFocus) {
                Bridge.restorePreviousFocus();
            }
        }
    }

    IslandCapsule {
        id: capsule
        z: 20
        fsm: fsm
        relay: relay
        timeService: timeService
        sedentaryService: sedentaryService
        onRequestSettings: root.openSettingsWindow()

        scale: (capsule.isRightPressing || corridorArea.isRightPressing) ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    // 全域综合悬停判定
    readonly property bool isUserHovering: corridorArea.containsMouse || 
                                          corridorHover.hovered || 
                                          (capsule && capsule.isHovered)

    onIsUserHoveringChanged: {
        fsm.isHovering = isUserHovering;
        if (isUserHovering) {
            userLeaveDebounce.stop();
            fsm.handleIntent("USER_ACTIVE", { source: "Hover_Enter" });
        } else {
            if (fsm.currentState !== IslandFsm.State.Expanded) {
                userLeaveDebounce.restart();
            }
            // 🚀【终极补丁】：只要鼠标离开整个岛屿，无条件强制下发精细遮罩，把下方控制权还给屏幕！
            if (capsule && !capsule.isCurrentExpanded && !capsule.isAnyMenuOpen) {
                capsule.executeActualMaskCommit();
            }
        }
    }

    MouseArea {
        id: corridorArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: capsule ? Math.max(340, capsule.baseRestingWidth + 24) : 340
        property bool isRightPressing: false

        readonly property bool isExpanded: fsm ? (fsm.currentState === IslandFsm.State.Expanded) : false
        enabled: !isExpanded && !root.isGridActive && !(capsule && capsule.isActivelyPulling)
        height: isExpanded ? 0 : ((fsm && fsm.currentState === IslandFsm.State.Hidden) ? 18 : 52)

        z: 5
        hoverEnabled: true
        acceptedButtons: Qt.RightButton

        HoverHandler {
            id: corridorHover
            enabled: !root.isGridActive
        }

        Timer {
            id: userLeaveDebounce
            interval: 280
            repeat: false
            onTriggered: {
                if (fsm.currentState !== IslandFsm.State.Expanded && !root.isUserHovering) {
                    fsm.handleIntent("USER_IDLE", { source: "Hysteresis_Guard_Timeout" });
                }
            }
        }

        onWheel: (wheel) => {
            userLeaveDebounce.stop();
            fsm.isHovering = true;
            if (typeof Bridge !== "undefined") {
                if (wheel.angleDelta.y > 0) Bridge.switchWorkspacePrev();
                else Bridge.switchWorkspaceNext();
            }
        }

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) corridorArea.isRightPressing = true;
        }
        onReleased: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                corridorArea.isRightPressing = false;
                fsm.handleIntent("TOGGLE_TUCK", { source: "Right_Click_Tuck" });
            }
        }
        onCanceled: { corridorArea.isRightPressing = false; }
    }

    Loader {
        id: settingsLoader
        active: false
        source: "SettingsWindow.qml"
        onLoaded: {
            item.visibleChanged.connect(function() {
                root.isSettingsOpen = item.visible;
            });
            item.openCentered();
        }
    }

    function openSettingsWindow() {
        root.isSettingsOpen = true;
        if (fsm.currentState === IslandFsm.State.Expanded) {
            fsm.handleIntent("COLLAPSE", { source: "OpenSettings_PreCollapse" });
        }

        if (settingsLoader.status === Loader.Ready && settingsLoader.item) {
            settingsLoader.item.openCentered();
        } else {
            settingsLoader.active = true;
        }
    }
}