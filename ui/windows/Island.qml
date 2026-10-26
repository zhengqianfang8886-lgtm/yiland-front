// =========================================================================
// 📄 File: ui/windows/Island.qml
// 🌟 顶级窗口视图 (运动态感应自锁 · 彻底根除假悬停顿挫版)
// =========================================================================
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

    Component.onCompleted: {
        capsule.resolveAndExpress();
        if (typeof Bridge !== "undefined" && Bridge.setUiActive) {
            Bridge.setUiActive(fsm.currentState !== IslandFsm.State.Hidden);
        }
        fsm.isHovering = isUserHovering;
    }

    Shortcut {
        sequence: "Escape"
        enabled: fsm.currentState === IslandFsm.State.Expanded
        onActivated: fsm.handleIntent("COLLAPSE", { source: "Shortcut_Escape" })
    }

    IslandFsm { id: fsm }

    IslandTimeService { 
        id: timeService 
        isTucked: (fsm.currentState === IslandFsm.State.Hidden)
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

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onWindowDeactivated() {
            if (root.isSettingsOpen) return;
            if (fsm.currentState === IslandFsm.State.Expanded) {
                fsm.handleIntent("COLLAPSE", { source: "Wayland_External_Click_Deactivated" });
            }
        }
    }

    ExpandedSensorCoordinator {
        id: expandedCoordinator
        targetCapsule: capsule
        isExpanded: (fsm.currentState === IslandFsm.State.Expanded)
        leaveDelayMs: 150

        onRequestCollapse: (reason) => fsm.handleIntent("COLLAPSE", { source: reason })
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
        onRequestSettings: root.openSettingsWindow()
    }

    readonly property bool isUserHovering: corridorArea.containsMouse || capsule.isHovered

    onIsUserHoveringChanged: {
        // 🚀【核心根治】：当灵动岛正在做物理收缩或形变时，绝对禁止触发 USER_ACTIVE 干扰减速曲线！
        if (capsule.isMoving) {
            return;
        }

        fsm.isHovering = isUserHovering;
        if (isUserHovering) {
            userLeaveDebounce.stop();
            fsm.handleIntent("USER_ACTIVE", { source: "Hover_Enter" });
        } else {
            if (fsm.currentState !== IslandFsm.State.Expanded) {
                userLeaveDebounce.restart();
            }
        }
    }

    MouseArea {
        id: corridorArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 360

        readonly property bool isExpanded: fsm ? (fsm.currentState === IslandFsm.State.Expanded) : false
        // 🚀 形变运动中自动挂起走廊感应，杜绝收缩边缘擦过引发假触控
        enabled: !isExpanded && !capsule.isMoving
        height: isExpanded ? 0 : ((fsm.currentState === IslandFsm.State.Hidden) ? 10 : 54)

        z: 5
        hoverEnabled: true
        acceptedButtons: Qt.RightButton

        Timer {
            id: userLeaveDebounce
            interval: 220
            repeat: false
            onTriggered: {
                if (!capsule.isMoving) {
                    fsm.handleIntent("USER_IDLE", { source: "Corridor_Debounce" });
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

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                fsm.handleIntent("TOGGLE_TUCK", { source: "Right_Click_Tuck" });
            }
        }
    }

    Loader {
        id: settingsLoader
        active: false
        source: "SettingsWindow.qml"
        onLoaded: {
            item.visibleChanged.connect(function() {
                root.isSettingsOpen = item.visible;
            });
            item.openCentered(); // 🚀 在屏幕正中心独立弹出！
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