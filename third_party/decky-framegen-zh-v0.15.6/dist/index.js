// Decky Loader will pass this api in, it's versioned to allow for backwards compatibility.
// @ts-ignore

// Prevents it from being duplicated in output.
const manifest = {"name":"FSR4","author":"Kurt Himebauch","flags":[],"api_version":1,"publish":{"tags":["DLSS","Framegen","upscaling","FSR"],"description":"汉化：闲鱼双叶。管理 OptiScaler，为 DirectX 12 游戏提供超分辨率与插帧支持。","image":"https://raw.githubusercontent.com/xXJSONDeruloXx/Decky-Framegen/refs/heads/main/assets/optiscaler_final.png"}};
const API_VERSION = 2;
const internalAPIConnection = window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit;
// Initialize
if (!internalAPIConnection) {
    throw new Error('[@decky/api]: Failed to connect to the loader as as the loader API was not initialized. This is likely a bug in Decky Loader.');
}
// Version 1 throws on version mismatch so we have to account for that here.
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
const callable = api.callable;
const toaster = api.toaster;
const openFilePicker = api.openFilePicker;
const definePlugin = (fn) => {
    return (...args) => {
        // TODO: Maybe wrap this
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
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), !0).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(obj, key, value) { key = _toPropertyKey(key); if (key in obj) { Object.defineProperty(obj, key, { value: value, enumerable: true, configurable: true, writable: true }); } else { obj[key] = value; } return obj; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == typeof i ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != typeof t || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r || "default"); if ("object" != typeof i) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
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
function MdOutlineAutoAwesomeMotion (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 24 24"},"child":[{"tag":"path","attr":{"fill":"none","d":"M0 0h24v24H0z"},"child":[]},{"tag":"path","attr":{"d":"M14 2H4c-1.1 0-2 .9-2 2v10h2V4h10V2zm4 4H8c-1.1 0-2 .9-2 2v10h2V8h10V6zm2 4h-8c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2v-8c0-1.1-.9-2-2-2zm0 10h-8v-8h8v8z"},"child":[]}]})(props);
}

const runInstallFGMod = callable("run_install_fgmod");
const runUninstallFGMod = callable("run_uninstall_fgmod");
const setDefaultFsr4Variant = callable("set_default_fsr4_variant");
const checkFGModPath = callable("check_fgmod_path");
const listInstalledGames = callable("list_installed_games");
const logError = callable("log_error");
const getPathDefaults = callable("get_path_defaults");
const runManualPatch = callable("manual_patch_directory");
const runManualUnpatch = callable("manual_unpatch_directory");
const getGameStatus = callable("get_game_status");
const patchGame = callable("patch_game");
const unpatchGame = callable("unpatch_game");

/**
 * Utility for creating a timer that automatically clears after specified timeout
 * @param callback Function to call when timer completes
 * @param timeout Timeout in milliseconds
 * @returns Cleanup function that can be used in useEffect
 */
const createAutoCleanupTimer = (callback, timeout) => {
    const timer = setTimeout(callback, timeout);
    return () => clearTimeout(timer);
};
/**
 * Safe wrapper for async operations to handle errors consistently
 * @param operation Async operation to perform
 * @param errorContext Context string for error logging
 */
const safeAsyncOperation = async (operation, errorContext) => {
    try {
        return await operation();
    }
    catch (e) {
        logError(`${errorContext}: ${String(e)}`);
        console.error(e);
        return undefined;
    }
};

// Common types for the application
// Common style definitions
const STYLES = {
    resultBox: {
        padding: '12px',
        marginTop: '16px',
        backgroundColor: 'var(--decky-selected-ui-bg)',
        borderRadius: '8px',
        border: '1px solid var(--decky-border-color)',
        fontSize: '14px'
    },
    statusInstalled: {
        color: '#22c55e',
        fontWeight: 'bold',
        fontSize: '14px'
    },
    statusNotInstalled: {
        color: '#f97316',
        fontWeight: 'bold',
        fontSize: '14px'
    },
    statusSuccess: { color: "#22c55e" },
    statusError: { color: "#ef4444" },
    preWrap: { whiteSpace: "pre-wrap" },
    instructionCard: {
        padding: '14px',
        backgroundColor: 'var(--decky-selected-ui-bg)',
        borderRadius: '8px',
        border: '1px solid var(--decky-border-color)',
        marginTop: '8px',
        fontSize: '13px',
        lineHeight: '1.4'
    }
};
// Proxy DLL name options for OptiScaler injection
const PROXY_DLL_OPTIONS = [
    { value: "dxgi.dll", label: "dxgi.dll（默认）", hint: "适用于大多数 DX12 游戏。" },
    { value: "winmm.dll", label: "winmm.dll", hint: "当 dxgi.dll 与游戏已有文件冲突时使用。" },
    { value: "version.dll", label: "version.dll", hint: "常用备用项，适配许多启动器。" },
    { value: "dbghelp.dll", label: "dbghelp.dll", hint: "用于调试辅助挂钩路径。" },
    { value: "winhttp.dll", label: "winhttp.dll", hint: "其他 DLL 名称冲突时使用。" },
    { value: "wininet.dll", label: "wininet.dll", hint: "其他 DLL 名称冲突时使用。" },
    { value: "OptiScaler.asi", label: "OptiScaler.asi", hint: "用于 ASI 加载器；游戏需已安装 ASI 加载器。" },
];
const DEFAULT_PROXY_DLL = "dxgi.dll";
const FSR4_VARIANT_OPTIONS = [
    {
        value: "rdna23-int8",
        label: "Steam Deck / RDNA2-3 优化版",
        hint: "使用内置 FSR4 INT8 4.0.2c，推荐 Steam Deck 与其他非 RDNA4 设备。",
    },
    {
        value: "rdna4-native",
        label: "原生组件 / RDNA4",
        hint: "使用 OptiScaler 0.9.2a 组件内附的 amd_fidelityfx_upscaler_dx12.dll。",
    },
];
const DEFAULT_FSR4_VARIANT = "rdna23-int8";
// Common timeout values
const TIMEOUTS = {
    resultDisplay: 5000, // 5 seconds
    pathCheck: 3000 // 3 seconds
};
// Message strings
const MESSAGES = {
    modInstalled: "OptiScaler 模组已安装",
    modNotInstalled: "OptiScaler 模组未安装",
    installing: "正在安装 OptiScaler…",
    installButton: "安装 OptiScaler 模组",
    uninstalling: "正在移除 OptiScaler…",
    uninstallButton: "移除 OptiScaler 模组",
    installSuccess: "OptiScaler 模组安装成功！",
    uninstallSuccess: "OptiScaler 模组已移除。",
    instructionTitle: "使用说明：",
    instructionText: "标准方式请使用“复制启动选项”。如需包装器命令，请开启手动模式以显示“复制修补命令”和“复制撤销修补命令”。\n\n游戏内：在图形设置中启用 DLSS，以在 DirectX 12 游戏中使用 FSR 3.1/XeSS 2.0。\n\n如需更多 OptiScaler 选项，可将一个背键映射为键盘 Insert 键。"
};

