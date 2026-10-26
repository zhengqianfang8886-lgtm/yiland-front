// ==========================================
// 📄 File: ui/windows/SettingsWindow.qml
// 🌟 纯正独立桌面窗口 (原生系统级拖拽 · 居中弹出 · 自由移动版)
// ==========================================
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../components/settings"

Window {
    id: settingsWin
    title: "Alcove Island 偏好设置"
    width: 720
    height: 540
    visible: false
    color: "transparent" // 外层透明以实现圆角阴影效果

    // 🚀 声明为独立无边框顶层窗口
    flags: Qt.Window | Qt.FramelessWindowHint

    property int currentCategoryIndex: 0
    property var healthData: ({})

    // 窗口居中弹出逻辑
    function openCentered() {
        if (Screen.width > 0 && Screen.height > 0) {
            settingsWin.x = Math.round((Screen.width - settingsWin.width) / 2);
            settingsWin.y = Math.round((Screen.height - settingsWin.height) / 2);
        }
        settingsWin.show();
        settingsWin.raise();
        settingsWin.requestActivate();
        refreshHealth();
    }

    function refreshHealth() {
        if (typeof Bridge !== "undefined" && Bridge.getSystemHealth) {
            healthData = Bridge.getSystemHealth();
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: settingsWin.close()
    }

    // 🚀【主体窗口容器】：带有高级毛玻璃与精致深色圆角边框
    Rectangle {
        id: windowFrame
        anchors.fill: parent
        anchors.margins: 6 // 留出微弱呼吸边
        radius: 14
        color: "#0f111a"
        border.color: Qt.rgba(255, 255, 255, 0.12)
        border.width: 1
        clip: true

        Row {
            anchors.fill: parent

            // =================================================================
            // 1. 左侧功能导航栏 (顶部带有拖拽手柄区域)
            // =================================================================
            Rectangle {
                width: 200
                height: parent.height
                color: "#141724"
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                // 🚀【拖拽区域 A：左侧顶栏手柄】
                MouseArea {
                    id: leftDragArea
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 52
                    cursorShape: Qt.ArrowCursor

                    property point clickPos: "0,0"

                    onPressed: (mouse) => {
                        leftDragArea.clickPos = Qt.point(mouse.x, mouse.y);
                        // 优先尝试 Wayland 原生系统拖拽协议
                        if (typeof settingsWin.startSystemMove === "function") {
                            settingsWin.startSystemMove();
                        }
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed && typeof settingsWin.startSystemMove !== "function") {
                            var delta = Qt.point(mouse.x - clickPos.x, mouse.y - clickPos.y);
                            settingsWin.x += delta.x;
                            settingsWin.y += delta.y;
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // 窗口控制三色圆点 (Mac/Linux 高级质感)
                    Row {
                        spacing: 7
                        Rectangle {
                            width: 12; height: 12; radius: 6; color: "#ef4444"
                            HoverHandler { id: closeH; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: settingsWin.close() }
                            Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 8; color: "#500"; visible: closeH.hovered }
                        }
                        Rectangle {
                            width: 12; height: 12; radius: 6; color: "#f59e0b"
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: settingsWin.showMinimized() }
                        }
                        Rectangle {
                            width: 12; height: 12; radius: 6; color: Qt.rgba(255, 255, 255, 0.15)
                        }
                    }

                    // 品牌标识
                    Row {
                        spacing: 8
                        Rectangle {
                            width: 26; height: 26; radius: 6
                            color: Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.18)
                            border.color: "#38bdf8"; border.width: 1
                            Text { anchors.centerIn: parent; text: "🏝️"; font.pixelSize: 13 }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "Alcove Island"; color: "white"; font.pixelSize: 12; font.bold: true }
                            Text { text: "独立偏好设置中心"; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 9 }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    // 导航选项卡列表
                    Column {
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: [
                                { name: "物理几何与高度", icon: "📐" },
                                { name: "显示与页面调控", icon: "📑" },
                                { name: "健康关怀与监控", icon: "🌿" },
                                { name: "排版与字体样式", icon: "🔤" },
                                { name: "底层驱动健康度", icon: "🩺" }
                            ]

                            Rectangle {
                                width: parent.width
                                height: 34
                                radius: 8
                                readonly property bool isCurrent: settingsWin.currentCategoryIndex === index
                                color: isCurrent ? Qt.rgba(56 / 255, 189 / 255, 248 / 255, 0.20) : (navHover.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                border.color: isCurrent ? "#38bdf8" : "transparent"
                                border.width: 1

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Text { text: modelData.icon; font.pixelSize: 12 }
                                    Text {
                                        text: modelData.name
                                        color: parent.parent.isCurrent ? "white" : Qt.rgba(1, 1, 1, 0.65)
                                        font.pixelSize: 11
                                        font.bold: parent.parent.isCurrent
                                    }
                                }

                                HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: settingsWin.currentCategoryIndex = index }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // 2. 右侧配置区 (顶部自带全宽拖拽标题栏)
            // =================================================================
            Item {
                width: parent.width - 200
                height: parent.height

                // 🚀【拖拽区域 B：右侧全宽顶栏拖拽手柄】
                MouseArea {
                    id: topDragArea
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 44
                    cursorShape: Qt.ArrowCursor

                    property point clickPos: "0,0"

                    onPressed: (mouse) => {
                        topDragArea.clickPos = Qt.point(mouse.x, mouse.y);
                        if (typeof settingsWin.startSystemMove === "function") {
                            settingsWin.startSystemMove();
                        }
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed && typeof settingsWin.startSystemMove !== "function") {
                            var delta = Qt.point(mouse.x - clickPos.x, mouse.y - clickPos.y);
                            settingsWin.x += delta.x;
                            settingsWin.y += delta.y;
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            text: "拖拽移动窗口"
                            color: Qt.rgba(1, 1, 1, 0.25)
                            font.pixelSize: 10
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24
                        width: doneRow.implicitWidth + 14
                        radius: 12
                        color: doneTap.pressed ? Qt.rgba(1, 1, 1, 0.22) : (doneH.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1

                        Row {
                            id: doneRow
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "✓"; color: "#34d399"; font.pixelSize: 10; font.bold: true }
                            Text { text: "完成"; color: "white"; font.pixelSize: 10; font.bold: true }
                        }

                        HoverHandler { id: doneH; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: doneTap; onTapped: settingsWin.close() }
                    }
                }

                // 核心内容展示区
                Flickable {
                    id: contentFlickable
                    anchors.top: topDragArea.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 14
                    anchors.topMargin: 0
                    contentWidth: width
                    contentHeight: contentStack.implicitHeight + 20
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        width: 4
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.25) }
                    }

                    Item {
                        id: contentStack
                        width: parent.width - 8
                        implicitHeight: {
                            switch(settingsWin.currentCategoryIndex) {
                                case 0: return posCard.height;
                                case 1: return dispCard.height;
                                case 2: return healthCard.height;
                                case 3: return fontCard.height;
                                case 4: return diagCol.implicitHeight;
                                default: return 300;
                            }
                        }

                        // 0: 几何高度
                        SettingsPositionCard {
                            id: posCard
                            width: parent.width
                            visible: settingsWin.currentCategoryIndex === 0
                        }

                        // 1: 显示与顺序
                        SettingsDisplayCard {
                            id: dispCard
                            width: parent.width
                            visible: settingsWin.currentCategoryIndex === 1
                        }

                        // 2: 健康与监控
                        SettingsHealthCard {
                            id: healthCard
                            width: parent.width
                            visible: settingsWin.currentCategoryIndex === 2
                        }

                        // 3: 字体样式
                        SettingsFontCard {
                            id: fontCard
                            width: parent.width
                            visible: settingsWin.currentCategoryIndex === 3
                        }

                        // 4: 底层驱动健康度检测探针
                        Column {
                            id: diagCol
                            width: parent.width
                            spacing: 12
                            visible: settingsWin.currentCategoryIndex === 4

                            Rectangle {
                                width: parent.width
                                height: 48
                                radius: 10
                                color: Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.12)
                                border.color: "#34d399"; border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text { text: "🛡️"; font.pixelSize: 15 }
                                    Text {
                                        text: "运行环境: " + (settingsWin.healthData.platform || "检测中...")
                                        color: "#34d399"; font.pixelSize: 12; font.bold: true
                                    }
                                }
                            }

                            Repeater {
                                model: [
                                    { name: "KWin 窗口合成器协议", status: settingsWin.healthData.kwinWorking, tip: "用于实现置顶常驻与跨桌面锁定" },
                                    { name: "PulseAudio / PipeWire 音频中枢", status: settingsWin.healthData.audioWorking, tip: "用于硬件音量监听与双长连接控制" },
                                    { name: "Solid 硬件背光亮度通道", status: settingsWin.healthData.brightnessWorking, tip: "用于 D-Bus 原生屏幕亮度调控" },
                                    { name: "CAVA 硬件音频声谱驱动", status: settingsWin.healthData.cavaInstalled, tip: "用于生成动态音乐律动条" },
                                    { name: "wl-paste 独立剪贴板看门狗", status: settingsWin.healthData.wlPasteInstalled, tip: "用于零焦点隐私剪贴板嗅探" },
                                    { name: "SQLite 习惯日程存储引擎", status: settingsWin.healthData.dbConnected, tip: "用于本地 WAL 事务日程日志写入" }
                                ]

                                Rectangle {
                                    width: parent.width
                                    height: 44
                                    radius: 8
                                    color: Qt.rgba(1, 1, 1, 0.04)
                                    border.color: modelData.status ? Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.3) : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.3)
                                    border.width: 1

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8

                                        Rectangle {
                                            width: 8; height: 8; radius: 4
                                            color: modelData.status ? "#34d399" : "#ef4444"
                                        }

                                        Column {
                                            Text { text: modelData.name; color: "white"; font.pixelSize: 11; font.bold: true }
                                            Text { text: modelData.tip; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 9 }
                                        }
                                    }

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 20
                                        width: statusText.implicitWidth + 12
                                        radius: 10
                                        color: modelData.status ? Qt.rgba(52 / 255, 211 / 255, 153 / 255, 0.2) : Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.2)

                                        Text {
                                            id: statusText
                                            anchors.centerIn: parent
                                            text: modelData.status ? "正常就绪" : "未挂载/缺失"
                                            color: modelData.status ? "#34d399" : "#ef4444"
                                            font.pixelSize: 9; font.bold: true
                                        }
                                    }
                                }
                            }

                            Button {
                                text: "重新测试驱动连接"
                                anchors.horizontalCenter: parent.horizontalCenter
                                onClicked: settingsWin.refreshHealth()
                            }
                        }
                    }
                }
            }
        }
    }
}