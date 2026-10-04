// ==========================================
// 📄 File: control/ControlCenterIcon.qml
// ==========================================
import QtQuick
import QtQuick.Shapes

Item {
    id: iconRoot
    width: 14
    height: 14

    property string iconType: "controlCenter"
    property color iconColor: "white"
    property bool isMuted: false

    // =========================================================================
    // 1. 🚀【全新重构】：macOS 正统控制中心调节开关 (绝非简陋等号 =)
    // =========================================================================
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "controlCenter"
        layer.enabled: true
        layer.samples: 4

        // 1.1 上导轨细线 (y=4.5)
        ShapePath {
            strokeColor: Qt.rgba(iconRoot.iconColor.r, iconRoot.iconColor.g, iconRoot.iconColor.b, 0.45)
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 1.5; startY: 4.5
            PathLine { x: 12.5; y: 4.5 }
        }

        // 1.2 上轨饱满实心滑块 (靠左驻留，宽 4.2，高 3.2，圆角饱满)
        ShapePath {
            fillColor: iconRoot.iconColor
            strokeColor: "transparent"
            startX: 3.5; startY: 2.8
            PathArc { x: 6.5; y: 2.8; radiusX: 1.5; radiusY: 1.5; useLargeArc: false }
            PathLine { x: 6.5; y: 6.2 }
            PathArc { x: 3.5; y: 6.2; radiusX: 1.5; radiusY: 1.5; useLargeArc: false }
            PathLine { x: 3.5; y: 2.8 }
        }

        // 1.3 下导轨细线 (y=9.5)
        ShapePath {
            strokeColor: Qt.rgba(iconRoot.iconColor.r, iconRoot.iconColor.g, iconRoot.iconColor.b, 0.45)
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 1.5; startY: 9.5
            PathLine { x: 12.5; y: 9.5 }
        }

        // 1.4 下轨饱满实心滑块 (靠右驻留，宽 4.2，高 3.2，清晰错位)
        ShapePath {
            fillColor: iconRoot.iconColor
            strokeColor: "transparent"
            startX: 7.5; startY: 7.8
            PathArc { x: 10.5; y: 7.8; radiusX: 1.5; radiusY: 1.5; useLargeArc: false }
            PathLine { x: 10.5; y: 11.2 }
            PathArc { x: 7.5; y: 11.2; radiusX: 1.5; radiusY: 1.5; useLargeArc: false }
            PathLine { x: 7.5; y: 7.8 }
        }
    }

    // 2. 音量喇叭
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "volume"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: iconRoot.isMuted ? Theme.danger : iconRoot.iconColor
            strokeColor: iconRoot.isMuted ? Theme.danger : iconRoot.iconColor
            strokeWidth: 0.6
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 2.0; startY: 5.2
            PathLine { x: 4.2; y: 5.2 }
            PathLine { x: 7.2; y: 2.5 }
            PathLine { x: 7.2; y: 11.5 }
            PathLine { x: 4.2; y: 8.8 }
            PathLine { x: 2.0; y: 8.8 }
            PathLine { x: 2.0; y: 5.2 }
        }

        ShapePath {
            strokeColor: (!iconRoot.isMuted) ? iconRoot.iconColor : "transparent"
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 9.5; startY: 4.5
            PathArc { x: 9.5; y: 9.5; radiusX: 3.5; radiusY: 3.5; useLargeArc: false }
        }

        ShapePath {
            strokeColor: iconRoot.isMuted ? Theme.danger : "transparent"
            strokeWidth: 1.3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 9.2; startY: 4.5
            PathLine { x: 12.8; y: 9.5 }
            PathMove { x: 12.8; y: 4.5 }
            PathLine { x: 9.2; y: 9.5 }
        }
    }

    // 3. 日冕太阳图标
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "brightness"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: iconRoot.iconColor
            strokeColor: "transparent"
            startX: 7.0; startY: 4.6
            PathArc { x: 7.0; y: 9.4; radiusX: 2.4; radiusY: 2.4; useLargeArc: false }
            PathArc { x: 7.0; y: 4.6; radiusX: 2.4; radiusY: 2.4; useLargeArc: false }
        }

        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.15
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            startX: 7.0; startY: 1.2
            PathLine { x: 7.0; y: 2.8 }
            PathMove { x: 7.0; y: 11.2 }
            PathLine { x: 7.0; y: 12.8 }

            PathMove { x: 1.2; y: 7.0 }
            PathLine { x: 2.8; y: 7.0 }
            PathMove { x: 11.2; y: 7.0 }
            PathLine { x: 12.8; y: 7.0 }

            PathMove { x: 2.9; y: 2.9 }
            PathLine { x: 4.0; y: 4.0 }
            PathMove { x: 10.0; y: 10.0 }
            PathLine { x: 11.1; y: 11.1 }
            PathMove { x: 2.9; y: 11.1 }
            PathLine { x: 4.0; y: 10.0 }
            PathMove { x: 10.0; y: 4.0 }
            PathLine { x: 11.1; y: 2.9 }
        }
    }

    // 4. 标准极简录音室麦克风
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "mic"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: iconRoot.isMuted ? Theme.danger : iconRoot.iconColor
            strokeColor: "transparent"
            startX: 5.5; startY: 2.5
            PathArc { x: 8.5; y: 2.5; radiusX: 1.5; radiusY: 1.5; useLargeArc: false }
            PathLine { x: 8.5; y: 5.2 }
            PathArc { x: 5.5; y: 5.2; radiusX: 1.5; radiusY: 1.5; useLargeArc: false }
            PathLine { x: 5.5; y: 2.5 }
        }

        ShapePath {
            strokeColor: iconRoot.isMuted ? Theme.danger : iconRoot.iconColor
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: 3.5; startY: 4.5
            PathLine { x: 3.5; y: 5.5 }
            PathArc { x: 10.5; y: 5.5; radiusX: 3.5; radiusY: 3.5; useLargeArc: false }
            PathLine { x: 10.5; y: 4.5 }

            PathMove { x: 7.0; y: 9.0 }
            PathLine { x: 7.0; y: 12.0 }

            PathMove { x: 4.8; y: 12.0 }
            PathLine { x: 9.2; y: 12.0 }
        }

        ShapePath {
            strokeColor: iconRoot.isMuted ? Theme.danger : "transparent"
            strokeWidth: 1.3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 2.2; startY: 2.2
            PathLine { x: 11.8; y: 11.8 }
        }
    }

    // 5. 设置齿轮
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "settings"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 7.0; startY: 5.0
            PathArc { x: 7.0; y: 9.0; radiusX: 2.0; radiusY: 2.0; useLargeArc: false }
            PathArc { x: 7.0; y: 5.0; radiusX: 2.0; radiusY: 2.0; useLargeArc: false }
        }

        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            startX: 7.0; startY: 1.2
            PathLine { x: 7.0; y: 2.5 }
            PathMove { x: 7.0; y: 11.5 }
            PathLine { x: 7.0; y: 12.8 }
            PathMove { x: 1.2; y: 7.0 }
            PathLine { x: 2.5; y: 7.0 }
            PathMove { x: 11.5; y: 7.0 }
            PathLine { x: 12.8; y: 7.0 }

            PathMove { x: 2.8; y: 2.8 }
            PathLine { x: 3.8; y: 3.8 }
            PathMove { x: 10.2; y: 10.2 }
            PathLine { x: 11.2; y: 11.2 }
            PathMove { x: 2.8; y: 11.2 }
            PathLine { x: 3.8; y: 10.2 }
            PathMove { x: 10.2; y: 3.8 }
            PathLine { x: 11.2; y: 2.8 }
        }
    }

    // 6. 收起 Chevron 箭头
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "chevron"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.35
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 8.5; startY: 3.5
            PathLine { x: 5.0; y: 7.0 }
            PathLine { x: 8.5; y: 10.5 }
        }
    }
}