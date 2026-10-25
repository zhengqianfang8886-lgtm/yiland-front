// ==========================================
// 📄 File: ui/windows/SettingsWindow.qml
// 🌟 灵动岛全局偏好设置主视窗（完整独立窗口规范导入版）
// ==========================================
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../components/settings"

Window {
    id: settingsWin
    title: "Alcove Island 偏好设置"
    width: 580
    height: 640
    visible: false
    color: "#0f172a"
    flags: Qt.Window | Qt.WindowCloseButtonHint | Qt.WindowTitleHint

    onClosing: {
        settingsWin.visible = false;
    }

    // 快捷关闭支持
    Shortcut {
        sequence: "Escape"
        onActivated: settingsWin.close()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // 1. 窗口头部标题与状态指示
        Item {
            width: parent.width
            height: 38

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.15)
                    border.color: "#38bdf8"; border.width: 1
                    Text { anchors.centerIn: parent; text: "🏝️"; font.pixelSize: 16 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: "Alcove Island 偏好设置"
                        color: "white"
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Text {
                        text: "自适应流体系统级灵动岛 · 配置中心"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 72; height: 26; radius: 13
                color: Qt.rgba(1, 1, 1, 0.08)
                border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1

                Row {
                    anchors.centerIn: parent; spacing: 4
                    Text { text: "✓"; color: "#34d399"; font.pixelSize: 11; font.bold: true }
                    Text { text: "已保存"; color: "white"; font.pixelSize: 11; font.bold: true }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

        // 2. 核心设置可滚动区域
        Flickable {
            id: scrollArea
            width: parent.width
            height: parent.height - 38 - 16 - 16 - 36
            contentWidth: width
            contentHeight: settingsCardsCol.implicitHeight + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                width: 4
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.3) }
            }

            Column {
                id: settingsCardsCol
                width: parent.width - 10
                spacing: 16

                // 2.1 悬浮位置与手势灵敏度
                SettingsPositionCard {
                    width: parent.width
                }

                // 2.2 页面展示顺序与功能开关
                SettingsDisplayCard {
                    width: parent.width
                }

                // 2.3 健康关怀与系统监控
                SettingsHealthCard {
                    width: parent.width
                }

                // 2.4 字体样式调控
                SettingsFontCard {
                    width: parent.width
                }
            }
        }

        // 3. 底部快捷栏
        Item {
            width: parent.width
            height: 32

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "💡 所有设置项均实时生效，修改后无需手动重启程序"
                color: Qt.rgba(1, 1, 1, 0.4)
                font.pixelSize: 11
            }

            Button {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "完成并关闭"
                onClicked: settingsWin.close()
            }
        }
    }
}