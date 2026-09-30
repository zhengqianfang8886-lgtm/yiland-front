import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Window {
    id: settingsWin
    title: "Alcove Island 偏好设置"
    width: 420
    height: 520
    flags: Qt.Window | Qt.WindowStaysOnTopHint
    minimumWidth: 420
    minimumHeight: 500
    maximumWidth: 420
    maximumHeight: 560
    color: "#121215"
    visible: false

    ScrollView {
        anchors.fill: parent
        anchors.margins: 22
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 16

            RowLayout {
                spacing: 8
                Text { text: "⏰"; font.pixelSize: 16 }
                Text { text: "日期与时间偏好"; color: "white"; font.pixelSize: 15; font.bold: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "时间制式"; color: "#e4e4e7"; font.pixelSize: 13; Layout.fillWidth: true }
                ComboBox {
                    model: ["12小时制 (04:53 pm)", "24小时制 (16:53)"]
                    currentIndex: Config.timeFormat === "12h" ? 0 : 1
                    onActivated: Config.timeFormat = (index === 0 ? "12h" : "24h")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "显示走字秒数 (:00)"; color: "#e4e4e7"; font.pixelSize: 13; Layout.fillWidth: true }
                Switch { checked: Config.showSeconds; onToggled: Config.showSeconds = checked }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "显示日期 (周/月/日)"; color: "#e4e4e7"; font.pixelSize: 13; Layout.fillWidth: true }
                Switch { checked: Config.showDate; onToggled: Config.showDate = checked }
            }

            Item { height: 6 }

            RowLayout {
                spacing: 8
                Text { text: "🎨"; font.pixelSize: 16 }
                Text { text: "界面字体与视觉样式"; color: "white"; font.pixelSize: 15; font.bold: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "系统字体 (输入过滤或下拉选择)"; color: "#e4e4e7"; font.pixelSize: 13; Layout.fillWidth: true }
                }

                ComboBox {
                    id: fontSelector
                    Layout.fillWidth: true
                    editable: true
                    model: Config.systemFonts
                    currentIndex: {
                        var idx = Config.systemFonts.indexOf(Config.fontFamily)
                        return (idx >= 0) ? idx : 0
                    }

                    onActivated: (index) => {
                        Config.fontFamily = Config.systemFonts[index]
                    }
                    onAccepted: {
                        Config.fontFamily = editText
                    }

                    delegate: ItemDelegate {
                        width: fontSelector.width
                        contentItem: Text {
                            text: modelData
                            color: "white"
                            font.pixelSize: 13
                            font.family: (modelData.indexOf("系统默认") !== -1) ? "" : modelData
                            elide: Text.ElideRight
                        }
                        highlighted: fontSelector.highlightedIndex === index
                    }
                }

                Text {
                    text: "字体样式预览: 09/30 周三 19:55:28 • Doom Doc"
                    color: "#a1a1aa"
                    font.pixelSize: 11
                    font.family: (Config.fontFamily && Config.fontFamily.indexOf("系统默认") === -1) ? Config.fontFamily : ""
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    topPadding: 2
                }
            }

            Item { height: 6 }

            RowLayout {
                spacing: 8
                Text { text: "📍"; font.pixelSize: 16 }
                Text { text: "物理屏幕定位基准"; color: "white"; font.pixelSize: 15; font.bold: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "顶部吸附基准"; color: "#e4e4e7"; font.pixelSize: 13; Layout.fillWidth: true }
                ComboBox {
                    model: ["物理屏幕最顶部 (绝对像素Y=0)", "可用工作区顶部 (避让顶栏)"]
                    currentIndex: Config.anchorMode === "screen" ? 0 : 1
                    onActivated: Config.anchorMode = (index === 0 ? "screen" : "workarea")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "垂直顶距 (Top Margin)"; color: "#e4e4e7"; font.pixelSize: 13; Layout.fillWidth: true }
                SpinBox {
                    from: 0; to: 50; value: Config.topMargin; editable: true
                    onValueModified: Config.topMargin = value
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "水平微调 (Offset X)"; color: "#e4e4e7"; font.pixelSize: 13; Layout.fillWidth: true }
                SpinBox {
                    from: -200; to: 200; value: Config.offsetX; editable: true
                    onValueModified: Config.offsetX = value
                }
            }

            Item { height: 10 }

            Text {
                text: "💡 提示：更改字体即刻全局生效并自动保存本地。"
                color: "#71717a"
                font.pixelSize: 11
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