function InstallationStatus({ pathExists, installing, onInstallClick }) {
    if (pathExists !== false)
        return null;
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { style: STYLES.statusNotInstalled }, MESSAGES.modNotInstalled)),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: onInstallClick, disabled: installing }, installing ? MESSAGES.installing : MESSAGES.installButton))));
}

var optiScalerImage = 'http://127.0.0.1:1337/plugins/FSR4/assets/header-banner-891a8a50.png';

function OptiScalerHeader({ pathExists }) {
    if (pathExists !== true)
        return null;
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement("div", { style: {
                display: 'flex',
                justifyContent: 'center',
                marginBottom: '16px'
            } },
            window.SP_REACT.createElement("img", { src: optiScalerImage, alt: "OptiScaler", style: {
                    maxWidth: '100%',
                    height: 'auto',
                    borderRadius: '8px'
                } }))));
}

// THIS FILE IS AUTO GENERATED
function FaBook (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 448 512"},"child":[{"tag":"path","attr":{"d":"M448 360V24c0-13.3-10.7-24-24-24H96C43 0 0 43 0 96v320c0 53 43 96 96 96h328c13.3 0 24-10.7 24-24v-16c0-7.5-3.5-14.3-8.9-18.7-4.2-15.4-4.2-59.3 0-74.7 5.4-4.3 8.9-11.1 8.9-18.6zM128 134c0-3.3 2.7-6 6-6h212c3.3 0 6 2.7 6 6v20c0 3.3-2.7 6-6 6H134c-3.3 0-6-2.7-6-6v-20zm0 64c0-3.3 2.7-6 6-6h212c3.3 0 6 2.7 6 6v20c0 3.3-2.7 6-6 6H134c-3.3 0-6-2.7-6-6v-20zm253.4 250H96c-17.7 0-32-14.3-32-32 0-17.6 14.4-32 32-32h285.4c-1.9 17.1-1.9 46.9 0 64z"},"child":[]}]})(props);
}function FaCheck (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 512 512"},"child":[{"tag":"path","attr":{"d":"M173.898 439.404l-166.4-166.4c-9.997-9.997-9.997-26.206 0-36.204l36.203-36.204c9.997-9.998 26.207-9.998 36.204 0L192 312.69 432.095 72.596c9.997-9.997 26.207-9.997 36.204 0l36.203 36.204c9.997 9.997 9.997 26.206 0 36.204l-294.4 294.401c-9.998 9.997-26.207 9.997-36.204-.001z"},"child":[]}]})(props);
}function FaClipboard (props) {
  return GenIcon({"tag":"svg","attr":{"viewBox":"0 0 384 512"},"child":[{"tag":"path","attr":{"d":"M384 112v352c0 26.51-21.49 48-48 48H48c-26.51 0-48-21.49-48-48V112c0-26.51 21.49-48 48-48h80c0-35.29 28.71-64 64-64s64 28.71 64 64h80c26.51 0 48 21.49 48 48zM192 40c-13.255 0-24 10.745-24 24s10.745 24 24 24 24-10.745 24-24-10.745-24-24-24m96 114v-20a6 6 0 0 0-6-6H102a6 6 0 0 0-6 6v20a6 6 0 0 0 6 6h180a6 6 0 0 0 6-6z"},"child":[]}]})(props);
}

