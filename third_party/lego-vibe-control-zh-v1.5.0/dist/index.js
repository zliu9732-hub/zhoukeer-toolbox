const manifest = {"name":"Legion Go 震动控制"};
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

// ── Constants ─────────────────────────────────────────────────────────────────
const DEFAULT_APP = "0";
const LEVEL_LABELS = ["关闭", "低", "中", "高"];
const LEVEL_NOTCHES = ["关", "低", "中", "高"];
// Display names for the driver's raw mode values. Anything the driver
// reports that is not listed here is title-cased at render time, so a new
// kernel mode shows up without needing a plugin release.
const MODE_LABELS = {
    fps: "FPS",
    racing: "竞速",
    standard: "标准",
    spg: "SPG",
    rpg: "RPG",
};
const MODE_NOTCHES = {
    fps: "FPS",
    racing: "竞速",
    standard: "标准",
    spg: "SPG",
    rpg: "RPG",
};
const FALLBACK_MODES = ["fps", "racing", "standard", "spg", "rpg"];
const titleCase = (raw) => raw.charAt(0).toUpperCase() + raw.slice(1);
const modeLabel = (raw) => MODE_LABELS[raw] ?? titleCase(raw);
const modeNotch = (raw) => MODE_NOTCHES[raw] ?? titleCase(raw).slice(0, 5);
// ── Backend callables ─────────────────────────────────────────────────────────
const isReady = callable("is_ready");
const getSettings = callable("get_settings");
const setActiveApp = callable("set_active_app");
const setIntensity = callable("set_intensity");
const setRumbleMode = callable("set_rumble_mode");
const setTouchpadIntensity = callable("set_touchpad_intensity");
const setTouchpadEnabled = callable("set_touchpad_enabled");
const resetToDefault = callable("reset_to_default");
const reapply = callable("reapply");
const setProfileOverwrite = callable("set_profile_overwrite");
const getDriverStatus = callable("get_driver_status");
const getCapabilities = callable("get_capabilities");
const getVersion = callable("get_version");
const testVibration = callable("test_vibration");
const checkForUpdates = callable("check_for_updates");
const performUpdate = callable("perform_update");
// ── Toasts ────────────────────────────────────────────────────────────────────
const notify = (title, body) => {
    try {
        toaster.toast({ title, body, duration: 4000 });
    }
    catch {
        console.error(`[lego-vibe] ${title}: ${body}`);
    }
};
const notifyFailure = (title, err) => {
    const body = err instanceof Error ? err.message : String(err ?? "未知错误");
    console.error(`[lego-vibe] ${title}`, err);
    notify(title, body);
};
/** Report a backend result that carries its own error string. */
const checkResult = (title, res) => {
    if (!res.success)
        notify(title, res.error ?? "The driver rejected the change");
    return res.success;
};
// ── Resume from suspend ───────────────────────────────────────────────────────
/**
 * Subscribe to resume-from-suspend. Returns an unsubscribe function, or null
 * when the client offers no way to hear about it.
 *
 * `SteamClient.System.RegisterForOnResumeFromSuspend` was removed from the
 * Steam client in the September 2025 beta. Optional chaining meant calling it
 * silently did nothing - confirmed on the device, where two suspend cycles
 * produced no reapply at all. Nothing looked broken only because the
 * controller happened to re-enumerate and the hotplug monitor caught it; on a
 * resume where it does not, the write cache still believes our values are in
 * place and the controller quietly keeps the firmware defaults.
 *
 * The replacement lives on a SleepManager module, reachable either as a global
 * or through the webpack exports; the legacy call stays for older clients.
 */
