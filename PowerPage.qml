import QtQuick
import QtQuick.Controls

Item {
    id: powerRoot
    anchors.fill: parent

    property string chosenFont: ""
    property bool isCompactTrayMode: false
    property bool dropdownOpen: false

    // 二次确认状态机变量
    property bool isConfirming: false
    property string pendingActionName: ""
    property string pendingIpcAction: ""
    property string pendingIcon: ""
    property string pendingWarningText: ""
    property color pendingColor: Theme.danger

    // 🚀 显式声明收缩信号
    signal startCollapse()

    function requestAction(name, ipcCmd, icon, color, warnText) {
        powerRoot.pendingActionName = name
        powerRoot.pendingIpcAction = ipcCmd
        powerRoot.pendingIcon = icon
        powerRoot.pendingColor = color
        powerRoot.pendingWarningText = warnText
        powerRoot.dropdownOpen = false
        powerRoot.isConfirming = true
    }

    function confirmExecute() {
        if (!powerRoot.pendingIpcAction) return
        if (typeof Bridge !== "undefined" && Bridge.executePowerAction) {
            Bridge.executePowerAction(powerRoot.pendingIpcAction)
        }
        powerRoot.isConfirming = false
        powerRoot.startCollapse()
    }

    function cancelAction() {
        powerRoot.isConfirming = false
        powerRoot.pendingActionName = ""
        powerRoot.pendingIpcAction = ""
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => mouse.accepted = true
    }

    Item {
        id: topActionBar
        width: parent.width
        height: 22
        anchors.top: parent.top

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Rectangle {
                width: 6; height: 6; radius: 3
                color: "#22c55e"
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: "SYSTEM POWER & SESSION · 会话管理"
                color: Theme.textMuted
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 0.6
                font.family: powerRoot.chosenFont
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: modeToggleRow.implicitWidth + 12
            height: 20
            radius: 10
            color: modeToggleArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
            border.color: powerRoot.isCompactTrayMode ? Theme.calendar : Theme.borderSubtle
            border.width: 1

            Row {
                id: modeToggleRow
                anchors.centerIn: parent
                spacing: 4
                Text { text: powerRoot.isCompactTrayMode ? "⊞" : "☰"; font.pixelSize: 10; color: Theme.calendar }
                Text {
                    text: powerRoot.isCompactTrayMode ? "平铺矩阵" : "托盘条形态"
                    color: "white"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.family: powerRoot.chosenFont
                }
            }

            MouseArea {
                id: modeToggleArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    powerRoot.isCompactTrayMode = !powerRoot.isCompactTrayMode
                    powerRoot.dropdownOpen = false
                }
            }
        }
    }

    Grid {
        id: bentoGrid
        visible: !powerRoot.isCompactTrayMode
        anchors.top: topActionBar.bottom
        anchors.topMargin: 6
        width: parent.width
        height: parent.height - 28
        columns: 3
        spacing: 7

        // 1. 睡眠
        Rectangle {
            width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
            color: sleepArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem
            border.color: sleepArea.containsMouse ? Qt.rgba(129, 140, 248, 0.6) : Theme.borderSubtle
            border.width: 1
            scale: sleepArea.pressed ? 0.95 : (sleepArea.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 2
                Item {
                    width: parent.width; height: 22
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 6; color: Qt.rgba(129, 140, 248, 0.16)
                        Text { anchors.centerIn: parent; text: "🌙"; font.pixelSize: 12 }
                    }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "SUSPEND"; font.pixelSize: 8; font.weight: Font.Black; color: "#818cf8"; font.letterSpacing: 0.5 }
                }
                Item { height: 2 }
                Text { text: "睡眠"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                Text { text: "深度低功耗待机"; color: Theme.textMuted; font.pixelSize: 9; font.family: powerRoot.chosenFont }
            }

            MouseArea {
                id: sleepArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: powerRoot.requestAction("睡眠", "POWER_SUSPEND", "🌙", "#818cf8", "系统将进入低功耗待机，保留当前会话")
            }
        }

        // 2. 重启
        Rectangle {
            width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
            color: rebootArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem
            border.color: rebootArea.containsMouse ? Qt.rgba(245, 158, 11, 0.6) : Theme.borderSubtle
            border.width: 1
            scale: rebootArea.pressed ? 0.95 : (rebootArea.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 2
                Item {
                    width: parent.width; height: 22
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 6; color: Qt.rgba(245, 158, 11, 0.16)
                        Text { anchors.centerIn: parent; text: "⟳"; font.pixelSize: 14; font.weight: Font.Black; color: "#f59e0b" }
                    }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "REBOOT"; font.pixelSize: 8; font.weight: Font.Black; color: "#f59e0b"; font.letterSpacing: 0.5 }
                }
                Item { height: 2 }
                Text { text: "重启"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                Text { text: "重新引导系统"; color: Theme.textMuted; font.pixelSize: 9; font.family: powerRoot.chosenFont }
            }

            MouseArea {
                id: rebootArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: powerRoot.requestAction("重启", "POWER_REBOOT", "⟳", "#f59e0b", "所有正在运行的程序将被关闭并重启计算机")
            }
        }

        // 3. 关机
        Rectangle {
            width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
            color: shutdownArea.containsMouse ? Qt.rgba(239, 68, 68, 0.18) : Theme.bgCardItem
            border.color: shutdownArea.containsMouse ? Qt.rgba(239, 68, 68, 0.75) : Theme.borderSubtle
            border.width: 1
            scale: shutdownArea.pressed ? 0.95 : (shutdownArea.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 2
                Item {
                    width: parent.width; height: 22
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 6; color: Qt.rgba(239, 68, 68, 0.2)
                        Text { anchors.centerIn: parent; text: "⏻"; font.pixelSize: 13; font.weight: Font.Black; color: "#ef4444" }
                    }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "POWER OFF"; font.pixelSize: 8; font.weight: Font.Black; color: "#ef4444"; font.letterSpacing: 0.5 }
                }
                Item { height: 2 }
                Text { text: "关机"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                Text { text: "安全切断电源"; color: Theme.textMuted; font.pixelSize: 9; font.family: powerRoot.chosenFont }
            }

            MouseArea {
                id: shutdownArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: powerRoot.requestAction("关机", "POWER_OFF", "⏻", "#ef4444", "未保存的内容将会丢失，计算机将切断电源")
            }
        }

        // 4. 锁定屏幕
        Rectangle {
            width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
            color: lockArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem
            border.color: lockArea.containsMouse ? Qt.rgba(56, 189, 248, 0.6) : Theme.borderSubtle
            border.width: 1
            scale: lockArea.pressed ? 0.95 : (lockArea.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 2
                Item {
                    width: parent.width; height: 22
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 6; color: Qt.rgba(56, 189, 248, 0.16)
                        Text { anchors.centerIn: parent; text: "🔒"; font.pixelSize: 12 }
                    }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "LOCK"; font.pixelSize: 8; font.weight: Font.Black; color: "#38bdf8"; font.letterSpacing: 0.5 }
                }
                Item { height: 2 }
                Text { text: "锁定屏幕"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                Text { text: "保留后台任务运行"; color: Theme.textMuted; font.pixelSize: 9; font.family: powerRoot.chosenFont }
            }

            MouseArea {
                id: lockArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: powerRoot.requestAction("锁定屏幕", "SESSION_LOCK", "🔒", "#38bdf8", "当前会话与后台程序保持运行，解锁需输入密码")
            }
        }

        // 5. 注销会话
        Rectangle {
            width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
            color: logoutArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem
            border.color: logoutArea.containsMouse ? Qt.rgba(244, 63, 94, 0.6) : Theme.borderSubtle
            border.width: 1
            scale: logoutArea.pressed ? 0.95 : (logoutArea.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 2
                Item {
                    width: parent.width; height: 22
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 6; color: Qt.rgba(244, 63, 94, 0.16)
                        Text { anchors.centerIn: parent; text: "⎋"; font.pixelSize: 14; font.weight: Font.Black; color: "#f43f5e" }
                    }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "LOGOUT"; font.pixelSize: 8; font.weight: Font.Black; color: "#f43f5e"; font.letterSpacing: 0.5 }
                }
                Item { height: 2 }
                Text { text: "注销会话"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                Text { text: "退出当前账户登录"; color: Theme.textMuted; font.pixelSize: 9; font.family: powerRoot.chosenFont }
            }

            MouseArea {
                id: logoutArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: powerRoot.requestAction("注销会话", "SESSION_LOGOUT", "⎋", "#f43f5e", "将退出当前用户登录并关闭所有运行中的窗口")
            }
        }

        // 6. 切换用户
        Rectangle {
            width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
            color: switchUserArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem
            border.color: switchUserArea.containsMouse ? Qt.rgba(52, 211, 153, 0.6) : Theme.borderSubtle
            border.width: 1
            scale: switchUserArea.pressed ? 0.95 : (switchUserArea.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 2
                Item {
                    width: parent.width; height: 22
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 6; color: Qt.rgba(52, 211, 153, 0.16)
                        Text { anchors.centerIn: parent; text: "⇄"; font.pixelSize: 14; font.weight: Font.Black; color: "#34d399" }
                    }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "SWITCH"; font.pixelSize: 8; font.weight: Font.Black; color: "#34d399"; font.letterSpacing: 0.5 }
                }
                Item { height: 2 }
                Text { text: "切换用户"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                Text { text: "保留会话在后台运行"; color: Theme.textMuted; font.pixelSize: 9; font.family: powerRoot.chosenFont }
            }

            MouseArea {
                id: switchUserArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: powerRoot.requestAction("切换用户", "SESSION_SWITCH_USER", "⇄", "#34d399", "当前用户会话将保持锁定并挂起在后台")
            }
        }
    }

    Item {
        id: trayBarModeContainer
        visible: powerRoot.isCompactTrayMode
        anchors.top: topActionBar.bottom
        anchors.topMargin: 18
        width: parent.width
        height: parent.height - 38

        Rectangle {
            id: mainTrayPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: 330
            height: 42
            radius: 12
            color: "#1f1f23"
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 6
                spacing: 6

                Rectangle {
                    width: 74; height: 30; radius: 8; anchors.verticalCenter: parent.verticalCenter
                    color: tSleepArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Text { text: "🌙"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "睡眠"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold; font.family: powerRoot.chosenFont; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: tSleepArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: powerRoot.requestAction("睡眠", "POWER_SUSPEND", "🌙", "#818cf8", "系统将进入低功耗待机，保留当前会话")
                    }
                }

                Rectangle {
                    width: 74; height: 30; radius: 8; anchors.verticalCenter: parent.verticalCenter
                    color: tRebootArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Text { text: "⟳"; font.pixelSize: 13; font.weight: Font.Black; color: "#f59e0b"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "重启"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold; font.family: powerRoot.chosenFont; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: tRebootArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: powerRoot.requestAction("重启", "POWER_REBOOT", "⟳", "#f59e0b", "所有正在运行的程序将被关闭并重启计算机")
                    }
                }

                Rectangle {
                    width: 74; height: 30; radius: 8; anchors.verticalCenter: parent.verticalCenter
                    color: tShutdownArea.containsMouse ? Qt.rgba(239, 68, 68, 0.2) : "transparent"
                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Text { text: "⏻"; font.pixelSize: 13; font.weight: Font.Black; color: "#ef4444"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "关机"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold; font.family: powerRoot.chosenFont; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: tShutdownArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: powerRoot.requestAction("关机", "POWER_OFF", "⏻", "#ef4444", "未保存的内容将会丢失，计算机将切断电源")
                    }
                }

                Item { width: 4 }

                Rectangle {
                    width: 32; height: 30; radius: 8; anchors.verticalCenter: parent.verticalCenter
                    color: powerRoot.dropdownOpen ? "#2563eb" : (tMenuArea.containsMouse ? "#3b82f6" : "#2563eb")
                    scale: tMenuArea.pressed ? 0.94 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: powerRoot.dropdownOpen ? "▾" : "‹"
                        font.pixelSize: 16
                        font.weight: Font.Black
                        color: "white"
                    }

                    MouseArea {
                        id: tMenuArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: powerRoot.dropdownOpen = !powerRoot.dropdownOpen
                    }
                }
            }
        }

        Rectangle {
            id: popupMenu
            anchors.top: mainTrayPill.bottom
            anchors.topMargin: 6
            anchors.right: mainTrayPill.right
            width: 128
            height: powerRoot.dropdownOpen ? 104 : 0
            radius: 10
            color: "#242428"
            border.color: Qt.rgba(1, 1, 1, 0.15)
            border.width: 1
            clip: true
            opacity: powerRoot.dropdownOpen ? 1.0 : 0.0
            visible: opacity > 0.01
            z: 99

            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Column {
                anchors.fill: parent; anchors.margins: 4; spacing: 2

                Rectangle {
                    width: parent.width; height: 30; radius: 6
                    color: pLockArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        Text { text: "🔒"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "锁定"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold; font.family: powerRoot.chosenFont; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: pLockArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: powerRoot.requestAction("锁定屏幕", "SESSION_LOCK", "🔒", "#38bdf8", "当前会话与后台程序保持运行，解锁需输入密码")
                    }
                }

                Rectangle {
                    width: parent.width; height: 30; radius: 6
                    color: pLogoutArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        Text { text: "⎋"; font.pixelSize: 12; font.weight: Font.Black; color: "#f43f5e"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "注销"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold; font.family: powerRoot.chosenFont; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: pLogoutArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: powerRoot.requestAction("注销会话", "SESSION_LOGOUT", "⎋", "#f43f5e", "将退出当前用户登录并关闭所有运行中的窗口")
                    }
                }

                Rectangle {
                    width: parent.width; height: 30; radius: 6
                    color: pSwitchArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        Text { text: "⇄"; font.pixelSize: 12; font.weight: Font.Black; color: "#34d399"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "切换用户"; color: "white"; font.pixelSize: 12; font.weight: Font.Bold; font.family: powerRoot.chosenFont; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: pSwitchArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: powerRoot.requestAction("切换用户", "SESSION_SWITCH_USER", "⇄", "#34d399", "当前用户会话将保持锁定并挂起在后台")
                    }
                }
            }
        }
    }

    // =========================================================================
    // 全局二步确认模态弹层
    // =========================================================================
    Rectangle {
        id: confirmOverlay
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(18 / 255, 18 / 255, 22 / 255, 0.94)
        border.color: powerRoot.isConfirming ? powerRoot.pendingColor : "transparent"
        border.width: 1.5
        visible: powerRoot.isConfirming
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.92
        z: 200

        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }

        Column {
            anchors.centerIn: parent
            width: parent.width - 40
            spacing: 10

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Rectangle {
                    width: 32; height: 32; radius: 16
                    color: Qt.rgba(powerRoot.pendingColor.r, powerRoot.pendingColor.g, powerRoot.pendingColor.b, 0.22)
                    border.color: powerRoot.pendingColor
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: powerRoot.pendingIcon
                        font.pixelSize: 16
                        font.weight: Font.Black
                        color: powerRoot.pendingColor
                    }
                }

                Text {
                    text: "确定要执行 [ " + powerRoot.pendingActionName + " ] 吗？"
                    color: "white"
                    font.family: powerRoot.chosenFont
                    font.pixelSize: 15
                    font.weight: Font.Black
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                text: powerRoot.pendingWarningText
                color: Qt.rgba(1, 1, 1, 0.75)
                font.family: powerRoot.chosenFont
                font.pixelSize: 11
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width
            }

            Item { height: 4 }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Rectangle {
                    width: 100; height: 32; radius: 16
                    color: cancelMouse.pressed ? Qt.rgba(1, 1, 1, 0.22) : (cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
                    border.color: Theme.borderSubtle; border.width: 1
                    scale: cancelMouse.pressed ? 0.94 : 1.0

                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "✕"; color: Theme.textMuted; font.pixelSize: 11; font.weight: Font.Black }
                        Text { text: "取消"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: powerRoot.chosenFont }
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: powerRoot.cancelAction()
                    }
                }

                Rectangle {
                    width: 140; height: 32; radius: 16
                    color: confirmMouse.pressed ? Qt.darker(powerRoot.pendingColor, 1.25) : (confirmMouse.containsMouse ? Qt.lighter(powerRoot.pendingColor, 1.1) : powerRoot.pendingColor)
                    scale: confirmMouse.pressed ? 0.94 : (confirmMouse.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Row {
                        anchors.centerIn: parent; spacing: 6
                        Text { text: "✓"; color: "white"; font.pixelSize: 12; font.weight: Font.Black }
                        Text { text: "确认 " + powerRoot.pendingActionName; color: "white"; font.pixelSize: 12; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                    }

                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: powerRoot.confirmExecute()
                    }
                }
            }
        }
    }
}