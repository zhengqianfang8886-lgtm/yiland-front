import QtQuick

Row {
    id: wsRoot
    spacing: 9

    property string chosenFont: ""
    property string wsName: ""
    property int displayWsNumber: 1
    property int wsTotal: 4
    property int activeSlotIndex: 0
    property bool hasZeroWs: false

    Rectangle {
        width: 20; height: 20; radius: 6
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.25)
        border.color: Qt.rgba(Theme.workspace.r, Theme.workspace.g, Theme.workspace.b, 0.75)
        border.width: 1

        Text {
            anchors.centerIn: parent; text: wsRoot.displayWsNumber; color: "white"; font.pixelSize: 11; font.weight: Font.Black
            font.family: (wsRoot.chosenFont !== "") ? wsRoot.chosenFont : "Monospace"
        }
    }

    Item {
        height: 20; width: Math.min(84, wsNameText.implicitWidth)
        clip: true; anchors.verticalCenter: parent.verticalCenter

        Text {
            id: wsNameText; anchors.verticalCenter: parent.verticalCenter
            text: wsRoot.wsName ? wsRoot.wsName : ("桌面 " + wsRoot.displayWsNumber)
            color: "white"; font.family: wsRoot.chosenFont; font.pixelSize: 13; font.weight: Font.Black
            font.letterSpacing: 0.5; elide: Text.ElideRight; width: parent.width
        }
    }

    Rectangle {
        height: 16; radius: 8; width: wsDotsRow.implicitWidth + 10
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(1, 1, 1, 0.12); border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1

        Row {
            id: wsDotsRow; anchors.centerIn: parent; spacing: 4
            Repeater {
                model: Math.min(8, Math.max(2, wsRoot.wsTotal))
                Rectangle {
                    readonly property bool isCurrent: (index === wsRoot.activeSlotIndex)
                    width: isCurrent ? 14 : 4; height: 4; radius: 2
                    color: isCurrent ? Theme.workspace : Qt.rgba(1, 1, 1, 0.5)
                    scale: isCurrent ? 1.0 : (dotMouse.hovered ? 1.3 : 1.0)
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                    HoverHandler { id: dotMouse; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (typeof Bridge !== "undefined") {
                                Bridge.switchWorkspace(wsRoot.hasZeroWs ? index : (index + 1))
                            }
                        }
                    }
                }
            }
        }
    }
}