function onResumeFromSuspend(handler) {
    const asUnsub = (reg) => {
        if (typeof reg === "function")
            return reg;
        if (typeof reg?.unregister === "function")
            return () => reg.unregister();
        return null;
    };
    const isSleepManager = (e) => !!e && typeof e === "object" &&
        (typeof e.RegisterForNotifyResumeFromSuspend === "function" ||
            typeof e.NotifyResumeFromSuspend === "function");
    try {
        const mgr = window.SleepManager ?? DFL.findModuleExport(isSleepManager);
        const unsub = asUnsub(mgr?.RegisterForNotifyResumeFromSuspend?.(handler));
        if (unsub)
            return unsub;
    }
    catch (e) {
        console.warn("[lego-vibe] SleepManager lookup failed", e);
    }
    try {
        const unsub = asUnsub(window.SteamClient?.System?.RegisterForOnResumeFromSuspend?.(handler));
        if (unsub)
            return unsub;
    }
    catch (e) {
        console.warn("[lego-vibe] legacy resume registration failed", e);
    }
    // Said out loud rather than swallowed: this going quiet again is exactly how
    // the previous registration rotted unnoticed.
    console.warn("[lego-vibe] no resume-from-suspend notification available; "
        + "settings will only be restored if the controller re-enumerates");
    return null;
}
/**
 * Tracks the foreground game and tells the backend about it, so the backend
 * can resolve per-game profiles on its own - including for hotplug and
 * resume, which never go through the UI.
 *
 * This used to poll every 100 ms. It now reacts to Steam's app lifetime
 * notifications, with a slow interval purely as a safety net because
 * Router.MainRunningApp can change without a lifetime event firing.
 */
