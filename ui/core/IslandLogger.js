// =========================================================================
// 📄 File: ui/core/IslandLogger.js
// 🌟 统一日志驱动遥测引擎 (LDD 专职毫秒高精度探针版)
// =========================================================================
.pragma library

function _pad(num, size) {
    var s = num + "";
    while (s.length < size) s = "0" + s;
    return s;
}

function _timestamp() {
    var d = new Date();
    return _pad(d.getHours(), 2) + ":" + 
           _pad(d.getMinutes(), 2) + ":" + 
           _pad(d.getSeconds(), 2) + "." + 
           _pad(d.getMilliseconds(), 3);
}

function info(tag, message) {
    console.log("[" + _timestamp() + "] 💎 [" + tag.toUpperCase() + "] " + message);
}

function pipeline(tag, message) {
    console.log("[" + _timestamp() + "] 🧩 [PIPELINE::" + tag.toUpperCase() + "] " + message);
}

function gesture(tag, message) {
    console.log("[" + _timestamp() + "] 🎯 [GESTURE::" + tag.toUpperCase() + "] " + message);
}

function slot(slotName, state, message) {
    var icon = "⚪";
    if (state === "BUD") icon = "🚀";
    else if (state === "SETTLE") icon = "🟢";
    else if (state === "IMPLODE") icon = "💨";
    else if (state === "DISMISS") icon = "⚪";
    console.log("[" + _timestamp() + "] " + icon + " [SLOT::" + slotName.toUpperCase() + "] " + message);
}

function action(actionName, message) {
    console.log("[" + _timestamp() + "] ⚡ [ACTION_BUS] " + actionName + " | " + message);
}

// 🚀【LDD 专属几何探针】：高亮打印引发重排的尺寸跳变
function geom(tag, source, targetW, actualW, extra) {
    var ext = extra ? (" | " + extra) : "";
    console.log("\x1b[36m[" + _timestamp() + "] 📐 [GEOM::" + tag + "]\x1b[0m " + source + " -> 目标宽: " + targetW + "px, 实体宽: " + actualW + "px" + ext);
}

// 🚀【LDD 专属跳变警报】：捕获二次重排
function jitter(tag, reason, beforeVal, afterVal) {
    console.log("\x1b[31;1m[" + _timestamp() + "] ⚠️ [JITTER-ALERT::" + tag + "]\x1b[0m " + reason + " (前值: " + beforeVal + " -> 现值: " + afterVal + ")");
}