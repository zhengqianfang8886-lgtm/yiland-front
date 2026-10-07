// ==========================================
// 📄 File: CompactCapsuleView.qml
// 🌟 纯正苹果灵动岛形态交融 · 优雅音量 OSD 转场版
// ==========================================
import QtQuick
import "compact"

Item {
    id: compactRoot

    property string chosenFont: ""
    property string activeTransient: ""
    property string status: "Paused"
    property bool isCalling: false
    property bool isExpanded: false
    property bool isCollapsing: false

    property bool showNetSpeed: true
    property bool isCapsLock: (typeof Bridge !== "undefined" && Bridge.isCapsLock !== undefined) ? Bridge.isCapsLock : false
    property bool isNumLock: (typeof Bridge !== "undefined" && Bridge.isNumLock !== undefined) ? Bridge.isNumLock : false

    property string wsName: ""
    property int wsCurrent: 1
    property int wsTotal: 4

    property string osdIcon: "🔊"
    property int osdValue: 50
    property string alertTitle: ""
    property string alertSubtitle: ""
    property string alertAvatar: ""
    property string alertIcon: "🔔"
    property string callTitle: ""
    property string callSubtitle: ""
    property string callAvatar: ""

    property string displayDate: ""
    property string displayTime: "04:53"
    property string displaySeconds: ""
    property string displayPeriod: "pm"
    property string downCompact: "0K"
    property string upCompact: "0K"

    property int continuousSitMinutes: 45
    signal sedentaryRested()
    signal sedentarySnooze()

    readonly property int textRowImplicitWidth: clockView.implicitWidth
    readonly property int wsRowImplicitWidth: wsView.implicitWidth
    readonly property int wsContentImplicitWidth: wsView.contentImplicitWidth
    readonly property int alertContentImplicitWidth: alertView.implicitContentWidth
    readonly property bool isAlertActive: (activeTransient === "ALERT") && !isCalling
    readonly property bool isHardwareMuted: (osdIcon === "🔇" || osdIcon === "🚫")
    readonly property bool isOsdMode: (activeTransient === "OSD" && !isCalling && !isExpanded)

    readonly property color alertThemeColor: {
        if (alertIcon === "⏰") return Theme.timer
        if (["bluetooth", "ᛒ", "🎧", "🖱️", "⌨️", "📱"].indexOf(alertIcon) !== -1) return Theme.bluetooth
        if (alertIcon === "🛡️") return Theme.network
        if (alertIcon === "📞") return Theme.media
        return Theme.notification
    }

    readonly property int displayWsNumber: {
        var n = Number(wsCurrent)
        if (isNaN(n)) return 0
        if (wsName && /^\d+$/.test(wsName.trim())) return Number(wsName.trim())
        return n
    }

    // 1. 久坐打断弹窗
    CompactSedentaryView {
        id: sedentaryView
        chosenFont: compactRoot.chosenFont
        continuousSitMinutes: compactRoot.continuousSitMinutes
        visible: opacity > 0.001
        opacity: (compactRoot.activeTransient === "SEDENTARY" && !compactRoot.isCalling && !compactRoot.isExpanded) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        onSedentaryRested: compactRoot.sedentaryRested()
        onSedentarySnooze: compactRoot.sedentarySnooze()
    }

    // 2. 来电专属模式条
    CompactCallView {
        id: callView
        chosenFont: compactRoot.chosenFont
        callTitle: compactRoot.callTitle; callSubtitle: compactRoot.callSubtitle; callAvatar: compactRoot.callAvatar
        isCalling: compactRoot.isCalling
        visible: opacity > 0.001
        opacity: (compactRoot.isCalling && !compactRoot.isExpanded) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // 3. 桌面切换动画展示条
    CompactWorkspaceView {
        id: wsView
        anchors.centerIn: parent
        chosenFont: compactRoot.chosenFont
        wsName: compactRoot.wsName; wsTotal: compactRoot.wsTotal; displayWsNumber: compactRoot.displayWsNumber
        activeSlotIndex: Math.max(0, Math.min(compactRoot.displayWsNumber, compactRoot.wsTotal - 1))
        visible: opacity > 0.001
        opacity: (compactRoot.activeTransient === "WORKSPACE" && !compactRoot.isCalling && !compactRoot.isExpanded) ? 1.0 : 0.0
        scale: opacity > 0.01 ? 1.0 : 0.94
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    // 4. 🚀 纯正苹果流体音量/静音 OSD（优雅向外舒展浮现）
    CompactOsdView {
        id: osdView
        anchors.fill: parent
        chosenFont: compactRoot.chosenFont
        osdIcon: compactRoot.osdIcon
        osdValue: compactRoot.osdValue
        visible: opacity > 0.001

        opacity: compactRoot.isOsdMode ? 1.0 : 0.0
        scale: compactRoot.isOsdMode ? 1.0 : 0.88

        Behavior on opacity {
            NumberAnimation { duration: compactRoot.isOsdMode ? 140 : 110; easing.type: Easing.OutQuad }
        }
        Behavior on scale {
            NumberAnimation {
                duration: compactRoot.isOsdMode ? 180 : 110
                easing.type: compactRoot.isOsdMode ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.08
            }
        }
    }

    // 5. 通知弹窗横幅 (ALERT)
    CompactAlertView {
        id: alertView
        chosenFont: compactRoot.chosenFont
        alertTitle: compactRoot.alertTitle; alertSubtitle: compactRoot.alertSubtitle; alertAvatar: compactRoot.alertAvatar
        alertThemeColor: compactRoot.alertThemeColor
        isAlertActive: !compactRoot.isExpanded && compactRoot.isAlertActive
    }

    // 6. 🚀 常态时钟（OSD 进场时优雅向景深处微退，OSD 离开时水润浮现）
    CompactClockView {
        id: clockView
        anchors.centerIn: parent
        chosenFont: compactRoot.chosenFont
        isCapsLock: compactRoot.isCapsLock
        isNumLock: compactRoot.isNumLock
        showNetSpeed: compactRoot.showNetSpeed
        downCompact: compactRoot.downCompact; upCompact: compactRoot.upCompact
        displayDate: compactRoot.displayDate; displayTime: compactRoot.displayTime; displaySeconds: compactRoot.displaySeconds; displayPeriod: compactRoot.displayPeriod

        readonly property bool clockVisibleState: (!compactRoot.isExpanded && compactRoot.activeTransient === "" && !compactRoot.isCalling)
        isClockActive: clockVisibleState

        opacity: clockVisibleState ? 1.0 : 0.0
        scale: clockVisibleState ? 1.0 : 0.90

        Behavior on opacity {
            NumberAnimation { duration: clockView.clockVisibleState ? 150 : 90; easing.type: Easing.OutQuad }
        }
        Behavior on scale {
            NumberAnimation { duration: clockView.clockVisibleState ? 170 : 90; easing.type: Easing.OutCubic }
        }
    }
}