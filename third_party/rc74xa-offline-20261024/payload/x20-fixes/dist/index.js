const manifest = {"name":"X20 Fixes"};
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
const addEventListener = api.addEventListener;
const removeEventListener = api.removeEventListener;
const toaster = api.toaster;
const useQuickAccessVisible = api.useQuickAccessVisible;
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
function FaVolumeUp (props) {
  return GenIcon({"attr":{"viewBox":"0 0 576 512"},"child":[{"tag":"path","attr":{"d":"M215.03 71.05L126.06 160H24c-13.26 0-24 10.74-24 24v144c0 13.25 10.74 24 24 24h102.06l88.97 88.95c15.03 15.03 40.97 4.47 40.97-16.97V88.02c0-21.46-25.96-31.98-40.97-16.97zm233.32-51.08c-11.17-7.33-26.18-4.24-33.51 6.95-7.34 11.17-4.22 26.18 6.95 33.51 66.27 43.49 105.82 116.6 105.82 195.58 0 78.98-39.55 152.09-105.82 195.58-11.17 7.32-14.29 22.34-6.95 33.5 7.04 10.71 21.93 14.56 33.51 6.95C528.27 439.58 576 351.33 576 256S528.27 72.43 448.35 19.97zM480 256c0-63.53-32.06-121.94-85.77-156.24-11.19-7.14-26.03-3.82-33.12 7.46s-3.78 26.21 7.41 33.36C408.27 165.97 432 209.11 432 256s-23.73 90.03-63.48 115.42c-11.19 7.14-14.5 22.07-7.41 33.36 6.51 10.36 21.12 15.14 33.12 7.46C447.94 377.94 480 319.54 480 256zm-141.77-76.87c-11.58-6.33-26.19-2.16-32.61 9.45-6.39 11.61-2.16 26.2 9.45 32.61C327.98 228.28 336 241.63 336 256c0 14.38-8.02 27.72-20.92 34.81-11.61 6.41-15.84 21-9.45 32.61 6.43 11.66 21.05 15.8 32.61 9.45 28.23-15.55 45.77-45 45.77-76.88s-17.54-61.32-45.78-76.86z"},"child":[]}]})(props);
}