function SmartClipboardButton({ command = "~/fgmod/fgmod %command%", buttonText = "复制启动命令" }) {
    const [isLoading, setIsLoading] = SP_REACT.useState(false);
    const [showSuccess, setShowSuccess] = SP_REACT.useState(false);
    // Reset success state after 3 seconds
    SP_REACT.useEffect(() => {
        if (showSuccess) {
            const timer = setTimeout(() => {
                setShowSuccess(false);
            }, 3000);
            return () => clearTimeout(timer);
        }
        return undefined;
    }, [showSuccess]);
    const copyToClipboard = async () => {
        if (isLoading || showSuccess)
            return;
        const isPatchCommand = command.includes("fgmod %command%") && !command.includes("uninstaller");
        if (isPatchCommand) {
            DFL.showModal(window.SP_REACT.createElement(DFL.ConfirmModal, { strTitle: "\u8981\u4F7F\u7528 OptiScaler \u4FEE\u8865\u6E38\u620F\u5417\uFF1F", strDescription: "WARNING: Decky Framegen does not unpatch games when uninstalled. Be sure to unpatch the game or run the OptiScaler uninstall script inside the game files if you choose to uninstall the plugin or the game has issues.", strOKButtonText: "\u590D\u5236\u4FEE\u8865\u547D\u4EE4", strCancelButtonText: "\u53D6\u6D88", onOK: async () => {
                    await performCopy();
                } }));
            return;
        }
        // For non-patch commands, copy directly
        await performCopy();
    };
    const performCopy = async () => {
        if (isLoading || showSuccess)
            return;
        setIsLoading(true);
        try {
            const text = command;
            // Use the proven input simulation method
            const tempInput = document.createElement('input');
            tempInput.value = text;
            tempInput.style.position = 'absolute';
            tempInput.style.left = '-9999px';
            document.body.appendChild(tempInput);
            // Focus and select the text
            tempInput.focus();
            tempInput.select();
            // Try copying using execCommand first (most reliable in gaming mode)
            let copySuccess = false;
            try {
                if (document.execCommand('copy')) {
                    copySuccess = true;
                }
            }
            catch (e) {
                // If execCommand fails, try navigator.clipboard as fallback
                try {
                    await navigator.clipboard.writeText(text);
                    copySuccess = true;
                }
                catch (clipboardError) {
                    console.error('Both copy methods failed:', e, clipboardError);
                }
            }
            // Clean up
            document.body.removeChild(tempInput);
            if (copySuccess) {
                // Show success feedback in the button instead of toast
                setShowSuccess(true);
                // Verify the copy worked by reading back
                try {
                    const readBack = await navigator.clipboard.readText();
                    if (readBack !== text) {
                        // Copy worked but verification failed - still show success
                        console.log('Copy verification failed but copy likely worked');
                    }
                }
                catch (e) {
                    // Verification failed but copy likely worked
                    console.log('Copy verification unavailable but copy likely worked');
                }
            }
            else {
                toaster.toast({
                    title: "复制失败",
                    body: "无法复制到剪贴板"
                });
            }
        }
        catch (error) {
            toaster.toast({
                title: "复制失败",
                body: `错误：${String(error)}`
            });
        }
        finally {
            setIsLoading(false);
        }
    };
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: copyToClipboard, disabled: isLoading || showSuccess },
            window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
                showSuccess ? (window.SP_REACT.createElement(FaCheck, { style: {
                        color: "#4CAF50" // Green color for success
                    } })) : isLoading ? (window.SP_REACT.createElement(FaClipboard, { style: {
                        animation: "pulse 1s ease-in-out infinite",
                        opacity: 0.7
                    } })) : (window.SP_REACT.createElement(FaClipboard, null)),
                window.SP_REACT.createElement("div", { style: {
                        color: showSuccess ? "#4CAF50" : "inherit",
                        fontWeight: showSuccess ? "bold" : "normal"
                    } }, showSuccess ? "已复制到剪贴板" : isLoading ? "正在复制…" : buttonText))),
        window.SP_REACT.createElement("style", null, `
        @keyframes pulse {
          0% { opacity: 0.7; }
          50% { opacity: 1; }
          100% { opacity: 0.7; }
        }
      `)));
}

function ClipboardCommands({ pathExists, dllName, manualModeEnabled = false, showLaunchOptions = true, }) {
    if (pathExists !== true)
        return null;
    const launchCmd = dllName === "OptiScaler.asi"
        ? "SteamDeck=0 %command%"
        : `WINEDLLOVERRIDES=${dllName.replace(".dll", "")}=n,b SteamDeck=0 %command%`;
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        showLaunchOptions ? (window.SP_REACT.createElement(SmartClipboardButton, { command: launchCmd, buttonText: "\u590D\u5236\u542F\u52A8\u9009\u9879" })) : null,
        manualModeEnabled ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
            window.SP_REACT.createElement(SmartClipboardButton, { command: "~/fgmod/fgmod %command%", buttonText: "\u590D\u5236\u4FEE\u8865\u547D\u4EE4" }),
            window.SP_REACT.createElement(SmartClipboardButton, { command: "~/fgmod/fgmod-uninstaller.sh %command%", buttonText: "\u590D\u5236\u64A4\u9500\u4FEE\u8865\u547D\u4EE4" }))) : null));
}

function InstructionCard({ pathExists }) {
    if (pathExists !== true)
        return null;
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement("div", { style: STYLES.instructionCard },
            window.SP_REACT.createElement("div", { style: { fontWeight: 'bold', marginBottom: '8px', color: 'var(--decky-accent-text)' } }, MESSAGES.instructionTitle),
            window.SP_REACT.createElement("div", { style: { whiteSpace: 'pre-line' } }, MESSAGES.instructionText))));
}

