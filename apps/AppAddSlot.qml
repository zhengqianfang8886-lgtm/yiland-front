// ==========================================
// 📄 File: apps/AppAddSlot.qml
// 🌟 42×42 统一位格圆角虚线添加槽位组件
// ==========================================
import QtQuick
import QtQuick.Shapes

Item {
    id: addSlotRoot
    width: 42
    height: 42

    readonly property bool isHovered: addSlotHover.hovered
    signal clicked()
    signal hoverChanged(bool hovered)

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeWidth: 1.4
            strokeColor: addSlotRoot.isHovered ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.30)
            fillColor: addSlotRoot.isHovered ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.12) : Qt.rgba(255, 255, 255, 0.04)
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 3]
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            // 42×42 像素，四周 10px 优雅圆角全闭合
            startX: 11; startY: 1
            PathLine { x: 31; y: 1 }
            PathArc { x: 41; y: 11; radiusX: 10; radiusY: 10 }
            PathLine { x: 41; y: 31 }
            PathArc { x: 31; y: 41; radiusX: 10; radiusY: 10 }
            PathLine { x: 11; y: 41 }
            PathArc { x: 1; y: 31; radiusX: 10; radiusY: 10 }
            PathLine { x: 1; y: 11 }
            PathArc { x: 11; y: 1; radiusX: 10; radiusY: 10 }
        }
    }

    Text {
        anchors.centerIn: parent
        text: "＋"
        color: addSlotRoot.isHovered ? "#38bdf8" : Qt.rgba(255, 255, 255, 0.6)
        font.pixelSize: 18
        font.weight: Font.DemiBold
        scale: addSlotTap.pressed ? 0.90 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    HoverHandler {
        id: addSlotHover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: addSlotRoot.hoverChanged(hovered)
    }

    TapHandler {
        id: addSlotTap
        onTapped: addSlotRoot.clicked()
    }
}