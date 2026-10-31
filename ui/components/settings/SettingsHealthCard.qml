// ==========================================
// 📄 File: ui/components/settings/SettingsHealthCard.qml
// 🌟 健康关怀与硬件负载调控卡片 (CPU 出芽专属版)
// ==========================================
import QtQuick
import QtQuick.Controls

Rectangle {
    id: cardRoot
    height: healthSettingsCol.implicitHeight + 24
    radius: 12
    color: Qt.rgba(1, 1, 1, 0.05)
    border.color: Qt.rgba(52, 211, 153, 0.3)
    border.width: 1

    Column {
        id: healthSettingsCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text { text: "🌿 健康关怀与系统监控"; color: "#34d399"; font.pixelSize: 12; font.bold: true }

        // =====================================================================
        // 1. CPU 高压报警小岛 (智能出芽模式)
        // =====================================================================
        Item {
            width: parent.width; height: 36
            Column {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                Row {
                    spacing: 6
                    Text { text: "⚡"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "高压 CPU 动态出芽监控"; color: "white"; font.pixelSize: 12; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }
                Text { text: "平时保持隐形，仅在 CPU 负载过高时弹出出芽警告，点击可调出任务管理器"; color: Qt.rgba(1, 1, 1, 0.45); font.pixelSize: 9 }
            }
            Switch {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                checked: (typeof Config !== "undefined" && Config.showCpuBubble !== undefined) ? Config.showCpuBubble : true
                onToggled: if (typeof Config !== "undefined") Config.showCpuBubble = checked
            }
        }

        Row {
            width: parent.width; height: 26; spacing: 6
            visible: (typeof Config !== "undefined" && Config.showCpuBubble !== false)

            Text { text: "弹出阈值:"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter }

            Repeater {
                model: [
                    { label: "常驻显示", val: 0 },
                    { label: "50%", val: 50 },
                    { label: "60%", val: 60 },
                    { label: "70%", val: 70 },
                    { label: "80%", val: 80 },
                    { label: "90%", val: 90 }
                ]
                Rectangle {
                    width: 52; height: 22; radius: 11
                    readonly property bool isSel: (typeof Config !== "undefined" && Config.cpuThreshold === modelData.val)
                    color: isSel ? Qt.rgba(52, 211, 153, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: isSel ? "#34d399" : "transparent"; border.width: 1

                    Text {
                        anchors.centerIn: parent; text: modelData.label
                        color: parent.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (typeof Config !== "undefined") Config.cpuThreshold = modelData.val
                    }
                }
            }
        }

        Item { height: 4 }
        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
        Item { height: 4 }

        // =====================================================================
        // 2. 久坐提醒
        // =====================================================================
        Item {
            width: parent.width; height: 30
            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                Text { text: "🧘"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "久坐伏案提醒 (特大打断弹窗)"; color: "white"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
            Switch {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                checked: (typeof Config !== "undefined" && Config.sedentaryReminderEnabled !== undefined) ? Config.sedentaryReminderEnabled : true
                onToggled: if (typeof Config !== "undefined") Config.sedentaryReminderEnabled = checked
            }
        }

        Row {
            width: parent.width; height: 26; spacing: 8
            visible: (typeof Config !== "undefined" && Config.sedentaryReminderEnabled !== false)

            Text { text: "提醒周期:"; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter }

            Repeater {
                model: [30, 45, 60, 90]
                Rectangle {
                    width: 54; height: 24; radius: 12
                    readonly property bool isSel: (typeof Config !== "undefined" && Config.sedentaryIntervalMinutes === modelData)
                    color: isSel ? Qt.rgba(52, 211, 153, 0.28) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: isSel ? "#34d399" : "transparent"; border.width: 1

                    Text {
                        anchors.centerIn: parent; text: modelData + "m"
                        color: parent.isSel ? "white" : Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 10; font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (typeof Config !== "undefined") Config.sedentaryIntervalMinutes = modelData
                    }
                }
            }
        }
    }
}