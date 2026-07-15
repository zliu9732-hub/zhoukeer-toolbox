const manifest = {"name":"周克儿汉化"};
const API_VERSION = 2;
const internalAPIConnection = window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit;
if (!internalAPIConnection) {
    throw new Error('[@decky/api]: Failed to connect to the loader as as the loader API was not initialized. This is likely a bug in Decky Loader.');
}
let api;
try {
    api = internalAPIConnection.connect(API_VERSION, manifest.name);
}
catch {
    api = internalAPIConnection.connect(1, manifest.name);
    console.warn(`[@decky/api] Requested API version ${API_VERSION} but the running loader only supports version 1. Some features may not work.`);
}
if (api._version != API_VERSION) {
    console.warn(`[@decky/api] Requested API version ${API_VERSION} but the running loader only supports version ${api._version}. Some features may not work.`);
}
const toaster = api.toaster;
const definePlugin = (fn) => {
    return (...args) => {
        return fn(...args);
    };
};

var DefaultContext = {
  color: undefined,
  size: undefined,
  className: undefined,
  style: undefined,
  attr: undefined
};
var IconContext = SP_REACT.createContext && /*#__PURE__*/SP_REACT.createContext(DefaultContext);

var _excluded = ["attr", "size", "title"];
function _objectWithoutProperties(e, t) { if (null == e) return {}; var o, r, i = _objectWithoutPropertiesLoose(e, t); if (Object.getOwnPropertySymbols) { var n = Object.getOwnPropertySymbols(e); for (r = 0; r < n.length; r++) o = n[r], -1 === t.indexOf(o) && {}.propertyIsEnumerable.call(e, o) && (i[o] = e[o]); } return i; }
function _objectWithoutPropertiesLoose(r, e) { if (null == r) return {}; var t = {}; for (var n in r) if ({}.hasOwnProperty.call(r, n)) { if (-1 !== e.indexOf(n)) continue; t[n] = r[n]; } return t; }
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), true).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: true, configurable: true, writable: true }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == typeof i ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != typeof t || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r); if ("object" != typeof i) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
function Tree2Element(tree) {
  return tree && tree.map((node, i) => /*#__PURE__*/SP_REACT.createElement(node.tag, _objectSpread({
    key: i
  }, node.attr), Tree2Element(node.child)));
}
function GenIcon(data) {
  return props => /*#__PURE__*/SP_REACT.createElement(IconBase, _extends({
    attr: _objectSpread({}, data.attr)
  }, props), Tree2Element(data.child));
}
function IconBase(props) {
  var elem = conf => {
    var attr = props.attr,
      size = props.size,
      title = props.title,
      svgProps = _objectWithoutProperties(props, _excluded);
    var computedSize = size || conf.size || "1em";
    var className;
    if (conf.className) className = conf.className;
    if (props.className) className = (className ? className + " " : "") + props.className;
    return /*#__PURE__*/SP_REACT.createElement("svg", _extends({
      stroke: "currentColor",
      fill: "currentColor",
      strokeWidth: "0"
    }, conf.attr, attr, svgProps, {
      className: className,
      style: _objectSpread(_objectSpread({
        color: props.color || conf.color
      }, conf.style), props.style),
      height: computedSize,
      width: computedSize,
      xmlns: "http://www.w3.org/2000/svg"
    }), title && /*#__PURE__*/SP_REACT.createElement("title", null, title), props.children);
  };
  return IconContext !== undefined ? /*#__PURE__*/SP_REACT.createElement(IconContext.Consumer, null, conf => elem(conf)) : elem(DefaultContext);
}