function OptiScalerWiki({ pathExists }) {
    if (pathExists !== true)
        return null;
    const handleWikiClick = () => {
        window.open("https://github.com/optiscaler/OptiScaler/wiki", "_blank");
    };
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: handleWikiClick },
            window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
                window.SP_REACT.createElement(FaBook, null),
                window.SP_REACT.createElement("div", null, "\u6253\u5F00 OptiScaler \u4F7F\u7528\u8BF4\u660E")))));
}

function UninstallButton({ pathExists, uninstalling, onUninstallClick }) {
    if (pathExists !== true)
        return null;
    return (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
        window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: onUninstallClick, disabled: uninstalling },
            window.SP_REACT.createElement("div", { style: {
                    color: '#ef4444',
                    fontWeight: 'bold'
                } }, uninstalling ? MESSAGES.uninstalling : MESSAGES.uninstallButton))));
}

const DEFAULT_HOME = "/home";
const DEFAULT_STEAM_COMMON = "/home/deck/.local/share/Steam/steamapps/common";
const INITIAL_DEFAULTS = {
    home: DEFAULT_HOME,
    steamCommon: DEFAULT_STEAM_COMMON,
};
const normalizePath = (value) => value.replace(/\\/g, "/");
const stripTrailingSlash = (value) => value.length > 1 && value.endsWith("/") ? value.slice(0, -1) : value;
const ensureDirectory = (value) => {
    const normalized = normalizePath(value);
    const lastSegment = normalized.substring(normalized.lastIndexOf("/") + 1);
    if (!lastSegment || !lastSegment.includes(".")) {
        return stripTrailingSlash(normalized);
    }
    const parent = normalized.slice(0, normalized.lastIndexOf("/"));
    return parent || "/";
};
const INITIAL_PICKER_STATE = {
    selectedPath: null,
    lastError: null,
};
const formatResultMessage = (result) => {
    if (!result)
        return null;
    if (result.status === "success") {
        return result.message || result.output || "Operation completed successfully.";
    }
    return result.message || result.output || "Operation failed.";
};
const ManualPatchControls = ({ isAvailable, onManualModeChange, dllName, fsr4Variant }) => {
    const [isEnabled, setEnabled] = SP_REACT.useState(false);
    const [defaults, setDefaults] = SP_REACT.useState(INITIAL_DEFAULTS);
    const [pickerState, setPickerState] = SP_REACT.useState(INITIAL_PICKER_STATE);
    const [isPatching, setIsPatching] = SP_REACT.useState(false);
    const [isUnpatching, setIsUnpatching] = SP_REACT.useState(false);
    const [operationResult, setOperationResult] = SP_REACT.useState(null);
    const [lastOperation, setLastOperation] = SP_REACT.useState(null);
    SP_REACT.useEffect(() => {
        let cancelled = false;
        (async () => {
            try {
                const response = await getPathDefaults();
                if (!response || cancelled)
                    return;
                const home = response.home ? normalizePath(response.home) : DEFAULT_HOME;
                const steamCommon = response.steam_common
                    ? normalizePath(response.steam_common)
                    : normalizePath(`${stripTrailingSlash(home)}/.local/share/Steam/steamapps/common`);
                setDefaults({
                    home,
                    steamCommon: steamCommon || DEFAULT_STEAM_COMMON,
                });
            }
            catch (err) {
                console.error("ManualPatchControls -> getPathDefaults", err);
            }
        })();
        return () => {
            cancelled = true;
        };
    }, []);
    SP_REACT.useEffect(() => {
        if (!isAvailable) {
            setEnabled(false);
            setPickerState(INITIAL_PICKER_STATE);
            setOperationResult(null);
            setLastOperation(null);
            onManualModeChange?.(false);
        }
    }, [isAvailable, onManualModeChange]);
    const canInteract = isAvailable && isEnabled;
    const selectedPath = pickerState.selectedPath;
    const statusMessage = SP_REACT.useMemo(() => formatResultMessage(operationResult), [operationResult]);
    const wasSuccessful = operationResult?.status === "success";
    const statusLabel = SP_REACT.useMemo(() => {
        if (!operationResult || !lastOperation)
            return null;
        if (operationResult.status === "success") {
            return lastOperation === "patch" ? "游戏已修补" : "游戏已撤销修补";
        }
        return lastOperation === "patch" ? "修补失败" : "撤销修补失败";
    }, [lastOperation, operationResult]);
    const openDirectoryPicker = SP_REACT.useCallback(async () => {
        const candidates = [
            selectedPath,
            defaults.steamCommon,
            defaults.home,
        ];
        let lastError = null;
        for (const candidate of candidates) {
            if (!candidate)
                continue;
            const startPath = ensureDirectory(candidate);
            try {
                const result = await openFilePicker(1 /* FileSelectionType.FOLDER */, startPath, true, true, undefined, undefined, true);
                if (result?.path) {
                    setPickerState({ selectedPath: normalizePath(result.path), lastError: null });
                    setOperationResult(null);
                    return;
                }
            }
            catch (err) {
                console.error("ManualPatchControls -> openDirectoryPicker", err);
                lastError = err instanceof Error ? err.message : String(err);
            }
        }
        setPickerState((prev) => ({ ...prev, lastError }));
    }, [defaults.home, defaults.steamCommon, selectedPath]);
    const runOperation = SP_REACT.useCallback(async (action) => {
        if (!selectedPath)
            return;
        const setBusy = action === "patch" ? setIsPatching : setIsUnpatching;
        setLastOperation(action);
        setBusy(true);
        setOperationResult(null);
        try {
            const response = action === "patch"
                ? await runManualPatch(selectedPath, dllName, fsr4Variant)
                : await runManualUnpatch(selectedPath);
            setOperationResult(response ?? { status: "error", message: "No response from backend." });
        }
        catch (err) {
            setOperationResult({
                status: "error",
                message: err instanceof Error ? err.message : String(err),
            });
        }
        finally {
            setBusy(false);
        }
    }, [selectedPath, dllName, fsr4Variant]);
    const handleToggle = (value) => {
        if (!isAvailable) {
            setEnabled(false);
            return;
        }
        setEnabled(value);
        onManualModeChange?.(value);
        if (!value) {
            setPickerState(INITIAL_PICKER_STATE);
            setOperationResult(null);
            setLastOperation(null);
        }
    };
    const busy = isPatching || isUnpatching;
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ToggleField, { label: "\u9AD8\u7EA7\u6A21\u5F0F", description: isAvailable
                    ? "手动将 OptiScaler 应用到指定游戏目录。"
                    : "请先安装 OptiScaler，才能使用手动修补。", checked: isEnabled && isAvailable, disabled: !isAvailable, onChange: handleToggle })),
        canInteract && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
            window.SP_REACT.createElement(SmartClipboardButton, { command: dllName === "OptiScaler.asi"
                    ? "SteamDeck=0 %command%"
                    : `WINEDLLOVERRIDES="${dllName.replace(".dll", "")}=n,b" SteamDeck=0 %command%`, buttonText: "\u590D\u5236\u624B\u52A8\u542F\u52A8\u547D\u4EE4" }),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: openDirectoryPicker, description: "\u9009\u62E9\u6E38\u620F\u5B89\u88C5\u76EE\u5F55\uFF08EXE \u6587\u4EF6\u6240\u5728\u4F4D\u7F6E\uFF09\u3002" }, "Select directory")),
            pickerState.lastError && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { label: "\u9009\u62E9\u5668\u9519\u8BEF", description: pickerState.lastError }))),
            selectedPath && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement(DFL.Field, { label: "\u76EE\u6807\u76EE\u5F55", description: "OptiScaler \u6587\u4EF6\u5C06\u590D\u5236\u5230\u8FD9\u91CC\u3002" },
                        window.SP_REACT.createElement("div", { style: {
                                fontFamily: "monospace",
                                backgroundColor: "rgba(255, 255, 255, 0.05)",
                                border: "1px solid rgba(255, 255, 255, 0.1)",
                                borderRadius: "4px",
                                padding: "6px 8px",
                                width: "100%",
                                boxSizing: "border-box",
                                whiteSpace: "pre-wrap",
                                wordBreak: "break-word",
                            } }, selectedPath))),
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", disabled: busy, onClick: () => runOperation("patch") }, isPatching ? "正在修补…" : "修补目录")),
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", disabled: busy, onClick: () => runOperation("unpatch") }, isUnpatching ? "正在撤销…" : "撤销修补目录")))),
            operationResult && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { label: statusLabel ?? (wasSuccessful ? "上次操作成功" : "上次操作失败") }, !wasSuccessful && statusMessage ? statusMessage : null)))))));
};