const getStatus = callable("get_status");
const getJob = callable("get_job");
const start = callable("start");
const setAutoApply = callable("set_auto_apply");
const startupNotice = callable("startup_notice");
const reboot = callable("reboot");
const setQamButton = callable("set_qam_button");
const setWakeFix = callable("set_wake_fix");
const setButtonFix = callable("set_button_fix");
// ESideMenu.QuickAccess in Steam's menu store.
const QUICK_ACCESS = 2;
// Open the Quick Access menu, or close it if it is already open (like the real button).
function toggleQuickAccess() {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const menus = DFL.Router?.WindowStore?.GamepadUIMainWindowInstance?.MenuStore;
    if (menus?.ToggleSideMenu) {
        menus.ToggleSideMenu(QUICK_ACCESS);
    }
    else if (menus?.IsSideMenuVisible?.(QUICK_ACCESS)) {
        DFL.Navigation.CloseSideMenus();
    }
    else {
        DFL.Navigation.OpenQuickAccessMenu();
    }
}
// Headline per state from "ally-audio-fix.sh check".
const HEADLINE = {
    ok: "Speakers working",
    needs_reboot: "Reboot needed",
    needs_install: "Fix not applied",
    needs_build: "Fix needs a rebuild",
    acpi_stale: "Fix out of date",
    fixed_upstream: "Fix no longer needed",
    broken: "Speakers not working",
    unsupported: "Not an Ally X20",
    kernel_too_old: "Needs SteamOS Beta",
};
// How each component's state reads in the details list.
const COMPONENT = {
    acpi: {
        override_active: "Fixed (override active)",
        override_pending: "Fixed after reboot",
        override_ignored: "Override ignored by kernel",
        needed: "Needs fixing",
        not_needed: "Not needed",
        stale: "Built for an older BIOS",
        unknown: "Unknown",
    },
    module: {
        loaded: "Fixed (loaded)",
        installed: "Installed, not loaded",
        available: "Ready to install",
        missing: "Needs building for this kernel",
        not_needed: "Not needed (kernel has it)",
        kernel_too_old: "Needs SteamOS Beta",
    },
    firmware: { installed: "Installed", system: "Provided by SteamOS", missing: "Missing" },
    ucm: { overlay: "Installed", system: "Provided by SteamOS", missing: "Missing" },
};
function confirm(title, description, ok, onOK) {
    DFL.showModal(SP_JSX.jsx(DFL.ConfirmModal, { strTitle: title, strDescription: description, strOKButtonText: ok, onOK: onOK }));
}
function Content() {
    const visible = useQuickAccessVisible();
    const [snap, setSnap] = SP_REACT.useState(null);
    const [job, setJob] = SP_REACT.useState(null);
    const [showLog, setShowLog] = SP_REACT.useState(false);
    const [error, setError] = SP_REACT.useState(null);
    const refresh = SP_REACT.useCallback(async () => {
        // Don't spin forever if the backend errors out or never answers.
        const timeout = new Promise((_, reject) => setTimeout(() => reject(new Error("The plugin backend did not respond within 30 seconds.")), 30000));
        try {
            const s = await Promise.race([getStatus(), timeout]);
            setSnap(s);
            setJob(s.job);
            setError(null);
        }
        catch (e) {
            setError(e instanceof Error ? e.message : String(e));
        }
    }, []);
    SP_REACT.useEffect(() => {
        if (visible)
            refresh();
    }, [visible, refresh]);
    // While a job runs and the panel is open, follow its progress.
    SP_REACT.useEffect(() => {
        if (!visible || !job?.running)
            return;
        const timer = setInterval(async () => {
            const j = await getJob();
            setJob(j);
            if (!j.running)
                refresh();
        }, 1000);
        return () => clearInterval(timer);
    }, [visible, job?.running, refresh]);
    const run = async (kind) => {
        if (await start(kind)) {
            setJob({ kind, running: true, ok: null, step: "Starting…", log: [] });
            setShowLog(true);
        }
    };
    if (!snap) {
        return (SP_JSX.jsx(DFL.PanelSection, { children: error ? (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "Could not load status", description: error, bottomSeparator: "none" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "Logs", description: "In Desktop Mode: ls ~/homebrew/logs/ and look in the folder for this plugin.", bottomSeparator: "none" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: () => { setError(null); refresh(); }, children: "Try again" }) })] })) : (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Spinner, { style: { height: "32px" } }) })) }));
    }
    const st = snap.status;
    const state = st.state ?? "broken";
    const busy = !!job?.running;
    const lastLines = (job?.log ?? []).slice(-12);
    const primary = (() => {
        switch (state) {
            case "needs_install":
                return { label: "Apply fix", onClick: () => run("apply") };
            case "needs_build":
                return {
                    label: "Rebuild and apply fix",
                    onClick: () => confirm("Rebuild the fix?", "This downloads the kernel headers and builds the speaker layout module for this " +
                        "SteamOS version. It needs internet and takes several minutes; you can close this " +
                        "menu while it runs.", "Rebuild", () => run("apply")),
                };
            case "needs_reboot":
                return { label: "Reboot now", onClick: () => reboot() };
            case "acpi_stale":
                return {
                    label: "Remove outdated fix",
                    onClick: () => confirm("Remove the outdated fix?", "Your BIOS was updated after the fix was made, so it has to be redone. After the " +
                        "reboot, open this menu again and choose Apply fix.", "Remove", () => run("uninstall")),
                };
            case "fixed_upstream":
                return { label: "Remove fix", onClick: () => run("uninstall") };
            case "broken":
                return { label: "Try applying again", onClick: () => run("apply") };
            default:
                return null;
        }
    })();
    return (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsxs(DFL.PanelSection, { title: "Speakers", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: HEADLINE[state] ?? state, description: st.message, bottomSeparator: "none" }) }), busy && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: job?.step || "Working…", icon: SP_JSX.jsx(DFL.Spinner, { style: { height: "20px" } }), bottomSeparator: "none" }) })), primary && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", disabled: busy, onClick: primary.onClick, children: primary.label }) })), !busy && job?.kind && job.ok === false && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "Last action failed", description: "See the log below.", bottomSeparator: "none" }) }))] }), state !== "unsupported" && (SP_JSX.jsxs(DFL.PanelSection, { title: "Details", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "BIOS audio flag", children: COMPONENT.acpi[st.acpi] ?? st.acpi }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "Speaker layout", children: COMPONENT.module[st.module] ?? st.module }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "Amp tuning", children: COMPONENT.firmware[st.firmware] ?? st.firmware }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "Audio profile", children: COMPONENT.ucm[st.ucm] ?? st.ucm }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "Kernel", description: st.kernel, bottomSeparator: "none" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Field, { label: "BIOS", description: st.bios }) })] })), SP_JSX.jsxs(DFL.PanelSection, { title: "Settings", children: [snap.qam.supported && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "Quick Access button", description: !snap.settings.qam_button
                                ? "Off. Use Xbox + A to open this menu."
                                : snap.qam.devices.length
                                    ? `Working (${snap.qam.presses} presses since boot).`
                                    : "On, but the button's HID interface was not found yet.", checked: snap.settings.qam_button, onChange: async (v) => {
                                const r = await setQamButton(v);
                                setSnap({ ...snap, settings: r.settings, qam: r.qam });
                            } }) })), snap.wake.supported && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "Fix buttons after sleep", description: snap.settings.button_fix
                                ? `Re-sends the controller's mode after waking. Since boot: ${snap.wake.wakes} wakes, ${snap.wake.mode_resent} re-sends.`
                                : "Off. After some wakes, the Xbox button stops working until the next sleep.", checked: snap.settings.button_fix, onChange: async (v) => {
                                const r = await setButtonFix(v);
                                setSnap({ ...snap, settings: r.settings, wake: r.wake });
                            } }) })), snap.wake.supported && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "Fix sound after sleep", description: snap.settings.wake_fix
                                ? `Reopens the speakers right after waking. Since boot: ${snap.wake.wakes} wakes, ${snap.wake.reopened} reopens.`
                                : "Off. After waking, the speakers can stay silent for 30 seconds or more.", checked: snap.settings.wake_fix, onChange: async (v) => {
                                const r = await setWakeFix(v);
                                setSnap({ ...snap, settings: r.settings, wake: r.wake });
                            } }) })), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "Re-apply after updates", description: "When a SteamOS update undoes the fix and no rebuild is needed, re-apply it at boot. You still reboot once.", checked: snap.settings.auto_apply, onChange: async (v) => setSnap({ ...snap, settings: await setAutoApply(v) }) }) })] }), SP_JSX.jsxs(DFL.PanelSection, { title: "More", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", disabled: busy, onClick: refresh, children: "Refresh" }) }), (job?.log?.length ?? 0) > 0 && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: () => setShowLog(!showLog), children: showLog ? "Hide log" : "Show log" }) })), showLog && lastLines.length > 0 && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: { fontFamily: "monospace", fontSize: "11px", whiteSpace: "pre-wrap",
                                wordBreak: "break-all", opacity: 0.8 }, children: lastLines.join("\n") }) })), !["unsupported", "fixed_upstream", "kernel_too_old"].includes(state) && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", disabled: busy, onClick: () => confirm("Remove the speaker fix?", "This undoes every change the fix made to this SteamOS slot. The speakers stop " +
                                "working after the next reboot.", "Remove", () => run("uninstall")), children: "Remove fix" }) }))] })] }));
}
var index = definePlugin(() => {
    // Finished jobs (including an automatic re-apply at boot) report back with a toast.
    const onJobDone = addEventListener("job_done", (kind, ok, state, message) => {
        const what = kind === "uninstall" ? "Speaker fix removed" : "Speaker fix applied";
        toaster.toast({
            title: ok ? what : "Speaker fix: action failed",
            body: ok && state === "needs_reboot" ? "Reboot to finish." : message,
        });
    });
    // The backend saw the X20's Quick Access button.
    const onQamButton = addEventListener("qam_button", toggleQuickAccess);
    // Once per boot, say so if the fix needs attention (typically after a SteamOS update).
    const noticeTimer = setTimeout(async () => {
        const n = await startupNotice();
        if (n.title)
            toaster.toast({ title: n.title, body: n.body ?? "", duration: 8000 });
    }, 15000);
    return {
        name: "X20 Fixes",
        titleView: SP_JSX.jsx("div", { className: DFL.staticClasses.Title, children: "X20 Fixes" }),
        content: SP_JSX.jsx(Content, {}),
        icon: SP_JSX.jsx(FaVolumeUp, {}),
        onDismount() {
            clearTimeout(noticeTimer);
            removeEventListener("job_done", onJobDone);
            removeEventListener("qam_button", onQamButton);
        },
    };
});

export { index as default };
//# sourceMappingURL=index.js.map
