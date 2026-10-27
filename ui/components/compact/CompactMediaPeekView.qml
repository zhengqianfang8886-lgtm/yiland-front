// =========================================================================
// 📄 File: ui/components/compact/CompactMediaPeekView.qml
// 🌟 媒体切歌悬浮呼吸卡片 (解耦独立原子组件版)
// =========================================================================
import QtQuick

Item {
    id: peekRoot
    anchors.fill: parent
    anchors.leftMargin: 14
    anchors.rightMargin: 14

    property var payload: ({})
    property string effectiveFont: ""
    property var relay: null

    implicitWidth: {
        var titleLen = (payload && payload.title) ? payload.title.length : 0;
        return Math.min(360, Math.max(260, 140 + titleLen * 12));
    }

    function getBandValue(idx) {
        if (!relay) return 0.2;
        var s1 = relay.spec1 || 0.2, s2 = relay.spec2 || 0.2;
        var s3 = relay.spec3 || 0.2, s4 = relay.spec4 || 0.2;
        switch (idx) {
            case 0: return Math.max(0.18, Math.min(1.0, s1 * 0.82));
            case 1: return Math.max(0.20, Math.min(1.0, s1));
            case 2: return Math.max(0.24, Math.min(1.0, s2));
            case 3: return Math.max(0.24, Math.min(1.0, s3));
            case 4: return Math.max(0.20, Math.min(1.0, s4));
            case 5: return Math.max(0.18, Math.min(1.0, (s3 + s4) * 0.52));
            default: return 0.2;
        }
    }

    Row {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            width: 24; height: 24; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(255, 255, 255, 0.10)
            Text { anchors.centerIn: parent; text: "🎵"; font.pixelSize: 13 }
        }

        Column {
            width: parent.width - 24 - 10 - 46 - 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            clip: true

            Text {
                text: (peekRoot.payload && peekRoot.payload.title) ? peekRoot.payload.title : "正在播放"
                color: "#ffffff"
                font.family: peekRoot.effectiveFont
                font.pixelSize: 12
                font.weight: Font.Bold
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: (peekRoot.payload && peekRoot.payload.subtitle) ? peekRoot.payload.subtitle : "音乐媒体"
                color: (peekRoot.payload && peekRoot.payload.color) ? peekRoot.payload.color : "#22c55e"
                font.family: peekRoot.effectiveFont
                font.pixelSize: 10
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2.5

            Repeater {
                model: 6
                Rectangle {
                    width: 2.8; height: 15; radius: 1.4
                    color: (peekRoot.payload && peekRoot.payload.color) ? peekRoot.payload.color : "#22c55e"
                    anchors.verticalCenter: parent.verticalCenter
                    transform: Scale {
                        origin.y: 7.5
                        yScale: peekRoot.getBandValue(index)
                        Behavior on yScale { NumberAnimation { duration: 75 } }
                    }
                }
            }
        }
    }
}