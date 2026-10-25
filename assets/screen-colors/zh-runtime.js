// Display-only localization by RenAmamiya; original backend and controls unchanged.
const renkitScreenColorsZh = __SCREEN_COLORS_ZH__;
function t(key) { return renkitScreenColorsZh[key] ?? key; }
function renkitScreenDetail(value) {
    if (value === "sin probar") return "尚未检查游戏模式。";
    if (typeof value === "string" && value.startsWith("sin socket gamescope en "))
        return "未找到游戏模式的画面连接，请返回游戏模式后再试。";
    const result = typeof value === "string" && value.match(/^socket=.* version rc=(-?\d+)$/);
    if (result) return `游戏模式连接检查未通过（返回值 ${result[1]}）。`;
    return "暂时无法调整屏幕色彩，请重新进入游戏模式后重试。";
}
function renkitScreenTitle(original) {
    return SP_JSX.jsxs("div", { children: [original, SP_JSX.jsx("div", {
        style: { color: "#ffcc66", fontSize: "12px", fontWeight: "bold", lineHeight: "18px" },
        children: "RenAmamiya汉化"
    })] });
}
