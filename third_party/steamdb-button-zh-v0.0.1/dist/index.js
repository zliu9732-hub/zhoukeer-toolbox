const manifest = {"name":"SteamDB 游戏数据"};
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
const call = api.call;
const fetchNoCors = api.fetchNoCors;
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
function _objectWithoutProperties(source, excluded) { if (source == null) return {}; var target = _objectWithoutPropertiesLoose(source, excluded); var key, i; if (Object.getOwnPropertySymbols) { var sourceSymbolKeys = Object.getOwnPropertySymbols(source); for (i = 0; i < sourceSymbolKeys.length; i++) { key = sourceSymbolKeys[i]; if (excluded.indexOf(key) >= 0) continue; if (!Object.prototype.propertyIsEnumerable.call(source, key)) continue; target[key] = source[key]; } } return target; }
function _objectWithoutPropertiesLoose(source, excluded) { if (source == null) return {}; var target = {}; for (var key in source) { if (Object.prototype.hasOwnProperty.call(source, key)) { if (excluded.indexOf(key) >= 0) continue; target[key] = source[key]; } } return target; }
function _extends() { _extends = Object.assign ? Object.assign.bind() : function (target) { for (var i = 1; i < arguments.length; i++) { var source = arguments[i]; for (var key in source) { if (Object.prototype.hasOwnProperty.call(source, key)) { target[key] = source[key]; } } } return target; }; return _extends.apply(this, arguments); }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), true).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(obj, key, value) { key = _toPropertyKey(key); if (key in obj) { Object.defineProperty(obj, key, { value: value, enumerable: true, configurable: true, writable: true }); } else { obj[key] = value; } return obj; }
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
    var {
        attr,
        size,
        title
      } = props,
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
function FaDollarSign (props) {
  return GenIcon({"attr":{"viewBox":"0 0 288 512"},"child":[{"tag":"path","attr":{"d":"M209.2 233.4l-108-31.6C88.7 198.2 80 186.5 80 173.5c0-16.3 13.2-29.5 29.5-29.5h66.3c12.2 0 24.2 3.7 34.2 10.5 6.1 4.1 14.3 3.1 19.5-2l34.8-34c7.1-6.9 6.1-18.4-1.8-24.5C238 74.8 207.4 64.1 176 64V16c0-8.8-7.2-16-16-16h-32c-8.8 0-16 7.2-16 16v48h-2.5C45.8 64-5.4 118.7.5 183.6c4.2 46.1 39.4 83.6 83.8 96.6l102.5 30c12.5 3.7 21.2 15.3 21.2 28.3 0 16.3-13.2 29.5-29.5 29.5h-66.3C100 368 88 364.3 78 357.5c-6.1-4.1-14.3-3.1-19.5 2l-34.8 34c-7.1 6.9-6.1 18.4 1.8 24.5 24.5 19.2 55.1 29.9 86.5 30v48c0 8.8 7.2 16 16 16h32c8.8 0 16-7.2 16-16v-48.2c46.6-.9 90.3-28.6 105.7-72.7 21.5-61.6-14.6-124.8-72.5-141.7z"},"child":[]}]})(props);
}

