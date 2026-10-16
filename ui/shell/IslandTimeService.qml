import QtQuick

Item {
    id: timeService
    property bool isTucked: false

    property string displayDate: ""
    property string displayTime: "04:53"
    property string displaySeconds: ""
    property string displayPeriod: "pm"

    Timer {
        interval: 1000
        running: !timeService.isTucked
        repeat: true
        triggeredOnStart: true
        onTriggered: timeService.updateDateTime()
    }

    function updateDateTime() {
        var d = new Date(), h = d.getHours(), m = d.getMinutes(), s = d.getSeconds()
        if (typeof Config !== "undefined" && Config.showDate) {
            var days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            displayDate = (d.getMonth() + 1 < 10 ? "0" : "") + (d.getMonth() + 1) + "/" + (d.getDate() < 10 ? "0" : "") + d.getDate() + " " + days[d.getDay()]
        } else { displayDate = "" }

        displaySeconds = (typeof Config !== "undefined" && Config.showSeconds) ? (":" + (s < 10 ? "0" : "") + s) : ""

        if (typeof Config !== "undefined" && Config.timeFormat === "24h") {
            displayTime = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
            displayPeriod = ""
        } else {
            displayPeriod = h >= 12 ? "pm" : "am"
            h = h % 12; h = h ? h : 12
            displayTime = (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
        }
    }
}