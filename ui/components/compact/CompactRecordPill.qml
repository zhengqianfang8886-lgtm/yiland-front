// ==========================================
// 📄 File: ui/components/compact/CompactRecordPill.qml
// 🌟 纯粹的内容展示层 (外观与行为已解耦，修复 QML 语法错误版)
// ==========================================
import QtQuick
import QtQuick.Shapes
import QtQuick.Controls

Item {
    id: recRoot
    anchors.fill: parent

    readonly property bool isActive: (typeof Bridge !== "undefined" && Bridge.isRecordingActive !== undefined) ? Boolean(Bridge.isRecordingActive) : false
    readonly property string iconUrl: (typeof Bridge !== "undefined" && Bridge.recordingIcon !== undefined) ? String(Bridge.recordingIcon) : ""
    readonly property var recItems: (typeof Bridge !== "undefined" && Bridge.recordingItems !== undefined) ? Bridge.recordingItems : []
    readonly property bool hasObsIcon: iconUrl !== ""

    function showInfo(anchorItem) {
        var rootObj = infoPopup.parent; 
        var p = recRoot;
        while (p && p.parent) p = p.parent;
        infoPopup.parent = p;
        if (p && anchorItem) {
            var pt = anchorItem.mapToItem(p, 0, anchorItem.height + 6);
            infoPopup.x = Math.max(8, Math.min(p.width - infoPopup.width - 8, pt.x - (infoPopup.width / 2) + 11));
            infoPopup.y = pt.y;
            infoPopup.open();
        }
    }
    
    function hideInfo() { 
        infoPopup.close(); 
    }

    Row {
        anchors.centerIn: parent
        spacing: 8 

        Item {
            width: 10
            height: 10 
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: 14
                height: 14
                radius: 7 
                color: "transparent"
                border.color: "#FF453A"
                border.width: 1.5

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: recRoot.isActive
                    NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 6
                height: 6
                radius: 3 
                color: "#FF453A"
            }
        }

        Image {
            id: sysImg
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16 
            source: recRoot.iconUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            cache: false
            visible: recRoot.hasObsIcon && status === Image.Ready
            smooth: true
            mipmap: true
        }

        Shape {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            visible: recRoot.hasObsIcon && !sysImg.visible
            layer.enabled: true
            layer.samples: 4

            ShapePath { fillColor: "#ffffff"; strokeColor: "transparent"; PathAngleArc { centerX: 8.0; centerY: 8.0; radiusX: 7.5; radiusY: 7.5; startAngle: 0; sweepAngle: 360 } }
            ShapePath { fillColor: "#14151b"; strokeColor: "transparent"; PathAngleArc { centerX: 8.0; centerY: 5.5; radiusX: 3.0; radiusY: 3.0; startAngle: 0; sweepAngle: 360 } }
            ShapePath { fillColor: "#14151b"; strokeColor: "transparent"; PathAngleArc { centerX: 5.5; centerY: 10.5; radiusX: 3.0; radiusY: 3.0; startAngle: 0; sweepAngle: 360 } }
            ShapePath { fillColor: "#14151b"; strokeColor: "transparent"; PathAngleArc { centerX: 10.5; centerY: 10.5; radiusX: 3.0; radiusY: 3.0; startAngle: 0; sweepAngle: 360 } }
            ShapePath { fillColor: "#ffffff"; strokeColor: "transparent"; PathAngleArc { centerX: 8.0; centerY: 8.0; radiusX: 2.0; radiusY: 2.0; startAngle: 0; sweepAngle: 360 } }
        }
    }

    Popup {
        id: infoPopup
        width: 170
        padding: 8
        modal: false
        dim: false
        closePolicy: Popup.CloseOnEscape
        z: 9998

        background: Rectangle { 
            color: "#1c1e26"
            radius: 8
            border.color: Qt.rgba(255, 255, 255, 0.16)
            border.width: 1 
        }

        contentItem: Column {
            spacing: 6
            width: parent.width

            Repeater {
                model: recRoot.recItems.length > 0 ? recRoot.recItems : [{ "title": "音频采集", "subtitle": "系统录制", "icon": "🎙️" }]
                
                delegate: Column {
                    width: parent.width
                    spacing: 2

                    Row { 
                        spacing: 5
                        
                        Text { 
                            text: modelData.icon || "🎙️"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter 
                        }
                        
                        Text { 
                            text: modelData.title || "音频采集"
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.weight: Font.Black
                            anchors.verticalCenter: parent.verticalCenter 
                        } 
                    }

                    Text { 
                        text: (modelData.subtitle || "系统录制") + " · 正在使用"
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        width: parent.width 
                    }

                    Rectangle { 
                        width: parent.width
                        height: 1
                        color: Qt.rgba(255, 255, 255, 0.08)
                        visible: index < recRoot.recItems.length - 1 
                    }
                }
            }
        }
    }
}