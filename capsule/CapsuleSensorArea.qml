// ==========================================
// 📄 File: capsule/CapsuleSensorArea.qml
// ==========================================
import QtQuick

Item {
    id: sensorRoot
    anchors.fill: parent

    // 状态注入
    property bool isExpanded: false
    property bool isCollapsing: false
    property bool isCalling: false
    property bool isNoticeActive: false
    property string activeTransient: ""
    property bool subBubbleInteracting: false
    property string expandedTab: ""
    property bool anySubBubbleHovered: false

    // 输出信号
    signal requestExpand(string tabName)
    signal requestCollapse()
    signal cancelCollapse()
    signal requestHideIsland()
    signal wheelAction(real deltaY)

    readonly property bool isCapsuleDirectHovered: capsuleRootHover.hovered || hitSensorArea.containsMouse
    readonly property bool isMouseOver: isCapsuleDirectHovered || (isExpanded && anySubBubbleHovered)

    property bool scrollSessionLocked: false

    // 1. 悬停展开时序管理器
    HoverHandler {
        id: capsuleRootHover
        onHoveredChanged: {
            if (hovered) {
                sensorRoot.cancelCollapse()
                if (!sensorRoot.isExpanded && !sensorRoot.isCollapsing && !sensorRoot.subBubbleInteracting) {
                    if (typeof Config === "undefined" || Config.hoverExpandEnabled !== false) {
                        hoverDwellTimer.restart()
                    }
                }
            } else {
                hoverDwellTimer.stop()
                sensorRoot.scrollSessionLocked = false
                sensorRoot.requestCollapse()
            }
        }
    }

    Timer {
        id: hoverDwellTimer
        interval: (typeof Config !== "undefined" && Config.hoverDwellTime !== undefined) ? Config.hoverDwellTime : 240
        onTriggered: {
            if (typeof Config !== "undefined" && Config.hoverExpandEnabled === false) return
            if (!sensorRoot.scrollSessionLocked && !sensorRoot.subBubbleInteracting && !sensorRoot.isCollapsing && sensorRoot.isCapsuleDirectHovered && !sensorRoot.isExpanded) {
                if (sensorRoot.isCalling) sensorRoot.requestExpand("media")
                else if (sensorRoot.activeTransient === "ALERT") sensorRoot.requestExpand("notification")
                else if (sensorRoot.activeTransient === "SEDENTARY") return
                else sensorRoot.requestExpand("workspace")
            }
        }
    }

    // 2. 离开失焦宽限定时器
    Timer {
        id: leaveGraceTimer
        interval: 180
        onTriggered: {
            if (!sensorRoot.isMouseOver && sensorRoot.isExpanded) {
                sensorRoot.requestCollapse()
            }
        }
    }

    function cancelLeaveGrace() { leaveGraceTimer.stop() }
    function startLeaveGrace() { if (sensorRoot.isExpanded) leaveGraceTimer.restart() }
    function stopDwell() { hoverDwellTimer.stop() }

    // 3. 点击与滚轮感应区
    MouseArea {
        id: hitSensorArea
        anchors.fill: parent
        z: (sensorRoot.isExpanded || sensorRoot.isNoticeActive) ? -1 : 1
        hoverEnabled: true

        acceptedButtons: sensorRoot.isExpanded ? Qt.NoButton : (Qt.LeftButton | Qt.RightButton)
        cursorShape: sensorRoot.isExpanded ? Qt.ArrowCursor : Qt.PointingHandCursor

        onEntered: {
            sensorRoot.cancelCollapse()
            sensorRoot.scrollSessionLocked = false
            if (!sensorRoot.isExpanded && !sensorRoot.isCollapsing && !sensorRoot.subBubbleInteracting) {
                if (typeof Config === "undefined" || Config.hoverExpandEnabled !== false) {
                    hoverDwellTimer.restart()
                }
            }
        }
        onExited: {
            hoverDwellTimer.stop()
            sensorRoot.scrollSessionLocked = false
            sensorRoot.requestCollapse()
        }
        onWheel: (wheel) => {
            wheel.accepted = true
            if (!sensorRoot.isExpanded || sensorRoot.expandedTab === "workspace") {
                sensorRoot.wheelAction(wheel.angleDelta.y)
            }
        }
        onClicked: (mouse) => {
            if (sensorRoot.isExpanded || sensorRoot.activeTransient === "SEDENTARY") return

            hoverDwellTimer.stop()
            leaveGraceTimer.stop()
            sensorRoot.scrollSessionLocked = false

            if (mouse.button === Qt.RightButton) {
                sensorRoot.requestHideIsland()
                return
            }

            if (sensorRoot.isCalling) { sensorRoot.requestExpand("media"); return }
            if (sensorRoot.activeTransient === "ALERT") { sensorRoot.requestExpand("notification"); return }
            sensorRoot.requestExpand("time")
        }
    }
}