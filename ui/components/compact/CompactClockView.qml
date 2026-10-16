// ==========================================
// 📄 File: compact/CompactClockView.qml (无网速纯粹版)
// ==========================================
import QtQuick

Row {
    id: clockRoot
    spacing: 6
    anchors.verticalCenter: parent.verticalCenter

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property bool isCapsLock: false
    property bool isNumLock: false

    // 🚀【彻底关闭胶囊网速】：默认为 false，不再渲染网速
    property bool showNetSpeed: false

    property string downCompact: "0K"
    property string upCompact: "0K"
    property string displayDate: ""
    property string displayTime: "04:53"
    property string displaySeconds: ""
    property string displayPeriod: "pm"
    property bool isClockActive: true

    property bool showWorkspaceName: true
    property string wsName: ""
    property int displayWsNumber: 0

    opacity: clockRoot.isClockActive ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: clockRoot.isClockActive ? 140 : 80; easing.type: Easing.OutQuad } }

    Text {
        id: timeMetricDummy
        text: "88:88"
        font.family: clockRoot.displayFont
        font.pixelSize: 17
        font.weight: Font.Black
        font.letterSpacing: 0.3
        visible: false
    }

    Text {
        id: secMetricDummy
        text: ":88"
        font.family: clockRoot.displayFont
        font.pixelSize: 11
        font.weight: Font.Bold
        visible: false
    }

    Text {
        id: periodMetricDummy
        text: "PM"
        font.family: clockRoot.effectiveFont
        font.pixelSize: 8
        font.weight: Font.Black
        font.capitalization: Font.AllUppercase
        visible: false
    }

    // 0. 当前工作区微徽标
    Item {
        id: wsBadge
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        readonly property string resolvedWsText: clockRoot.wsName ? clockRoot.wsName : ("" + clockRoot.displayWsNumber)
        readonly property bool shouldShow: clockRoot.showWorkspaceName && (resolvedWsText !== "")

        visible: width > 0
        width: shouldShow ? 52 : 0 // 🚀 强制定宽防抽搐
        opacity: shouldShow ? 1.0 : 0.0

        Text {
            id: wsBadgeText
            anchors.centerIn: parent
            text: wsBadge.resolvedWsText
            color: wsBadgeMouse.containsMouse ? Theme.workspace : Qt.rgba(1, 1, 1, 0.75)
            font.pixelSize: 10
            font.weight: Font.Black
            font.family: clockRoot.displayFont
            elide: Text.ElideRight
            width: Math.min(48, implicitWidth)
            horizontalAlignment: Text.AlignHCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            id: wsBadgeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: {
                if (typeof Bridge !== "undefined") Bridge.switchWorkspaceNext()
            }
            onWheel: (wheel) => {
                wheel.accepted = true
                if (typeof Bridge !== "undefined") {
                    if (wheel.angleDelta.y > 0) Bridge.switchWorkspacePrev()
                    else Bridge.switchWorkspaceNext()
                }
            }
        }
    }

    // 1. CAPS LOCK
    Item {
        id: capsLockBadge
        height: parent.height; anchors.verticalCenter: parent.verticalCenter; clip: true
        visible: width > 0; width: clockRoot.isCapsLock ? capsLockRow.implicitWidth : 0
        opacity: clockRoot.isCapsLock ? 1.0 : 0.0

        Row {
            id: capsLockRow
            anchors.centerIn: parent; spacing: 2
            Text { text: "⇪"; color: "#38bdf8"; font.pixelSize: 10; font.weight: Font.Black; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "CAPS"; color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 8; font.weight: Font.Black; font.family: clockRoot.displayFont; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // 2. NUM LOCK
    Item {
        id: numLockBadge
        height: parent.height; anchors.verticalCenter: parent.verticalCenter; clip: true
        visible: width > 0; width: clockRoot.isNumLock ? numLockRow.implicitWidth : 0
        opacity: clockRoot.isNumLock ? 1.0 : 0.0

        Row {
            id: numLockRow
            anchors.centerIn: parent; spacing: 2.5
            Rectangle {
                width: 4; height: 4; radius: 2; color: "#34d399"; anchors.verticalCenter: parent.verticalCenter
            }
            Text { text: "NUM"; color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 8; font.weight: Font.Black; font.family: clockRoot.displayFont; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // 3. 实时网速：由于 showNetSpeed 为 false，此处宽度为 0 且绝不占用任何布局像素
    Item {
        id: netSpeedItem
        height: parent.height; anchors.verticalCenter: parent.verticalCenter; clip: true
        visible: clockRoot.showNetSpeed && width > 0
        width: clockRoot.showNetSpeed ? 40 : 0
        opacity: clockRoot.showNetSpeed ? 1.0 : 0.0
    }

    // 4. 当前日期
    Item {
        id: dateItem
        height: parent.height; anchors.verticalCenter: parent.verticalCenter
        readonly property bool shouldShow: (typeof Config !== "undefined" && Config.showDate) && clockRoot.displayDate !== ""
        visible: width > 0; width: shouldShow ? Math.ceil(dateText.implicitWidth + 2) : 0; opacity: shouldShow ? 1.0 : 0.0
        Text {
            id: dateText; anchors.centerIn: parent; text: clockRoot.displayDate; color: Qt.rgba(1, 1, 1, 0.65)
            font.family: clockRoot.effectiveFont; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 0.2; renderType: Text.QtRendering
        }
    }

    // 5. 分隔圆点
    Rectangle {
        id: dateDot
        width: 3; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.22); anchors.verticalCenter: parent.verticalCenter
        visible: dateItem.visible && (typeof Config !== "undefined" && Config.showDate) && clockRoot.displayDate !== ""
        opacity: dateItem.opacity
    }

    // 6. 核心时间
    Row {
        id: timeRow
        spacing: 2; anchors.verticalCenter: parent.verticalCenter

        Item {
            id: mainTimeSlot
            width: Math.ceil(timeMetricDummy.implicitWidth); height: 20; anchors.verticalCenter: parent.verticalCenter
            Text {
                id: mainTimeText; anchors.centerIn: parent; text: clockRoot.displayTime; color: "#ffffff"
                font.family: clockRoot.displayFont; font.pixelSize: 17; font.weight: Font.Black; font.letterSpacing: 0.3; font.features: { "tnum": 1 }; renderType: Text.QtRendering
            }
        }

        Item {
            id: secSlot
            visible: (typeof Config !== "undefined" && Config.showSeconds) && clockRoot.displaySeconds !== ""
            width: visible ? Math.ceil(secMetricDummy.implicitWidth + 2) : 0; height: 20; anchors.verticalCenter: parent.verticalCenter; clip: true
            Row {
                id: secRow; anchors.centerIn: parent; anchors.verticalCenterOffset: 1; spacing: 0
                Text { text: ":"; color: Qt.rgba(1, 1, 1, 0.35); font.family: clockRoot.displayFont; font.pixelSize: 11; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                Text { text: clockRoot.displaySeconds.replace(/^:/, ""); color: Qt.rgba(1, 1, 1, 0.52); font.family: clockRoot.displayFont; font.pixelSize: 11; font.weight: Font.Bold; font.features: { "tnum": 1 }; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Item {
            id: periodSlot
            visible: (typeof Config !== "undefined" && Config.timeFormat === "12h") && clockRoot.displayPeriod !== ""
            width: visible ? Math.ceil(periodMetricDummy.implicitWidth + 2) : 0; height: 20; anchors.verticalCenter: parent.verticalCenter
            Text {
                id: periodText; anchors.centerIn: parent; anchors.verticalCenterOffset: 1; text: clockRoot.displayPeriod
                color: Qt.rgba(1, 1, 1, 0.40); font.family: clockRoot.effectiveFont; font.pixelSize: 8; font.weight: Font.Black; font.capitalization: Font.AllUppercase
            }
        }
    }
}