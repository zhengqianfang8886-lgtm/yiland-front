// ==========================================
// 📄 File: process/ProcessSidebar.qml
// ==========================================
import QtQuick

Rectangle {
    id: sidebarRoot
    width: 108
    height: parent.height
    radius: Theme.radiusCard
    color: Qt.rgba(1, 1, 1, 0.035)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1
    clip: true

    property string effectiveFont: ""
    property string effectiveMono: ""
    property int totalCount: 0
    property int runningCount: 0

    signal requestAdd()
    signal requestStartAll()
    signal requestStopAll()

    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        // 1. 状态看板统计区
        Column {
            width: parent.width
            spacing: 1

            Row {
                spacing: 4
                anchors.horizontalCenter: parent.horizontalCenter
                Rectangle {
                    width: 5; height: 5; radius: 2.5
                    color: sidebarRoot.runningCount > 0 ? "#10b981" : "#a855f7"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "服务管控"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Theme.textSecondary
                    font.family: sidebarRoot.effectiveFont
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2
                Text {
                    text: sidebarRoot.runningCount
                    color: sidebarRoot.runningCount > 0 ? "#10b981" : "white"
                    font.pixelSize: 19
                    font.weight: Font.Black
                    font.family: sidebarRoot.effectiveMono
                }
                Text {
                    text: "/" + sidebarRoot.totalCount
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.family: sidebarRoot.effectiveMono
                    anchors.baseline: parent.children[0].baseline
                }
            }

            Text {
                text: sidebarRoot.runningCount > 0 ? (sidebarRoot.runningCount + " 活跃中") : "服务就绪"
                font.pixelSize: 9
                font.weight: Font.Bold
                color: sidebarRoot.runningCount > 0 ? "#34d399" : Theme.textMuted
                font.family: sidebarRoot.effectiveFont
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

        // 2. 核心三大动作按键
        Column {
            width: parent.width
            spacing: 4

            // + 新建服务
            Rectangle {
                width: parent.width; height: 24; radius: 5
                color: addHover.hovered ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.3) : Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.16)
                border.color: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.55); border.width: 1
                scale: addTap.pressed ? 0.95 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                Row {
                    anchors.centerIn: parent; spacing: 3
                    Text { text: "+"; color: "#c084fc"; font.pixelSize: 12; font.weight: Font.Black; font.family: sidebarRoot.effectiveFont }
                    Text { text: "新建服务"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: sidebarRoot.effectiveFont }
                }
                HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: addTap; onTapped: sidebarRoot.requestAdd() }
            }

            // ▶ 全部启动
            Rectangle {
                width: parent.width; height: 22; radius: 5
                color: startHover.hovered ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.28) : Qt.rgba(1, 1, 1, 0.12)
                border.color: startHover.hovered ? "#10b981" : Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.35); border.width: 1
                scale: startTap.pressed ? 0.95 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                Row {
                    anchors.centerIn: parent; spacing: 3
                    Text { text: "▶"; color: "#10b981"; font.pixelSize: 8; font.family: sidebarRoot.effectiveFont }
                    Text { text: "全部启动"; color: startHover.hovered ? "#34d399" : "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: sidebarRoot.effectiveFont }
                }
                HoverHandler { id: startHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: startTap; onTapped: sidebarRoot.requestStartAll() }
            }

            // ■ 全部停止
            Rectangle {
                width: parent.width; height: 22; radius: 5
                color: stopHover.hovered ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.26) : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.08)
                border.color: stopHover.hovered ? Theme.danger : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.3); border.width: 1
                scale: stopTap.pressed ? 0.95 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                Row {
                    anchors.centerIn: parent; spacing: 3
                    Text { text: "■"; color: Theme.danger; font.pixelSize: 8; font.family: sidebarRoot.effectiveFont }
                    Text { text: "全部停止"; color: stopHover.hovered ? Theme.danger : Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: sidebarRoot.effectiveFont }
                }
                HoverHandler { id: stopHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: stopTap; onTapped: sidebarRoot.requestStopAll() }
            }
        }
    }
}