// ==========================================
// 📄 File: compact/CompactCallView.qml
// 🌟 纯正苹果美学 · 绝不重叠 · 双圆对称来电条
// ==========================================
import QtQuick
import QtQuick.Shapes

Item {
    id: callRoot
    anchors.fill: parent

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""
    property bool isCalling: false

    // =========================================================================
    // 1. 左侧：来电头像与柔光脉冲光环 (32x32)
    // =========================================================================
    Item {
        id: avatarWrapper
        width: 32
        height: 32
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter

        // 柔光微外扩脉冲
        Rectangle {
            id: pulseRing
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            color: "transparent"
            border.color: "#30D158"
            border.width: 1.5

            SequentialAnimation {
                running: callRoot.isCalling
                loops: Animation.Infinite
                ParallelAnimation {
                    NumberAnimation { target: pulseRing; property: "scale"; from: 0.95; to: 1.35; duration: 1200; easing.type: Easing.OutQuad }
                    NumberAnimation { target: pulseRing; property: "opacity"; from: 0.75; to: 0.0; duration: 1200; easing.type: Easing.OutQuad }
                }
                PauseAnimation { duration: 150 }
            }
        }

        // 头像主体 / 首字母兜底
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: callAvatarImg.visible ? "transparent" : "#4F46E5"
            border.color: Qt.rgba(255, 255, 255, 0.2)
            border.width: 1
            clip: true

            Image {
                id: callAvatarImg
                anchors.fill: parent
                source: callRoot.callAvatar || ""
                fillMode: Image.PreserveAspectCrop
                visible: (callRoot.callAvatar !== "") && status === Image.Ready
                sourceSize.width: 64
                sourceSize.height: 64
                asynchronous: true
                cache: true
            }

            Text {
                anchors.centerIn: parent
                text: {
                    if (callAvatarImg.visible) return ""
                    var t = (callRoot.callTitle || "来电").trim()
                    var parts = t.split(" ")
                    return (parts.length >= 2) ? (parts[0][0] + parts[1][0]).toUpperCase() : t.charAt(0).toUpperCase()
                }
                color: "white"
                font.family: callRoot.effectiveFont
                font.pixelSize: 12
                font.weight: Font.Black
                visible: !callAvatarImg.visible
            }
        }
    }

    // =========================================================================
    // 2. 右侧：苹果经典双圆对称操作钮 (拒绝生硬长条按钮)
    // =========================================================================
    Row {
        id: actionsRow
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // 🔴 拒接 / 挂断圆钮 (Apple Red #FF453A)
        Rectangle {
            id: rejectBtn
            width: 28
            height: 28
            radius: 14
            anchors.verticalCenter: parent.verticalCenter
            color: rejectTap.pressed ? "#b91c1c" : (rejectHover.hovered ? "#dc2626" : "#ef4444")
            scale: rejectTap.pressed ? 0.90 : (rejectHover.hovered ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: 120 } }

            // 纯白拒接交叉叉号
            Shape {
                anchors.centerIn: parent
                width: 10
                height: 10
                layer.enabled: true
                layer.samples: 4

                ShapePath {
                    strokeColor: "#ffffff"
                    strokeWidth: 1.8
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 1.5; startY: 1.5
                    PathLine { x: 8.5; y: 8.5 }
                    PathMove { x: 8.5; y: 1.5 }
                    PathLine { x: 1.5; y: 8.5 }
                }
            }

            HoverHandler { id: rejectHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: rejectTap
                onTapped: if (typeof Bridge !== "undefined") Bridge.rejectTeamsCall()
            }
        }

        // 🟢 接听圆钮 (Apple Green #30D158)
        Rectangle {
            id: answerBtn
            width: 28
            height: 28
            radius: 14
            anchors.verticalCenter: parent.verticalCenter
            color: answerTap.pressed ? "#15803d" : (answerHover.hovered ? "#16a34a" : "#22c55e")
            scale: answerTap.pressed ? 0.90 : (answerHover.hovered ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: 120 } }

            // 纯白接听微听筒矢量
            Text {
                anchors.centerIn: parent
                text: "📞"
                font.pixelSize: 12
                color: "white"
            }

            HoverHandler { id: answerHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: answerTap
                onTapped: if (typeof Bridge !== "undefined") Bridge.answerTeamsCall()
            }
        }
    }

    // =========================================================================
    // 3. 中间：流体自适应文字排版 (物理锁死于头像与按钮之间，永不重叠)
    // =========================================================================
    Column {
        id: textCol
        anchors.left: avatarWrapper.right
        anchors.leftMargin: 10
        anchors.right: actionsRow.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        clip: true

        Text {
            id: titleText
            text: callRoot.callTitle || "Teams 来电"
            color: "#ffffff"
            font.family: callRoot.effectiveFont
            font.pixelSize: 13
            font.weight: Font.Black
            elide: Text.ElideRight
            width: parent.width
        }

        Text {
            id: subText
            text: callRoot.callSubtitle || "正在呼叫你..."
            // 苹果优雅次级灰阶白 (彻底剔除破坏氛围的高饱和荧光绿)
            color: Qt.rgba(1, 1, 1, 0.65)
            font.family: callRoot.effectiveFont
            font.pixelSize: 10
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            width: parent.width
        }
    }
}