// =========================================================================
// 📄 File: ui/core/IslandPluginRegistry.js
// 🌟 展开态卡片页面插件化注册协议 (可扩展架构)
// =========================================================================
.pragma library

var _plugins = [];

function registerPlugin(pluginDef) {
    if (!pluginDef.id || !pluginDef.title || !pluginDef.componentUrl) {
        console.error("[PluginRegistry] 注册失败: 缺少核心字段 (id, title, componentUrl)");
        return;
    }

    for (var i = 0; i < _plugins.length; i++) {
        if (_plugins[i].id === pluginDef.id) {
            _plugins[i] = pluginDef;
            return;
        }
    }

    _plugins.push({
        id: pluginDef.id,
        title: pluginDef.title,
        icon: pluginDef.icon || "📌",
        color: pluginDef.color || "#ffffff",
        componentUrl: pluginDef.componentUrl,
        defaultEnabled: pluginDef.defaultEnabled !== false
    });
}

function getEnabledPlugins(orderList, switchMap) {
    var list = [];
    var order = orderList || [];

    for (var i = 0; i < order.length; i++) {
        var key = order[i];
        if (switchMap && switchMap[key] === false) continue;

        for (var j = 0; j < _plugins.length; j++) {
            if (_plugins[j].id === key) {
                list.push(_plugins[j]);
                break;
            }
        }
    }
    return list;
}