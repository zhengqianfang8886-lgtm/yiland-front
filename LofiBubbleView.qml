// ==========================================
// 📄 File: LofiBubbleView.qml
// 🌟 纯正灵动岛美学 · 离屏渲染即时切断 · 零残影完整版
// ==========================================
import QtQuick
import QtQuick.Effects

Item {
    id: lofiRoot

    property bool active: true
    readonly property bool isHovered: bubbleHover.hovered

    readonly property color themeColor: "#a855f7"

    property var lofiFileList: []

    property int currentIndex: (typeof Config !== "undefined" && Config.lofiSceneIndex !== undefined) ? Config.lofiSceneIndex : 0
    readonly property int totalCount: lofiFileList.length
    readonly property bool hasAnimations: totalCount > 0

    readonly property string currentFilePath: {
        if (!hasAnimations) return ""
        var safeIdx = Math.max(0, Math.min(currentIndex, totalCount - 1))
        return lofiFileList[safeIdx]
    }

    readonly property real imgRatio: (customPlayer.sourceSize.height > 0) ?
                                     (customPlayer.sourceSize.width / customPlayer.sourceSize.height) : (16.0 / 9.0)

    height: 34
    readonly property int radiusVal: 17

    readonly property int dynamicWidth: Math.round(lofiRoot.height * lofiRoot.imgRatio)
    readonly property int targetWidth: lofiRoot.hasAnimations ? Math.max(52, Math.min(108, dynamicWidth)) : 88
    width: targetWidth
    clip: false

    Behavior on width {
        NumberAnimation { duration: Theme.animFast; easing.type: Theme.curveDecel }
    }

    // 🚀【生命周期严密闭环】：active 为 false 时加速收拢且绝对切断 visible，不留半点幽灵像素
    visible: active && (opacity > 0.001)
    opacity: active ? 1.0 : 0.0
    scale: active ? 1.0 : 0.0

    Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.curveFluid } }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animSpring
            easing.type: Theme.curveSpring
            easing.overshoot: Theme.springOvershootNormal
        }
    }

    property real tapPulseScale: 1.0
    Behavior on tapPulseScale {
        NumberAnimation { duration: Theme.animInstant; easing.type: Theme.curveDecel }
    }
    Timer {
        id: tapPulseReset
        interval: 40
        repeat: false
        onTriggered: lofiRoot.tapPulseScale = 1.0
    }

    function switchToNext() {
        if (!hasAnimations) return
        tapPulseScale = 0.94
        tapPulseReset.restart()
        var nextIdx = (currentIndex + 1) % totalCount
        currentIndex = nextIdx
        if (typeof Config !== "undefined") {
            Config.lofiSceneIndex = nextIdx
        }
    }

    function switchToPrev() {
        if (!hasAnimations) return
        tapPulseScale = 0.94
        tapPulseReset.restart()
        var prevIdx = (currentIndex - 1 + totalCount) % totalCount
        currentIndex = prevIdx
        if (typeof Config !== "undefined") {
            Config.lofiSceneIndex = prevIdx
        }
    }

    function reloadList() {
        if (typeof Bridge !== "undefined" && Bridge.scanLofiAnimations) {
            var scanned = Bridge.scanLofiAnimations()
            if (scanned && scanned.length > 0) {
                lofiFileList = scanned
                if (currentIndex >= lofiFileList.length) {
                    currentIndex = 0
                }
                return
            }
        }
        if (typeof Config !== "undefined" && Config.lofiCustomPath && Config.lofiCustomPath !== "") {
            lofiFileList = [Config.lofiCustomPath]
            currentIndex = 0
        } else {
            lofiFileList = []
        }
    }

    Component.onCompleted: reloadList()

    // 1. 底层流体玻璃着色器
    ShaderEffect {
        id: liquidGlassEffect
        anchors.fill: parent
        z: 0

        property vector2d u_size: Qt.vector2d(lofiRoot.width, lofiRoot.height)
        property real u_radius: lofiRoot.radiusVal
        property color u_accent: lofiRoot.themeColor
        property real u_hasAccent: 0.75
        property real u_isHovered: lofiRoot.isHovered ? 1.0 : 0.0

        fragmentShader: "liquid_glass.frag.qsb"
    }

    // 黑曜石底板
    Rectangle {
        id: baseBackground
        anchors.fill: parent
        radius: lofiRoot.radiusVal
        color: Qt.rgba(10 / 255, 12 / 255, 18 / 255, 0.95)
        antialiasing: true
        smooth: true
        z: 1
    }

    // 2. 动图渲染沙盒
    Item {
        id: rawImageSource
        anchors.fill: parent
        anchors.margins: 1
        visible: false
        layer.enabled: lofiRoot.active
        layer.samples: 8
        layer.smooth: true

        AnimatedImage {
            id: customPlayer
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            smooth: true
            antialiasing: true
            mipmap: true
            source: (lofiRoot.currentFilePath !== "" && lofiRoot.active) ? ("file://" + lofiRoot.currentFilePath) : ""
            playing: lofiRoot.active && lofiRoot.visible
            asynchronous: true
            cache: true
        }
    }

    Rectangle {
        id: capsuleMaskTarget
        anchors.fill: parent
        anchors.margins: 1
        radius: lofiRoot.radiusVal - 1
        color: "black"
        visible: false
        antialiasing: true
        smooth: true
        layer.enabled: lofiRoot.active
        layer.samples: 8
        layer.smooth: true
    }

    // 🚀【显存残影强阻断】：当 lofiRoot.active 为 false 时，MultiEffect 立刻断开显示并释放 FBO
    MultiEffect {
        id: roundedOutput
        anchors.fill: parent
        anchors.margins: 1
        source: rawImageSource
        maskEnabled: true
        maskSource: capsuleMaskTarget
        z: 2
        visible: lofiRoot.active && lofiRoot.hasAnimations && (customPlayer.status === AnimatedImage.Ready)
        scale: lofiRoot.tapPulseScale
    }

    // 3. 原生黑胶唱片兜底场景
    Item {
        id: singleNativeVinylScene
        anchors.fill: parent
        z: 2
        visible: lofiRoot.active && !roundedOutput.visible
        scale: lofiRoot.tapPulseScale

        Item {
            id: vinylDisc
            width: 26; height: 26
            anchors.left: parent.left
            anchors.leftMargin: 7
            anchors.verticalCenter: parent.verticalCenter

            RotationAnimator on rotation {
                running: lofiRoot.active && singleNativeVinylScene.visible
                loops: Animation.Infinite
                from: 0; to: 360
                duration: 3600
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#18181b"
                border.color: "#27272a"
                border.width: 1
                antialiasing: true

                Rectangle {
                    anchors.centerIn: parent
                    width: 18; height: 18; radius: 9
                    color: "transparent"
                    border.color: Qt.rgba(255, 255, 255, 0.12)
                    border.width: 1
                    antialiasing: true
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 12; height: 12; radius: 6
                    color: "transparent"
                    border.color: Qt.rgba(255, 255, 255, 0.18)
                    border.width: 0.8
                    antialiasing: true
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 8; height: 8; radius: 4
                    color: "#a855f7"
                    antialiasing: true

                    Rectangle {
                        anchors.centerIn: parent
                        width: 2; height: 2; radius: 1
                        color: "#ffffff"
                    }
                }
            }
        }

        Column {
            anchors.left: vinylDisc.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Row {
                spacing: 4
                anchors.left: parent.left

                Text {
                    text: "LO-FI"
                    color: "#c084fc"
                    font.pixelSize: 10
                    font.weight: Font.Black
                    font.family: Theme.displayMonoFont
                    font.letterSpacing: 0.5
                }

                Rectangle {
                    width: 4; height: 4; radius: 2
                    color: "#34d399"
                    anchors.verticalCenter: parent.verticalCenter
                    antialiasing: true
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.35; to: 1.0; duration: 800 }
                        NumberAnimation { from: 1.0; to: 0.35; duration: 800 }
                    }
                }
            }

            Row {
                spacing: 2.5
                anchors.left: parent.left

                Repeater {
                    model: 5
                    Rectangle {
                        width: 2
                        radius: 1
                        color: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.75)
                        antialiasing: true
                        SequentialAnimation on height {
                            loops: Animation.Infinite
                            NumberAnimation { from: 2; to: 7 + (index % 3) * 2; duration: 240 + index * 80; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 7 + (index % 3) * 2; to: 2; duration: 280 + index * 60; easing.type: Easing.InOutQuad }
                        }
                    }
                }
            }
        }
    }

    // 4. 悬停进度微标
    Rectangle {
        id: hoverBadge
        anchors.centerIn: parent
        width: badgeRow.implicitWidth + 10
        height: 18
        radius: 9
        color: Qt.rgba(0, 0, 0, 0.75)
        border.color: Qt.rgba(255, 255, 255, 0.2)
        border.width: 1
        z: 8
        visible: lofiRoot.isHovered && (lofiRoot.totalCount > 1)
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animInstant } }

        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 3

            Text {
                text: "🎬"
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: (lofiRoot.currentIndex + 1) + " / " + lofiRoot.totalCount
                color: "#ffffff"
                font.pixelSize: 9
                font.weight: Font.Bold
                font.family: Theme.displayMonoFont
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // 5. 置顶精密压边框
    Rectangle {
        id: outerCapsuleBorder
        anchors.fill: parent
        radius: lofiRoot.radiusVal
        color: "transparent"
        border.width: 1.2
        border.color: lofiRoot.isHovered ? Qt.rgba(lofiRoot.themeColor.r, lofiRoot.themeColor.g, lofiRoot.themeColor.b, 0.90) : Theme.borderSubtle
        antialiasing: true
        smooth: true
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
        z: 10
    }

    HoverHandler { id: bubbleHover; cursorShape: Qt.PointingHandCursor }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: lofiRoot.switchToNext()
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            event.accepted = true
            if (event.angleDelta.y > 0) {
                lofiRoot.switchToPrev()
            } else if (event.angleDelta.y < 0) {
                lofiRoot.switchToNext()
            }
        }
    }
}