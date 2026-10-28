// ==========================================
// 📄 File: ui/windows/Island.qml
// 🌟 顶级窗口视图 (极速跟手 · 零粘滞退场 · 纯净日历与超时联动版)
// ==========================================
import QtQuick
import QtQuick.Controls
import "../core"
import "../shell"
import "../components/expanded"

Item {
    id: root
    width: 680
    height: 480

    focus: true

    readonly property bool isGridActive: (typeof Bridge !== "undefined" && Bridge.isGridActive !== undefined) ? Bridge.isGridActive : false

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

    readonly property bool isUserHovering: corridorArea.containsMouse || (capsule && capsule.isHovered)

    onIsUserHoveringChanged: {
        fsm.isHovering = isUserHovering;
        if (isUserHovering) {
            userLeaveDebounce.stop();
            fsm.handleIntent("USER_ACTIVE", { source: "Hover_Enter" });
        } else {
            if (fsm.currentState !== IslandFsm.State.Expanded) {
                // 移出后立即启动短延迟防抖
                userLeaveDebounce.restart();
            }
        }
    }

    // =========================================================================
    // 顶部外围走廊感应区 (边缘收紧 · 杜绝无形区域阻碍鼠标退出)
    // =========================================================================
    MouseArea {
        id: corridorArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        // 🚀【优化 1】：从原先多出的 24px 缩减至紧凑贴合的 6px，鼠标滑出胶囊立即判定离开
        width: capsule ? Math.max(180, capsule.width + 6) : 220

        property bool isRightPressing: false

        readonly property bool isExpanded: fsm ? (fsm.currentState === IslandFsm.State.Expanded) : false
        enabled: !isExpanded && !root.isGridActive
        height: isExpanded ? 0 : ((fsm && fsm.currentState === IslandFsm.State.Hidden) ? 10 : (capsule ? Math.round(capsule.y + capsule.height + 4) : 44))

        z: 5
        hoverEnabled: true
        acceptedButtons: Qt.RightButton

        // 🚀【优化 2】：将原先 500ms 的死等，削减到极度跟手的 100ms！
        Timer {
            id: userLeaveDebounce
            interval: (fsm && fsm.isTuckedPreference) ? 90 : 120
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