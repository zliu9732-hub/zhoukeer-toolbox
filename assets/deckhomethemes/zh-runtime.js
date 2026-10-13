// Renkit 的界面翻译层：不修改主题 ID、后端方法、文件名或用户保存的数据。
const renkitThemeHubZh = __RENKIT_THEMEHUB_TRANSLATIONS__;
function renkitThemeHubText(value) {
    if (typeof value !== "string") return value;
    if (Object.prototype.hasOwnProperty.call(renkitThemeHubZh.strings, value))
        return renkitThemeHubZh.strings[value];
    // 只有已审阅的界面前缀会参与替换；服务器原始内容和游戏名称不作全文翻译。
    for (const [prefix, translated] of Object.entries(renkitThemeHubZh.fragments)) {
        if (value.startsWith(prefix)) return translated + value.slice(prefix.length);
    }
    return value;
}
function renkitThemeHubChildren(value) {
    if (Array.isArray(value)) return value.map(renkitThemeHubChildren);
    if (typeof value !== "string") return value;
    return renkitThemeHubZh.children[value] || renkitThemeHubText(value);
}
function renkitThemeHubProps(type, original) {
    if (!original || type === "style" || type === "script") return original;
    const props = { ...original };
    for (const key of ["label", "title", "description", "placeholder", "tooltip", "aria-label", "sOperationText", "strTitle", "strDescription", "strOKButtonText", "strCancelButtonText"])
        if (typeof props[key] === "string") props[key] = renkitThemeHubText(props[key]);
    if ("children" in props) props.children = renkitThemeHubChildren(props.children);
    const options = (items) => items.map(item => {
        if (!item || typeof item !== "object") return item;
        const copy = { ...item };
        if (typeof copy.label === "string") copy.label = renkitThemeHubText(copy.label);
        if (Array.isArray(copy.options)) copy.options = options(copy.options);
        return copy;
    });
    if (Array.isArray(props.rgOptions)) props.rgOptions = options(props.rgOptions);
    return props;
}
const RenkitThemeHubJSX = {
    jsx: (type, props, ...rest) => SP_JSX.jsx(type, renkitThemeHubProps(type, props), ...rest),
    jsxs: (type, props, ...rest) => SP_JSX.jsxs(type, renkitThemeHubProps(type, props), ...rest),
};
