// ==========================================
// 📄 File: ui/components/compact/CompactRecordDot.qml
// 🌟 纯正 macOS 风格红色录制指示灯 (独立红圈红点 · 悬停展示流详情)
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: dotRoot
    width: 18
    height: 22

    readonly property bool isActive: (typeof Bridge !== "undefined" && Bridge.isRecordingActive !== undefined) ? Bridge.isRecordingActive : false
    readonly property var recItems: (typeof Bridge !== "undefined" && Bridge.recordingItems !== undefined) ? Bridge.recordingItems : []

    function getRootItem() {
        var p = dotRoot;
        while (p && p.parent) p = p.parent;
        return p;
    }

    Item {
        anchors.centerIn: parent
        width: 14
        height: 14

        // 1. 外层红圈
        Rectangle {
            id: outerRing
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: "#ff3b30"
            border.width: 1.5

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: dotRoot.isActive
                NumberAnimation { to: 0.35; duration: 800; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.00; duration: 800; easing.type: Easing.InOutQuad }
            }
        }

        // 2. 内层实心红点
        Rectangle {
            anchors.centerIn: parent
            width: 7
            height: 7
            radius: width / 2
            color: "#ff3b30"
        }

        MouseArea {
            id: dotMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: {
                var rootObj = dotRoot.getRootItem();
                if (rootObj) {
                    var pt = dotRoot.mapToItem(rootObj, 0, dotRoot.height + 6);
                    infoPopup.parent = rootObj;
                    infoPopup.x = Math.max(8, Math.min(rootObj.width - infoPopup.width - 8, pt.x - (infoPopup.width / 2) + 9));
                    infoPopup.y = pt.y;
                }
                infoPopup.open();
            }
            onExited: infoPopup.close()
            onClicked: {
                infoPopup.close();
                if (typeof Bridge !== "undefined" && Bridge.toggleObsWindow) {
                    Bridge.toggleObsWindow();
                }
            }
        }
    }

    // 悬停提示卡片 (如截图所示：麦克风 / 桌面音频)
    Popup {
        id: infoPopup
        width: 168
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
                model: dotRoot.recItems.length > 0 ? dotRoot.recItems : [
                    { "title": "麦克风与音频采集", "subtitle": "OBS Studio", "icon": "🎙️" }
                ]

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
                        text: (modelData.subtitle || "OBS Studio") + " · 正在使用"
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
                        visible: index < dotRoot.recItems.length - 1
                    }
                }
            }
        }
    }
}