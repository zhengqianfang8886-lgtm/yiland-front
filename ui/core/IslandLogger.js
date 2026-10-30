// =========================================================================
// 📄 File: ui/core/IslandLogger.js
// 🌟 统一日志驱动遥测引擎 (结构化时标 · 模块徽章 · 级别过滤)
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
    console.log("[" + _timestamp() + "] ⚡ [ACTION_BUS] 触发业务动作 -> " + actionName + " | " + message);
}