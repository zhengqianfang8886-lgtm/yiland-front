// ==========================================
// 📄 File: ui/components/compact/CompactRecordPill.qml
// 🌟 纯正数据驱动录制托盘 (对标 CompactImeView: 零硬编码 · 真身位图 · 真实菜单)
// ==========================================
import QtQuick
import QtQuick.Controls

Item {
    id: recRoot
    width: 26
    height: 24

    readonly property bool isActive: (typeof Bridge !== "undefined" && Bridge.isRecordingActive !== undefined) ? Bridge.isRecordingActive : false
    readonly property string iconUrl: (typeof Bridge !== "undefined" && Bridge.recordingIcon !== undefined) ? Bridge.recordingIcon : ""
    readonly property string recTitle: (typeof Bridge !== "undefined" && Bridge.recordingTitle !== undefined) ? Bridge.recordingTitle : "麦克风"
    readonly property string recSub: (typeof Bridge !== "undefined" && Bridge.recordingSubtitle !== undefined) ? Bridge.recordingSubtitle : "OBS Studio"
    readonly property var menuList: (typeof Bridge !== "undefined" && Bridge.recordingMenuList !== undefined) ? Bridge.recordingMenuList : []

    readonly property bool isMenuOpen: menuPopup.opened

    function getRootItem() {
        var p = recRoot;
        while (p && p.parent) p = p.parent;
        return p;
    }

    Rectangle {
        id: recBox
        anchors.centerIn: parent
        width: 22
        height: 22
        radius: 5

        color: recMouse.containsMouse ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.25) : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.12)
        border.color: recMouse.containsMouse ? "#ef4444" : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.45)
        border.width: 1

        scale: recMouse.pressed ? 0.90 : 1.0
        Behavior on scale { NumberAnimation { duration: 70 } }

        // 1. 红色呼吸指示点 (位于左上角)
        Rectangle {
            x: 2; y: 2
            width: 4; height: 4; radius: 2
            color: "#ef4444"
            z: 2

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: recRoot.isActive
                NumberAnimation { to: 0.2; duration: 750; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutQuad }
            }
        }

        // 2. 真实 OBS 位图渲染 (来自 image://recording/current，零伪造)
        Image {
            id: sysImg
            anchors.centerIn: parent
            width: 16
            height: 16
            source: recRoot.iconUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            cache: false
            visible: recRoot.iconUrl !== "" && status === Image.Ready
            smooth: true
            mipmap: true
        }

        // 兜底文字
        Text {
            anchors.centerIn: parent
            text: "●"
            color: "#ef4444"
            font.pixelSize: 10
            visible: !sysImg.visible
        }

        MouseArea {
            id: recMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onEntered: {
                if (!menuPopup.opened) {
                    var rootObj = recRoot.getRootItem();
                    if (rootObj) {
                        var pt = recBox.mapToItem(rootObj, 0, recBox.height + 6);
                        infoPopup.parent = rootObj;
                        infoPopup.x = Math.max(8, Math.min(rootObj.width - infoPopup.width - 8, pt.x - (infoPopup.width / 2) + 11));
                        infoPopup.y = pt.y;
                    }
                    infoPopup.open();
                }
            }
            onExited: infoPopup.close()

            onClicked: (mouse) => {
                infoPopup.close();
                if (mouse.button === Qt.LeftButton) {
                    if (typeof Bridge !== "undefined" && Bridge.toggleRecording) {
                        Bridge.toggleRecording();
                    }
                } else if (mouse.button === Qt.RightButton && recRoot.menuList.length > 0) {
                    if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) {
                        Bridge.openFullCorridorForMotion();
                    }
                    var rootObj = recRoot.getRootItem();
                    if (rootObj) {
                        var pt = recBox.mapToItem(rootObj, 0, recBox.height + 6);
                        menuPopup.parent = rootObj;
                        menuPopup.x = Math.max(8, Math.min(rootObj.width - menuPopup.width - 8, pt.x - (menuPopup.width / 2)));
                        menuPopup.y = pt.y;
                    }
                    menuPopup.open();
                }
            }
        }
    }

    // 悬停提示气泡 (完全由后端 ToolTip 驱动，不写死任何内容)
    Popup {
        id: infoPopup
        width: 140
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
            spacing: 3

            Row {
                spacing: 5
                Rectangle {
                    width: 5; height: 5; radius: 2.5
                    color: "#ef4444"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: recRoot.recTitle
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.weight: Font.Black
                }
            }

            Text {
                text: recRoot.recSub
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pixelSize: 9
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    // 右键上下文菜单 (完全由后端 DBusMenu 驱动，与 IME 完全一致)
    Popup {
        id: menuPopup
        width: 180
        padding: 6
        modal: true
        dim: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        z: 9999

        background: Rectangle {
            color: "#1c1e26"
            radius: 10
            border.color: Qt.rgba(255, 255, 255, 0.16)
            border.width: 1
        }

        contentItem: Column {
            spacing: 3
            width: parent.width

            Repeater {
                model: recRoot.menuList

                delegate: Item {
                    width: parent.width
                    height: modelData.isSeparator ? 6 : 28

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 1
                        color: Qt.rgba(255, 255, 255, 0.12)
                        visible: modelData.isSeparator
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        visible: !modelData.isSeparator
                        color: itemMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label || ""
                            color: "white"
                            font.pixelSize: 11
                            font.bold: modelData.isActive
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                menuPopup.close();
                                if (typeof Bridge !== "undefined" && Bridge.activateRecordingMenuItem) {
                                    Bridge.activateRecordingMenuItem(modelData.id);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}