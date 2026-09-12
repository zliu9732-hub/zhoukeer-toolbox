const manifest = {"name":"LeGo2 亮度修复"};
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
const callable = api.callable;
const toaster = api.toaster;
const useQuickAccessVisible = api.useQuickAccessVisible;
const definePlugin = (fn) => {
    return (...args) => {
        return fn(...args);
    };
};

// One upside and one downside each, because that is the whole decision. The
// numbers come from this panel: a ~471 nit ceiling on the eDP AUX luminance
// control, against the 1100 nit peak the EDID advertises for a 10% window.
const MODE_INFO = {
    gamma22: {
        label: "伽马 2.2",
        pro: "系统亮度滑块会直接控制面板，因此任何亮度下黑色都能保持纯黑。",
        con: "HDR 会按面板约 471 尼特的上限进行色调映射，高光效果会减弱。",
    },
    pq: {
        label: "PQ 模式",
        pro: "HDR 可达到面板完整的 1100 尼特峰值，并按内容母版的绝对亮度显示。",
        con: "面板会忽略硬件亮度控制；调暗只会淡化画面，暗部可能发灰。",
    },
    hybrid: {
        label: "混合模式",
        pro: "日常使用伽马 2.2，仅在游戏输出 HDR 时切换到 PQ，兼顾两者。",
        con: "每次在 HDR 与 SDR 间切换时，屏幕会短暂黑一下。",
    },
};
// Hybrid first and recommended: it is the only one that does not trade away
// something the user would notice every day.
const RECOMMENDED = "hybrid";
const MODE_ORDER = ["hybrid", "pq", "gamma22"];
const modeLabel = (m) => m === RECOMMENDED ? `${MODE_INFO[m].label}（推荐）` : MODE_INFO[m].label;
const getState = callable("get_state");
const setEnabled = callable("set_enabled");
const setEdidFix = callable("set_edid_fix");
const runSetup = callable("run_setup");
const setPanelMode = callable("set_panel_mode");
const restartSession = callable("restart_session");
const getVersion = callable("get_version");
const checkForUpdates = callable("check_for_updates");
const performUpdate = callable("perform_update");
const notify = (title, body) => toaster.toast({ title, body, duration: 5000 });
// ── Updates ────────────────────────────────────────────────────────────────────
const UpdateSection = () => {
    const [info, setInfo] = SP_REACT.useState(null);
    const [version, setVersion] = SP_REACT.useState("");
    const [checking, setChecking] = SP_REACT.useState(false);
    const [downloading, setDownloading] = SP_REACT.useState(false);
    const [downloadPath, setDownloadPath] = SP_REACT.useState(null);
    // Read straight from the manifest so the installed version is on screen
    // before anyone presses the button, rather than only after a network call.
    SP_REACT.useEffect(() => {
        let active = true;
        getVersion()
            .then((v) => { if (active)
            setVersion(v.version ?? ""); })
            .catch(() => undefined);
        return () => { active = false; };
    }, []);
    const check = SP_REACT.useCallback(async () => {
        setChecking(true);
        setInfo(null);
        setDownloadPath(null);
        try {
            setInfo(await checkForUpdates());
        }
        catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            notify("检查更新失败", msg);
            setInfo({ error: msg });
        }
        finally {
            setChecking(false);
        }
    }, []);
    const download = SP_REACT.useCallback(async () => {
        if (!info?.download_url || !info?.asset_name) {
            notify("无法下载", "此版本暂时没有可安装的 ZIP 文件。");
            return;
        }
        setDownloading(true);
        try {
            const res = await performUpdate(info.download_url, info.asset_name);
            if (res.success && res.path)
                setDownloadPath(res.path);
            else {
                setInfo({ ...info, error: res.error });
                notify("下载失败", res.error ?? "未知错误");
            }
        }
        catch (e) {
            notify("下载失败", e instanceof Error ? e.message : String(e));
        }
        finally {
            setDownloading(false);
        }
    }, [info]);
    return (SP_JSX.jsxs(DFL.PanelSection, { title: "\u66F4\u65B0", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u5DF2\u5B89\u88C5\u7248\u672C", focusable: true, children: `v${(info?.current_version ?? version) || "?"}` }) }), info?.latest_version && !info.error && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u6700\u65B0\u7248\u672C", focusable: true, children: `v${info.latest_version}` }) })), info?.error && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u9519\u8BEF", description: info.error }) })), info && !info.error && !info.update_available && !downloadPath && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u5DF2\u662F\u6700\u65B0\u7248\u672C" }) })), info?.update_available && info.download_url && info.asset_name && !downloadPath && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: download, disabled: downloading, children: downloading ? "正在下载…" : `下载 v${info.latest_version}` }) })), downloadPath && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u5DF2\u4E0B\u8F7D", description: `${downloadPath} - 安装方法：在 Decky 的开发者选项中卸载 ` +
                        "LeGo2 亮度修复，然后选择“从 ZIP 安装插件”并选取该文件。" +
                        "你的设置会保留。" }) })), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: check, disabled: checking || downloading, children: checking ? "正在检查…" : "检查更新" }) })] }));
};
// ── Mode picker ────────────────────────────────────────────────────────────────
const ProCon = ({ mode }) => (SP_JSX.jsxs("div", { style: { fontSize: "0.75em", lineHeight: 1.35, padding: "0 16px 10px" }, children: [SP_JSX.jsx("div", { style: { color: "#5ee07a" }, children: `+ ${MODE_INFO[mode].pro}` }), SP_JSX.jsx("div", { style: { color: "#ff7b72" }, children: `- ${MODE_INFO[mode].con}` })] }));
/** One button plus the two lines that justify it. */
const ModeChoice = ({ mode, busy, onPick }) => (SP_JSX.jsxs(SP_REACT.Fragment, { children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: () => onPick(mode), disabled: busy, children: modeLabel(mode) }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(ProCon, { mode: mode }) })] }));
// ── Main content ───────────────────────────────────────────────────────────────
const Content = () => {
    const visible = useQuickAccessVisible();
    const [state, setState] = SP_REACT.useState(null);
    const [busy, setBusy] = SP_REACT.useState(false);
    // Both lists start folded away: on first run the recommendation is the whole
    // point, and afterwards the mode is a decision already made.
    const [showOthers, setShowOthers] = SP_REACT.useState(false);
    const [showSwitch, setShowSwitch] = SP_REACT.useState(false);
    const refresh = SP_REACT.useCallback(async () => {
        try {
            setState(await getState());
        }
        catch {
            /* backend not up yet; the next tick will pick it up */
        }
    }, []);
    // Only poll while the panel is actually on screen. The backend keeps working
    // either way - this is just what the user sees.
    SP_REACT.useEffect(() => {
        refresh();
        if (!visible)
            return;
        const id = setInterval(refresh, 1000);
        return () => clearInterval(id);
    }, [visible, refresh]);
    const toggle = SP_REACT.useCallback(async (fn, key, value) => {
        setState((s) => (s ? { ...s, [key]: value } : s));
        try {
            setState(await fn(value));
        }
        catch {
            refresh();
        }
    }, [refresh]);
    const setup = SP_REACT.useCallback(async (mode) => {
        setBusy(true);
        try {
            const next = await runSetup(mode);
            setState(next);
            if (next.setup_error)
                notify("设置失败", next.setup_error);
        }
        catch (e) {
            notify("设置失败", e instanceof Error ? e.message : String(e));
        }
        finally {
            setBusy(false);
        }
    }, []);
    const changeMode = SP_REACT.useCallback(async (mode) => {
        setBusy(true);
        try {
            const next = await setPanelMode(mode);
            setState(next);
            if (next.setup_error)
                notify("无法切换模式", next.setup_error);
        }
        catch (e) {
            notify("无法切换模式", e instanceof Error ? e.message : String(e));
        }
        finally {
            setBusy(false);
        }
    }, []);
    const restart = SP_REACT.useCallback(async () => {
        setBusy(true);
        try {
            // If this returns at all, the session did not go down - so surface
            // whatever the backend reported instead of leaving a dead button.
            setState(await restartSession());
        }
        catch {
            /* the session going down mid-call is the expected outcome */
        }
        finally {
            setBusy(false);
        }
    }, []);
    if (!state) {
        return (SP_JSX.jsx(DFL.PanelSection, { children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Spinner, {}) }) }));
    }
    // Nothing works until gamescope has the display script: without it the panel
    // is either stock or, far more often on this device, still carrying the
    // gamma 2.2 workaround that takes it out of PQ entirely. Showing the normal
    // controls before that point would just look broken.
    // No mode chosen yet. Nothing is installed on the user's behalf before this,
    // because every option trades away something they may care about.
    if (!state.panel_mode) {
        return (SP_JSX.jsxs(DFL.PanelSection, { title: "\u9009\u62E9\u663E\u793A\u6A21\u5F0F", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { description: "请选择 Legion Go 2 OLED 面板的驱动方式。这会安装一个 " +
                            "Gamescope 显示脚本并替换现有的该面板脚本；旧脚本会保留为 " +
                            ".backup 文件。你可以随时更改选择。" }) }), SP_JSX.jsx(ModeChoice, { mode: RECOMMENDED, busy: busy, onPick: setup }), state.setup_error && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u8BBE\u7F6E\u5931\u8D25", description: state.setup_error }) })), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: () => setShowOthers((v) => !v), disabled: busy, children: showOthers ? "隐藏其他选项" : "其他选项" }) }), showOthers &&
                    MODE_ORDER.filter((m) => m !== RECOMMENDED).map((m) => (SP_JSX.jsx(ModeChoice, { mode: m, busy: busy, onPick: setup }, m)))] }));
    }
    if (!state.setup_done) {
        return (SP_JSX.jsxs(DFL.PanelSection, { title: "\u8BBE\u7F6E", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: `需要显示脚本（${MODE_INFO[state.panel_mode].label}）`, description: "此模式所需脚本尚未就位。安装会替换现有的该面板脚本，旧脚本会以 .backup 文件保留。" }) }), state.setup_note && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u72B6\u6001", description: state.setup_note }) })), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: () => setup(state.panel_mode), disabled: busy, children: busy ? "正在安装…" : "安装显示修复" }) })] }));
    }
    if (state.restart_pending) {
        return (SP_JSX.jsxs(DFL.PanelSection, { title: "\u9700\u8981\u91CD\u542F", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u663E\u793A\u811A\u672C\u5DF2\u5B89\u88C5", description: "Gamescope 只会在启动时读取显示脚本。因此需重启游戏模式才能生效；这会关闭 Steam 后立即重新打开。" }) }), state.restart_error && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u65E0\u6CD5\u91CD\u542F", description: `${state.restart_error}。请手动重启游戏模式：Steam 菜单 → 电源 → 切换到桌面模式后再切回，或直接重启设备。` }) })), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: restart, disabled: busy, children: "\u91CD\u542F\u6E38\u620F\u6A21\u5F0F" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: () => setShowSwitch((v) => !v), disabled: busy, children: showSwitch ? "保持当前选择" : "更改显示模式" }) }), showSwitch &&
                    MODE_ORDER.filter((m) => m !== state.panel_mode).map((m) => (SP_JSX.jsx(ModeChoice, { mode: m, busy: busy, onPick: changeMode }, m)))] }));
    }
    return (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(DFL.PanelSection, { title: "\u663E\u793A\u5668", children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: state.panel_desc || "未知面板", description: state.backlight
                            ? `背光：${state.backlight}` +
                                (state.max_nits ? ` · 最高 ${state.max_nits.toFixed(0)} 尼特` : "")
                            : undefined }) }) }), SP_JSX.jsxs(DFL.PanelSection, { title: "\u663E\u793A\u6A21\u5F0F", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u6A21\u5F0F", focusable: true, children: MODE_INFO[state.panel_mode].label }) }), state.panel_mode === "hybrid" && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u5F53\u524D\u9762\u677F\u6A21\u5F0F", description: state.hybrid_reason, focusable: true, children: state.hdr_now ? "PQ 模式" : "伽马 2.2" }) })), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: () => setShowSwitch((v) => !v), disabled: busy, children: showSwitch ? "取消" : "切换显示模式" }) }), showSwitch &&
                        MODE_ORDER.filter((m) => m !== state.panel_mode).map((m) => (SP_JSX.jsx(ModeChoice, { mode: m, busy: busy, onPick: (picked) => {
                                setShowSwitch(false);
                                changeMode(picked);
                            } }, m)))] }), SP_JSX.jsx(DFL.PanelSection, { title: "\u4EAE\u5EA6\u6ED1\u5757", children: state.panel_ok ? (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "\u542F\u7528", description: "\u9762\u677F\u5904\u4E8E HDR/PQ \u65F6\uFF0C\u5C06 Steam \u4EAE\u5EA6\u6ED1\u5757\u7684\u503C\u8F6C\u4EA4\u7ED9 Gamescope\u3002", checked: state.enabled, onChange: (v) => toggle(setEnabled, "enabled", v) }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u72B6\u6001", description: state.reason, focusable: true, children: state.active ? "已生效" : "待命" }) }), state.active && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u4EAE\u5EA6", focusable: true, children: `${state.nits.toFixed(1)} / ${state.max_nits.toFixed(0)} 尼特` }) }))] })) : (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u4E0D\u9002\u7528", description: "此功能仅在已知会于 HDR/PQ 下忽略背光控制的面板上运行，因此当前没有修改任何设置。" }) })) }), SP_JSX.jsxs(DFL.PanelSection, { title: "\u6E38\u620F EDID", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "\u542F\u7528", description: "\u4ECE Gamescope \u4EA4\u7ED9\u6E38\u620F\u7684 EDID \u4E2D\u79FB\u9664 DXVK \u65E0\u6CD5\u89E3\u6790\u7684 DisplayID \u533A\u5757\u3002", checked: state.edid_fix, onChange: (v) => toggle(setEdidFix, "edid_fix", v) }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u72B6\u6001", description: state.edid_reason, focusable: true, children: state.edid_patched ? "已应用" : "待命" }) }), state.edid_patched && state.edid_game_nits > 0 && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "\u6E38\u620F\u8BFB\u53D6\u503C", description: "\u672A\u542F\u7528\u65F6\uFF0C\u6E38\u620F\u4F1A\u56DE\u9000\u4E3A DXVK \u7684 1499 \u5C3C\u7279\u5360\u4F4D\u503C\u548C\u901A\u7528\u539F\u8272\u3002", focusable: true, children: `${state.edid_game_nits.toFixed(0)} 尼特` }) }))] }), SP_JSX.jsx(UpdateSection, {})] }));
};
// ── Icon ───────────────────────────────────────────────────────────────────────
const BrightnessIcon = () => (SP_JSX.jsx("svg", { xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "currentColor", style: { width: "1em", height: "1em" }, children: SP_JSX.jsx("path", { d: "M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10zm0-6h-1v3h2V1h-1zm0 19h-1v3h2v-3h-1zM1 11v2h3v-2H1zm19 0v2h3v-2h-3zM4.2 4.2 3.5 4.9l2.1 2.1.7-.7-2.1-2.1zm13 13-.7.7 2.1 2.1.7-.7-2.1-2.1zM6.3 17.9l-2.1 2.1.7.7 2.1-2.1-.7-.7zm13-13-2.1 2.1.7.7 2.1-2.1-.7-.7z" }) }));
var index = definePlugin(() => ({
    name: "LeGo2 亮度修复",
    titleView: SP_JSX.jsx("div", { className: DFL.staticClasses.Title, children: "LeGo2 \u4EAE\u5EA6\u4FEE\u590D" }),
    content: SP_JSX.jsx(Content, {}),
    icon: SP_JSX.jsx(BrightnessIcon, {}),
    onDismount() {
        /* the backend releases the atom and restores the EDID in _unload */
    },
}));

export { index as default };
//# sourceMappingURL=index.js.map
