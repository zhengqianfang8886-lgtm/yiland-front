// ==========================================
// 📄 File: process/ProcessModal.qml
// ==========================================
import QtQuick

Rectangle {
    id: modalRoot
    anchors.fill: parent
    radius: Theme.radiusCard
    color: Qt.rgba(16 / 255, 16 / 255, 22 / 255, 0.98)
    border.color: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.35)
    border.width: 1
    visible: modalRoot.isOpen
    z: 100

    property string effectiveFont: ""
    property string effectiveMono: ""

    property bool isOpen: false
    property string editId: ""
    property string editStatus: "stopped"

    signal saveRequested(string id, string name, string cwd, string cmd)
    signal deleteRequested(string id)

    // 屏蔽下层事件
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: (mouse) => mouse.accepted = true }

    Timer {
        id: focusTimer; interval: 60; repeat: false
        onTriggered: { nameInput.forceActiveFocus(); nameInput.selectAll() }
    }

    function openAdd() {
        modalRoot.editId = ""
        modalRoot.editStatus = "stopped"
        nameInput.text = ""
        cwdInput.text = "~"
        cmdInput.text = ""
        modalRoot.isOpen = true
        focusTimer.restart()
    }

    function openDetail(item) {
        modalRoot.editId = item.taskId
        modalRoot.editStatus = item.status || "stopped"
        nameInput.text = item.name
        cwdInput.text = item.cwd
        cmdInput.text = item.cmd
        modalRoot.isOpen = true
        focusTimer.restart()
    }

    function close() {
        modalRoot.editId = ""
        nameInput.text = ""
        cwdInput.text = ""
        cmdInput.text = ""
        modalRoot.isOpen = false
    }

    function submit() {
        var nameVal = nameInput.text.trim()
        var cwdVal = cwdInput.text.trim() || "~"
        var cmdVal = cmdInput.text.trim()
        if (!nameVal || !cmdVal) return
        modalRoot.saveRequested(modalRoot.editId, nameVal, cwdVal, cmdVal)
        modalRoot.close()
    }

    function remove() {
        if (modalRoot.editId) {
            modalRoot.deleteRequested(modalRoot.editId)
        }
        modalRoot.close()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // 标头
        Item {
            width: parent.width; height: 24

            Row {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Text {
                    text: modalRoot.editId ? "服务配置" : "新建常驻服务"
                    color: "white"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.family: modalRoot.effectiveFont
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    height: 16
                    width: statusText.implicitWidth + 10
                    radius: 8
                    color: modalRoot.editStatus === "running" ? Qt.rgba(16 / 255, 185 / 255, 129 / 255, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modalRoot.editId !== ""

                    Row {
                        anchors.centerIn: parent; spacing: 3
                        Rectangle {
                            width: 4; height: 4; radius: 2
                            color: modalRoot.editStatus === "running" ? "#10b981" : Theme.textMuted
                        }
                        Text {
                            id: statusText
                            text: modalRoot.editStatus === "running" ? "RUNNING" : "STOPPED"
                            color: modalRoot.editStatus === "running" ? "#34d399" : Theme.textMuted
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            font.family: modalRoot.effectiveMono
                        }
                    }
                }
            }

            Rectangle {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                width: 20; height: 20; radius: 10
                color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                Text { anchors.centerIn: parent; text: "✕"; color: Theme.textMuted; font.pixelSize: 10 }
                HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: modalRoot.close() }
            }
        }

        // 一体化输入卡片
        Rectangle {
            width: parent.width; height: 94; radius: 8
            color: Qt.rgba(1, 1, 1, 0.035)
            border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

            Column {
                anchors.fill: parent

                // 1. 服务名称
                Item {
                    width: parent.width; height: 31
                    Text { id: lblName; text: "名称"; color: Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: modalRoot.effectiveFont; anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; width: 30 }

                    TextInput {
                        id: nameInput
                        anchors.left: lblName.right; anchors.leftMargin: 6; anchors.right: parent.right; anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"; font.pixelSize: 12; font.weight: Font.DemiBold; font.family: modalRoot.effectiveFont
                        selectByMouse: true; activeFocusOnPress: true
                        selectionColor: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.4)
                        KeyNavigation.tab: cwdInput
                        Keys.onReturnPressed: modalRoot.submit()
                        Keys.onEnterPressed: modalRoot.submit()
                        Keys.onEscapePressed: modalRoot.close()

                        Text {
                            text: "输入服务唯一名称 (如 book-search)..."
                            color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 11; font.family: modalRoot.effectiveFont
                            visible: !nameInput.text && !nameInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.IBeamCursor
                        onPressed: { if (typeof Bridge !== "undefined") Bridge.requestWindowFocus(); nameInput.forceActiveFocus() }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.05) }

                // 2. 工作目录
                Item {
                    width: parent.width; height: 31
                    Text { id: lblCwd; text: "目录"; color: Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: modalRoot.effectiveFont; anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; width: 30 }

                    TextInput {
                        id: cwdInput
                        anchors.left: lblCwd.right; anchors.leftMargin: 6; anchors.right: browseBtn.left; anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.textSecondary; font.pixelSize: 11; font.family: modalRoot.effectiveMono
                        selectByMouse: true; activeFocusOnPress: true
                        selectionColor: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.4)
                        KeyNavigation.tab: cmdInput
                        Keys.onReturnPressed: modalRoot.submit()
                        Keys.onEnterPressed: modalRoot.submit()
                        Keys.onEscapePressed: modalRoot.close()

                        Text {
                            text: "绝对路径 (默认: ~)..."
                            color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 10; font.family: modalRoot.effectiveMono
                            visible: !cwdInput.text && !cwdInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        id: browseBtn
                        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 4
                        color: browseHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                        Text { anchors.centerIn: parent; text: "📁"; font.pixelSize: 11 }
                        HoverHandler { id: browseHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (typeof Bridge !== "undefined" && Bridge.selectLocalDirectory) {
                                    var dir = Bridge.selectLocalDirectory()
                                    if (dir) cwdInput.text = dir
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.left: parent.left; anchors.right: browseBtn.left
                        anchors.top: parent.top; anchors.bottom: parent.bottom
                        cursorShape: Qt.IBeamCursor
                        onPressed: { if (typeof Bridge !== "undefined") Bridge.requestWindowFocus(); cwdInput.forceActiveFocus() }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.05) }

                // 3. 执行命令
                Item {
                    width: parent.width; height: 31
                    Text { id: lblCmd; text: "命令"; color: Theme.textMuted; font.pixelSize: 10; font.weight: Font.Bold; font.family: modalRoot.effectiveFont; anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; width: 30 }
                    Text { id: promptSymbol; text: "$"; color: "#c084fc"; font.pixelSize: 11; font.weight: Font.Bold; font.family: modalRoot.effectiveMono; anchors.left: lblCmd.right; anchors.leftMargin: 6; anchors.verticalCenter: parent.verticalCenter }

                    TextInput {
                        id: cmdInput
                        anchors.left: promptSymbol.right; anchors.leftMargin: 5; anchors.right: parent.right; anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"; font.pixelSize: 11; font.family: modalRoot.effectiveMono
                        selectByMouse: true; activeFocusOnPress: true
                        selectionColor: Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.4)
                        Keys.onReturnPressed: modalRoot.submit()
                        Keys.onEnterPressed: modalRoot.submit()
                        Keys.onEscapePressed: modalRoot.close()

                        Text {
                            text: "python3 main.py / npm run dev..."
                            color: Qt.rgba(1, 1, 1, 0.25); font.pixelSize: 11; font.family: modalRoot.effectiveMono
                            visible: !cmdInput.text && !cmdInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.IBeamCursor
                        onPressed: { if (typeof Bridge !== "undefined") Bridge.requestWindowFocus(); cmdInput.forceActiveFocus() }
                    }
                }
            }
        }

        // 底部动作行
        Item {
            width: parent.width; height: 26

            Rectangle {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: delRow.implicitWidth + 12; height: 24; radius: 5
                visible: modalRoot.editId !== ""
                color: delHover.hovered ? Qt.rgba(239 / 255, 68 / 68, 68 / 255, 0.16) : "transparent"
                border.color: delHover.hovered ? Theme.danger : "transparent"; border.width: 1

                Row {
                    id: delRow
                    anchors.centerIn: parent; spacing: 4
                    Text { text: "🗑️"; font.pixelSize: 9; opacity: delHover.hovered ? 1.0 : 0.6 }
                    Text {
                        text: "删除服务"
                        color: delHover.hovered ? Theme.danger : Theme.textMuted
                        font.pixelSize: 10
                        font.family: modalRoot.effectiveFont
                    }
                }
                HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: modalRoot.remove() }
            }

            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 48; height: 24; radius: 5
                    color: cancelHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    Text { anchors.centerIn: parent; text: "取消"; color: cancelHover.hovered ? "white" : Theme.textMuted; font.pixelSize: 11; font.family: modalRoot.effectiveFont }
                    HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: modalRoot.close() }
                }

                Rectangle {
                    width: 78; height: 24; radius: 12
                    color: saveHover.hovered ? Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.35) : Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.22)
                    border.color: saveHover.hovered ? "#c084fc" : Qt.rgba(168 / 255, 85 / 255, 247 / 255, 0.6)
                    border.width: 1
                    scale: saveTap.pressed ? 0.95 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Text { text: "✓"; color: "white"; font.pixelSize: 11; font.weight: Font.Black }
                        Text { text: "保存"; color: "white"; font.pixelSize: 11; font.weight: Font.Bold; font.family: modalRoot.effectiveFont }
                    }
                    HoverHandler { id: saveHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: saveTap; onTapped: modalRoot.submit() }
                }
            }
        }
    }
}