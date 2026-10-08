// ==========================================
// 📄 File: power/PowerActionIcon.qml
// 🌟 统一电源与会话状态矢量图标 (消除两处页面 1:1 重复代码)
// ==========================================
import QtQuick
import QtQuick.Shapes

Item {
    id: iconRoot
    width: 16
    height: 16

    property string iconType: "poweroff"
    property color strokeColor: "#ffffff"
    property color fillColor: "#ffffff"

    // 🔒 锁定
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "lock"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: iconRoot.strokeColor
            strokeWidth: 1.4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 5.0; startY: 6.5
            PathLine { x: 5.0; y: 4.8 }
            PathArc { x: 11.0; y: 4.8; radiusX: 3.0; radiusY: 3.0; useLargeArc: false }
            PathLine { x: 11.0; y: 6.5 }
        }
        ShapePath {
            fillColor: iconRoot.fillColor
            strokeColor: "transparent"
            startX: 3.0; startY: 6.5
            PathLine { x: 13.0; y: 6.5 }
            PathLine { x: 13.0; y: 13.5 }
            PathLine { x: 3.0; y: 13.5 }
            PathLine { x: 3.0; y: 6.5 }
        }
    }

    // 🌙 睡眠
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "suspend"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: iconRoot.fillColor
            strokeColor: "transparent"
            startX: 12.0; startY: 2.2
            PathArc { x: 4.0; y: 13.5; radiusX: 6.5; radiusY: 6.5; useLargeArc: false }
            PathQuad { x: 12.0; y: 2.2; controlX: 9.0; controlY: 8.5 }
        }
    }

    // ⇄ 切换用户
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "switch"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: iconRoot.strokeColor
            strokeWidth: 1.4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 2.0; startY: 5.0
            PathLine { x: 13.5; y: 5.0 }
            PathMove { x: 10.5; y: 2.5 }
            PathLine { x: 13.5; y: 5.0 }
            PathLine { x: 10.5; y: 7.5 }
        }
        ShapePath {
            strokeColor: iconRoot.strokeColor
            strokeWidth: 1.4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 14.0; startY: 11.0
            PathLine { x: 2.5; y: 11.0 }
            PathMove { x: 5.5; y: 8.5 }
            PathLine { x: 2.5; y: 11.0 }
            PathLine { x: 5.5; y: 13.5 }
        }
    }

    // ⎋ 注销
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "logout"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: iconRoot.strokeColor
            strokeWidth: 1.4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 8.0; startY: 2.5
            PathLine { x: 2.5; y: 2.5 }
            PathLine { x: 2.5; y: 13.5 }
            PathLine { x: 8.0; y: 13.5 }
        }
        ShapePath {
            strokeColor: iconRoot.strokeColor
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 6.0; startY: 8.0
            PathLine { x: 13.5; y: 8.0 }
            PathMove { x: 10.5; y: 5.0 }
            PathLine { x: 13.5; y: 8.0 }
            PathLine { x: 10.5; y: 11.0 }
        }
    }

    // ⟳ 重启
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "reboot"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: iconRoot.strokeColor
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 8.0; startY: 1.8
            PathArc { x: 14.0; y: 8.0; radiusX: 6.0; radiusY: 6.0; useLargeArc: false }
            PathArc { x: 8.0; y: 14.0; radiusX: 6.0; radiusY: 6.0; useLargeArc: false }
            PathArc { x: 2.6; y: 9.6; radiusX: 6.0; radiusY: 6.0; useLargeArc: false }
        }
        ShapePath {
            fillColor: iconRoot.fillColor
            strokeColor: "transparent"
            startX: 1.0; startY: 10.5
            PathLine { x: 4.5; y: 10.5 }
            PathLine { x: 2.6; y: 7.0 }
            PathLine { x: 1.0; y: 10.5 }
        }
    }

    // ⏻ 关机
    Shape {
        anchors.fill: parent
        visible: iconRoot.iconType === "poweroff"
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: iconRoot.strokeColor
            strokeWidth: 1.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 4.5; startY: 4.5
            PathArc { x: 11.5; y: 4.5; radiusX: 5.2; radiusY: 5.2; useLargeArc: true }
        }
        ShapePath {
            strokeColor: iconRoot.strokeColor
            strokeWidth: 1.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 8.0; startY: 1.8
            PathLine { x: 8.0; y: 8.0 }
        }
    }
}