class AppWatcher {
    static activeId() {
        try {
            return String(DFL.Router?.MainRunningApp?.appid || DEFAULT_APP);
        }
        catch {
            return DEFAULT_APP;
        }
    }
    static displayName() {
        try {
            const app = DFL.Router?.MainRunningApp;
            return app?.appid ? (app.display_name || `App ${app.appid}`) : "";
        }
        catch {
            return "";
        }
    }
    static listen(fn) {
        this.listeners.push(fn);
        return () => {
            this.listeners = this.listeners.filter((f) => f !== fn);
        };
    }
    static start() {
        if (this.started)
            return;
        this.started = true;
        this.currentId = this.activeId();
        // Push the starting state so the backend is never out of sync with us.
        void setActiveApp(this.currentId).catch((e) => console.error("[lego-vibe] initial setActiveApp failed", e));
        const steam = window.SteamClient;
        try {
            const reg = steam?.GameSessions?.RegisterForAppLifetimeNotifications?.(() => {
                // Router.MainRunningApp lags the notification slightly.
                setTimeout(() => void this.check(), 300);
            });
            if (reg?.unregister)
                this.unsubs.push(() => reg.unregister());
        }
        catch (e) {
            console.warn("[lego-vibe] app lifetime notifications unavailable", e);
        }
        // The controller comes back at its firmware defaults, and the backend's
        // write cache would otherwise skip the rewrite.
        const offResume = onResumeFromSuspend(() => {
            void reapply()
                .then((res) => {
                if (!res.success)
                    console.warn("[lego-vibe] reapply after resume failed");
            })
                .catch((e) => console.error("[lego-vibe] reapply after resume threw", e));
        });
        if (offResume)
            this.unsubs.push(offResume);
        this.timer = setInterval(() => void this.check(), 2000);
    }
    static stop() {
        if (this.timer) {
            clearInterval(this.timer);
            this.timer = undefined;
        }
        for (const off of this.unsubs) {
            try {
                off();
            }
            catch {
                /* the subscription may already be gone */
            }
        }
        this.unsubs = [];
        this.listeners = [];
        this.currentId = DEFAULT_APP;
        this.started = false;
    }
    static async check() {
        if (this.busy)
            return;
        const id = this.activeId();
        if (id === this.currentId)
            return;
        this.busy = true;
        try {
            const res = await setActiveApp(id);
            // Committed only once the backend has it. Recording the id before the
            // call meant a single failed RPC - the loader restarting, say - left
            // every later tick thinking there was nothing to send, so the hardware
            // kept the previous game's profile for the rest of the session.
            this.currentId = id;
            this.listeners.forEach((fn) => fn(res));
        }
        catch (e) {
            console.error("[lego-vibe] setActiveApp failed, will retry", e);
        }
        finally {
            this.busy = false;
        }
    }
}
AppWatcher.listeners = [];
AppWatcher.currentId = DEFAULT_APP;
AppWatcher.unsubs = [];
AppWatcher.started = false;
AppWatcher.busy = false;
// ── Styles - Steam theme variables with hardcoded fallbacks ───────────────────
const OK_COLOR = "var(--gpColor-Green, #4ade80)";
const BAD_COLOR = "var(--gpColor-Red, #f87171)";
const WARN_COLOR = "var(--gpColor-Yellow, #fbbf24)";
const DIM_COLOR = "var(--gpColor-TextMuted, rgba(255,255,255,0.5))";
const styles = {
    container: { display: "flex", flexDirection: "column", gap: "4px" },
    statusRow: { display: "flex", alignItems: "center", gap: "8px", padding: "4px 0" },
    dot: (ok) => ({
        width: "8px",
        height: "8px",
        borderRadius: "50%",
        backgroundColor: ok ? OK_COLOR : BAD_COLOR,
        flexShrink: 0,
    }),
    statusText: (ok) => ({
        fontSize: "11px",
        color: ok ? OK_COLOR : BAD_COLOR,
        fontFamily: "monospace",
        wordBreak: "break-all",
    }),
    valueTag: {
        fontSize: "13px",
        fontWeight: "bold",
        color: "var(--gpColor-White, #fff)",
        background: "rgba(255,255,255,0.1)",
        borderRadius: "4px",
        padding: "1px 6px",
        fontFamily: "monospace",
    },
    infoBox: {
        background: "rgba(251,191,36,0.15)",
        border: "1px solid rgba(251,191,36,0.4)",
        borderRadius: "6px",
        padding: "8px 10px",
        fontSize: "11px",
        color: WARN_COLOR,
        lineHeight: "1.5",
        marginTop: "4px",
    },
    errorBox: {
        background: "rgba(248,113,113,0.1)",
        border: "1px solid rgba(248,113,113,0.4)",
        borderRadius: "6px",
        padding: "8px 10px",
        fontSize: "11px",
        color: BAD_COLOR,
        lineHeight: "1.5",
        marginTop: "4px",
    },
    methodText: {
        fontSize: "10px",
        color: DIM_COLOR,
        fontFamily: "monospace",
        marginTop: "2px",
    },
    profileTag: {
        fontSize: "11px",
        fontWeight: "bold",
        color: "var(--gpColor-White, #fff)",
        background: "rgba(74,222,128,0.25)",
        border: "1px solid rgba(74,222,128,0.5)",
        borderRadius: "3px",
        padding: "0px 5px",
        fontFamily: "monospace",
    },
};
// ── Main component ────────────────────────────────────────────────────────────
const DEFAULT_SETTINGS = {
    level: 2,
    mode: 0,
    touchpadIntensity: 2,
    touchpadEnabled: true,
};
const LGoVibeControl = () => {
    const [settings, setSettings] = SP_REACT.useState(DEFAULT_SETTINGS);
    const [modes, setModes] = SP_REACT.useState(FALLBACK_MODES);
    const [driver, setDriver] = SP_REACT.useState(null);
    const [version, setVersion] = SP_REACT.useState("");
    const [appId, setAppId] = SP_REACT.useState(DEFAULT_APP);
    const [gameName, setGameName] = SP_REACT.useState("");
    const [perGameOn, setPerGameOn] = SP_REACT.useState(false);
    const [loading, setLoading] = SP_REACT.useState(true);
    const [setupErr, setSetupErr] = SP_REACT.useState(null);
    const [applying, setApplying] = SP_REACT.useState(false);
    const [testing, setTesting] = SP_REACT.useState(false);
    const [updateInfo, setUpdateInfo] = SP_REACT.useState(null);
    const [checking, setChecking] = SP_REACT.useState(false);
    const [downloading, setDownloading] = SP_REACT.useState(false);
    const [downloadPath, setDownloadPath] = SP_REACT.useState(null);
    const visible = useQuickAccessVisible();
    // Coalesces a slider drag into a single backend call. The UI still moves
    // immediately; only the RPC and its disk commit are deferred.
    const timers = SP_REACT.useRef({});
    const debounce = SP_REACT.useCallback((key, fn, delay = 150) => {
        const pending = timers.current[key];
        if (pending)
            clearTimeout(pending);
        timers.current[key] = setTimeout(fn, delay);
    }, []);
    SP_REACT.useEffect(() => () => {
        for (const t of Object.values(timers.current))
            clearTimeout(t);
    }, []);
    // Bumped by every optimistic edit. A reply may only overwrite the UI while it
    // is still the newest thing that happened, otherwise a slow sysfs write snaps
    // the slider back to a value the user has already moved off.
    const editSeq = SP_REACT.useRef(0);
    const adoptResponse = SP_REACT.useCallback((res) => {
        // Counts as an edit: switching game replaces the whole profile, and a field
        // reply still in flight from the previous one must not undo that.
        editSeq.current += 1;
        setSettings(res.settings);
        setAppId(res.app_id);
        setPerGameOn(res.overwrite);
        setGameName(AppWatcher.displayName());
    }, []);
    const refreshDriver = SP_REACT.useCallback(async () => {
        try {
            setDriver(await getDriverStatus());
        }
        catch (e) {
            console.error("[lego-vibe] getDriverStatus failed", e);
        }
    }, []);
    // Initial load. Gated on is_ready so a backend that failed to start shows the
    // reason instead of sliders that silently do nothing.
    SP_REACT.useEffect(() => {
        let active = true;
        const check = async () => {
            try {
                const state = await isReady();
                if (!active)
                    return;
                if (state.error) {
                    setSetupErr(state.error);
                    setLoading(false);
                    return;
                }
                if (!state.ready) {
                    if (active)
                        setTimeout(check, 1000);
                    return;
                }
                const [current, status, caps, ver] = await Promise.all([
                    getSettings(),
                    getDriverStatus(),
                    getCapabilities().catch(() => ({ mode: FALLBACK_MODES })),
                    getVersion().catch(() => ({ version: "" })),
                ]);
                if (!active)
                    return;
                adoptResponse(current);
                setDriver(status);
                setModes(caps?.mode?.length ? caps.mode : FALLBACK_MODES);
                setVersion(ver.version ?? "");
                setLoading(false);
            }
            catch (e) {
                if (!active)
                    return;
                notifyFailure("Legion Go 震动控制加载失败", e);
                setLoading(false);
            }
        };
        void check();
        return () => { active = false; };
    }, [adoptResponse]);
    // Hotplug pushes the driver status from the backend, so the dot is right even
    // while the panel is shut. Registered unconditionally: a controller is plugged
    // in with the Quick Access Menu closed far more often than with it open, and
    // adopting the state on arrival beats discovering it on the next open.
    //
    // Only the status. A hotplug re-applies the stored profile without changing
    // it, so a settings payload would carry nothing new - and feeding one to
    // adoptResponse bumps editSeq, which would make the panel throw away the
    // reply to an edit the user was making at that moment.
    SP_REACT.useEffect(() => {
        const onDevice = (status) => setDriver(status);
        addEventListener("device", onDevice);
        return () => removeEventListener("device", onDevice);
    }, []);
    // Still re-checked on open, as the backstop for the cases no event covers:
    // without pyudev there is no hotplug monitor at all, and a plugin reload
    // starts with whatever the hardware already is.
    SP_REACT.useEffect(() => {
        if (visible && !loading)
            void refreshDriver();
    }, [visible, loading, refreshDriver]);
    // Game changes are applied by the backend; just adopt what it reports.
    SP_REACT.useEffect(() => AppWatcher.listen(adoptResponse), [adoptResponse]);
    // Handlers
    const applyField = SP_REACT.useCallback(async (key, optimistic, call) => {
        const seq = ++editSeq.current;
        setSettings((prev) => ({ ...prev, ...optimistic }));
        debounce(key, () => {
            setApplying(true);
            call()
                .then((res) => {
                checkResult("Could not apply setting", res);
                if (res.settings && seq === editSeq.current)
                    setSettings(res.settings);
            })
                .catch((e) => {
                notifyFailure("Could not apply setting", e);
                // Only resync when nothing newer is pending; the newer edit's own
                // reply is the one that should decide what the panel shows.
                if (seq === editSeq.current) {
                    void getSettings().then(adoptResponse).catch(() => undefined);
                }
            })
                .finally(() => setApplying(false));
        });
    }, [debounce, adoptResponse]);
    const handleLevel = SP_REACT.useCallback((val) => void applyField("level", { level: val }, () => setIntensity(val)), [applyField]);
    const handleMode = SP_REACT.useCallback(
    // No sample is played here on purpose: the controller firmware already
    // demonstrates the new pattern. Adding our own put a second rumble on
    // top of it, which is why the same mode felt different every time.
    (val) => void applyField("mode", { mode: val }, () => setRumbleMode(val)), [applyField]);
    const handleTpIntensity = SP_REACT.useCallback((val) => void applyField("tpIntensity", { touchpadIntensity: val }, () => setTouchpadIntensity(val)), [applyField]);
    const handleTpToggle = SP_REACT.useCallback((val) => void applyField("tpEnabled", { touchpadEnabled: val }, () => setTouchpadEnabled(val)), [applyField]);
    const handleReset = SP_REACT.useCallback(async () => {
        setApplying(true);
        try {
            const res = await resetToDefault();
            if (checkResult("Reset failed", res)) {
                setSettings(res.settings);
                notify("Legion Go 震动控制", "已恢复默认设置");
            }
        }
        catch (e) {
            notifyFailure("Reset failed", e);
        }
        finally {
            setApplying(false);
        }
    }, []);
    const handleTest = SP_REACT.useCallback(async () => {
        setTesting(true);
        try {
            const res = await testVibration(500);
            checkResult("Test vibration failed", res);
        }
        catch (e) {
            notifyFailure("Test vibration failed", e);
        }
        finally {
            setTesting(false);
        }
    }, []);
    const handlePerGameToggle = SP_REACT.useCallback(async (val) => {
        setPerGameOn(val);
        setApplying(true);
        try {
            // The backend applies the resolved profile for us, which is what the
            // old frontend skipped when *enabling* a profile - the UI showed the
            // game's values while the hardware kept the global ones.
            const res = await setProfileOverwrite(appId, val, AppWatcher.displayName());
            if (checkResult("Could not switch profile", res)) {
                setSettings(res.settings);
            }
            else {
                setPerGameOn(!val);
            }
        }
        catch (e) {
            setPerGameOn(!val);
            notifyFailure("Could not switch profile", e);
        }
        finally {
            setApplying(false);
        }
    }, [appId]);
    const handleCheckUpdate = SP_REACT.useCallback(async () => {
        setChecking(true);
        setUpdateInfo(null);
        setDownloadPath(null);
        try {
            setUpdateInfo(await checkForUpdates());
        }
        catch (e) {
            notifyFailure("Update check failed", e);
            setUpdateInfo({ error: e instanceof Error ? e.message : String(e) });
        }
        finally {
            setChecking(false);
        }
    }, []);
    const handleDownloadUpdate = SP_REACT.useCallback(async () => {
        if (!updateInfo?.download_url || !updateInfo?.asset_name)
            return;
        setDownloading(true);
        try {
            const res = await performUpdate(updateInfo.download_url, updateInfo.asset_name);
            if (res.success && res.path)
                setDownloadPath(res.path);
            else {
                setUpdateInfo({ ...updateInfo, error: res.error });
                notify("下载失败", res.error ?? "未知错误");
            }
        }
        catch (e) {
            notifyFailure("下载失败", e);
        }
        finally {
            setDownloading(false);
        }
    }, [updateInfo]);
    // Render
    if (setupErr) {
        return (SP_JSX.jsx(DFL.PanelSection, { title: "\u8BBE\u7F6E\u9519\u8BEF", children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: styles.errorBox, children: setupErr }) }) }));
    }
    if (loading) {
        return (SP_JSX.jsx(DFL.PanelSection, { title: "\u6B63\u5728\u521D\u59CB\u5316\u2026", children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.Spinner, {}) }) }));
    }
    const driverFound = driver?.found ?? false;
    const gameRunning = appId !== DEFAULT_APP;
    const modeName = modes[settings.mode] ?? FALLBACK_MODES[0];
    return (SP_JSX.jsxs("div", { style: styles.container, children: [SP_JSX.jsx("div", { style: { color: "#d9a441", fontSize: "12px", padding: "4px 12px" }, children: "\u4E2D\u6587\u6C49\u5316\uFF1ARen-Amamiya-pixie / zliu9732-hub\uFF08\u95F2\u9C7CRenAmamiya\uFF09" }), SP_JSX.jsxs(DFL.PanelSection, { title: "\u9A71\u52A8\u72B6\u6001", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: styles.statusRow, children: [SP_JSX.jsx("div", { style: styles.dot(driverFound) }), SP_JSX.jsxs("div", { children: [SP_JSX.jsx("span", { style: styles.statusText(driverFound), children: driverFound
                                                ? driver?.paths[0] ?? "已找到 hid-lenovo-go"
                                                : "未找到 hid-lenovo-go 驱动" }), driverFound && driver?.method && (SP_JSX.jsxs("div", { style: styles.methodText, children: ["\u65B9\u5F0F\uFF1A", driver.method, driver.ids ? ` (${driver.ids})` : ""] }))] })] }) }), !driverFound && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: styles.infoBox, children: "\u672A\u68C0\u6D4B\u5230 hid-lenovo-go sysfs \u63A5\u53E3\u3002\u9700\u8981 SteamOS 3.8+ / \u5185\u6838 6.18+\uFF0C\u5E76\u5728 Legion Go \u4E0A\u52A0\u8F7D hid-lenovo-go \u6A21\u5757\u3002" }) }))] }), SP_JSX.jsx(DFL.PanelSection, { title: "\u6309\u6E38\u620F\u914D\u7F6E", children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "\u542F\u7528\u6309\u6E38\u620F\u914D\u7F6E", description: gameRunning ? (perGameOn ? (SP_JSX.jsxs("span", { style: { display: "flex", flexDirection: "column", gap: "3px" }, children: [SP_JSX.jsx("span", { children: gameName }), SP_JSX.jsx("span", { children: SP_JSX.jsxs("span", { style: styles.profileTag, children: [modeLabel(modeName), " | ", LEVEL_LABELS[settings.level]] }) })] })) : (gameName)) : ("启动游戏后即可使用独立配置。"), checked: perGameOn && gameRunning, disabled: !gameRunning || applying, onChange: handlePerGameToggle }) }) }), SP_JSX.jsxs(DFL.PanelSection, { title: "\u9707\u52A8", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.SliderField, { label: "\u5F3A\u5EA6", description: SP_JSX.jsxs("span", { children: ["\u7EA7\u522B\uFF1A ", SP_JSX.jsx("span", { style: styles.valueTag, children: LEVEL_LABELS[settings.level] })] }), value: settings.level, min: 0, max: 3, step: 1, notchCount: 4, notchLabels: LEVEL_NOTCHES.map((label, notchIndex) => ({ notchIndex, label })), onChange: handleLevel }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.SliderField, { label: "\u6A21\u5F0F", description: SP_JSX.jsxs("span", { children: ["\u6A21\u5F0F\uFF1A ", SP_JSX.jsx("span", { style: styles.valueTag, children: modeLabel(modeName) })] }), value: settings.mode, min: 0, max: Math.max(0, modes.length - 1), step: 1, notchCount: modes.length, notchLabels: modes.map((raw, notchIndex) => ({ notchIndex, label: modeNotch(raw) })), onChange: handleMode }) })] }), SP_JSX.jsxs(DFL.PanelSection, { title: "\u89E6\u63A7\u677F", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "\u89E6\u63A7\u677F\u9707\u52A8", description: "\u542F\u7528\u89E6\u63A7\u677F\u89E6\u89C9\u53CD\u9988", checked: settings.touchpadEnabled, onChange: handleTpToggle }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.SliderField, { label: "\u89E6\u63A7\u677F\u5F3A\u5EA6", description: SP_JSX.jsxs("span", { children: ["\u7EA7\u522B\uFF1A", " ", SP_JSX.jsx("span", { style: styles.valueTag, children: LEVEL_LABELS[settings.touchpadIntensity] })] }), value: settings.touchpadIntensity, min: 0, max: 3, step: 1, notchCount: 4, notchLabels: LEVEL_NOTCHES.map((label, notchIndex) => ({ notchIndex, label })), disabled: !settings.touchpadEnabled, onChange: handleTpIntensity }) })] }), SP_JSX.jsxs(DFL.PanelSection, { title: "\u64CD\u4F5C", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", description: "\u6D4B\u8BD5\u5F53\u524D\u5F3A\u5EA6\u548C\u9707\u52A8\u6A21\u5F0F\u3002", onClick: handleTest, disabled: applying || testing, children: testing ? "正在震动…" : "测试震动（0.5 秒）" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: handleReset, disabled: applying || testing, children: "\u6062\u590D\u9ED8\u8BA4\u8BBE\u7F6E" }) })] }), SP_JSX.jsxs(DFL.PanelSection, { title: "\u66F4\u65B0", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: { fontSize: "12px", color: DIM_COLOR }, children: ["\u5DF2\u5B89\u88C5\uFF1A", " ", SP_JSX.jsxs("span", { style: styles.valueTag, children: ["v", updateInfo?.current_version ?? version ?? "?"] }), updateInfo?.latest_version && !updateInfo.error && (SP_JSX.jsxs("span", { children: [" ", "\u6700\u65B0\uFF1A ", SP_JSX.jsxs("span", { style: styles.valueTag, children: ["v", updateInfo.latest_version] })] }))] }) }), updateInfo?.error && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: styles.errorBox, children: updateInfo.error }) })), updateInfo && !updateInfo.error && !updateInfo.update_available && !downloadPath && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: { fontSize: "12px", color: OK_COLOR }, children: "\u5DF2\u662F\u6700\u65B0\u7248\u672C" }) })), updateInfo?.update_available && !downloadPath && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: handleDownloadUpdate, disabled: downloading, children: downloading ? "正在下载…" : `下载 v${updateInfo.latest_version}` }) })), downloadPath && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: styles.infoBox, children: ["\u5DF2\u4E0B\u8F7D\u5230", " ", SP_JSX.jsx("span", { style: { fontFamily: "monospace", wordBreak: "break-all" }, children: downloadPath }), SP_JSX.jsx("br", {}), SP_JSX.jsx("br", {}), "\u5B89\u88C5\u65B9\u6CD5\uFF1A\u5728 Decky \u5F00\u53D1\u8005\u9009\u9879\u4E2D\u5378\u8F7D\u65E7\u7248\uFF0C\u518D\u9009\u62E9\u201C\u4ECE ZIP \u5B89\u88C5\u63D2\u4EF6\u201D\u5E76\u9009\u4E2D\u8BE5\u6587\u4EF6\u3002"] }) })), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: handleCheckUpdate, disabled: checking || downloading, children: checking ? "正在检查…" : "检查更新" }) })] }), SP_JSX.jsx(DFL.PanelSection, { title: "\u8BF4\u660E", children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: styles.infoBox, children: "\u5F3A\u5EA6\u5206\u4E3A\u5173\u95ED\u3001\u4F4E\u3001\u4E2D\u3001\u9AD8\u3002\u6A21\u5F0F\u4F1A\u6539\u53D8\u4E24\u4FA7\u624B\u67C4\u7684\u9707\u52A8\u8282\u594F\u3002\u8BBE\u7F6E\u4F1A\u5728\u91CD\u542F\u540E\u4FDD\u7559\uFF0C\u5E76\u5728\u5524\u9192\u6216\u624B\u67C4\u91CD\u8FDE\u540E\u91CD\u65B0\u5E94\u7528\uFF1B\u542F\u52A8\u5DF2\u6709\u914D\u7F6E\u7684\u6E38\u620F\u65F6\u4F1A\u81EA\u52A8\u5957\u7528\u3002" }) }) })] }));
};
// ── Plugin entry point ────────────────────────────────────────────────────────
var index = definePlugin(() => {
    // Started unconditionally: the old code registered the game listener inside
    // an init().then(), so a single failed load disabled per-game profiles for
    // the rest of the session.
    AppWatcher.start();
    return {
        name: "Legion Go 震动控制",
        titleView: SP_JSX.jsx("div", { className: DFL.staticClasses.Title, children: "Legion Go \u9707\u52A8\u63A7\u5236" }),
        content: SP_JSX.jsx(LGoVibeControl, {}),
        icon: (SP_JSX.jsx("svg", { xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: "currentColor", style: { width: "1em", height: "1em" }, children: SP_JSX.jsx("path", { d: "M0 15h2V9H0v6zm3 2h2V7H3v10zm19-8v6h2V9h-2zm-3 8h2V7h-2v10zm-7-1c2.76 0 5-2.24 5-5s-2.24-5-5-5-5 2.24-5 5 2.24 5 5 5zm0-8c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3z" }) })),
        onDismount() {
            AppWatcher.stop();
        },
    };
});

export { index as default };
//# sourceMappingURL=index.js.map
