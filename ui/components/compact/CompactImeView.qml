// =========================================================================
// 📄 File: ui/components/compact/CompactImeView.qml
// 🌟 系统原生级输入法组件 (系统级'A'与'朗'双模渲染 · 补全 fontFam 版)
// =========================================================================
import QtQuick
import QtQuick.Controls

Item {
    id: imeRoot
    width: 26
    height: 24

    property string fontFam: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    readonly property bool isActive: (typeof Bridge !== "undefined" && Bridge.isImeActive !== undefined) ? Bridge.isImeActive : false
    readonly property string iconUrl: (typeof Bridge !== "undefined" && Bridge.imeIcon !== undefined) ? Bridge.imeIcon : ""
    readonly property string fallbackLabel: (typeof Bridge !== "undefined" && Bridge.imeLabel !== undefined) ? Bridge.imeLabel : "A"

    readonly property bool isMenuOpen: menuPopup.opened

    Rectangle {
        id: imeBox
        anchors.centerIn: parent
        width: 22
        height: 22
        radius: 5
        antialiasing: true

        // 无论是系统'朗'还是系统'A'，均呈现系统托盘同款微黑底与微光边框
        color: (imeRoot.fallbackLabel === "朗" || imeRoot.fallbackLabel === "A") ? 
               (imeMouse.containsMouse ? "#2a2a34" : "#1a1a24") : 
               (imeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent")

        border.color: (imeRoot.fallbackLabel === "朗" || imeRoot.fallbackLabel === "A") ? 
                      Qt.rgba(255, 255, 255, 0.28) : 
                      (imeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent")
        border.width: 1

        scale: imeMouse.pressed ? 0.90 : 1.0
        Behavior on scale { NumberAnimation { duration: 70 } }
        Behavior on color { ColorAnimation { duration: 100 } }

        // =====================================================================
        // 🚀【系统原生图像流】：100% 渲染系统下发的 'A' 图标或 '朗' 字位图
        // =====================================================================
        Image {
            id: sysImg
            anchors.centerIn: parent
            width: 17
            height: 17
            source: imeRoot.iconUrl
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            cache: false
            visible: imeRoot.iconUrl !== "" && status === Image.Ready
            smooth: true
            mipmap: true
        }

        // 文字兜底：如果系统未发位图，直接呈现等效的 13px 白字 'A' 或 '朗'
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -0.5
            text: imeRoot.fallbackLabel
            color: "#ffffff"
            font.family: imeRoot.fontFam
            font.pixelSize: (imeRoot.fallbackLabel === "A" || imeRoot.fallbackLabel === "朗") ? 13 : 11
            font.weight: Font.Black
            visible: !sysImg.visible
            renderType: Text.QtRendering
        }

        MouseArea {
            id: imeMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            onClicked: (mouse) => handleMouse(mouse)
            onDoubleClicked: (mouse) => handleMouse(mouse)

            function handleMouse(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    menuPopup.close();
                    if (typeof Bridge !== "undefined" && Bridge.toggleIme) {
                        Bridge.toggleIme();
                    }
                } else if (mouse.button === Qt.RightButton) {
                    if (menuPopup.opened) menuPopup.close();
                    else menuPopup.open();
                }
            }
        }
    }

    Popup {
        id: menuPopup
        y: imeRoot.height + 8
        x: Math.round((imeRoot.width - width) / 2)
        width: 178
        padding: 6
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Overlay.modal: Rectangle { color: "transparent" }

        onOpened: {
            if (typeof Bridge !== "undefined" && Bridge.openFullCorridorForMotion) {
                Bridge.openFullCorridorForMotion();
            }
        }

        background: Rectangle {
            color: "#23262e"
            radius: 9
            border.color: Qt.rgba(255, 255, 255, 0.16)
            border.width: 1
        }

        contentItem: Column {
            id: menuCol
            spacing: 2

            Rectangle {
                width: parent.width; height: 26; radius: 5
                color: (!imeRoot.isActive) ? Qt.rgba(255, 255, 255, 0.14) : (enMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                Row {
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    Text { text: "⌘"; color: "white"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "键盘 - 英语 (美国)"; color: "white"; font.pixelSize: 11; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: (!imeRoot.isActive) ? "●" : ""
                    color: "#38bdf8"; font.pixelSize: 8
                }
                MouseArea {
                    id: enMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        menuPopup.close();
                        if (typeof Bridge !== "undefined") Bridge.switchImeTo("keyboard-us");
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 26; radius: 5
                color: (imeRoot.isActive) ? Qt.rgba(255, 255, 255, 0.14) : (rimeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                Row {
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    Text { text: "⊙"; color: "white"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "中州韵"; color: "white"; font.pixelSize: 11; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: (imeRoot.isActive) ? "●" : ""
                    color: "#34d399"; font.pixelSize: 8
                }
                MouseArea {
                    id: rimeMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        menuPopup.close();
                        if (typeof Bridge !== "undefined") Bridge.switchImeTo("rime");
                    }
                }
            }

            Rectangle { width: parent.width - 8; height: 1; color: Qt.rgba(255, 255, 255, 0.08); anchors.horizontalCenter: parent.horizontalCenter }

            Rectangle {
                width: parent.width; height: 26; radius: 5
                color: pinyinMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    Text { text: "🌐"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "朗月拼音·简化字"; color: "white"; font.pixelSize: 11; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 12
                }
                MouseArea { id: pinyinMouse; anchors.fill: parent; hoverEnabled: true }
            }

            Rectangle {
                width: parent.width; height: 24; radius: 5
                color: banjiaoMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 26
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "半角 → 全角"; color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 10; font.weight: Font.DemiBold }
                }
                MouseArea { id: banjiaoMouse; anchors.fill: parent; hoverEnabled: true }
            }

            Rectangle {
                width: parent.width; height: 24; radius: 5
                color: fantiMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 26
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "汉字 → 漢字"; color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 10; font.weight: Font.DemiBold }
                }
                MouseArea { id: fantiMouse; anchors.fill: parent; hoverEnabled: true }
            }

            Rectangle {
                width: parent.width; height: 24; radius: 5
                color: biaodianMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 26
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "。， → ．，"; color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 10; font.weight: Font.DemiBold }
                }
                MouseArea { id: biaodianMouse; anchors.fill: parent; hoverEnabled: true }
            }

            Rectangle { width: parent.width - 8; height: 1; color: Qt.rgba(255, 255, 255, 0.08); anchors.horizontalCenter: parent.horizontalCenter }

            Rectangle {
                width: parent.width; height: 26; radius: 5
                color: cfgMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    Text { text: "⚙"; color: "white"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "配置"; color: "white"; font.pixelSize: 11; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: cfgMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        menuPopup.close();
                        if (typeof Bridge !== "undefined") Bridge.openImeConfig();
                    }
                }
            }
        }
    }
}