// ─── SteamClient helpers ─────────────────────────────────────────────────────
const getAppLaunchOptions = (appId) => new Promise((resolve, reject) => {
    if (typeof SteamClient === "undefined" || !SteamClient?.Apps?.RegisterForAppDetails) {
        resolve("");
        return;
    }
    let settled = false;
    let unregister = () => { };
    const timeout = window.setTimeout(() => {
        if (settled)
            return;
        settled = true;
        unregister();
        reject(new Error("Timed out reading launch options."));
    }, 5000);
    const registration = SteamClient.Apps.RegisterForAppDetails(appId, (details) => {
        if (settled)
            return;
        settled = true;
        window.clearTimeout(timeout);
        unregister();
        resolve(details?.strLaunchOptions ?? "");
    });
    unregister = registration.unregister;
});
const setAppLaunchOptions = (appId, options) => {
    if (typeof SteamClient !== "undefined" && SteamClient?.Apps?.SetAppLaunchOptions) {
        SteamClient.Apps.SetAppLaunchOptions(appId, options);
    }
};
// ─── Module-level state persistence ──────────────────────────────────────────
let lastSelectedAppId = "";
function SteamGamePatcher({ dllName, fsr4Variant }) {
    const [games, setGames] = SP_REACT.useState([]);
    const [gamesLoading, setGamesLoading] = SP_REACT.useState(true);
    const [selectedAppId, setSelectedAppId] = SP_REACT.useState(() => lastSelectedAppId);
    const [gameStatus, setGameStatus] = SP_REACT.useState(null);
    const [statusLoading, setStatusLoading] = SP_REACT.useState(false);
    const [busyAction, setBusyAction] = SP_REACT.useState(null);
    const [resultMessage, setResultMessage] = SP_REACT.useState("");
    // ── Data loaders ───────────────────────────────────────────────────────────
    const loadGames = SP_REACT.useCallback(async () => {
        setGamesLoading(true);
        try {
            const result = await listInstalledGames();
            if (result.status !== "success")
                throw new Error(result.message || "Failed to load games.");
            const gameList = result.games;
            setGames(gameList);
            if (!gameList.length) {
                lastSelectedAppId = "";
                setSelectedAppId("");
                return;
            }
            setSelectedAppId((current) => {
                const valid = current && gameList.some((g) => g.appid === current) ? current : gameList[0].appid;
                lastSelectedAppId = valid;
                return valid;
            });
        }
        catch (err) {
            const msg = err instanceof Error ? err.message : "Failed to load games.";
            toaster.toast({ title: "Decky Framegen", body: msg });
        }
        finally {
            setGamesLoading(false);
        }
    }, []);
    const loadStatus = SP_REACT.useCallback(async (appid) => {
        if (!appid) {
            setGameStatus(null);
            return;
        }
        setStatusLoading(true);
        try {
            const result = await getGameStatus(appid);
            setGameStatus(result);
        }
        catch (err) {
            setGameStatus({
                status: "error",
                message: err instanceof Error ? err.message : "Failed to load status.",
            });
        }
        finally {
            setStatusLoading(false);
        }
    }, []);
    SP_REACT.useEffect(() => {
        void loadGames();
    }, [loadGames]);
    SP_REACT.useEffect(() => {
        if (!selectedAppId) {
            setGameStatus(null);
            return;
        }
        void loadStatus(selectedAppId);
    }, [selectedAppId, loadStatus]);
    // ── Derived state ──────────────────────────────────────────────────────────
    const selectedGame = SP_REACT.useMemo(() => games.find((g) => g.appid === selectedAppId) ?? null, [games, selectedAppId]);
    const isPatchedWithDifferentDll = gameStatus?.patched && gameStatus?.dll_name && gameStatus.dll_name !== dllName;
    const canPatch = Boolean(selectedGame && gameStatus?.install_found && !busyAction);
    const canUnpatch = Boolean(selectedGame && gameStatus?.patched && !busyAction);
    const patchButtonLabel = SP_REACT.useMemo(() => {
        if (busyAction === "patch")
            return "Patching...";
        if (!selectedGame)
            return "Patch this game";
        if (!gameStatus?.install_found)
            return "Install not found";
        if (isPatchedWithDifferentDll)
            return `Switch to ${dllName}`;
        if (gameStatus?.patched)
            return `Reinstall (${dllName})`;
        return `Patch with ${dllName}`;
    }, [busyAction, dllName, gameStatus, isPatchedWithDifferentDll, selectedGame]);
    // ── Actions ────────────────────────────────────────────────────────────────
    const handlePatch = SP_REACT.useCallback(async () => {
        if (!selectedGame || !selectedAppId || busyAction)
            return;
        setBusyAction("patch");
        setResultMessage("");
        try {
            let currentLaunchOptions = "";
            try {
                currentLaunchOptions = await getAppLaunchOptions(Number(selectedAppId));
            }
            catch {
                // non-fatal: proceed without current launch options
            }
            const result = await patchGame(selectedAppId, dllName, currentLaunchOptions, fsr4Variant);
            if (result.status !== "success")
                throw new Error(result.message || "Patch failed.");
            setAppLaunchOptions(Number(selectedAppId), result.launch_options || "");
            const msg = result.message || `Patched ${selectedGame.name}.`;
            setResultMessage(msg);
            toaster.toast({ title: "Decky Framegen", body: msg });
            await loadStatus(selectedAppId);
        }
        catch (err) {
            const msg = err instanceof Error ? err.message : "Patch failed.";
            setResultMessage(`Error: ${msg}`);
            toaster.toast({ title: "Decky Framegen", body: msg });
        }
        finally {
            setBusyAction(null);
        }
    }, [busyAction, dllName, fsr4Variant, loadStatus, selectedAppId, selectedGame]);
    const handleUnpatch = SP_REACT.useCallback(async () => {
        if (!selectedGame || !selectedAppId || busyAction)
            return;
        setBusyAction("unpatch");
        setResultMessage("");
        try {
            const result = await unpatchGame(selectedAppId);
            if (result.status !== "success")
                throw new Error(result.message || "Unpatch failed.");
            setAppLaunchOptions(Number(selectedAppId), result.launch_options || "");
            const msg = result.message || `Unpatched ${selectedGame.name}.`;
            setResultMessage(msg);
            toaster.toast({ title: "Decky Framegen", body: msg });
            await loadStatus(selectedAppId);
        }
        catch (err) {
            const msg = err instanceof Error ? err.message : "Unpatch failed.";
            setResultMessage(`Error: ${msg}`);
            toaster.toast({ title: "Decky Framegen", body: msg });
        }
        finally {
            setBusyAction(null);
        }
    }, [busyAction, loadStatus, selectedAppId, selectedGame]);
    // ── Status display ─────────────────────────────────────────────────────────
    const statusDisplay = SP_REACT.useMemo(() => {
        if (!selectedGame)
            return { text: "—", color: undefined };
        if (statusLoading)
            return { text: "Loading...", color: undefined };
        if (!gameStatus || gameStatus.status === "error")
            return { text: gameStatus?.message || "—", color: undefined };
        if (!gameStatus.install_found)
            return { text: "Install not found", color: "#ffd866" };
        if (!gameStatus.patched)
            return { text: "Not patched", color: undefined };
        const dllLabel = gameStatus.dll_name || "unknown";
        if (isPatchedWithDifferentDll)
            return { text: `Patched (${dllLabel}) — switch available`, color: "#ffd866" };
        return { text: `Patched (${dllLabel})`, color: "#3fb950" };
    }, [gameStatus, isPatchedWithDifferentDll, selectedGame, statusLoading]);
    const focusableFieldProps = { focusable: true, highlightOnFocus: true };
    // ── Render ─────────────────────────────────────────────────────────────────
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.DropdownItem, { layout: "below", label: "Steam game", menuLabel: "Select a Steam game", strDefaultLabel: gamesLoading ? "Loading games..." : "Choose a game", disabled: gamesLoading || games.length === 0, selectedOption: selectedAppId, rgOptions: games.map((g) => ({
                    data: g.appid,
                    label: g.install_found === false ? `${g.name} (not installed)` : g.name,
                })), onChange: (option) => {
                    const next = String(option.data);
                    lastSelectedAppId = next;
                    setSelectedAppId(next);
                    setResultMessage("");
                } })),
        selectedGame && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { ...focusableFieldProps, label: "Patch status" }, statusDisplay.color ? (window.SP_REACT.createElement("span", { style: { color: statusDisplay.color, fontWeight: 600 } }, statusDisplay.text)) : (statusDisplay.text))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { ...focusableFieldProps, label: "FSR4 runtime" }, gameStatus?.patched
                    ? (gameStatus?.fsr4_variant_label || "Unknown")
                    : (fsr4Variant === "rdna4-native"
                        ? "Will patch with Native bundle / RDNA4"
                        : "Will patch with Steam Deck / RDNA2-3 optimized"))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", disabled: !canPatch, onClick: handlePatch }, patchButtonLabel)),
            canUnpatch && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", disabled: busyAction !== null, onClick: handleUnpatch }, busyAction === "unpatch" ? "Unpatching..." : "Unpatch this game"))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", disabled: !selectedAppId || busyAction !== null || statusLoading, onClick: () => void loadStatus(selectedAppId) }, statusLoading ? "Refreshing..." : "Refresh status")),
            resultMessage && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { ...focusableFieldProps, label: "Result" }, resultMessage)))))));
}