// THIS FILE IS AUTO GENERATED
function FaLanguage (props) {
  return GenIcon({"attr":{"viewBox":"0 0 640 512"},"child":[{"tag":"path","attr":{"d":"M152.1 236.2c-3.5-12.1-7.8-33.2-7.8-33.2h-.5s-4.3 21.1-7.8 33.2l-11.1 37.5H163zM616 96H336v320h280c13.3 0 24-10.7 24-24V120c0-13.3-10.7-24-24-24zm-24 120c0 6.6-5.4 12-12 12h-11.4c-6.9 23.6-21.7 47.4-42.7 69.9 8.4 6.4 17.1 12.5 26.1 18 5.5 3.4 7.3 10.5 4.1 16.2l-7.9 13.9c-3.4 5.9-10.9 7.8-16.7 4.3-12.6-7.8-24.5-16.1-35.4-24.9-10.9 8.7-22.7 17.1-35.4 24.9-5.8 3.5-13.3 1.6-16.7-4.3l-7.9-13.9c-3.2-5.6-1.4-12.8 4.2-16.2 9.3-5.7 18-11.7 26.1-18-7.9-8.4-14.9-17-21-25.7-4-5.7-2.2-13.6 3.7-17.1l6.5-3.9 7.3-4.3c5.4-3.2 12.4-1.7 16 3.4 5 7 10.8 14 17.4 20.9 13.5-14.2 23.8-28.9 30-43.2H412c-6.6 0-12-5.4-12-12v-16c0-6.6 5.4-12 12-12h64v-16c0-6.6 5.4-12 12-12h16c6.6 0 12 5.4 12 12v16h64c6.6 0 12 5.4 12 12zM0 120v272c0 13.3 10.7 24 24 24h280V96H24c-13.3 0-24 10.7-24 24zm58.9 216.1L116.4 167c1.7-4.9 6.2-8.1 11.4-8.1h32.5c5.1 0 9.7 3.3 11.4 8.1l57.5 169.1c2.6 7.8-3.1 15.9-11.4 15.9h-22.9a12 12 0 0 1-11.5-8.6l-9.4-31.9h-60.2l-9.1 31.8c-1.5 5.1-6.2 8.7-11.5 8.7H70.3c-8.2 0-14-8.1-11.4-15.9z"},"child":[]}]})(props);
}

const AUTHOR_NOTICE = "闲鱼双叶汉化，请支持插件原作者";
// Keep every plugin's wording isolated so updates can be reviewed and released in small batches.
const TRANSLATIONS = [
    {
        plugin: "CSS Loader",
        chineseName: "CSS Loader（主题与界面美化）",
        strings: {
            "Themes": "主题",
            "Theme Loader": "主题加载器",
            "Settings": "设置"
        }
    },
    {
        plugin: "vibrantDeck",
        chineseName: "vibrantDeck（屏幕色彩）",
        strings: {
            "Saturation": "饱和度",
            "Display Settings": "屏幕设置",
            "Settings": "设置"
        }
    },
    {
        plugin: "Animation Changer",
        chineseName: "Animation Changer（开机与休眠动画）",
        strings: {
            "Boot Animation": "开机动画",
            "Suspend Animation": "休眠动画",
            "Settings": "设置"
        }
    },
    {
        plugin: "Audio Loader",
        chineseName: "Audio Loader（系统音效）",
        strings: {
            "Audio": "音效",
            "Sound Pack": "音效包",
            "Settings": "设置"
        }
    },
    {
        plugin: "SteamGridDB",
        chineseName: "SteamGridDB（游戏封面）",
        strings: {
            "Change Artwork": "更换封面",
            "Search": "搜索",
            "Settings": "设置"
        }
    },
    {
        plugin: "PowerTools",
        chineseName: "PowerTools（性能调校）",
        strings: {
            "CPU": "CPU",
            "GPU": "GPU",
            "Settings": "设置"
        }
    },
    {
        plugin: "Storage Cleaner",
        chineseName: "Storage Cleaner（缓存清理）",
        strings: {
            "Shader Cache": "着色器缓存",
            "Compatibility Data": "兼容数据",
            "Clean": "清理"
        }
    },
    {
        plugin: "Bluetooth",
        chineseName: "Bluetooth（蓝牙设备）",
        strings: {
            "Paired Devices": "已配对设备",
            "Connect": "连接",
            "Disconnect": "断开连接"
        }
    },
    {
        plugin: "ProtonDB Badges",
        chineseName: "ProtonDB Badges（兼容性标记）",
        strings: { "Rating": "评级", "Reports": "报告", "Settings": "设置" }
    },
    {
        plugin: "Deck Settings",
        chineseName: "Deck Settings（游戏设置推荐）",
        strings: { "Game Settings": "游戏设置", "Search": "搜索", "Settings": "设置" }
    },
    {
        plugin: "HLTB for Deck",
        chineseName: "HLTB for Deck（通关时长）",
        strings: { "HowLongToBeat": "通关时长", "Main Story": "主线流程", "Search": "搜索" }
    },
    {
        plugin: "PlayCount",
        chineseName: "PlayCount（在线人数）",
        strings: { "Players": "玩家人数", "Online": "在线", "Refresh": "刷新" }
    },
    {
        plugin: "TabMaster",
        chineseName: "TabMaster（库标签管理）",
        strings: { "Tabs": "标签页", "Library": "游戏库", "Settings": "设置" }
    },
    {
        plugin: "Game Theme Music",
        chineseName: "Game Theme Music（主题音乐）",
        strings: { "Theme Music": "主题音乐", "Enable": "启用", "Volume": "音量" }
    },
    {
        plugin: "Wine Cellar",
        chineseName: "Wine Cellar（Wine 管理）",
        strings: { "Versions": "版本", "Install": "安装", "Remove": "移除" }
    },
    {
        plugin: "Pause Games",
        chineseName: "Pause Games（暂停游戏）",
        strings: { "Pause": "暂停", "Resume": "继续", "Settings": "设置" }
    },
    {
        plugin: "Controller Tools",
        chineseName: "Controller Tools（控制器工具）",
        strings: { "Controller": "控制器", "Configure": "配置", "Settings": "设置" }
    },
    {
        plugin: "Volume Mixer",
        chineseName: "Volume Mixer（音量混音）",
        strings: { "Applications": "应用程序", "Mute": "静音", "Volume": "音量" }
    },
    {
        plugin: "Battery Tracker",
        chineseName: "Battery Tracker（电池记录）",
        strings: { "Battery": "电池", "History": "历史记录", "Clear": "清除" }
    },
    {
        plugin: "PlayTime",
        chineseName: "PlayTime（游戏时间）",
        strings: { "Play Time": "游戏时间", "Today": "今天", "Total": "总计" }
    },
    {
        plugin: "Free Loader",
        chineseName: "Free Loader（插件加载）",
        strings: { "Plugins": "插件", "Reload": "重新加载", "Settings": "设置" }
    },
    {
        plugin: "DeckMTP",
        chineseName: "DeckMTP（文件互传）",
        strings: { "Connected": "已连接", "Transfer": "传输", "Settings": "设置" }
    },
    {
        plugin: "MangoPeel",
        chineseName: "MangoPeel（性能监控）",
        strings: { "Performance": "性能", "Overlay": "浮层", "Settings": "设置" }
    },
    {
        plugin: "SimpleDeckyTDP",
        chineseName: "SimpleDeckyTDP（TDP 性能控制）",
        strings: { "TDP": "功耗墙", "Performance": "性能", "Apply": "应用" }
    },
    {
        plugin: "Unifideck",
        chineseName: "Unifideck（多平台游戏库）",
        strings: { "Libraries": "游戏库", "Refresh": "刷新", "Settings": "设置" }
    },
    {
        plugin: "LSFG-VK",
        chineseName: "LSFG-VK（小黄鸭帧生成）",
        strings: { "Frame Generation": "帧生成", "Enable": "启用", "Settings": "设置" }
    },
    {
        plugin: "Decky-Framegen",
        chineseName: "Decky-Framegen（FSR4 帧生成）",
        strings: { "Frame Generation": "帧生成", "Enable": "启用", "Settings": "设置" }
    },
    {
        plugin: "CheatDeck",
        chineseName: "CheatDeck（游戏辅助）",
        strings: { "Cheats": "辅助功能", "Enable": "启用", "Settings": "设置" }
    }
];
new Map(TRANSLATIONS.flatMap((entry) => [
    [entry.plugin, entry.chineseName],
    ...Object.entries(entry.strings)
]));

