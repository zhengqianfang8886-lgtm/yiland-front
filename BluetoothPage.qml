import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

Item {
    id: btRoot

    property string chosenFont: ""
    property var deviceList: []
    property bool isPowered: true
    property bool isRefreshing: false

    function getBatteryColor(pct) {
        if (pct === null || pct === undefined || isNaN(pct)) return Qt.rgba(1, 1, 1, 0.4)
        if (pct >= 60) return "#22c55e"
        if (pct >= 25) return "#f59e0b"
        return "#ef4444"
    }

    function refresh() {
        isRefreshing = true
        if (typeof Bridge !== "undefined" && Bridge.getBluetoothDevices) {
            btRoot.deviceList = Bridge.getBluetoothDevices()
            if (Bridge.isBluetoothPowered) {
                btRoot.isPowered = Bridge.isBluetoothPowered()
            }
        }
        refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: 600
        onTriggered: btRoot.isRefreshing = false
    }

    Timer {
        interval: 3500
        running: btRoot.visible
        repeat: true
        onTriggered: {
            if (!btRoot.isRefreshing && typeof Bridge !== "undefined" && Bridge.getBluetoothDevices) {
                btRoot.deviceList = Bridge.getBluetoothDevices()
            }
        }
    }

    Connections {
        target: (typeof Bridge !== "undefined") ? Bridge : null
        function onBluetoothUpdated(list) {
            if (list) btRoot.deviceList = list
        }
        function onBluetoothStateChanged(powered) {
            btRoot.isPowered = powered
        }
    }

    Component.onCompleted: refresh()

    readonly property var connectedList: {
        var res = []
        for (var i = 0; i < deviceList.length; i++) {
            if (deviceList[i].connected) res.push(deviceList[i])
        }
        return res
    }

    readonly property var primaryActiveDevice: connectedList.length > 0 ? connectedList[0] : null

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

        // 1. 左侧看板
        Rectangle {
            width: 142
            height: parent.height
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.04)
            border.color: Qt.rgba(96, 165, 250, 0.22)
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
                        color: btRoot.isPowered ? (btRoot.connectedList.length > 0 ? "#60a5fa" : "#34d399") : Qt.rgba(1, 1, 1, 0.25)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "BLUETOOTH"
                        font.pixelSize: 9
                        font.weight: Font.Black
                        color: btRoot.isPowered ? "#60a5fa" : Qt.rgba(1, 1, 1, 0.4)
                        font.family: btRoot.chosenFont
                        font.letterSpacing: 0.8
                    }
                }

                // 徽章：GPU 硬件加速绘制蓝牙矢量符号
                Item {
                    width: 38; height: 38
                    anchors.horizontalCenter: parent.horizontalCenter

                    Shape {
                        anchors.centerIn: parent
                        width: 20; height: 24
                        visible: !btRoot.primaryActiveDevice || btRoot.getDeviceIcon(btRoot.primaryActiveDevice.name, btRoot.primaryActiveDevice.icon) === "bluetooth"
                        layer.enabled: true
                        layer.samples: 4

                        ShapePath {
                            strokeColor: "#60a5fa"
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
                        text: btRoot.primaryActiveDevice ? btRoot.getDeviceIcon(btRoot.primaryActiveDevice.name, btRoot.primaryActiveDevice.icon) : ""
                        font.pixelSize: 30
                        visible: btRoot.primaryActiveDevice && text !== "bluetooth"
                    }
                }

                Text {
                    text: {
                        if (!btRoot.isPowered) return "蓝牙已关闭"
                        if (btRoot.connectedList.length === 0) return "未连接设备"
                        if (btRoot.connectedList.length === 1) return btRoot.primaryActiveDevice.name
                        return btRoot.connectedList.length + " 个设备连接中"
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
                    visible: btRoot.primaryActiveDevice && btRoot.primaryActiveDevice.battery !== null && btRoot.primaryActiveDevice.battery !== undefined

                    Rectangle {
                        width: 20; height: 10; radius: 2.5
                        color: "transparent"
                        border.color: btRoot.getBatteryColor(btRoot.primaryActiveDevice ? btRoot.primaryActiveDevice.battery : 100)
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.left: parent.left; anchors.leftMargin: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(2, (parent.width - 3) * Math.min(1.0, (btRoot.primaryActiveDevice ? btRoot.primaryActiveDevice.battery : 0) / 100.0))
                            height: parent.height - 3; radius: 1
                            color: btRoot.getBatteryColor(btRoot.primaryActiveDevice ? btRoot.primaryActiveDevice.battery : 100)
                        }
                    }

                    Text {
                        text: (btRoot.primaryActiveDevice ? btRoot.primaryActiveDevice.battery : 0) + "%"
                        color: btRoot.getBatteryColor(btRoot.primaryActiveDevice ? btRoot.primaryActiveDevice.battery : 100)
                        font.pixelSize: 10
                        font.weight: Font.Black
                        font.family: "Monospace"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: btRoot.connectedList.length > 0 ? ("共 " + btRoot.connectedList.length + " 个已连") : "蓝牙控制器已就绪"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.family: btRoot.chosenFont
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !(btRoot.primaryActiveDevice && btRoot.primaryActiveDevice.battery !== null && btRoot.primaryActiveDevice.battery !== undefined)
                }

                Item { height: 2 }

                Rectangle {
                    width: 96; height: 24; radius: 12
                    color: managerBtnArea.containsMouse ? Qt.rgba(96, 165, 250, 0.24) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(96, 165, 250, 0.3)
                    border.width: 1
                    scale: managerBtnArea.pressed ? 0.94 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "系统管理"; color: "white"; font.pixelSize: 10; font.weight: Font.Bold; font.family: btRoot.chosenFont }
                        Text { text: "↗"; color: "#60a5fa"; font.pixelSize: 10; font.weight: Font.Bold }
                    }

                    MouseArea {
                        id: managerBtnArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (typeof Bridge !== "undefined" && Bridge.openBluetoothSettings) Bridge.openBluetoothSettings()
                    }
                }
            }
        }

        // 2. 右侧设备列表
        Column {
            width: parent.width - 156
            height: parent.height
            spacing: 6

            Item {
                width: parent.width; height: 22

                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "已配对设备"
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.family: btRoot.chosenFont
                }

                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 52; height: 20; radius: 10
                    color: refreshArea.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                    scale: refreshArea.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: "⟳"
                            font.pixelSize: 12
                            color: "#60a5fa"
                            RotationAnimator on rotation {
                                running: btRoot.isRefreshing
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 600
                            }
                        }
                        Text { text: "刷新"; font.pixelSize: 9; color: "white"; font.weight: Font.Bold; font.family: btRoot.chosenFont }
                    }

                    MouseArea {
                        id: refreshArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: btRoot.refresh()
                    }
                }
            }

            ListView {
                id: deviceListView
                width: parent.width
                height: parent.height - 28
                clip: true
                spacing: 4
                model: btRoot.deviceList

                ScrollBar.vertical: ScrollBar {
                    width: 4; policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.3) }
                }

                Item {
                    anchors.fill: parent
                    visible: btRoot.deviceList.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "未发现配对的蓝牙设备"; color: Qt.rgba(1, 1, 1, 0.5); font.pixelSize: 11; font.family: btRoot.chosenFont; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: "点击左侧“系统管理”进行配对 ↗"; color: "#60a5fa"; font.pixelSize: 10; font.weight: Font.Bold; font.family: btRoot.chosenFont; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }

                delegate: Rectangle {
                    id: devCard
                    width: deviceListView.width - 6
                    height: 38
                    radius: 8
                    color: devHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: modelData.connected ? Qt.rgba(96, 165, 250, 0.35) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: devHover }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 8

                        // 列表项左侧硬件加速矢量图标
                        Item {
                            width: 18; height: 18
                            anchors.verticalCenter: parent.verticalCenter

                            Shape {
                                anchors.centerIn: parent
                                width: 12; height: 14
                                visible: btRoot.getDeviceIcon(modelData.name, modelData.icon) === "bluetooth"
                                layer.enabled: true
                                layer.samples: 4

                                ShapePath {
                                    strokeColor: modelData.connected ? "#60a5fa" : Qt.rgba(1, 1, 1, 0.5)
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
                                text: btRoot.getDeviceIcon(modelData.name, modelData.icon)
                                font.pixelSize: 16
                                visible: text !== "bluetooth"
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            width: parent.width - 92

                            Text {
                                text: modelData.name || "未知设备"
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
                                        color: modelData.connected ? "#34d399" : Qt.rgba(1, 1, 1, 0.25)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: modelData.connected ? "已连接" : "未连接"
                                        color: modelData.connected ? "#34d399" : Qt.rgba(1, 1, 1, 0.4)
                                        font.pixelSize: 9
                                        font.family: btRoot.chosenFont
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Row {
                                    spacing: 3
                                    visible: modelData.battery !== null && modelData.battery !== undefined
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        width: 16; height: 8; radius: 2
                                        color: "transparent"
                                        border.color: btRoot.getBatteryColor(modelData.battery)
                                        border.width: 1
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            anchors.left: parent.left; anchors.leftMargin: 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.max(1.5, (parent.width - 2) * Math.min(1.0, Math.max(0.0, modelData.battery / 100.0)))
                                            height: parent.height - 2; radius: 1
                                            color: btRoot.getBatteryColor(modelData.battery)
                                        }

                                        Rectangle {
                                            anchors.left: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            width: 1.5; height: 3.5; radius: 0.5
                                            color: btRoot.getBatteryColor(modelData.battery)
                                        }
                                    }

                                    Text {
                                        text: modelData.battery + "%"
                                        color: btRoot.getBatteryColor(modelData.battery)
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
                            color: modelData.connected ?
                                  (toggleBtnArea.containsMouse ? Qt.rgba(239, 68, 68, 0.25) : Qt.rgba(1, 1, 1, 0.08)) :
                                  (toggleBtnArea.containsMouse ? Qt.rgba(96, 165, 250, 0.3) : Qt.rgba(96, 165, 250, 0.15))
                            border.color: modelData.connected ?
                                  (toggleBtnArea.containsMouse ? "#ef4444" : "transparent") :
                                  "#60a5fa"
                            border.width: 1
                            scale: toggleBtnArea.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.connected ? "断开" : "连接"
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: modelData.connected ? (toggleBtnArea.containsMouse ? "#ef4444" : "white") : "#60a5fa"
                                font.family: btRoot.chosenFont
                            }

                            MouseArea {
                                id: toggleBtnArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof Bridge !== "undefined") {
                                        if (modelData.connected && Bridge.disconnectBluetooth) {
                                            Bridge.disconnectBluetooth(modelData.mac)
                                        } else if (!modelData.connected && Bridge.connectBluetooth) {
                                            Bridge.connectBluetooth(modelData.mac)
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