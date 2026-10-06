// ==========================================
// 📄 File: HardwareBubbleView.qml
// 🌟 纯净内敛机械阻尼 · 零溢出零伪影 · 无闪烁黑框版
// ==========================================
import QtQuick

Item {
    id: typingBubbleRoot

    // 基础输入属性（完全兼容外部 Relay 注入）
    property bool isTyping: false
    property color typingThemeColor: "#38bdf8"
    property real spec1: 0.0
    property real spec2: 0.0
    property real spec3: 0.0
    property real spec4: 0.0
    property real kps: 0.0

    // 接收后端按键字符串（支持单键如 "A", 组合键如 "Ctrl+Shift", "Ctrl+Alt+Del"）
    property string activeMod: ""
    property string activeKey: ""

    // 接收每一次物理击键的全局脉冲计数器
    property int strokeRevision: 0

    property bool active: true
    readonly property bool isHovered: bubbleHover.hovered

    // 模式切换属性
    readonly property string bubbleMode: (typeof Config !== "undefined" && Config.typingBubbleMode) ? Config.typingBubbleMode : "bars"
    readonly property bool isKeycapMode: bubbleMode === "keycaps"

    // 联动系统 CapsLock 状态
    readonly property bool isCapsLock: (typeof Bridge !== "undefined" && Bridge.isCapsLock !== undefined) ? Bridge.isCapsLock : false

    // 打字流速与活跃度计算
    readonly property real intensity: Math.max(0.0, Math.min(1.0, kps / 10.0))
    readonly property bool isIdle: intensity < 0.02 && !isTyping

    // 高频自适应动画基准时长：高频连击回弹更干脆，低频单敲回弹更饱满阻尼
    readonly property int animPace: kps > 5.0 ? 55 : 75

    // 内部击键脉冲计数器（双保险机制）
    property int internalPulse: 0
    onStrokeRevisionChanged: internalPulse++
    onActiveKeyChanged: if (activeKey !== "") internalPulse++
    onActiveModChanged: if (activeMod !== "") internalPulse++

    // 前端动量跃迁双重感知
    onSpec1Changed: if (spec1 > 0.85) internalPulse++
    onSpec2Changed: if (spec2 > 0.85) internalPulse++
    onSpec3Changed: if (spec3 > 0.85) internalPulse++
    onSpec4Changed: if (spec4 > 0.85) internalPulse++

    // =========================================================================
    // 🔤 核心模块 1：按键符号解析与多键并发切分
    // =========================================================================
    QtObject {
        id: keyParser

        readonly property bool isShiftActive: {
            var m = (typingBubbleRoot.activeMod || "").toLowerCase()
            var k = (typingBubbleRoot.activeKey || "").toLowerCase()
            return m.indexOf("shift") !== -1 || k.indexOf("shift") !== -1
        }

        function formatSymbol(raw) {
            if (!raw) return ""
            var k = raw.trim()
            if (k === "Shift") return "⇧"
            if (k === "Ctrl") return "⌃"
            if (k === "Alt") return "⌥"
            if (k === "Win" || k === "Super" || k === "Meta") return "⊞"
            if (k === "Enter" || k === "Return") return "↵"
            if (k === "Bksp" || k === "Backspace") return "⌫"
            if (k === "Tab") return "⇥"
            if (k === "Space") return "␣"
            if (k === "Esc" || k === "Escape") return "⎋"
            if (k === "Caps" || k === "CapsLock") return "⇪"
            if (k === "Up") return "↑"
            if (k === "Down") return "↓"
            if (k === "Left") return "←"
            if (k === "Right") return "→"
            if (k === "PgUp" || k === "PageUp") return "⇞"
            if (k === "PgDn" || k === "PageDown") return "⇟"
            if (k === "Home") return "↖"
            if (k === "End") return "↘"

            if (k.length === 1 && /^[a-zA-Z]$/.test(k)) {
                var upper = keyParser.isShiftActive ? !typingBubbleRoot.isCapsLock : typingBubbleRoot.isCapsLock
                return upper ? k.toUpperCase() : k.toLowerCase()
            }
            return k
        }

        function parseKeys() {
            var res = []
            if (typingBubbleRoot.activeMod) {
                var mods = typingBubbleRoot.activeMod.split("+")
                for (var i = 0; i < mods.length; i++) {
                    var m = mods[i].trim()
                    if (m && res.length < 2) res.push({ label: formatSymbol(m), isMod: true })
                }
            }
            if (typingBubbleRoot.activeKey) {
                var keys = typingBubbleRoot.activeKey.split("+")
                for (var j = 0; j < keys.length; j++) {
                    var k = keys[j].trim()
                    if (k && (!typingBubbleRoot.activeMod || typingBubbleRoot.activeMod.indexOf(k) === -1)) {
                        if (res.length < 3) res.push({ label: formatSymbol(k), isMod: false })
                    }
                }
            }
            return res
        }
    }

    readonly property var currentKeys: keyParser.parseKeys()
    readonly property int keyCount: currentKeys.length

    readonly property var slot0Data: keyCount > 0 ? currentKeys[0] : null
    readonly property var slot1Data: keyCount > 1 ? currentKeys[1] : null
    readonly property var slot2Data: keyCount > 2 ? currentKeys[2] : null

    // =========================================================================
    // 📐 核心模块 2：安全稳定几何宽度（阶梯定宽，避免频繁触发系统 Mask 重建）
    // =========================================================================
    readonly property int islandHeight: 34
    readonly property int radius: 17

    readonly property int modeAWidth: (isIdle || intensity < 0.12) ? 56 : Math.round(56 + intensity * 14)

    // 模式 B 阶梯式稳定宽度（空闲 52 / 单键 64 / 双键 94 / 三键 120）
    readonly property int modeBTargetWidth: {
        if (keyCount === 0) return 52
        if (keyCount === 1) return (currentKeys[0].label.length > 2) ? 74 : 64
        if (keyCount === 2) return 94
        return 120
    }

    property int modeBWidth: modeBTargetWidth
    onModeBTargetWidthChanged: {
        widthAnim.stop()
        widthAnim.duration = modeBTargetWidth > modeBWidth ? 55 : 120
        widthAnim.to = modeBTargetWidth
        widthAnim.start()
    }

    NumberAnimation {
        id: widthAnim
        target: typingBubbleRoot
        property: "modeBWidth"
        easing.type: Easing.OutCubic
    }

    width: isKeycapMode ? modeBWidth : modeAWidth
    height: islandHeight
    clip: true
    transformOrigin: Item.Center

    visible: active
    opacity: active ? 1.0 : 0.0

    function toggleMode() {
        if (typeof Config === "undefined") return
        Config.typingBubbleMode = isKeycapMode ? "bars" : "keycaps"
    }

    // =========================================================================
    // 背景液态玻璃材质 Shader (严格限定在 34px 圆角内)
    // =========================================================================
    ShaderEffect {
        id: liquidGlassEffect
        anchors.fill: parent
        z: 0

        property vector2d u_size: Qt.vector2d(typingBubbleRoot.width, typingBubbleRoot.height)
        property real u_radius: typingBubbleRoot.radius
        property color u_accent: typingBubbleRoot.typingThemeColor
        property real u_hasAccent: typingBubbleRoot.isIdle ? 0.0 : Math.min(1.0, 0.4 + typingBubbleRoot.intensity * 0.6)
        property real u_isHovered: typingBubbleRoot.isHovered ? 1.0 : 0.0

        fragmentShader: "liquid_glass.frag.qsb"
    }

    // =========================================================================
    // 视图 1：模式 A · 原生机械律动波形 (Bars Mode)
    // =========================================================================
    Item {
        id: viewBars
        anchors.fill: parent
        visible: opacity > 0.01
        opacity: typingBubbleRoot.isKeycapMode ? 0.0 : 1.0
        scale: typingBubbleRoot.isKeycapMode ? 0.88 : 1.0

        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 12, 36 + typingBubbleRoot.intensity * 16)
            height: 16 + typingBubbleRoot.intensity * 8
            radius: 11
            color: Qt.rgba(typingThemeColor.r, typingThemeColor.g, typingThemeColor.b,
                           typingBubbleRoot.isIdle ? 0.0 : (0.08 + typingBubbleRoot.intensity * 0.18))
        }

        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            spacing: 2.2 + typingBubbleRoot.intensity * 1.2

            component KeyBar: Rectangle {
                id: barRoot
                property real strokeRatio: 0.0
                readonly property real targetY: Math.round(strokeRatio * (1.8 + typingBubbleRoot.intensity * 1.2))

                width: 8.2; height: 13.5; radius: 2.5
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: barRoot.targetY

                color: strokeRatio > 0.06 ?
                       Qt.rgba(typingThemeColor.r, typingThemeColor.g, typingThemeColor.b, 0.20 + strokeRatio * 0.4) :
                       Qt.rgba(1, 1, 1, 0.08)

                border.color: strokeRatio > 0.06 ?
                              Qt.rgba(typingThemeColor.r, typingThemeColor.g, typingThemeColor.b, 0.45 + strokeRatio * 0.55) :
                              Qt.rgba(1, 1, 1, 0.14)
                border.width: 1

                Rectangle {
                    anchors.top: parent.top; anchors.topMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 2; height: 1; radius: 0.5
                    color: Qt.rgba(1, 1, 1, barRoot.strokeRatio > 0.1 ? 0.4 : 0.22)
                }
            }

            KeyBar { strokeRatio: typingBubbleRoot.spec1 }
            KeyBar { strokeRatio: typingBubbleRoot.spec2 }
            KeyBar { strokeRatio: typingBubbleRoot.spec3 }
            KeyBar { strokeRatio: typingBubbleRoot.spec4 }
        }

        Rectangle {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 4.8
            anchors.horizontalCenter: parent.horizontalCenter
            width: typingBubbleRoot.isIdle ? 10 : (12 + typingBubbleRoot.intensity * 30)
            height: 1.6; radius: 0.8
            color: typingBubbleRoot.typingThemeColor
        }
    }

    // =========================================================================
    // 视图 2：模式 B · 🚀 客制化机械触感键舱 (Tactile Kinetic Keycap Deck)
    // 🌟 核心保证：所有形变与微光 100% 收敛在 34px 内，绝不溢出产生黑框
    // =========================================================================
    Item {
        id: viewKeycapPod
        anchors.fill: parent
        clip: true
        visible: opacity > 0.01
        opacity: typingBubbleRoot.isKeycapMode ? 1.0 : 0.0
        scale: typingBubbleRoot.isKeycapMode ? 1.0 : 0.90

        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

        // 1. 待机状态：极简微舱呼吸孔
        Item {
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: typingBubbleRoot.keyCount === 0 ? 1.0 : 0.0
            scale: typingBubbleRoot.keyCount === 0 ? 1.0 : 0.82
            Behavior on opacity { NumberAnimation { duration: 110 } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

            Rectangle {
                anchors.centerIn: parent
                width: 20; height: 20; radius: 10
                color: Qt.rgba(1, 1, 1, 0.05)

                Text {
                    anchors.centerIn: parent
                    text: "⌨"
                    font.pixelSize: 10
                    color: Qt.rgba(1, 1, 1, 0.45)
                }
            }
        }

        // =====================================================================
        // 2. 定槽机械触感单元 (Tactile Mechanical Unit)
        // 🚀 核心：纯局部 2.0px 弹性深潜，能量漫射限定在边框内，彻底消除外圈黑框
        // =====================================================================
        component KineticKeyUnit: Item {
            id: unitRoot
            property var slotData: null
            readonly property bool hasData: slotData !== null
            readonly property string labelText: hasData ? slotData.label : ""
            readonly property bool isModifier: hasData ? slotData.isMod : false
            readonly property bool isLetter: labelText.length === 1 && /^[a-zA-Z]$/.test(labelText)
            readonly property bool isCapsLedOn: !isModifier && isLetter && (/^[A-Z]$/.test(labelText)) && typingBubbleRoot.isCapsLock

            width: hasData ? (labelText.length > 2 ? 34 : 26) : 0
            height: 23
            anchors.verticalCenter: parent.verticalCenter
            visible: width > 0 || opacity > 0.01
            opacity: hasData ? 1.0 : 0.0
            scale: hasData ? 1.0 : 0.65

            Behavior on width { NumberAnimation { duration: 50; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 65; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 75; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

            Connections {
                target: typingBubbleRoot
                function onInternalPulseChanged() {
                    if (unitRoot.hasData) {
                        strokeImpulseAnim.stop()
                        strokeImpulseAnim.start()
                    }
                }
            }

            // 🚀 局部动力学：纯内部 2.0px 机械下潜 + 弹性回颤（严禁超出容器）
            SequentialAnimation {
                id: strokeImpulseAnim
                ParallelAnimation {
                    NumberAnimation { target: keycapSurface; property: "y"; to: 2.0; duration: 20; easing.type: Easing.InQuad }
                    NumberAnimation { target: keycapSurface; property: "scaleY"; to: 0.84; duration: 20; easing.type: Easing.OutQuad }
                    NumberAnimation { target: keycapSurface; property: "scaleX"; to: 1.04; duration: 20; easing.type: Easing.OutQuad }
                    NumberAnimation { target: keyText; property: "scale"; to: 0.85; duration: 20; easing.type: Easing.OutQuad }
                    NumberAnimation { target: tactileBloom; property: "opacity"; to: 0.85; duration: 20; easing.type: Easing.OutQuad }
                }
                ParallelAnimation {
                    NumberAnimation { target: keycapSurface; property: "y"; to: 0.0; duration: typingBubbleRoot.animPace; easing.type: Easing.OutBack; easing.overshoot: 1.30 }
                    NumberAnimation { target: keycapSurface; property: "scaleY"; to: 1.0; duration: typingBubbleRoot.animPace; easing.type: Easing.OutBack; easing.overshoot: 1.20 }
                    NumberAnimation { target: keycapSurface; property: "scaleX"; to: 1.0; duration: typingBubbleRoot.animPace; easing.type: Easing.OutBack; easing.overshoot: 1.10 }
                    NumberAnimation { target: keyText; property: "scale"; to: 1.0; duration: typingBubbleRoot.animPace; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                    NumberAnimation { target: tactileBloom; property: "opacity"; to: 0.0; duration: typingBubbleRoot.animPace + 35; easing.type: Easing.OutQuad }
                }
            }

            // 1. 能量微光漫射层（严格贴合在键帽周围 1.5px 范围内，绝不溢出黑边）
            Rectangle {
                id: tactileBloom
                anchors.centerIn: parent
                width: parent.width + 3
                height: parent.height + 3
                radius: 8
                color: Qt.rgba(typingBubbleRoot.typingThemeColor.r, typingBubbleRoot.typingThemeColor.g, typingBubbleRoot.typingThemeColor.b, 0.45)
                opacity: 0.0
            }

            // 2. PBT 内凹深暗基槽 (Cavity Well)
            Rectangle {
                anchors.fill: parent
                radius: 7
                color: Qt.rgba(0, 0, 0, 0.55)
                border.color: Qt.rgba(255, 255, 255, 0.04)
                border.width: 0.8
            }

            // 3. 悬浮键帽实体（超椭圆连续曲率，局部 X/Y 阻尼挤压）
            Rectangle {
                id: keycapSurface
                anchors.fill: parent
                radius: 7
                transformOrigin: Item.Center

                property real scaleX: 1.0
                property real scaleY: 1.0
                transform: Scale {
                    origin.x: keycapSurface.width / 2
                    origin.y: keycapSurface.height / 2
                    xScale: keycapSurface.scaleX
                    yScale: keycapSurface.scaleY
                }

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: typingBubbleRoot.isTyping ?
                               Qt.rgba(typingBubbleRoot.typingThemeColor.r, typingBubbleRoot.typingThemeColor.g, typingBubbleRoot.typingThemeColor.b, 0.40) :
                               (unitRoot.isModifier ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.18))
                    }
                    GradientStop {
                        position: 1.0
                        color: typingBubbleRoot.isTyping ?
                               Qt.rgba(typingBubbleRoot.typingThemeColor.r, typingBubbleRoot.typingThemeColor.g, typingBubbleRoot.typingThemeColor.b, 0.15) :
                               (unitRoot.isModifier ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.07))
                    }
                }

                border.color: typingBubbleRoot.isTyping ?
                              Qt.rgba(typingBubbleRoot.typingThemeColor.r, typingBubbleRoot.typingThemeColor.g, typingBubbleRoot.typingThemeColor.b, 0.95) :
                              Qt.rgba(255, 255, 255, 0.16)
                border.width: 0.8

                Text {
                    id: keyText
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: unitRoot.isCapsLedOn ? -1.5 : 0
                    transformOrigin: Item.Center
                    text: unitRoot.labelText
                    color: typingBubbleRoot.isTyping ? "#ffffff" : (unitRoot.isModifier ? Qt.rgba(1, 1, 1, 0.78) : "#ffffff")
                    font.family: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"
                    font.pixelSize: unitRoot.labelText.length > 2 ? 10 : 12
                    font.weight: typingBubbleRoot.isTyping ? Font.Black : Font.Bold
                    renderType: Text.QtRendering
                }

                Rectangle {
                    visible: unitRoot.isCapsLedOn
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2.2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 4
                    height: 1.5
                    radius: 0.75
                    color: "#34d399"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 3
                        radius: 1.5
                        color: Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.4)
                    }
                }
            }
        }

        // =====================================================================
        // 3. 常驻三槽并排流动排布区
        // =========================================================================
        Row {
            anchors.centerIn: parent
            spacing: 4
            visible: opacity > 0.01
            opacity: typingBubbleRoot.keyCount > 0 ? 1.0 : 0.0
            scale: typingBubbleRoot.keyCount > 0 ? 1.0 : 0.85

            Behavior on opacity { NumberAnimation { duration: 75; easing.type: Easing.OutQuad } }
            Behavior on scale { NumberAnimation { duration: 85; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

            KineticKeyUnit {
                slotData: typingBubbleRoot.slot0Data
            }

            KineticKeyUnit {
                slotData: typingBubbleRoot.slot1Data
            }

            KineticKeyUnit {
                slotData: typingBubbleRoot.slot2Data
            }
        }
    }

    // =========================================================================
    // 鼠标交互体系
    // =========================================================================
    HoverHandler {
        id: bubbleHover
        cursorShape: Qt.PointingHandCursor
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            event.accepted = true
            typingBubbleRoot.wheelInteracted()
            if (event.angleDelta.y > 0 && !typingBubbleRoot.isKeycapMode) {
                Config.typingBubbleMode = "keycaps"
            } else if (event.angleDelta.y < 0 && typingBubbleRoot.isKeycapMode) {
                Config.typingBubbleMode = "bars"
            } else if (event.angleDelta.y !== 0) {
                typingBubbleRoot.toggleMode()
            }
        }
    }

    TapHandler {
        onTapped: typingBubbleRoot.toggleMode()
    }

    signal wheelInteracted()
}