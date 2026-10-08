// ==========================================
// 📄 File: AppsBubbleView.qml
// 🌟 解决子图标抢占 Hover · 展开状态绝对稳固
// ==========================================
import QtQuick
import QtQuick.Controls
import "apps"

Rectangle {
    id: appsBubbleRoot

    property bool active: true
    readonly property bool isHovered: bubbleHover.hovered || gridComponent.hasActiveChildHover
    property bool isExpanded: false

    signal clicked()
    signal wheelInteracted()
    signal requestOpenManagerWindow()

    readonly property int targetWidth: isExpanded ? 220 : 40
    readonly property int targetHeight: isExpanded ? 220 : 34
    readonly property int targetRadius: isExpanded ? 22 : 17

    width: targetWidth
    height: targetHeight
    radius: targetRadius
    clip: true

    antialiasing: true
    smooth: true

    color: isExpanded ? "#14141c" : Theme.bgCapsule
    border.width: 1
    border.color: isExpanded ?
                  Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.45) :
                  (appsBubbleRoot.isHovered ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.85) : Theme.borderSubtle)

    Behavior on width {
        NumberAnimation {
            duration: appsBubbleRoot.isExpanded ? Theme.animSpring : 140
            easing.type: appsBubbleRoot.isExpanded ? Theme.curveSpring : Easing.OutCubic
            easing.overshoot: appsBubbleRoot.isExpanded ? Theme.springOvershootNormal : 1.0
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: appsBubbleRoot.isExpanded ? Theme.animSpring : 140
            easing.type: appsBubbleRoot.isExpanded ? Theme.curveSpring : Easing.OutCubic
            easing.overshoot: appsBubbleRoot.isExpanded ? Theme.springOvershootNormal : 1.0
        }
    }
    Behavior on radius {
        NumberAnimation {
            duration: appsBubbleRoot.isExpanded ? Theme.animSpring : 140
            easing.type: appsBubbleRoot.isExpanded ? Theme.curveSpring : Easing.OutCubic
            easing.overshoot: appsBubbleRoot.isExpanded ? Theme.springOvershootNormal : 1.0
        }
    }

    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    visible: opacity > 0.001
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveFluid } }
    Behavior on scale {
        NumberAnimation { duration: Theme.animSpring; easing.type: Theme.curveSpring; easing.overshoot: Theme.springOvershootNormal }
    }

    function logT(tag, msg) {
        if (typeof Bridge !== "undefined" && Bridge.traceLog) {
            Bridge.traceLog(tag, msg)
        } else {
            console.log("[" + tag + "] " + msg)
        }
    }

    // 🚀【跟手修复 1】：离开缓冲由 700ms 压缩至 150ms（既防手抖，又移开即收）
    Timer {
        id: leaveGraceTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (appsBubbleRoot.isExpanded && !appsBubbleRoot.isHovered) {
                appsBubbleRoot.collapse()
            }
        }
    }

    function collapse() {
        appsBubbleRoot.logT("TRACE-APPS", "调用 collapse(): isExpanded -> false")
        appsBubbleRoot.isExpanded = false
    }

    function expand() {
        appsBubbleRoot.logT("TRACE-APPS", "调用 expand(): isExpanded -> true")
        leaveGraceTimer.stop()
        appsBubbleRoot.isExpanded = true
    }

    Item {
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: appsBubbleRoot.isExpanded ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveFluid } }

        Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: 3
            Repeater {
                model: 4
                Rectangle {
                    width: 4; height: 4; radius: 1.5
                    color: appsBubbleRoot.isHovered ? "#38bdf8" : Qt.rgba(1, 1, 1, 0.85)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
            }
        }
    }

    AppGridView {
        id: gridComponent
        anchors.fill: parent
        visible: opacity > 0.001
        opacity: appsBubbleRoot.isExpanded ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveFluid } }

        // 🚀【关键】：只要子组件网格内有活动，随时清空收缩计时器
        onHoveredAppNameChanged: {
            if (hoveredAppName !== "") {
                leaveGraceTimer.stop()
            }
        }

        onRequestAdd: {
            if (typeof Bridge !== "undefined" && Bridge.openAppManagerWindow) {
                Bridge.openAppManagerWindow()
            }
            appsBubbleRoot.requestOpenManagerWindow()
            appsBubbleRoot.collapse()
        }

        onRequestLaunch: (appId) => {
            if (typeof Bridge !== "undefined" && Bridge.launchApp) {
                Bridge.launchApp(appId)
            }
            appsBubbleRoot.collapse()
        }

        onRequestDelete: (appId) => {
            if (typeof Bridge !== "undefined" && Bridge.deleteApp) {
                Bridge.deleteApp(appId)
            }
        }
    }

    HoverHandler {
        id: bubbleHover
        cursorShape: appsBubbleRoot.isExpanded ? Qt.ArrowCursor : Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered) {
                leaveGraceTimer.stop()
            } else if (appsBubbleRoot.isExpanded) {
                if (!gridComponent.hasActiveChildHover) {
                    leaveGraceTimer.restart()
                }
            }
        }
    }

    TapHandler {
        enabled: !appsBubbleRoot.isExpanded
        onTapped: appsBubbleRoot.expand()
    }
}