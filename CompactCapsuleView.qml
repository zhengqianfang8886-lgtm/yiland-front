// ==========================================
// 📄 File: compact/CompactCapsuleView.qml
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

    // 辅助状态暴露
    readonly property int textRowImplicitWidth: clockView.implicitWidth
    readonly property int wsRowImplicitWidth: wsView.implicitWidth
    readonly property int alertContentImplicitWidth: alertView.implicitContentWidth
    readonly property bool isAlertActive: (activeTransient === "ALERT") && !isCalling
    readonly property bool isHardwareMuted: (osdIcon === "🔇" || osdIcon === "🚫")

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

    // 1. 久坐打断特大弹窗 (520x108)
    CompactSedentaryView {
        id: sedentaryView
        chosenFont: compactRoot.chosenFont
        continuousSitMinutes: compactRoot.continuousSitMinutes
        visible: compactRoot.activeTransient === "SEDENTARY" && !compactRoot.isCalling && !compactRoot.isExpanded
        opacity: visible ? 1.0 : 0.0
        onSedentaryRested: compactRoot.sedentaryRested()
        onSedentarySnooze: compactRoot.sedentarySnooze()
    }

    // 2. 来电专属模式条 (320x44)
    CompactCallView {
        id: callView
        chosenFont: compactRoot.chosenFont
        callTitle: compactRoot.callTitle; callSubtitle: compactRoot.callSubtitle; callAvatar: compactRoot.callAvatar
        isCalling: compactRoot.isCalling
        visible: compactRoot.isCalling && !compactRoot.isExpanded
    }

    // 3. 桌面切换动画展示条
    CompactWorkspaceView {
        id: wsView
        anchors.centerIn: parent
        chosenFont: compactRoot.chosenFont
        wsName: compactRoot.wsName; wsTotal: compactRoot.wsTotal; displayWsNumber: compactRoot.displayWsNumber
        activeSlotIndex: Math.max(0, Math.min(compactRoot.displayWsNumber, compactRoot.wsTotal - 1))
        visible: compactRoot.activeTransient === "WORKSPACE" && !compactRoot.isCalling && !compactRoot.isExpanded
        opacity: visible ? 1.0 : 0.0
    }

    // 4. 🚀 灵动岛级硬件 OSD 滑轨（完整填充，饱满舒展）
    CompactOsdView {
        id: osdView
        anchors.fill: parent
        chosenFont: compactRoot.chosenFont
        osdIcon: compactRoot.osdIcon
        osdValue: compactRoot.osdValue
        visible: compactRoot.activeTransient === "OSD" && !compactRoot.isCalling && !compactRoot.isExpanded
        opacity: visible ? 1.0 : 0.0
        scale: visible ? 1.0 : 0.94
    }

    // 5. 通知弹窗横幅 (ALERT)
    CompactAlertView {
        id: alertView
        chosenFont: compactRoot.chosenFont
        alertTitle: compactRoot.alertTitle; alertSubtitle: compactRoot.alertSubtitle; alertAvatar: compactRoot.alertAvatar
        alertThemeColor: compactRoot.alertThemeColor
        isAlertActive: !compactRoot.isExpanded && compactRoot.isAlertActive
    }

    // 6. 常态时钟、网络与 ⇪ 大写锁指示行
    CompactClockView {
        id: clockView
        anchors.centerIn: parent
        chosenFont: compactRoot.chosenFont
        isCapsLock: compactRoot.isCapsLock; showNetSpeed: compactRoot.showNetSpeed
        downCompact: compactRoot.downCompact; upCompact: compactRoot.upCompact
        displayDate: compactRoot.displayDate; displayTime: compactRoot.displayTime; displaySeconds: compactRoot.displaySeconds; displayPeriod: compactRoot.displayPeriod
        isClockActive: (!compactRoot.isExpanded && compactRoot.activeTransient === "" && !compactRoot.isCalling)
    }
}