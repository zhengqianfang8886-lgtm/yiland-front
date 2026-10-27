// ==========================================
// 📄 File: ui/windows/Island.qml
// 🌟 顶级窗口视图 (集成平铺网格时序隐形防抓取版)
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

    // 🚀【核心隐形门禁】：平铺网格激活时，视图透明度归零，KWin 无法抓取到任何药丸图案
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
            console.log("[IslandRoot] ⌨️ 捕获 Escape 按键，执行唯一收起");
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
        sedentaryService: sedentaryService
        onRequestSettings: root.openSettingsWindow()
    }

    readonly property bool isUserHovering: corridorArea.containsMouse || (capsule && capsule.isHovered)

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

    // 顶部外围走廊感应区
    MouseArea {
        id: corridorArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: capsule ? Math.max(180, capsule.width + 24) : 260

        readonly property bool isExpanded: fsm ? (fsm.currentState === IslandFsm.State.Expanded) : false
        enabled: !isExpanded && !root.isGridActive
        height: isExpanded ? 0 : ((fsm && fsm.currentState === IslandFsm.State.Hidden) ? 14 : (capsule ? Math.round(capsule.y + capsule.height + 6) : 48))

        z: 5
        hoverEnabled: true
        acceptedButtons: Qt.RightButton

        Timer {
            id: userLeaveDebounce
            interval: 320
            repeat: false
            onTriggered: {
                if (fsm.currentState !== IslandFsm.State.Expanded) {
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