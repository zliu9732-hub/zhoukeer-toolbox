// Only display properties are translated. Backend IDs, values and callbacks stay untouched.
const renkitAyaneo3Zh = __RENKIT_AYANEO3_TRANSLATIONS__;
function renkitAyaneo3Text(value, depth = 0) {
    if (typeof value !== "string" || depth > 3) return value;
    if (Object.prototype.hasOwnProperty.call(renkitAyaneo3Zh.strings, value))
        return renkitAyaneo3Zh.strings[value];
    for (const [pattern, replacement, translateGroups = []] of renkitAyaneo3Zh.patterns) {
        const match = value.match(new RegExp(pattern));
        if (match) return replacement.replace(/\$(\d)/g, (_, i) => translateGroups.includes(Number(i))
            ? renkitAyaneo3Text(match[Number(i)], depth + 1) : match[Number(i)]);
    }
    return value;
}
function renkitAyaneo3Children(value) {
    if (Array.isArray(value)) return value.map(renkitAyaneo3Children);
    return renkitAyaneo3Text(value);
}
function renkitAyaneo3Props(type, original) {
    if (!original || type === "style" || type === "script") return original;
    const props = { ...original };
    for (const key of ["label", "title", "description", "placeholder", "tooltip", "aria-label", "statusNote", "strTitle", "strDescription", "strOKButtonText", "strCancelButtonText"])
        if (typeof props[key] === "string") props[key] = renkitAyaneo3Text(props[key]);
    if ("children" in props) props.children = renkitAyaneo3Children(props.children);
    if (Array.isArray(props.rgOptions)) props.rgOptions = props.rgOptions.map(item =>
        item && typeof item === "object" ? { ...item, label: renkitAyaneo3Text(item.label) } : item);
    return props;
}
const RenkitAyaneo3JSX = {
    jsx: (type, props, ...rest) => SP_JSX.jsx(type, renkitAyaneo3Props(type, props), ...rest),
    jsxs: (type, props, ...rest) => SP_JSX.jsxs(type, renkitAyaneo3Props(type, props), ...rest),
    toast: (payload, ...rest) => toaster.toast({ ...payload, title: renkitAyaneo3Text(payload.title), body: renkitAyaneo3Text(payload.body) }, ...rest),
    title: (original) => SP_JSX.jsxs("div", { children: [original, SP_JSX.jsx("div", {
        style: { color: "#ffcc66", fontSize: "12px", fontWeight: "bold", lineHeight: "18px" },
        children: "RenAmamiya汉化"
    })] })
};
