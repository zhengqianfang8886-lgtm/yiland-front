// ==========================================
// 📄 File: process/ProcessUtils.js
// 🌟 统一技术栈图标与进程工具库
// ==========================================
.pragma library

function getTechIcon(cmd, name) {
    var c = (cmd || "").toLowerCase()
    var n = (name || "").toLowerCase()
    if (c.indexOf("python") !== -1 || n.indexOf("py") !== -1) return "🐍"
    if (c.indexOf("cargo") !== -1 || c.indexOf("rust") !== -1 || c.indexOf("tauri") !== -1) return "🦀"
    if (c.indexOf("npm") !== -1 || c.indexOf("node") !== -1 || c.indexOf("vite") !== -1 || c.indexOf("yarn") !== -1 || c.indexOf("pnpm") !== -1) return "⬢"
    if (c.indexOf("docker") !== -1) return "🐳"
    if (c.indexOf("go ") !== -1 || n.indexOf("go") !== -1) return "🐹"
    if (c.indexOf("mac-engine") !== -1 || n.indexOf("engine") !== -1) return "⚙️"
    return "⚡"
}