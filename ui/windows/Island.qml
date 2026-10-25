// =========================================================================
// 📄 File: ui/windows/Island.qml
// 🌟 顶级窗口视图 (根除设置窗口焦点死循环闪烁版)
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
    Keys.onPressed: (event) => {
        console.log("[Island:Window] 🎹 窗口层捕获按键 -> key=" + event.key + ", text=" + event.text);
    }

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
        onActivated: {
            fsm.handleIntent("COLLAPSE", { source: "Shortcut_Escape" });
        }
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

    // 🚀【防死锁标志】：打开设置窗口时不进行焦点争夺
    property bool isSettingsOpen: false

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onWindowDeactivated() {
            // 如果正在与设置窗口交互，不要盲目抢焦点
            if (root.isSettingsOpen) return;

            if (fsm.currentState === IslandFsm.State.Expanded) {
                console.log("[Island] 🎯 捕获到外部点击失焦 -> 平滑收起大卡片");
                fsm.handleIntent("COLLAPSE", { source: "Wayland_External_Click_Deactivated" });
            }
        }
    }

    ExpandedSensorCoordinator {
        id: expandedCoordinator
        targetCapsule: capsule
        isExpanded: (fsm.currentState === IslandFsm.State.Expanded)
        leaveDelayMs: 120

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
            // 🚀【核心加固】：如果是因为去打开偏好设置窗口，绝对不能触发 restorePreviousFocus 抢夺焦点！
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
        width: Math.max(188, capsule.width + 16)

        readonly property bool isExpanded: fsm ? (fsm.currentState === IslandFsm.State.Expanded) : false
        enabled: !isExpanded
        height: isExpanded ? 0 : ((fsm.currentState === IslandFsm.State.Hidden) ? 10 : Math.max(48, capsule.y + capsule.height + 6))

        z: 5
        hoverEnabled: true
        acceptedButtons: Qt.RightButton

        Timer {
            id: userLeaveDebounce
            interval: 250
            repeat: false
            onTriggered: fsm.handleIntent("USER_IDLE", { source: "Corridor_Debounce" })
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
            item.show();
            item.raise();
            item.requestActivate();
        }
    }

    // 🚀【核心加固】：点击设置时，先安全收回大卡片，立起防争夺标志，再弹出设置窗口
    function openSettingsWindow() {
        root.isSettingsOpen = true;
        if (fsm.currentState === IslandFsm.State.Expanded) {
            fsm.handleIntent("COLLAPSE", { source: "OpenSettings_PreCollapse" });
        }

        if (settingsLoader.status === Loader.Ready && settingsLoader.item) {
            settingsLoader.item.show();
            settingsLoader.item.raise();
            settingsLoader.item.requestActivate();
        } else {
            settingsLoader.active = true;
        }
    }
}