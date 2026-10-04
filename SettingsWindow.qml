// ==========================================
// 📄 File: SettingsWindow.qml
// ==========================================
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "settings"

Window {
    id: settingsWin
    title: "Alcove Island 偏好设置"
    width: 420
    height: 860
    minimumWidth: 400
    minimumHeight: 600
    color: "#18181b"
    flags: Qt.Dialog | Qt.WindowCloseButtonHint

    Flickable {
        id: mainScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: settingsCol.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: vbar
            width: 4
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                radius: 2
                color: vbar.pressed ? "#818cf8" : Qt.rgba(1, 1, 1, 0.25)
            }
        }

        Column {
            id: settingsCol
            width: parent.width - 40
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            spacing: 14

            Text {
                text: "⚙️ 灵动岛模块与偏好设置"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }

            // 1. 悬浮位置与手势灵敏度
            SettingsPositionCard { width: parent.width }

            // 2. 字体样式与排版选择器
            SettingsFontCard { width: parent.width }

            // 3. 副岛排列、位置顺序与间距
            SettingsSubIslandsCard { width: parent.width }

            // 4. 健康关怀、打字心流与硬件监控
            SettingsHealthCard { width: parent.width }

            // 5. 动效质感、常态项与 Tab 直达开关
            SettingsDisplayCard { width: parent.width }

            Text {
                text: "💡 提示：所有配置点击即刻生效，并在灵动岛顶部自动增减微药丸指示点。"
                color: Qt.rgba(1, 1, 1, 0.45)
                font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Item { height: 12 }
        }
    }
}