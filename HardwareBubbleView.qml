// ==========================================
// 📄 File: HardwareBubbleView.qml (触感分层·非对称冲程·渐隐流光版)
// ==========================================
import QtQuick

Rectangle {
    id: typingBubbleRoot

    // 外部数据直接接口
    property bool isTyping: false
    property color typingThemeColor: "#38bdf8"
    property real spec1: 0.0  // 键 1 瞬态冲程 (0.0 ~ 1.0)
    property real spec2: 0.0  // 键 2 瞬态冲程 (0.0 ~ 1.0)
    property real spec3: 0.0  // 键 3 瞬态冲程 (0.0 ~ 1.0)
    property real spec4: 0.0  // 键 4 瞬态冲程 (0.0 ~ 1.0)
    property real kps: 0.0    // 实际代表平滑后的 intensity * 10 (0.0 ~ 10.0)

    property bool active: true
    readonly property bool isHovered: bubbleHover.hovered

    // =========================================================================
    // 状态反馈层 (Macro Flow / State Layer)
    // =========================================================================
    readonly property real intensity: Math.max(0.0, Math.min(1.0, kps / 10.0))
    readonly property bool isIdle: intensity < 0.02 && !isTyping

    // 迟滞区间状态 (进入需 >= 0.85，退出需 < 0.68)
    property bool inRageState: false
    onIntensityChanged: {
        if (!inRageState && intensity >= 0.85) inRageState = true
        else if (inRageState && intensity < 0.68) inRageState = false
    }

    // Rage 外圈只在刚刚进入该状态的瞬间单次爆发
    onInRageStateChanged: {
        if (inRageState) rageSingleBurstAnim.restart()
    }

    readonly property int islandWidth: 60
    readonly property int islandHeight: 34
    readonly property bool isExpanded: false

    width: islandWidth
    height: islandHeight
    radius: 17
    clip: false
    transformOrigin: Item.Left

    color: Theme.bgCapsule

    // 状态反馈：边框无级柔和过渡
    border.width: isIdle ? 1.0 : (1.2 + intensity * 0.6)
    border.color: isIdle ? Qt.rgba(1, 1, 1, 0.15) : typingThemeColor

    Behavior on border.width { NumberAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: isIdle ? 300 : 90 } }

    visible: active
    opacity: active ? 1.0 : 0.0

    // =========================================================================
    // 1. 状态层：Rage 单次脉冲冲击波 (单次爆发消散，不持续循环)
    // =========================================================================
    Rectangle {
        id: rageBurstRing
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: typingBubbleRoot.typingThemeColor
        border.width: 1.5
        visible: opacity > 0.001
        opacity: 0.0
        scale: 1.0

        ParallelAnimation {
            id: rageSingleBurstAnim
            NumberAnimation { target: rageBurstRing; property: "scale"; from: 1.0; to: 1.34; duration: 460; easing.type: Easing.OutCubic }
            NumberAnimation { target: rageBurstRing; property: "opacity"; from: 0.85; to: 0.0; duration: 460; easing.type: Easing.OutQuad }
        }
    }

    // =========================================================================
    // 2. 状态层：机身核心氛围底光 (根据 intensity 平滑膨胀与增亮)
    // =========================================================================
    Rectangle {
        anchors.centerIn: parent
        width: 38 + typingBubbleRoot.intensity * 12
        height: 16 + typingBubbleRoot.intensity * 8
        radius: 11
        color: Qt.rgba(typingThemeColor.r, typingThemeColor.g, typingThemeColor.b, 
                       typingBubbleRoot.isIdle ? 0.04 : (0.10 + typingBubbleRoot.intensity * 0.20))

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // =========================================================================
    // 3. 按键反馈层 (Key Stroke Tactile Layer)：4 颗微型机械键帽
    // 彻底解耦：下潜/回弹完全遵循“40ms 快下沉 + 180ms 慢回弹”
    // =========================================================================
    Item {
        id: keyboardContainer
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        width: 40
        height: 18

        Row {
            anchors.fill: parent
            spacing: 2.4

            // --- 单颗机械键帽模板 ---
            component KeyCap: Rectangle {
                id: capRoot
                property real strokeRatio: 0.0
                // 慢打下潜 1.8px，高速下潜到 3.0px
                readonly property real maxStrokePx: 1.8 + typingBubbleRoot.intensity * 1.2
                readonly property real targetY: Math.round(strokeRatio * maxStrokePx)

                width: 8.2; height: 13.5
                radius: 2.5
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: capRoot.targetY

                // 非对称物理动画：下沉 40ms 干脆触底，回弹 180ms 阻尼温和复位
                Behavior on anchors.verticalCenterOffset {
                    NumberAnimation {
                        duration: capRoot.anchors.verticalCenterOffset < capRoot.targetY ? 40 : 180
                        easing.type: capRoot.anchors.verticalCenterOffset < capRoot.targetY ? Easing.OutQuad : Easing.OutCubic
                    }
                }

                // 按键局部透光反馈
                color: {
                    if (strokeRatio > 0.06) {
                        return Qt.rgba(typingThemeColor.r, typingThemeColor.g, typingThemeColor.b, 
                                       0.18 + strokeRatio * (0.35 + typingBubbleRoot.intensity * 0.25))
                    }
                    return Qt.rgba(1, 1, 1, 0.08)
                }

                border.color: strokeRatio > 0.06 ? 
                              Qt.rgba(typingThemeColor.r, typingThemeColor.g, typingThemeColor.b, 0.45 + strokeRatio * 0.55) : 
                              Qt.rgba(1, 1, 1, 0.16)
                border.width: 1

                Behavior on color { ColorAnimation { duration: 90 } }
                Behavior on border.color { ColorAnimation { duration: 90 } }

                // 键帽顶面局部微高光
                Rectangle {
                    anchors.top: parent.top; anchors.topMargin: 1.0
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 2.0; height: 1; radius: 0.5
                    color: Qt.rgba(1, 1, 1, capRoot.strokeRatio > 0.1 ? (0.4 + typingBubbleRoot.intensity * 0.4) : 0.22)
                }
            }

            KeyCap { strokeRatio: typingBubbleRoot.spec1 }
            KeyCap { strokeRatio: typingBubbleRoot.spec2 }
            KeyCap { strokeRatio: typingBubbleRoot.spec3 }
            KeyCap { strokeRatio: typingBubbleRoot.spec4 }
        }
    }

    // =========================================================================
    // 4. 状态层：底部 Caret 激光流 (中心聚光高亮、两端柔和渐隐)
    // =========================================================================
    Rectangle {
        id: typingCaret
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4.8
        anchors.horizontalCenter: parent.horizontalCenter

        // 宽度根据 intensity 从 12px 连续平滑拓展至 38px
        width: typingBubbleRoot.isIdle ? 10 : (12 + typingBubbleRoot.intensity * 26)
        height: 1.6
        radius: 0.8
        clip: true

        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        // 柔和中心亮、两端羽化渐隐
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { 
                position: 0.25; 
                color: Qt.rgba(typingBubbleRoot.typingThemeColor.r, typingBubbleRoot.typingThemeColor.g, typingBubbleRoot.typingThemeColor.b, typingBubbleRoot.isIdle ? 0.25 : 0.65) 
            }
            GradientStop { 
                position: 0.5; 
                color: typingBubbleRoot.inRageState ? "#ffffff" : typingBubbleRoot.typingThemeColor 
            }
            GradientStop { 
                position: 0.75; 
                color: Qt.rgba(typingBubbleRoot.typingThemeColor.r, typingBubbleRoot.typingThemeColor.g, typingBubbleRoot.typingThemeColor.b, typingBubbleRoot.isIdle ? 0.25 : 0.65) 
            }
            GradientStop { position: 1.0; color: "transparent" }
        }

        // Idle 静息呼吸放慢至 3000ms（3 秒循环），安详沉稳
        SequentialAnimation on opacity {
            running: typingBubbleRoot.isIdle
            loops: Animation.Infinite
            NumberAnimation { to: 0.20; duration: 1500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.60; duration: 1500; easing.type: Easing.InOutSine }
        }
    }

    HoverHandler {
        id: bubbleHover
        cursorShape: Qt.ArrowCursor
    }
}