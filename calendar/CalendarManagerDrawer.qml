// ==========================================
// 📄 File: calendar/CalendarManagerDrawer.qml
// ==========================================
import QtQuick
import QtQuick.Controls

Rectangle {
    id: drawerRoot
    anchors.fill: parent
    color: "#181820"
    radius: Theme.radiusCard
    z: 50

    property string effectiveFont: ""
    property var habitsList: []
    property int currentHabitIndex: 0

    signal habitSelected(int index)
    signal habitCreated(string name)
    signal habitDeleted(string id)
    signal closeRequested()

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // 顶栏标题
        Item {
            width: parent.width
            height: 18

            Text {
                text: "事项设置"
                color: "#34d399"
                font.pixelSize: 11
                font.weight: Font.Black
                font.family: drawerRoot.effectiveFont
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: 18; height: 18; radius: 9
                color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                Text { anchors.centerIn: parent; text: "✕"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 9; font.weight: Font.Bold }
                HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: drawerRoot.closeRequested() }
            }
        }

        // 新增输入框
        Rectangle {
            width: parent.width
            height: 24
            radius: 5
            color: "#24242e"
            border.color: input.activeFocus ? "#10b981" : Qt.rgba(1, 1, 1, 0.15)
            border.width: 1

            TextInput {
                id: input
                anchors.left: parent.left; anchors.leftMargin: 6
                anchors.right: addBtn.left; anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 10
                color: "white"
                font.family: drawerRoot.effectiveFont
                clip: true
                selectByMouse: true

                Keys.onReturnPressed: commitAdd()

                Text {
                    text: "输入名称按回车..."
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.pixelSize: 9
                    font.family: drawerRoot.effectiveFont
                    visible: !input.text && !input.activeFocus
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                id: addBtn
                width: 18; height: 18; radius: 4
                anchors.right: parent.right; anchors.rightMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                color: input.text.trim().length > 0 ? "#10b981" : Qt.rgba(1, 1, 1, 0.08)

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: input.text.trim().length > 0 ? "white" : Qt.rgba(1, 1, 1, 0.3)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: commitAdd()
                }
            }
        }

        // 事项列表
        Item {
            width: parent.width
            height: parent.height - 56

            ListView {
                anchors.fill: parent
                clip: true
                spacing: 3
                model: drawerRoot.habitsList

                delegate: Rectangle {
                    width: parent.width - 4
                    height: 22
                    radius: 4
                    readonly property bool isSel: (drawerRoot.currentHabitIndex === index)
                    color: isSel ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.22) : (itemHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                    border.color: isSel ? "#10b981" : "transparent"
                    border.width: 1

                    HoverHandler { id: itemHover }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 6; anchors.rightMargin: 6

                        Text {
                            text: modelData.name
                            color: isSel ? "#34d399" : "white"
                            font.pixelSize: 9
                            font.weight: isSel ? Font.Black : Font.DemiBold
                            font.family: drawerRoot.effectiveFont
                            elide: Text.ElideRight
                            width: parent.width - 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "✕"
                            color: delHover.hovered ? "#ef4444" : Qt.rgba(1, 1, 1, 0.3)
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                            HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: drawerRoot.habitDeleted(modelData.id) }
                        }
                    }

                    MouseArea {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.rightMargin: 16
                        anchors.top: parent.top; anchors.bottom: parent.bottom
                        cursorShape: Qt.PointingHandCursor
                        onClicked: drawerRoot.habitSelected(index)
                    }
                }
            }
        }
    }

    function commitAdd() {
        if (!input.text.trim()) return;
        drawerRoot.habitCreated(input.text);
        input.text = "";
    }

    function focusInput() {
        input.forceActiveFocus();
    }
}