const DEFAULT_SETTINGS = {
    enabled: true,
    storePosition: "bc",
};
let currentSettings = DEFAULT_SETTINGS;
const settingsListeners = new Set();
function setSettings(next) {
    currentSettings = next;
    settingsListeners.forEach((listener) => listener(next));
}
async function loadSettings() {
    const settings = await call("get_setting", "settings", DEFAULT_SETTINGS);
    setSettings({ ...DEFAULT_SETTINGS, ...settings });
}
async function saveSettings(next) {
    setSettings(next);
    await call("set_setting", "settings", next);
    if (storeMounted) {
        if (!next.enabled) {
            storeRemoveButton();
        }
        else if (storeAppId) {
            storeInjectButton(storeAppId);
        }
    }
}
function useSettingsState() {
    const [settings, setState] = SP_REACT.useState(currentSettings);
    SP_REACT.useEffect(() => {
        const listener = (next) => setState(next);
        settingsListeners.add(listener);
        return () => {
            settingsListeners.delete(listener);
        };
    }, []);
    return settings;
}
function getSteamDbUrl(appId, section) {
    const parsed = Number(appId);
    if (!Number.isInteger(parsed) || parsed <= 0) {
        throw new Error("Invalid appid");
    }
    return section === "pricehistory"
        ? `https://steamdb.info/app/${parsed}/#pricehistory`
        : `https://steamdb.info/app/${parsed}/charts/`;
}
function SettingsPanel() {
    const settings = useSettingsState();
    return (SP_JSX.jsxs(DFL.PanelSection, { title: "SteamDB \u6E38\u620F\u6570\u636E", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "\u5728\u5546\u5E97\u9875\u663E\u793A\u6309\u94AE", checked: settings.enabled, onChange: (enabled) => void saveSettings({ ...settings, enabled }) }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.DropdownItem, { label: "\u6309\u94AE\u4F4D\u7F6E", menuLabel: "\u6309\u94AE\u4F4D\u7F6E", rgOptions: [
                        { data: 0, label: "左上" },
                        { data: 1, label: "顶部居中" },
                        { data: 2, label: "右上" },
                        { data: 3, label: "左下" },
                        { data: 4, label: "底部居中" },
                        { data: 5, label: "右下" },
                    ], selectedOption: { tl: 0, tc: 1, tr: 2, bl: 3, bc: 4, br: 5 }[settings.storePosition], onChange: (newVal) => {
                        const storePosition = { 0: "tl", 1: "tc", 2: "tr", 3: "bl", 4: "bc", 5: "br" }[newVal.data];
                        void saveSettings({ ...settings, storePosition });
                    } }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: { fontSize: "12px", opacity: 0.72 }, children: "\u53EF\u6253\u5F00 SteamDB \u67E5\u770B\u4EF7\u683C\u53F2\u4F4E\u548C\u5728\u7EBF\u4EBA\u6570\u5CF0\u503C\u3002\u6C49\u5316\uFF1ARenAmamiya" }) })] }));
}
const STORE_HOST = "store.steampowered.com";
const STORE_BUTTON_ID = "steamdb-store-button";
const STORE_DEBUGGER_TABS_URL = "http://localhost:8080/json";
const StoreHistoryModule = DFL.findModuleExport((exp) => exp?.m_history !== undefined);
const StoreHistory = StoreHistoryModule?.m_history;
let storeMounted = false;
let storeAppId = "";
let storeRuntimeReady = false;
let storeWebSocket = null;
let storeMessageId = 1;
function storeEvaluate(script) {
    if (!storeWebSocket || storeWebSocket.readyState !== WebSocket.OPEN || !storeRuntimeReady) {
        return;
    }
    storeWebSocket.send(JSON.stringify({
        id: storeMessageId++,
        method: "Runtime.evaluate",
        params: { expression: script },
    }));
}
function storeRemoveButton() {
    storeEvaluate(`(function(){const node=document.getElementById('${STORE_BUTTON_ID}');if(node){node.remove();}})();`);
}
function storeGetPosition() {
    switch (currentSettings.storePosition) {
        case "tl": return "top: 60px; left: 20px;";
        case "tr": return "top: 60px; right: 20px;";
        case "bl": return "bottom: 20px; left: 20px;";
        case "br": return "bottom: 20px; right: 20px;";
        case "tc": return "top: 60px; left: 50%; transform: translateX(-50%);";
        default: return "bottom: 20px; left: 50%; transform: translateX(-50%);";
    }
}
function storeInjectButton(appId) {
    if (!currentSettings.enabled) {
        storeRemoveButton();
        return;
    }
    let priceUrl;
    let chartsUrl;
    try {
        priceUrl = getSteamDbUrl(appId, "pricehistory");
        chartsUrl = getSteamDbUrl(appId, "charts");
    }
    catch {
        storeRemoveButton();
        return;
    }
    const script = `
    (function(){
      const existing=document.getElementById('${STORE_BUTTON_ID}');
      if(existing){existing.remove();}
      const wrapper=document.createElement('div');
      wrapper.id='${STORE_BUTTON_ID}';
      wrapper.style.cssText='position:fixed;z-index:999999;display:flex;gap:8px;${storeGetPosition()}';
      const addButton=function(label,url,symbol){
        const button=document.createElement('div');
        button.tabIndex=-1;
        button.setAttribute('role','presentation');
        button.setAttribute('aria-hidden','true');
        button.innerHTML='<span style="display:inline-flex;align-items:center;gap:6px;padding:6px 12px;border-radius:6px;background:#5ba32b;border:1px solid #5ba32b;color:#ffffff;font-weight:600;font-size:14px;cursor:pointer;"><span>'+symbol+'</span><span>'+label+'</span><span style="font-size:12px;opacity:0.5;">↗</span></span>';
        button.style.cssText='display:inline-block;cursor:pointer;';
        button.onclick=function(){window.open(url,'_blank');};
        wrapper.appendChild(button);
      };
      addButton('价格史低','${priceUrl}','$');
      addButton('在线峰值','${chartsUrl}','●');
      document.body.appendChild(wrapper);
    })();
  `;
    storeEvaluate(script);
}
function storeSyncButtonWithUrl(url) {
    const appId = url.includes(STORE_HOST) ? url.match(/\/app\/(\d+)(?:\/|$)/)?.[1] ?? "" : "";
    storeAppId = appId;
    if (!appId) {
        storeRemoveButton();
        return;
    }
    storeInjectButton(appId);
}
async function storeConnectToDebugger(retries = 3) {
    if (!storeMounted || retries <= 0)
        return;
    try {
        const response = await fetchNoCors(STORE_DEBUGGER_TABS_URL);
        if (!response.ok)
            throw new Error("debugger tabs unavailable");
        const tabs = (await response.json());
        const storeTab = tabs.find((tab) => tab.url.includes(STORE_HOST) && tab.webSocketDebuggerUrl);
        if (!storeTab?.webSocketDebuggerUrl) {
            setTimeout(() => void storeConnectToDebugger(retries - 1), 1000);
            return;
        }
        storeSyncButtonWithUrl(storeTab.url);
        storeWebSocket = new WebSocket(storeTab.webSocketDebuggerUrl);
        storeWebSocket.onopen = (event) => {
            const socket = event.target;
            if (!(socket instanceof WebSocket))
                return;
            socket.send(JSON.stringify({ id: storeMessageId++, method: "Page.enable" }));
            socket.send(JSON.stringify({ id: storeMessageId++, method: "Runtime.enable" }));
            setTimeout(() => {
                storeRuntimeReady = true;
                if (storeAppId)
                    storeInjectButton(storeAppId);
            }, 250);
        };
        storeWebSocket.onmessage = (event) => {
            if (!storeMounted)
                return;
            try {
                const payload = JSON.parse(event.data);
                if (payload.method !== "Page.frameNavigated")
                    return;
                const params = payload.params;
                const frame = params?.frame;
                const frameUrl = typeof frame?.url === "string" ? frame.url : "";
                if (!frameUrl)
                    return;
                setTimeout(() => storeSyncButtonWithUrl(frameUrl), 350);
            }
            catch {
                // ignore
            }
        };
        storeWebSocket.onclose = () => {
            storeRuntimeReady = false;
            storeWebSocket = null;
            if (storeMounted)
                setTimeout(() => void storeConnectToDebugger(), 1000);
        };
        storeWebSocket.onerror = () => {
            if (storeMounted)
                setTimeout(() => void storeConnectToDebugger(), 1000);
        };
    }
    catch {
        if (storeMounted)
            setTimeout(() => void storeConnectToDebugger(retries - 1), 1000);
    }
}
function storeDisconnectDebugger() {
    storeRemoveButton();
    storeMounted = false;
    storeAppId = "";
    storeRuntimeReady = false;
    if (storeWebSocket) {
        storeWebSocket.close();
        storeWebSocket = null;
    }
}
function storeHandlePathChange(pathname) {
    if (pathname === "/steamweb") {
        if (!storeMounted) {
            storeMounted = true;
            void storeConnectToDebugger();
        }
        else if (!storeWebSocket || storeWebSocket.readyState !== WebSocket.OPEN) {
            void storeConnectToDebugger();
        }
        return;
    }
    if (storeMounted) {
        storeDisconnectDebugger();
    }
}
var index = definePlugin(() => {
    void loadSettings();
    let stopStoreWatcher = () => { };
    if (StoreHistory) {
        storeHandlePathChange(StoreHistory.location?.pathname || window.location.pathname);
        const unlisten = StoreHistory.listen((location) => {
            const pathname = typeof location === "object" && location !== null && "pathname" in location
                ? String(location.pathname ?? "")
                : "";
            if (pathname)
                storeHandlePathChange(pathname);
        });
        setTimeout(() => storeHandlePathChange(window.location.pathname), 250);
        stopStoreWatcher = () => {
            unlisten();
            storeDisconnectDebugger();
        };
    }
    return {
        name: "steamdbDeckyPlugin",
        title: SP_JSX.jsx("div", { className: DFL.staticClasses.Title, children: "SteamDB \u6E38\u620F\u6570\u636E" }),
        icon: SP_JSX.jsx(FaDollarSign, {}),
        content: SP_JSX.jsx(SettingsPanel, {}),
        onDismount() {
            stopStoreWatcher();
        },
    };
});

export { index as default };
//# sourceMappingURL=index.js.map
