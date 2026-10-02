import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

Item {
    id: btRoot

    property string chosenFont: ""
    property bool isPowered: (typeof Bridge !== "undefined" && Bridge.isBluetoothPowered) ? Bridge.isBluetoothPowered() : true
    property bool isRefreshing: false

    readonly property var btModel: (typeof Bridge !== "undefined") ? Bridge.bluetoothModel : null

    // 辅助计算当前连接态设备
    property int connectedCount: 0
    property string primaryName: ""
    property string primaryIcon: "bluetooth"
    property var primaryBattery: null

    function recalculateConnectedState() {
        if (!btModel) {
            connectedCount = 0; primaryName = ""; primaryBattery = null; return
        }
        var cnt = 0
        var foundFirst = false
        for (var i = 0; i < btModel.rowCount(); i++) {
            var idx = btModel.index(i, 0)
            var isConn = btModel.data(idx, 259) // ConnectedRole
            if (isConn) {
                cnt++
                if (!foundFirst) {
                    primaryName = btModel.data(idx, 257) // NameRole
                    primaryBattery = btModel.data(idx, 260) // BatteryRole
                    primaryIcon = btModel.data(idx, 261) || "bluetooth" // IconRole
                    foundFirst = true
                }
            }
        }
        connectedCount = cnt
        if (!foundFirst) {
            primaryName = ""
            primaryBattery = null
            primaryIcon = "bluetooth"
        }
    }

    Connections {
        target: btRoot.btModel
        function onDataChanged() { btRoot.recalculateConnectedState() }
        function onRowsInserted() { btRoot.recalculateConnectedState() }
        function onRowsRemoved() { btRoot.recalculateConnectedState() }
        function onModelReset() { btRoot.recalculateConnectedState() }
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onBluetoothStateChanged(powered) {
            btRoot.isPowered = powered
            btRoot.recalculateConnectedState()
        }
    }

    Component.onCompleted: recalculateConnectedState()

    function getBatteryColor(pct) {
        if (pct === null || pct === undefined || isNaN(pct)) return Qt.rgba(1, 1, 1, 0.4)
        if (pct >= 60) return Theme.media
        if (pct >= 25) return Theme.clock
        return Theme.danger
    }

    function refresh() {
        isRefreshing = true
        refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: 600
        onTriggered: {
            btRoot.isRefreshing = false
            btRoot.recalculateConnectedState()
        }
    }

    function getDeviceIcon(name, iconType) {
        var n = (name || "").toLowerCase()
        var ic = (iconType || "").toLowerCase()
        if (ic.indexOf("audio") !== -1 || n.indexOf("pods") !== -1 || n.indexOf("buds") !== -1 || n.indexOf("wh-") !== -1 || n.indexOf("head") !== -1 || n.indexOf("sound") !== -1) return "🎧"
        if (ic.indexOf("mouse") !== -1 || n.indexOf("mouse") !== -1 || n.indexOf("mx ") !== -1) return "🖱️"
        if (ic.indexOf("keyboard") !== -1 || n.indexOf("key") !== -1) return "⌨️"
        if (ic.indexOf("phone") !== -1 || n.indexOf("phone") !== -1) return "📱"
        return "bluetooth"
    }

    Row {
        anchors.fill: parent
        spacing: 14

        // 1. 左侧统计看板
        Rectangle {
            width: 142
            height: parent.height
            radius: Theme.radiusCard
            color: Theme.bgCardItem
            border.color: Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.22)
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 5
                width: parent.width - 20

                Row {
                    spacing: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: btRoot.isPowered ? (btRoot.connectedCount > 0 ? Theme.bluetooth : Theme.network) : Qt.rgba(1, 1, 1, 0.25)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "BLUETOOTH"
                        font.pixelSize: 9
                        font.weight: Font.Black
                        color: btRoot.isPowered ? Theme.bluetooth : Theme.textMuted
                        font.family: btRoot.chosenFont
                        font.letterSpacing: 0.8
                    }
                }

                Item {
                    width: 38; height: 38
                    anchors.horizontalCenter: parent.horizontalCenter

                    Shape {
                        anchors.centerIn: parent
                        width: 20; height: 24
                        visible: btRoot.connectedCount === 0 || btRoot.getDeviceIcon(btRoot.primaryName, btRoot.primaryIcon) === "bluetooth"

                        ShapePath {
                            strokeColor: Theme.bluetooth
                            strokeWidth: 2.2
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin

                            startX: 5.5; startY: 6.5
                            PathLine { x: 14.5; y: 17.5 }
                            PathLine { x: 10.0; y: 22.5 }
                            PathLine { x: 10.0; y: 1.5 }
                            PathLine { x: 14.5; y: 6.5 }
                            PathLine { x: 5.5; y: 17.5 }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: btRoot.getDeviceIcon(btRoot.primaryName, btRoot.primaryIcon)
                        font.pixelSize: 30
                        visible: btRoot.connectedCount > 0 && text !== "bluetooth"
                    }
                }

                Text {
                    text: {
                        if (!btRoot.isPowered) return "蓝牙已关闭"
                        if (btRoot.connectedCount === 0) return "未连接设备"
                        if (btRoot.connectedCount === 1) return btRoot.primaryName
                        return btRoot.connectedCount + " 个设备连接中"
                    }
                    color: "white"
                    font.pixelSize: 12
                    font.weight: Font.Black
                    font.family: btRoot.chosenFont
                    elide: Text.ElideRight
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    spacing: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: btRoot.connectedCount > 0 && btRoot.primaryBattery !== null

                    Rectangle {
                        width: 20; height: 10; radius: 2.5
                        color: "transparent"
                        border.color: btRoot.getBatteryColor(btRoot.primaryBattery)
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.left: parent.left; anchors.leftMargin: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(2, (parent.width - 3) * Math.min(1.0, (btRoot.primaryBattery || 0) / 100.0))
                            height: parent.height - 3; radius: 1
                            color: btRoot.getBatteryColor(btRoot.primaryBattery)
                        }
                    }

                    Text {
                        text: (btRoot.primaryBattery || 0) + "%"
                        color: btRoot.getBatteryColor(btRoot.primaryBattery)
                        font.pixelSize: 10
                        font.weight: Font.Black
                        font.family: "Monospace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: btRoot.connectedCount > 0 ? ("共 " + btRoot.connectedCount + " 个已连") : "蓝牙控制器已就绪"
                    color: Theme.textMuted
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.family: btRoot.chosenFont
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !(btRoot.connectedCount > 0 && btRoot.primaryBattery !== null)
                }

                Item { height: 2 }

                Rectangle {
                    width: 96; height: 24; radius: 12
                    color: managerTap.pressed ? Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.35) : (managerHover.hovered ? Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.22) : Qt.rgba(1, 1, 1, 0.08))
                    border.color: Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.3)
                    border.width: 1
                    scale: managerTap.pressed ? 0.94 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                    Behavior on color { ColorAnimation { duration: Theme.animInstant } }
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "系统管理"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: btRoot.chosenFont }
                        Text { text: "↗"; color: Theme.bluetooth; font.pixelSize: 10; font.weight: Font.Bold }
                    }

                    HoverHandler { id: managerHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: managerTap
                        onTapped: if (typeof Bridge !== "undefined" && Bridge.openBluetoothSettings) Bridge.openBluetoothSettings()
                    }
                }
            }
        }

        // 2. 右侧设备列表（行级差量更新）
        Column {
            width: parent.width - 156
            height: parent.height
            spacing: 6

            Item {
                width: parent.width; height: 22

                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "已配对设备"
                    color: Theme.textMuted
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.family: btRoot.chosenFont
                }

                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 52; height: 20; radius: 10
                    color: refreshTap.pressed ? Qt.rgba(1, 1, 1, 0.2) : (refreshHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06))
                    scale: refreshTap.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.animInstant } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: "⟳"
                            font.pixelSize: 12
                            color: Theme.bluetooth
                            RotationAnimator on rotation {
                                running: btRoot.isRefreshing
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 600
                            }
                        }
                        Text { text: "刷新"; font.pixelSize: 9; color: "white"; font.weight: Font.Bold; font.family: btRoot.chosenFont }
                    }

                    HoverHandler { id: refreshHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: refreshTap; onTapped: btRoot.refresh() }
                }
            }

            ListView {
                id: deviceListView
                width: parent.width
                height: parent.height - 28
                clip: true
                spacing: 4
                model: btRoot.btModel

                ScrollBar.vertical: ScrollBar {
                    width: 4; policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 2; color: Theme.borderSubtle }
                }

                Item {
                    anchors.fill: parent
                    visible: !btRoot.btModel || btRoot.btModel.rowCount() === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "未发现配对的蓝牙设备"; color: Theme.textMuted; font.pixelSize: 11; font.family: btRoot.chosenFont; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "点击左侧“系统管理”进行配对 ↗"; color: Theme.bluetooth; font.pixelSize: 10; font.weight: Font.Bold; font.family: btRoot.chosenFont; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                delegate: Rectangle {
                    id: devCard
                    width: deviceListView.width - 6
                    height: 38
                    radius: Theme.radiusItem
                    color: devHover.hovered ? Theme.bgCardHover : Theme.bgCardItem
                    border.color: model.connected ? Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.35) : Theme.borderSubtle
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.animInstant } }

                    HoverHandler { id: devHover }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 8

                        Item {
                            width: 18; height: 18
                            anchors.verticalCenter: parent.verticalCenter

                            Shape {
                                anchors.centerIn: parent
                                width: 12; height: 14
                                visible: btRoot.getDeviceIcon(model.name, model.icon) === "bluetooth"

                                ShapePath {
                                    strokeColor: model.connected ? Theme.bluetooth : Theme.textMuted
                                    strokeWidth: 1.6
                                    fillColor: "transparent"
                                    capStyle: ShapePath.RoundCap
                                    joinStyle: ShapePath.RoundJoin

                                    startX: 3.2; startY: 3.8
                                    PathLine { x: 8.8; y: 10.2 }
                                    PathLine { x: 6.0; y: 13.0 }
                                    PathLine { x: 6.0; y: 1.0 }
                                    PathLine { x: 8.8; y: 3.8 }
                                    PathLine { x: 3.2; y: 10.2 }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: btRoot.getDeviceIcon(model.name, model.icon)
                                font.pixelSize: 16
                                visible: text !== "bluetooth"
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: parent.width - 92

                            Text {
                                text: model.name || "未知设备"
                                color: "white"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.family: btRoot.chosenFont
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Row {
                                spacing: 6

                                Row {
                                    spacing: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        width: 4; height: 4; radius: 2
                                        color: model.connected ? Theme.network : Qt.rgba(1, 1, 1, 0.25)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: model.connected ? "已连接" : "未连接"
                                        color: model.connected ? Theme.network : Theme.textMuted
                                        font.pixelSize: 9
                                        font.family: btRoot.chosenFont
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Row {
                                    spacing: 3
                                    visible: model.battery !== null && model.battery !== undefined
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: 16; height: 8; radius: 2
                                        color: "transparent"
                                        border.color: btRoot.getBatteryColor(model.battery)
                                        border.width: 1
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            anchors.left: parent.left; anchors.leftMargin: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.max(1.5, (parent.width - 2) * Math.min(1.0, Math.max(0.0, (model.battery || 0) / 100.0)))
                                            height: parent.height - 2; radius: 1
                                            color: btRoot.getBatteryColor(model.battery)
                                        }

                                        Rectangle {
                                            anchors.left: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            width: 1.5; height: 3.5; radius: 0.5
                                            color: btRoot.getBatteryColor(model.battery)
                                        }
                                    }

                                    Text {
                                        text: model.battery + "%"
                                        color: btRoot.getBatteryColor(model.battery)
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        font.family: "Monospace"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: 46; height: 22; radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: model.connected ?
                                  (toggleBtnHover.hovered ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.25) : Qt.rgba(1, 1, 1, 0.08)) :
                                  (toggleBtnHover.hovered ? Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.3) : Qt.rgba(Theme.bluetooth.r, Theme.bluetooth.g, Theme.bluetooth.b, 0.15))
                            border.color: model.connected ?
                                  (toggleBtnHover.hovered ? Theme.danger : "transparent") :
                                  Theme.bluetooth
                            border.width: 1
                            scale: toggleBtnTap.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: Theme.animInstant } }
                            Behavior on color { ColorAnimation { duration: Theme.animInstant } }

                            Text {
                                anchors.centerIn: parent
                                text: model.connected ? "断开" : "连接"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: model.connected ? (toggleBtnHover.hovered ? Theme.danger : "white") : Theme.bluetooth
                                font.family: btRoot.chosenFont
                            }

                            HoverHandler { id: toggleBtnHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                id: toggleBtnTap
                                onTapped: {
                                    if (typeof Bridge !== "undefined") {
                                        if (model.connected && Bridge.disconnectBluetooth) {
                                            Bridge.disconnectBluetooth(model.mac)
                                        } else if (!model.connected && Bridge.connectBluetooth) {
                                            Bridge.connectBluetooth(model.mac)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}