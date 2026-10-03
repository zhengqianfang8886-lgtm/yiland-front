import QtQuick

Item {
    id: sedRoot
    anchors.fill: parent
    anchors.margins: 12

    property string chosenFont: ""
    property int continuousSitMinutes: 45
    signal sedentaryRested()
    signal sedentarySnooze()

    Row {
        anchors.fill: parent
        spacing: 14

        Item {
            width: 52; height: 52
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: healthGlowRing
                anchors.centerIn: parent
                width: 52; height: 52; radius: 26
                color: "transparent"; border.color: "#34d399"; border.width: 1.5

                SequentialAnimation {
                    running: sedRoot.visible; loops: Animation.Infinite
                    ParallelAnimation {
                        NumberAnimation { target: healthGlowRing; property: "scale"; from: 0.85; to: 1.3; duration: 1400; easing.type: Easing.OutQuad }
                        NumberAnimation { target: healthGlowRing; property: "opacity"; from: 0.8; to: 0.0; duration: 1400; easing.type: Easing.OutQuad }
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 44; height: 44; radius: 22
                color: Qt.rgba(52, 211, 153, 0.2); border.color: "#34d399"; border.width: 1.5
                Text { anchors.centerIn: parent; text: "🧘"; font.pixelSize: 22 }
            }
        }

        Column {
            width: parent.width - 52 - 130 - 28
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Row {
                spacing: 6
                Rectangle { width: 6; height: 6; radius: 3; color: "#34d399"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "HEALTH & RECOVERY · 站立建议"; color: "#34d399"; font.pixelSize: 9; font.weight: Font.Black; font.letterSpacing: 0.8; font.family: sedRoot.chosenFont }
            }

            Text { text: "该站起来活动一下了"; color: "white"; font.family: sedRoot.chosenFont; font.pixelSize: 15; font.weight: Font.Black; elide: Text.ElideRight; width: parent.width }
            Text { text: "已连续伏案 " + sedRoot.continuousSitMinutes + " 分钟 · 建议起身接水、舒展放松"; color: Qt.rgba(1, 1, 1, 0.85); font.family: sedRoot.chosenFont; font.pixelSize: 11; font.weight: Font.Bold; wrapMode: Text.WordWrap; width: parent.width }
        }

        Column {
            width: 130
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Rectangle {
                width: parent.width; height: 32; radius: 16
                color: restTap.pressed ? "#15803d" : (restHover.hovered ? "#16a34a" : "#22c55e")
                scale: restTap.pressed ? 0.94 : (restHover.hovered ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent; spacing: 4
                    Text { text: "✓"; color: "white"; font.pixelSize: 11; font.weight: Font.Black }
                    Text { text: "我已起身活动"; color: "white"; font.pixelSize: 11; font.weight: Font.Black; font.family: sedRoot.chosenFont }
                }

                HoverHandler { id: restHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: restTap; onTapped: sedRoot.sedentaryRested() }
            }

            Rectangle {
                width: parent.width; height: 26; radius: 13
                color: snoozeTap.pressed ? Qt.rgba(1, 1, 1, 0.22) : (snoozeHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                border.color: Theme.borderSubtle; border.width: 1
                scale: snoozeTap.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                Row {
                    anchors.centerIn: parent; spacing: 4
                    Text { text: "⏱"; font.pixelSize: 10 }
                    Text { text: "延后 5 分钟"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 10; font.weight: Font.Bold; font.family: sedRoot.chosenFont }
                }

                HoverHandler { id: snoozeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: snoozeTap; onTapped: sedRoot.sedentarySnooze() }
            }
        }
    }
}