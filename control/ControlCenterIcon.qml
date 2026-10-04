import QtQuick
import QtQuick.Shapes

Item {
    id: iconRoot
    width: 14
    height: 14

    property string iconType: "controlCenter" // "controlCenter" | "volume" | "brightness" | "mic" | "settings"
    property color iconColor: "white"
    property bool isMuted: false

    // 1. 控制中心双滑块开关图标
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "controlCenter"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 1.5
            startY: 4.0
            PathLine { x: 12.5; y: 4.0 }
        }
        ShapePath {
            fillColor: iconRoot.iconColor
            strokeColor: "transparent"
            startX: 9.5
            startY: 4.0
            PathArc { x: 9.5; y: 4.0; radiusX: 2.0; radiusY: 2.0; useLargeArc: true }
        }

        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 1.5
            startY: 10.0
            PathLine { x: 12.5; y: 10.0 }
        }
        ShapePath {
            fillColor: iconRoot.iconColor
            strokeColor: "transparent"
            startX: 4.5
            startY: 10.0
            PathArc { x: 4.5; y: 10.0; radiusX: 2.0; radiusY: 2.0; useLargeArc: true }
        }
    }

    // 2. 喇叭图标
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "volume"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: iconRoot.isMuted ? Theme.danger : iconRoot.iconColor
            strokeColor: iconRoot.isMuted ? Theme.danger : iconRoot.iconColor
            strokeWidth: 0.8
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 1.5
            startY: 5.0
            PathLine { x: 3.8; y: 5.0 }
            PathLine { x: 7.2; y: 2.2 }
            PathLine { x: 7.2; y: 11.8 }
            PathLine { x: 3.8; y: 9.0 }
            PathLine { x: 1.5; y: 9.0 }
            PathLine { x: 1.5; y: 5.0 }
        }
    }

    // 3. 屏幕亮度图标
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "brightness"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: iconRoot.iconColor
            strokeColor: "transparent"
            startX: 7.0
            startY: 4.5
            PathArc { x: 7.0; y: 9.5; radiusX: 2.5; radiusY: 2.5; useLargeArc: false }
            PathArc { x: 7.0; y: 4.5; radiusX: 2.5; radiusY: 2.5; useLargeArc: false }
        }

        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 7.0
            startY: 1.0
            PathLine { x: 7.0; y: 2.6 }
            PathMove { x: 7.0; y: 11.4 }
            PathLine { x: 7.0; y: 13.0 }
            PathMove { x: 1.0; y: 7.0 }
            PathLine { x: 2.6; y: 7.0 }
            PathMove { x: 11.4; y: 7.0 }
            PathLine { x: 13.0; y: 7.0 }
        }
    }

    // 4. 麦克风图标
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "mic"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: iconRoot.isMuted ? Theme.danger : iconRoot.iconColor
            strokeColor: "transparent"
            startX: 4.5
            startY: 2.5
            PathArc { x: 9.5; y: 2.5; radiusX: 2.5; radiusY: 2.5; useLargeArc: false }
            PathLine { x: 9.5; y: 6.5 }
            PathArc { x: 4.5; y: 6.5; radiusX: 2.5; radiusY: 2.5; useLargeArc: false }
            PathLine { x: 4.5; y: 2.5 }
        }

        ShapePath {
            strokeColor: iconRoot.isMuted ? Theme.danger : iconRoot.iconColor
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 3.0
            startY: 5.5
            PathLine { x: 3.0; y: 6.8 }
            PathArc { x: 11.0; y: 6.8; radiusX: 4.0; radiusY: 4.0; useLargeArc: false }
            PathLine { x: 11.0; y: 5.5 }
            PathMove { x: 7.0; y: 10.8 }
            PathLine { x: 7.0; y: 13.0 }
        }
    }

    // 5. 纯矢量设置齿轮图标
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "settings"
        layer.enabled: true
        layer.samples: 4

        // 中心圆孔
        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 7.0
            startY: 4.8
            PathArc { x: 7.0; y: 9.2; radiusX: 2.2; radiusY: 2.2; useLargeArc: false }
            PathArc { x: 7.0; y: 4.8; radiusX: 2.2; radiusY: 2.2; useLargeArc: false }
        }

        // 外圈 8 向凸齿（修复了坐标与闭合大括号）
        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 7.0
            startY: 1.2
            PathLine { x: 7.0; y: 2.8 }
            PathMove { x: 7.0; y: 11.2 }
            PathLine { x: 7.0; y: 12.8 }
            PathMove { x: 1.2; y: 7.0 }
            PathLine { x: 2.8; y: 7.0 }
            PathMove { x: 11.2; y: 7.0 }
            PathLine { x: 12.8; y: 7.0 }

            PathMove { x: 2.9; y: 2.9 }
            PathLine { x: 4.1; y: 4.1 }
            PathMove { x: 9.9; y: 9.9 }
            PathLine { x: 11.1; y: 11.1 }
            PathMove { x: 2.9; y: 11.1 }
            PathLine { x: 4.1; y: 9.9 }
            PathMove { x: 9.9; y: 4.1 }
            PathLine { x: 11.1; y: 2.9 }
        }
    }
}