function OptiScalerControls({ pathExists, setPathExists, fgmodInfo }) {
    const [installing, setInstalling] = SP_REACT.useState(false);
    const [uninstalling, setUninstalling] = SP_REACT.useState(false);
    const [installResult, setInstallResult] = SP_REACT.useState(null);
    const [uninstallResult, setUninstallResult] = SP_REACT.useState(null);
    const [advancedModeEnabled, setAdvancedModeEnabled] = SP_REACT.useState(false);
    const [manualClipboardModeEnabled, setManualClipboardModeEnabled] = SP_REACT.useState(false);
    const [dllName, setDllName] = SP_REACT.useState(DEFAULT_PROXY_DLL);
    const [fsr4Variant, setFsr4Variant] = SP_REACT.useState(DEFAULT_FSR4_VARIANT);
    const [fsr4VariantTouched, setFsr4VariantTouched] = SP_REACT.useState(false);
    const [switchingVariant, setSwitchingVariant] = SP_REACT.useState(false);
    SP_REACT.useEffect(() => {
        if (installResult) {
            return createAutoCleanupTimer(() => setInstallResult(null), TIMEOUTS.resultDisplay);
        }
        return () => { }; // Ensure a cleanup function is always returned
    }, [installResult]);
    SP_REACT.useEffect(() => {
        if (uninstallResult) {
            return createAutoCleanupTimer(() => setUninstallResult(null), TIMEOUTS.resultDisplay);
        }
        return () => { }; // Ensure a cleanup function is always returned
    }, [uninstallResult]);
    SP_REACT.useEffect(() => {
        const installedVariant = fgmodInfo?.selected_fsr4_variant;
        if (!fsr4VariantTouched && installedVariant && FSR4_VARIANT_OPTIONS.some((option) => option.value === installedVariant)) {
            setFsr4Variant(installedVariant);
        }
    }, [fgmodInfo?.selected_fsr4_variant, fsr4VariantTouched]);
    const handleInstallClick = async () => {
        try {
            setInstalling(true);
            const result = await runInstallFGMod(fsr4Variant);
            setInstallResult(result);
            if (result.status === "success") {
                setPathExists(true);
            }
        }
        catch (e) {
            console.error(e);
        }
        finally {
            setInstalling(false);
        }
    };
    const handleUninstallClick = async () => {
        try {
            setUninstalling(true);
            const result = await runUninstallFGMod();
            setUninstallResult(result);
            if (result.status === "success") {
                setPathExists(false);
            }
        }
        catch (e) {
            console.error(e);
        }
        finally {
            setUninstalling(false);
        }
    };
    const handleFsr4VariantChange = async (nextVariant) => {
        const previousVariant = fsr4Variant;
        setFsr4Variant(nextVariant);
        setFsr4VariantTouched(true);
        if (pathExists !== true)
            return;
        try {
            setSwitchingVariant(true);
            const result = await setDefaultFsr4Variant(nextVariant);
            if (result.status !== "success") {
                throw new Error(result.message || result.output || "Failed to switch default FSR4 runtime.");
            }
            setFsr4Variant(result.selected_default_variant || nextVariant);
            setFsr4VariantTouched(false);
        }
        catch (error) {
            console.error(error);
            setFsr4Variant(previousVariant);
        }
        finally {
            setSwitchingVariant(false);
        }
    };
    const installedVariantLabel = fgmodInfo?.selected_fsr4_variant_label || FSR4_VARIANT_OPTIONS.find((option) => option.value === fsr4Variant)?.label;
    return (window.SP_REACT.createElement(DFL.PanelSection, null,
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.Field, { label: "\u95F2\u9C7C\u53CC\u53F6\u6C49\u5316", description: "FSR4 \u4E2D\u6587\u754C\u9762" }, "\u539F\u63D2\u4EF6\u4F5C\u8005\uFF1AKurt Himebauch\uFF08xXJSONDeruloXx\uFF09")),
        window.SP_REACT.createElement(InstallationStatus, { pathExists: pathExists, installing: installing, onInstallClick: handleInstallClick }),
        window.SP_REACT.createElement(OptiScalerHeader, { pathExists: pathExists }),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.DropdownItem, { layout: "below", label: "\u9ED8\u8BA4 FSR4 \u8FD0\u884C\u5E93", description: FSR4_VARIANT_OPTIONS.find((option) => option.value === fsr4Variant)?.hint, menuLabel: "\u9009\u62E9\u9ED8\u8BA4 FSR4 \u8FD0\u884C\u5E93", selectedOption: fsr4Variant, rgOptions: FSR4_VARIANT_OPTIONS.map((option) => ({ data: option.value, label: option.label })), disabled: installing || uninstalling || switchingVariant, onChange: (option) => {
                    void handleFsr4VariantChange(String(option.data));
                } })),
        pathExists === true && fgmodInfo?.version && installedVariantLabel && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.Field, { label: "\u5DF2\u5B89\u88C5\u7EC4\u4EF6", description: `OptiScaler ${fgmodInfo.version}` }, installedVariantLabel))),
        pathExists === true && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.DropdownItem, { layout: "below", label: "\u4EE3\u7406 DLL \u540D\u79F0", description: PROXY_DLL_OPTIONS.find((o) => o.value === dllName)?.hint, menuLabel: "\u9009\u62E9\u4EE3\u7406 DLL \u540D\u79F0", selectedOption: dllName, rgOptions: PROXY_DLL_OPTIONS.map((o) => ({ data: o.value, label: o.label })), onChange: (option) => setDllName(String(option.data)) }))),
        pathExists === true && (window.SP_REACT.createElement(SteamGamePatcher, { dllName: dllName, fsr4Variant: fsr4Variant })),
        window.SP_REACT.createElement(ClipboardCommands, { pathExists: pathExists, dllName: dllName }),
        pathExists === true && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ToggleField, { label: "\u624B\u52A8\u6A21\u5F0F", description: "\u663E\u793A\u901A\u8FC7 ~/fgmod \u811A\u672C\u4FEE\u8865\u6216\u64A4\u9500\u4FEE\u8865\u7684\u547D\u4EE4\u590D\u5236\u6309\u94AE\u3002", checked: manualClipboardModeEnabled, onChange: setManualClipboardModeEnabled }))),
        pathExists === true && manualClipboardModeEnabled ? (window.SP_REACT.createElement(ClipboardCommands, { pathExists: pathExists, dllName: dllName, manualModeEnabled: true, showLaunchOptions: false })) : null,
        window.SP_REACT.createElement(ManualPatchControls, { isAvailable: pathExists === true, onManualModeChange: setAdvancedModeEnabled, dllName: dllName, fsr4Variant: fsr4Variant }),
        !advancedModeEnabled && (window.SP_REACT.createElement(InstructionCard, { pathExists: pathExists })),
        window.SP_REACT.createElement(OptiScalerWiki, { pathExists: pathExists }),
        window.SP_REACT.createElement(UninstallButton, { pathExists: pathExists, uninstalling: uninstalling, onUninstallClick: handleUninstallClick })));
}

