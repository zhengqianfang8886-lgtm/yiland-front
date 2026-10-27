// ==========================================
// 📄 File: ui/components/compact/CompactWorkspaceView.qml
// 🌟 纯净工作区横幅 (彻底移除鱼眼透镜 · 极简分页指示版)
// ==========================================
import QtQuick

Item {
    id: wsRoot
    anchors.fill: parent

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property string wsName: ""
    property int displayWsNumber: 1
    property int wsTotal: 4
    property var wsList: []

    // 格式化桌面列表
    readonly property var workspaceItems: {
        if (wsList && wsList.length > 0) {
            var res = [];
            for (var i = 0; i < wsList.length; i++) {
                var item = wsList[i];
                var title = "";
                var tid = i;
                if (typeof item === "object" && item !== null) {
                    title = item.name || ("桌面 " + (item.id !== undefined ? item.id : i));
                    tid = item.id !== undefined ? item.id : i;
                } else if (typeof item === "string") {
                    title = item;
                } else {
                    title = "桌面 " + i;
                }
                res.push({ index: i, id: tid, name: title });
            }
            return res;
        }
        var defs = [];
        var total = Math.max(1, wsTotal);
        for (var k = 0; k < total; k++) {
            defs.push({ index: k, id: k, name: "桌面 " + (k + 1) });
        }
        return defs;
    }

    implicitWidth: 260
    implicitHeight: 26

    // =========================================================================
    // 纯粹极简横幅：左侧桌面徽标 + 右侧分页圆点
    // =========================================================================
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Rectangle {
            width: 22
            height: 22
            radius: 6
            color: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.24)
            border.color: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.85)
            border.width: 1.2
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -0.5
                text: wsRoot.displayWsNumber
                color: "white"
                font.pixelSize: 11
                font.weight: Font.Black
                font.family: wsRoot.displayFont
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: wsRoot.wsName ? wsRoot.wsName : ("桌面 " + wsRoot.displayWsNumber)
            color: "#ffffff"
            font.family: wsRoot.effectiveFont
            font.pixelSize: 12
            font.weight: Font.Black
            font.letterSpacing: 0.4
            elide: Text.ElideRight
            renderType: Text.QtRendering
        }
    }

    // 右侧苹果分页小圆点指示器
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: wsRoot.workspaceItems

            Rectangle {
                readonly property bool isCurrent: (index === (wsRoot.displayWsNumber - 1) || index === wsRoot.displayWsNumber)
                width: isCurrent ? 12 : 4
                height: 4
                radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: isCurrent ? (typeof Theme !== "undefined" ? Theme.workspace : "#a855f7") : Qt.rgba(1, 1, 1, 0.25)

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }
}