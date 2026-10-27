// ==========================================
// 📄 File: ui/windows/Island.qml
// 🌟 顶级窗口视图 (空心环感应适配 · 纯净稳定版)
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

    // 展开态空心感应协调器
    ExpandedSensorCoordinator {
        id: expandedCoordinator
        targetCapsule: capsule
        isExpanded: (fsm.currentState === IslandFsm.State.Expanded)

        onRequestCollapse: (reason) => {
            console.log("[IslandRoot] 📢 接收到协调器收起请求，原因: " + reason);
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
        onRequestSettings: root.openSettingsWindow()
    }

    readonly property bool isUserHovering: corridorArea.containsMouse || (capsule && capsule.isHovered)

    onIsUserHoveringChanged: {
        if (capsule && capsule.isMoving) {
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
        width: capsule ? Math.max(160, capsule.width + 12) : 260

        readonly property bool isExpanded: fsm ? (fsm.currentState === IslandFsm.State.Expanded) : false
        enabled: !isExpanded && (!capsule || !capsule.isMoving)
        height: isExpanded ? 0 : ((fsm.currentState === IslandFsm.State.Hidden) ? 10 : (capsule ? Math.round(capsule.y + capsule.height + 2) : 40))

        z: 5
        hoverEnabled: true
        acceptedButtons: Qt.RightButton

        Timer {
            id: userLeaveDebounce
            interval: 220
            repeat: false
            onTriggered: {
                if ((!capsule || !capsule.isMoving) && fsm.currentState !== IslandFsm.State.Expanded) {
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