function MainContent() {
    const [pathExists, setPathExists] = SP_REACT.useState(null);
    const [fgmodInfo, setFgmodInfo] = SP_REACT.useState(null);
    SP_REACT.useEffect(() => {
        const checkPath = async () => {
            const result = await safeAsyncOperation(async () => await checkFGModPath(), 'MainContent -> checkPath');
            if (result) {
                setFgmodInfo(result);
                setPathExists(result.exists);
            }
        };
        checkPath(); // Initial check
        const intervalId = setInterval(checkPath, TIMEOUTS.pathCheck); // Check every 3 seconds
        return () => clearInterval(intervalId); // Cleanup interval on component unmount
    }, []);
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement(OptiScalerControls, { pathExists: pathExists, setPathExists: setPathExists, fgmodInfo: fgmodInfo }),
        pathExists === true ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null)) : null));
}
var index = definePlugin(() => ({
    name: "FSR4",
    titleView: window.SP_REACT.createElement("div", null, "FSR4"),
    alwaysRender: true,
    content: window.SP_REACT.createElement(MainContent, null),
    icon: window.SP_REACT.createElement(MdOutlineAutoAwesomeMotion, null),
    onDismount() {
        console.log("Decky Framegen Plugin unmounted");
    },
}));

export { index as default };
//# sourceMappingURL=index.js.map
