// ==========================================
// 📄 File: compact/CompactClockView.qml
// 🌟 纯净 Row 原生布局 (拆除包裹黑盒 · 彻底绝缘任何穿模重叠)
// ==========================================
import QtQuick

Row {
    id: clockRoot
    spacing: 5 // 全局标准流体间隙

    property string chosenFont: ""
    readonly property string effectiveFont: (typeof Theme !== "undefined" && Theme.activeFont) ? Theme.activeFont : chosenFont
    readonly property string displayFont: (typeof Theme !== "undefined" && Theme.displayMonoFont) ? Theme.displayMonoFont : "Monospace"

    property bool isCapsLock: false

    property string displayDate: ""
    property string displayTime: "04:53"
    property string displaySeconds: ""
    property string displayPeriod: "pm"

    Text {
        id: timeMetricDummy
        text: "88:88"
        font.family: clockRoot.displayFont
        font.pixelSize: 19
        font.weight: Font.Black
        font.letterSpacing: 0.3
        font.features: { "tnum": 1 }
        visible: false
    }

    Text {
        id: secMetricDummy
        text: ":88"
        font.family: clockRoot.displayFont
        font.pixelSize: 12
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
        visible: false
    }

    onIsCapsLockChanged: {
        if (isCapsLock) capsBloomAnim.restart()
        else capsCollapseAnim.restart()
    }

    // =========================================================================
    // 1. 公历日期 (依靠 Row 原生流体推挤排版，永不重叠)
    // =========================================================================
    Text {
        id: dateText
        visible: (typeof Config !== "undefined" && Config.showDate) && clockRoot.displayDate !== ""
        text: clockRoot.displayDate
        color: Qt.rgba(1, 1, 1, 0.65)
        font.family: clockRoot.effectiveFont
        font.pixelSize: 12
        font.weight: Font.DemiBold
        anchors.verticalCenter: parent.verticalCenter
        renderType: Text.QtRendering
    }

    Rectangle {
        id: dateDot
        visible: dateText.visible
        width: 3; height: 3; radius: 1.5
        color: Qt.rgba(1, 1, 1, 0.30)
        anchors.verticalCenter: parent.verticalCenter
    }

    // =========================================================================
    // 2. CapsLock 琥珀微晶
    // =========================================================================
    Item {
        id: capsSlot
        width: clockRoot.isCapsLock ? 13 : 0
        height: 22
        anchors.verticalCenter: parent.verticalCenter
        clip: false

        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Item {
            width: 6; height: 6
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: capsRippleRing
                anchors.centerIn: parent
                width: 5; height: 5; radius: 2.5
                color: "transparent"
                border.color: "#f59e0b"
                border.width: 1
                opacity: 0.0
                scale: 1.0
            }

            Rectangle {
                id: capsDotBody
                anchors.centerIn: parent
                width: 5; height: 5; radius: 2.5
                color: "#f59e0b"
                opacity: clockRoot.isCapsLock ? 1.0 : 0.0
                scale: clockRoot.isCapsLock ? 1.0 : 0.0
                antialiasing: true
            }

            ParallelAnimation {
                id: capsBloomAnim
                NumberAnimation { target: capsDotBody; property: "scale"; from: 0.0; to: 1.35; duration: 120; easing.type: Easing.OutBack }
                NumberAnimation { target: capsDotBody; property: "opacity"; to: 1.0; duration: 80 }
                SequentialAnimation {
                    PauseAnimation { duration: 40 }
                    ParallelAnimation {
                        NumberAnimation { target: capsRippleRing; property: "scale"; from: 1.0; to: 2.6; duration: 240; easing.type: Easing.OutQuad }
                        NumberAnimation { target: capsRippleRing; property: "opacity"; from: 0.8; to: 0.0; duration: 240; easing.type: Easing.OutQuad }
                    }
                }
                NumberAnimation { target: capsDotBody; property: "scale"; to: 1.0; duration: 90; easing.type: Easing.OutQuad }
            }

            ParallelAnimation {
                id: capsCollapseAnim
                NumberAnimation { target: capsDotBody; property: "scale"; to: 0.0; duration: 110; easing.type: Easing.InBack }
                NumberAnimation { target: capsDotBody; property: "opacity"; to: 0.0; duration: 90 }
            }
        }
    }

    // =========================================================================
    // 3. 时间锁核心 (秒数抖动隔离层)
    // =========================================================================
    Row {
        id: timeRow
        spacing: 2
        anchors.verticalCenter: parent.verticalCenter

        Item {
            id: mainTimeSlot
            width: Math.ceil(timeMetricDummy.implicitWidth)
            height: 22
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: mainTimeText
                anchors.centerIn: parent
                text: clockRoot.displayTime
                color: "#ffffff"
                font.family: clockRoot.displayFont
                font.pixelSize: 19
                font.weight: Font.Black
                font.letterSpacing: 0.3
                font.features: { "tnum": 1 }
                renderType: Text.QtRendering
            }
        }

        Item {
            id: secSlot
            visible: (typeof Config !== "undefined" && Config.showSeconds) && clockRoot.displaySeconds !== ""
            width: visible ? Math.ceil(secMetricDummy.implicitWidth + 2) : 0
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                spacing: 0
                Text { text: ":"; color: Qt.rgba(1, 1, 1, 0.35); font.family: clockRoot.displayFont; font.pixelSize: 12; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: clockRoot.displaySeconds.replace(/^:/, "")
                    color: Qt.rgba(1, 1, 1, 0.52)
                    font.family: clockRoot.displayFont
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Item {
            id: periodSlot
            visible: (typeof Config !== "undefined" && Config.timeFormat === "12h") && clockRoot.displayPeriod !== ""
            width: visible ? 18 : 0
            height: 22
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                text: clockRoot.displayPeriod
                color: Qt.rgba(1, 1, 1, 0.40)
                font.family: clockRoot.effectiveFont
                font.pixelSize: 9
                font.weight: Font.Black
                font.capitalization: Font.AllUppercase
            }
        }
    }
}