const ENABLED_KEY = "zhoukeer-localizer-enabled";
const FOOTER_ATTRIBUTE = "data-zhoukeer-localizer-footer";
const PLUGIN_ROOT_ATTRIBUTE = "data-zhoukeer-localizer-plugin";
const SKIP_TAGS = new Set(["SCRIPT", "STYLE", "TEXTAREA"]);
function readEnabled() {
    return localStorage.getItem(ENABLED_KEY) !== "false";
}
function writeEnabled(enabled) {
    localStorage.setItem(ENABLED_KEY, String(enabled));
}
function translateTextNode(node, strings) {
    const original = node.nodeValue;
    if (!original)
        return;
    const leading = original.match(/^\s*/)?.[0] ?? "";
    const trailing = original.match(/\s*$/)?.[0] ?? "";
    const translated = strings[original.trim()];
    if (translated)
        node.nodeValue = `${leading}${translated}${trailing}`;
}
function addAuthorFooter(title) {
    if (title.parentElement?.querySelector(`[${FOOTER_ATTRIBUTE}]`))
        return;
    const footer = document.createElement("div");
    footer.setAttribute(FOOTER_ATTRIBUTE, "true");
    footer.textContent = AUTHOR_NOTICE;
    footer.style.cssText = "font-size:11px;opacity:.62;margin-top:2px;line-height:1.35;";
    title.insertAdjacentElement("afterend", footer);
}
function translateTextIn(root, strings) {
    if (root instanceof Text) {
        if (!SKIP_TAGS.has(root.parentElement?.tagName ?? ""))
            translateTextNode(root, strings);
        return;
    }
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    while (walker.nextNode()) {
        const node = walker.currentNode;
        if (!SKIP_TAGS.has(node.parentElement?.tagName ?? ""))
            translateTextNode(node, strings);
    }
}
function findPluginRoot(title) {
    let candidate = title.parentElement;
    for (let level = 0; candidate && level < 6; level += 1, candidate = candidate.parentElement) {
        if (candidate.querySelector('[class*="PanelSectionRow"]'))
            return candidate;
    }
    return title.parentElement ?? title;
}
function activatePluginTitle(title, entry) {
    const pluginRoot = findPluginRoot(title);
    pluginRoot.setAttribute(PLUGIN_ROOT_ATTRIBUTE, entry.plugin);
    translateTextIn(pluginRoot, { [entry.plugin]: entry.chineseName, ...entry.strings });
    addAuthorFooter(title);
}
function findKnownPluginTitles(root) {
    if (!(root instanceof HTMLElement))
        return [];
    const candidates = [root, ...Array.from(root.querySelectorAll("*"))];
    return candidates.filter((element) => {
        const entry = TRANSLATIONS.find((item) => element.textContent?.trim() === item.plugin);
        return Boolean(entry) && !Array.from(element.children).some((child) => child.textContent?.trim() === entry?.plugin);
    });
}
function processNode(root) {
    const parent = root instanceof Text ? root.parentElement : root.parentElement;
    const activeRoot = parent?.closest(`[${PLUGIN_ROOT_ATTRIBUTE}]`);
    if (activeRoot) {
        const plugin = activeRoot.getAttribute(PLUGIN_ROOT_ATTRIBUTE);
        const entry = TRANSLATIONS.find((item) => item.plugin === plugin);
        if (entry)
            translateTextIn(root, entry.strings);
    }
    for (const title of findKnownPluginTitles(root)) {
        const entry = TRANSLATIONS.find((item) => item.plugin === title.textContent?.trim());
        if (entry)
            activatePluginTitle(title, entry);
    }
}
class TranslationEngine {
    observer;
    start() {
        if (this.observer || !readEnabled())
            return;
        processNode(document.body);
        this.observer = new MutationObserver((records) => {
            for (const record of records) {
                if (record.type === "characterData")
                    processNode(record.target);
                for (const node of record.addedNodes)
                    processNode(node);
            }
        });
        this.observer.observe(document.body, { childList: true, characterData: true, subtree: true });
    }
    stop() {
        this.observer?.disconnect();
        this.observer = undefined;
    }
    refresh(enabled) {
        writeEnabled(enabled);
        this.stop();
        if (enabled)
            this.start();
    }
}
const engine = new TranslationEngine();
function Content() {
    const [enabled, setEnabled] = SP_REACT.useState(readEnabled());
    const toggle = () => {
        const next = !enabled;
        setEnabled(next);
        engine.refresh(next);
        toaster.toast({
            title: "周克儿汉化",
            body: next ? "汉化层已启用。重新打开插件页面即可生效。" : "汉化层已暂停。"
        });
    };
    return (SP_JSX.jsxs(DFL.PanelSection, { title: "\u5468\u514B\u513F\u6C49\u5316", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: toggle, children: enabled ? "已启用，点击暂停" : "已暂停，点击启用" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: { fontSize: "12px", lineHeight: "1.45", opacity: 0.75 }, children: ["\u9996\u6279\u5DF2\u63A5\u5165 ", TRANSLATIONS.length, " \u4E2A\u63D2\u4EF6\u7684\u57FA\u7840\u8BCD\u5E93\u3002\u8BCD\u5E93\u4F1A\u968F\u5DE5\u5177\u7BB1\u66F4\u65B0\u6269\u5145\uFF0C\u4E0D\u4F1A\u6539\u5199\u539F\u63D2\u4EF6\u6587\u4EF6\u3002", SP_JSX.jsx("br", {}), AUTHOR_NOTICE] }) })] }));
}
var index = definePlugin(() => {
    engine.start();
    return {
        name: "周克儿汉化",
        titleView: SP_JSX.jsx("div", { className: DFL.staticClasses.Title, children: "\u5468\u514B\u513F\u6C49\u5316" }),
        content: SP_JSX.jsx(Content, {}),
        icon: SP_JSX.jsx(FaLanguage, {}),
        onDismount() {
            engine.stop();
        }
    };
});

export { index as default };
//# sourceMappingURL=index.js.map
