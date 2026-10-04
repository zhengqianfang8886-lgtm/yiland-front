import QtQuick
import QtQuick.Shapes

Item {
    id: iconRoot
    width: 14
    height: 14

    property string iconType: "controlCenter" // "controlCenter" | "volume" | "brightness" | "mic" | "settings" | "chevron"
    property color iconColor: "white"
    property bool isMuted: false

    // 1. 控制中心双滑块图标 (收起态)
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "controlCenter"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 1.5
            startY: 4.2
            PathLine { x: 12.5; y: 4.2 }
        }
        ShapePath {
            fillColor: iconRoot.iconColor
            strokeColor: "transparent"
            startX: 9.5
            startY: 4.2
            PathArc { x: 9.5; y: 4.2; radiusX: 2.0; radiusY: 2.0; useLargeArc: true }
        }
        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 1.5
            startY: 9.8
            PathLine { x: 12.5; y: 9.8 }
        }
        ShapePath {
            fillColor: iconRoot.iconColor
            strokeColor: "transparent"
            startX: 4.5
            startY: 9.8
            PathArc { x: 4.5; y: 9.8; radiusX: 2.0; radiusY: 2.0; useLargeArc: true }
        }
    }

    // 2. 现代极简音量喇叭
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
            startX: 2.0
            startY: 5.2
            PathLine { x: 4.2; y: 5.2 }
            PathLine { x: 7.2; y: 2.5 }
            PathLine { x: 7.2; y: 11.5 }
            PathLine { x: 4.2; y: 8.8 }
            PathLine { x: 2.0; y: 8.8 }
            PathLine { x: 2.0; y: 5.2 }
        }

        // 🚀 核心修复：通过透明色实现条件显隐，杜绝 ShapePath.visible 报错
        ShapePath {
            strokeColor: (!iconRoot.isMuted) ? iconRoot.iconColor : "transparent"
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 9.5
            startY: 4.5
            PathArc { x: 9.5; y: 9.5; radiusX: 3.5; radiusY: 3.5; useLargeArc: false }
        }

        // 静音斜杠
        ShapePath {
            strokeColor: iconRoot.isMuted ? Theme.danger : "transparent"
            strokeWidth: 1.3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 9.2
            startY: 4.5
            PathLine { x: 12.8; y: 9.5 }
            PathMove { x: 12.8; y: 4.5 }
            PathLine { x: 9.2; y: 9.5 }
        }
    }

    // 3. Apple 风格极简日冕日照图标 (告别发散刺猬感)
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "brightness"
        layer.enabled: true
        layer.samples: 4

        // 中心圆核
        ShapePath {
            fillColor: iconRoot.iconColor
            strokeColor: "transparent"
            startX: 7.0
            startY: 4.6
            PathArc { x: 7.0; y: 9.4; radiusX: 2.4; radiusY: 2.4; useLargeArc: false }
            PathArc { x: 7.0; y: 4.6; radiusX: 2.4; radiusY: 2.4; useLargeArc: false }
        }

        // 8 向高精密微光射线
        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.15
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            // 上下正向
            startX: 7.0
            startY: 1.2
            PathLine { x: 7.0; y: 2.8 }
            PathMove { x: 7.0; y: 11.2 }
            PathLine { x: 7.0; y: 12.8 }

            // 左右正向
            PathMove { x: 1.2; y: 7.0 }
            PathLine { x: 2.8; y: 7.0 }
            PathMove { x: 11.2; y: 7.0 }
            PathLine { x: 12.8; y: 7.0 }

            // 45 度对角射线
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

    // 4. 精品录音棚胶囊麦克风 (告别茄子感)
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "mic"
        layer.enabled: true
        layer.samples: 4

        // 麦克风拾音胶囊头
        ShapePath {
            fillColor: iconRoot.isMuted ? Theme.danger : iconRoot.iconColor
            strokeColor: "transparent"
            startX: 5.0
            startY: 2.2
            PathArc { x: 9.0; y: 2.2; radiusX: 2.0; radiusY: 2.0; useLargeArc: false }
            PathLine { x: 9.0; y: 6.8 }
            PathArc { x: 5.0; y: 6.8; radiusX: 2.0; radiusY: 2.0; useLargeArc: false }
            PathLine { x: 5.0; y: 2.2 }
        }

        // 弧形拾音支架与底座
        ShapePath {
            strokeColor: iconRoot.isMuted ? Theme.danger : iconRoot.iconColor
            strokeWidth: 1.15
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 3.4
            startY: 5.6
            PathLine { x: 3.4; y: 6.8 }
            PathArc { x: 10.6; y: 6.8; radiusX: 3.6; radiusY: 3.6; useLargeArc: false }
            PathLine { x: 10.6; y: 5.6 }
            PathMove { x: 7.0; y: 10.4 }
            PathLine { x: 7.0; y: 12.6 }
            PathMove { x: 4.8; y: 12.6 }
            PathLine { x: 9.2; y: 12.6 }
        }

        // 🚀 核心修复：静音斜切线通过透明色控制显示
        ShapePath {
            strokeColor: iconRoot.isMuted ? Theme.danger : "transparent"
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 2.0
            startY: 2.0
            PathLine { x: 12.0; y: 12.0 }
        }
    }

    // 5. 极简工业机械齿轮
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "settings"
        layer.enabled: true
        layer.samples: 4

        // 轴心圆孔
        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 7.0
            startY: 5.0
            PathArc { x: 7.0; y: 9.0; radiusX: 2.0; radiusY: 2.0; useLargeArc: false }
            PathArc { x: 7.0; y: 5.0; radiusX: 2.0; radiusY: 2.0; useLargeArc: false }
        }

        // 精密轮齿
        ShapePath {
            strokeColor: iconRoot.iconColor
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            startX: 7.0
            startY: 1.2
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

    // 6. 纯矢量微细折叠箭头
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
            startX: 8.5
            startY: 3.5
            PathLine { x: 5.0; y: 7.0 }
            PathLine { x: 8.5; y: 10.5 }
        }
    }
}