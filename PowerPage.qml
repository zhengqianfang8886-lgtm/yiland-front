import QtQuick
import QtQuick.Controls

Item {
    id: powerRoot
    anchors.fill: parent

    property string chosenFont: ""
    property string activeActionName: ""
    property color activeActionColor: Theme.calendar
    property bool isCompactTrayMode: false
    property bool dropdownOpen: false

    Timer {
        id: resetFeedbackTimer
        interval: 2400
        onTriggered: powerRoot.activeActionName = ""
    }

    function triggerAction(actionName, actionColor) {
        powerRoot.activeActionName = actionName
        powerRoot.activeActionColor = actionColor
        resetFeedbackTimer.restart()
    }

    // 🚀 防御层：拦截电源页背景空白处的未捕获点击，杜绝事件向底层冒泡
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => mouse.accepted = true
    }

    // =========================================================================
    // 1. 顶栏非侵入式状态反馈（0 遮挡，平滑融合）
    // =========================================================================
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
                color: powerRoot.activeActionName !== "" ? powerRoot.activeActionColor : "#22c55e"
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }

                SequentialAnimation on scale {
                    running: powerRoot.activeActionName !== ""
                    NumberAnimation { to: 1.4; duration: 150; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 1.0; duration: 200; easing.type: Easing.OutBack }
                }
            }

            Text {
                text: powerRoot.activeActionName !== "" ?
                      ("⚡ [ " + powerRoot.activeActionName + " ] 指令触发 · 前端交互已就绪") :
                      "SYSTEM POWER & SESSION · 会话管理"
                color: powerRoot.activeActionName !== "" ? powerRoot.activeActionColor : Theme.textMuted
                font.pixelSize: 10
                font.weight: powerRoot.activeActionName !== "" ? Font.Black : Font.Bold
                font.letterSpacing: 0.6
                font.family: powerRoot.chosenFont
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        // 切换形态按键
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

    // =========================================================================
    // 2. 形态一：Bento 豪华全功能矩阵视图（零遮挡，全视野通透）
    // =========================================================================
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
            id: sleepCard
            readonly property bool isHit: powerRoot.activeActionName === "睡眠"
            width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
            color: isHit ? Qt.rgba(129, 140, 248, 0.2) : (sleepArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem)
            border.color: isHit ? "#818cf8" : (sleepArea.containsMouse ? Qt.rgba(129, 140, 248, 0.6) : Theme.borderSubtle)
            border.width: isHit ? 1.5 : 1
            scale: sleepArea.pressed ? 0.95 : (sleepArea.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
            Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 2

                Item {
                    width: parent.width; height: 22
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 6; color: Qt.rgba(129, 140, 248, 0.16)
                        Text { anchors.centerIn: parent; text: "🌙"; font.pixelSize: 12 }
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "SUSPEND"; font.pixelSize: 8; font.weight: Font.Black; color: "#818cf8"; font.letterSpacing: 0.5
                    }
                }

                Item { height: 2 }
                Text { text: "睡眠"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                Text {
                    text: sleepCard.isHit ? "✓ 指令已就绪" : "深度低功耗待机"
                    color: sleepCard.isHit ? "#818cf8" : Theme.textMuted
                    font.pixelSize: 9; font.weight: sleepCard.isHit ? Font.Bold : Font.Normal; font.family: powerRoot.chosenFont
                }
            }

            MouseArea {
                id: sleepArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: powerRoot.triggerAction("睡眠", "#818cf8")
            }
        }

        // 2. 重启
        Rectangle {
            id: rebootCard
            readonly property bool isHit: powerRoot.activeActionName === "重启"
            width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
            color: isHit ? Qt.rgba(245, 158, 11, 0.2) : (rebootArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem)
            border.color: isHit ? "#f59e0b" : (rebootArea.containsMouse ? Qt.rgba(245, 158, 11, 0.6) : Theme.borderSubtle)
            border.width: isHit ? 1.5 : 1
            scale: rebootArea.pressed ? 0.95 : (rebootArea.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
            Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 2

                Item {
                    width: parent.width; height: 22
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 6; color: Qt.rgba(245, 158, 11, 0.16)
                        Text {
                            id: rebootIcon
                            anchors.centerIn: parent; text: "⟳"; font.pixelSize: 14; font.weight: Font.Black; color: "#f59e0b"
                            RotationAnimator on rotation {
                                running: rebootArea.containsMouse || rebootCard.isHit
                                loops: Animation.Infinite; from: 0; to: 360; duration: 800
                            }
                        }
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "REBOOT"; font.pixelSize: 8; font.weight: Font.Black; color: "#f59e0b"; font.letterSpacing: 0.5
                    }
                }

                Item { height: 2 }
                Text { text: "重启"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                Text {
                    text: rebootCard.isHit ? "✓ 指令已就绪" : "重新引导系统"
                    color: rebootCard.isHit ? "#f59e0b" : Theme.textMuted
                    font.pixelSize: 9; font.weight: rebootCard.isHit ? Font.Bold : Font.Normal; font.family: powerRoot.chosenFont
                }
            }

            MouseArea {
                id: rebootArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: powerRoot.triggerAction("重启", "#f59e0b")
            }
        }

        // 3. 关机
        Rectangle {
            id: shutdownCard
            readonly property bool isHit: powerRoot.activeActionName === "关机"
            width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
            color: isHit ? Qt.rgba(239, 68, 68, 0.25) : (shutdownArea.containsMouse ? Qt.rgba(239, 68, 68, 0.12) : Theme.bgCardItem)
            border.color: isHit ? "#ef4444" : (shutdownArea.containsMouse ? Qt.rgba(239, 68, 68, 0.75) : Theme.borderSubtle)
            border.width: isHit ? 1.5 : 1
            scale: shutdownArea.pressed ? 0.95 : (shutdownArea.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
            Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 2

                Item {
                    width: parent.width; height: 22
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 6; color: Qt.rgba(239, 68, 68, 0.2)
                        Text { anchors.centerIn: parent; text: "⏻"; font.pixelSize: 13; font.weight: Font.Black; color: "#ef4444" }
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "POWER OFF"; font.pixelSize: 8; font.weight: Font.Black; color: "#ef4444"; font.letterSpacing: 0.5
                    }
                }

                Item { height: 2 }
                Text { text: "关机"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                Text {
                    text: shutdownCard.isHit ? "✓ 指令已就绪" : "安全切断电源"
                    color: shutdownCard.isHit ? "#ef4444" : Theme.textMuted
                    font.pixelSize: 9; font.weight: shutdownCard.isHit ? Font.Bold : Font.Normal; font.family: powerRoot.chosenFont
                }
            }

            MouseArea {
                id: shutdownArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: powerRoot.triggerAction("关机", "#ef4444")
            }
        }

        // 4. 锁定
        Rectangle {
            id: lockCard
            readonly property bool isHit: powerRoot.activeActionName === "锁定屏幕"
            width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
            color: isHit ? Qt.rgba(56, 189, 248, 0.2) : (lockArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem)
            border.color: isHit ? "#38bdf8" : (lockArea.containsMouse ? Qt.rgba(56, 189, 248, 0.6) : Theme.borderSubtle)
            border.width: isHit ? 1.5 : 1
            scale: lockArea.pressed ? 0.95 : (lockArea.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
            Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 2

                Item {
                    width: parent.width; height: 22
                    Rectangle {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 6; color: Qt.rgba(56, 189, 248, 0.16)
                        Text { anchors.centerIn: parent; text: "🔒"; font.pixelSize: 12 }
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "LOCK"; font.pixelSize: 8; font.weight: Font.Black; color: "#38bdf8"; font.letterSpacing: 0.5
                    }
                }

                Item { height: 2 }
                Text { text: "锁定屏幕"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                Text {
                    text: lockCard.isHit ? "✓ 指令已就绪" : "快捷键 Win+L"
                    color: lockCard.isHit ? "#38bdf8" : Theme.textMuted
                    font.pixelSize: 9; font.weight: lockCard.isHit ? Font.Bold : Font.Normal; font.family: powerRoot.chosenFont
                }
            }

            MouseArea {
                id: lockArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: powerRoot.triggerAction("锁定屏幕", "#38bdf8")
            }
        }

        // 5. 注销
        Rectangle {
            id: logoutCard
            readonly property bool isHit: powerRoot.activeActionName === "注销会话"
            width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
            color: isHit ? Qt.rgba(244, 63, 94, 0.2) : (logoutArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem)
            border.color: isHit ? "#f43f5e" : (logoutArea.containsMouse ? Qt.rgba(244, 63, 94, 0.6) : Theme.borderSubtle)
            border.width: isHit ? 1.5 : 1
            scale: logoutArea.pressed ? 0.95 : (logoutArea.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
            Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 2

                Item {
                    width: parent.width; height: 22
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 6; color: Qt.rgba(244, 63, 94, 0.16)
                        Text { anchors.centerIn: parent; text: "⎋"; font.pixelSize: 14; font.weight: Font.Black; color: "#f43f5e" }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "LOGOUT"; font.pixelSize: 8; font.weight: Font.Black; color: "#f43f5e"; font.letterSpacing: 0.5
                    }
                }

                Item { height: 2 }
                Text { text: "注销会话"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                Text {
                    text: logoutCard.isHit ? "✓ 指令已就绪" : "退出当前账户"
                    color: logoutCard.isHit ? "#f43f5e" : Theme.textMuted
                    font.pixelSize: 9; font.weight: logoutCard.isHit ? Font.Bold : Font.Normal; font.family: powerRoot.chosenFont
                }
            }

            MouseArea {
                id: logoutArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: powerRoot.triggerAction("注销会话", "#f43f5e")
            }
        }

        // 6. 切换用户
        Rectangle {
            id: switchUserCard
            readonly property bool isHit: powerRoot.activeActionName === "切换用户"
            width: (bentoGrid.width - 14) / 3; height: (bentoGrid.height - 7) / 2; radius: 10
            color: isHit ? Qt.rgba(52, 211, 153, 0.2) : (switchUserArea.containsMouse ? Theme.bgCardHover : Theme.bgCardItem)
            border.color: isHit ? "#34d399" : (switchUserArea.containsMouse ? Qt.rgba(52, 211, 153, 0.6) : Theme.borderSubtle)
            border.width: isHit ? 1.5 : 1
            scale: switchUserArea.pressed ? 0.95 : (switchUserArea.containsMouse ? 1.015 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }
            Behavior on color { ColorAnimation { duration: Theme.animInstant } }
            Behavior on border.color { ColorAnimation { duration: Theme.animInstant } }

            Column {
                anchors.fill: parent; anchors.margins: 8; spacing: 2

                Item {
                    width: parent.width; height: 22
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 6; color: Qt.rgba(52, 211, 153, 0.16)
                        Text { anchors.centerIn: parent; text: "⇄"; font.pixelSize: 14; font.weight: Font.Black; color: "#34d399" }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SWITCH"; font.pixelSize: 8; font.weight: Font.Black; color: "#34d399"; font.letterSpacing: 0.5
                    }
                }

                Item { height: 2 }
                Text { text: "切换用户"; color: "white"; font.pixelSize: 13; font.weight: Font.Black; font.family: powerRoot.chosenFont }
                Text {
                    text: switchUserCard.isHit ? "✓ 指令已就绪" : "保留后台任务"
                    color: switchUserCard.isHit ? "#34d399" : Theme.textMuted
                    font.pixelSize: 9; font.weight: switchUserCard.isHit ? Font.Bold : Font.Normal; font.family: powerRoot.chosenFont
                }
            }

            MouseArea {
                id: switchUserArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: powerRoot.triggerAction("切换用户", "#34d399")
            }
        }
    }

    // =========================================================================
    // 3. 形态二：水平托盘栏 + 下拉菜单模式
    // =========================================================================
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
                        onClicked: powerRoot.triggerAction("睡眠", "#818cf8")
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
                        onClicked: powerRoot.triggerAction("重启", "#f59e0b")
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
                        onClicked: powerRoot.triggerAction("关机", "#ef4444")
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

        // 下拉菜单
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
                        onClicked: { powerRoot.triggerAction("锁定屏幕", "#38bdf8"); powerRoot.dropdownOpen = false }
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
                        onClicked: { powerRoot.triggerAction("注销会话", "#f43f5e"); powerRoot.dropdownOpen = false }
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
                        onClicked: { powerRoot.triggerAction("切换用户", "#34d399"); powerRoot.dropdownOpen = false }
                    }
                }
            }
        }
    }
}