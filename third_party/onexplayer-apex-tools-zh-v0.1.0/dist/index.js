const manifest = {"name":"OneXPlayer Apex 工具"};
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
const definePlugin = (fn) => {
    return (...args) => {
        return fn(...args);
    };
};

const BUILD_ID = "build-b696161-zh-renamamiya-r2";

const getStatus = callable("get_status");
const applyButtonFix = callable("apply_button_fix");
const revertButtonFix = callable("revert_button_fix");
const applyLightSleep = callable("apply_light_sleep");
const revertLightSleep = callable("revert_light_sleep");
const saveLogs = callable("save_logs");
const enableSpeakerDSP = callable("enable_speaker_dsp");
const disableSpeakerDSP = callable("disable_speaker_dsp");
const setDSPProfile = callable("set_dsp_profile");
const getLogs = callable("get_logs");
const getPresetBands = callable("get_preset_bands");
const getCustomProfiles = callable("get_custom_profiles");
const saveCustomProfile = callable("save_custom_profile");
const deleteCustomProfile = callable("delete_custom_profile");
const playTestSound = callable("play_test_sound");
const stopTestSound = callable("stop_test_sound");
const bypassSpeakerDSP = callable("bypass_speaker_dsp");
const unbypassSpeakerDSP = callable("unbypass_speaker_dsp");
const isBypassedSpeakerDSP = callable("is_bypassed_speaker_dsp");
// oxpec EC sensor driver
const applyOxpec = callable("apply_oxpec");
const revertOxpec = callable("revert_oxpec");
// Resume recovery (gamepad after sleep)
const applyResumeFix = callable("apply_resume_fix");
const revertResumeFix = callable("revert_resume_fix");
// xHCI recovery (manual gamepad recovery)
const recoverGamepad = callable("recover_gamepad");
// Sleep enablement (fw-fanctrl + fingerprint)
const applySleepEnable = callable("apply_sleep_enable");
const revertSleepEnable = callable("revert_sleep_enable");

const InlineStatus = ({ loading, result, section, }) => {
    if (loading.active === section) {
        return (SP_JSX.jsxs("div", { style: { display: "flex", alignItems: "center", gap: "8px", padding: "4px 0 8px 0" }, children: [SP_JSX.jsx(DFL.Spinner, { style: { width: "16px", height: "16px" } }), SP_JSX.jsx("span", { style: { fontSize: "12px", color: "#aaa" }, children: loading.message })] }));
    }
    if (result && result.key === section) {
        return (SP_JSX.jsx("div", { style: {
                padding: "4px 0 8px 0",
                fontSize: "12px",
                color: result.type === "error" ? "#ff4444" : "#44bb44",
            }, children: result.text }));
    }
    return null;
};

const PRESET_NAMES = ["balanced", "bass_boost", "treble"];
const EQ_BAND_DEFS = [
    { label: "低音", freq: 64 },
    { label: "中低音", freq: 125 },
    { label: "低中音", freq: 250 },
    { label: "中音", freq: 500 },
    { label: "中高音", freq: 2000 },
    { label: "高音", freq: 8000 },
    { label: "空气感", freq: 16000 },
];
const EQSliders = ({ gains, disabled, onChange }) => (SP_JSX.jsx(SP_JSX.Fragment, { children: EQ_BAND_DEFS.map((band) => {
        const freqStr = String(band.freq);
        const value = gains[freqStr] ?? 0;
        const freqLabel = band.freq >= 1000 ? `${band.freq / 1000}k` : `${band.freq}`;
        return (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.SliderField, { label: `${band.label} (${freqLabel} Hz)`, value: value, min: -15, max: 15, step: 1, showValue: true, disabled: disabled, onChange: disabled
                    ? undefined
                    : (val) => onChange?.(freqStr, val) }) }, freqStr));
    }) }));
const SpeakerDSPSection = ({ dspStatus, onStatusChange, loading, setLoading, showResult, result }) => {
    const [customProfiles, setCustomProfiles] = SP_REACT.useState({});
    const [bandGains, setBandGains] = SP_REACT.useState({});
    const [testPlaying, setTestPlaying] = SP_REACT.useState(false);
    const [bypassed, setBypassed] = SP_REACT.useState(false);
    const [bypassError, setBypassError] = SP_REACT.useState("");
    const [namingMode, setNamingMode] = SP_REACT.useState(false);
    const [newName, setNewName] = SP_REACT.useState("");
    const debounceRef = SP_REACT.useRef(undefined);
    const activeRef = SP_REACT.useRef(false);
    const isPreset = PRESET_NAMES.includes(dspStatus.profile || "");
    const isCustom = !isPreset && dspStatus.profile != null && dspStatus.profile !== "";
    // Load custom profiles and bypass status on mount
    SP_REACT.useEffect(() => {
        getCustomProfiles().then((res) => setCustomProfiles(res.profiles || {})).catch(() => { });
        if (dspStatus.enabled) {
            isBypassedSpeakerDSP().then((res) => setBypassed(res.bypassed)).catch(() => { });
        }
    }, []);
    // Load band values when profile changes
    SP_REACT.useEffect(() => {
        if (!dspStatus.enabled || !dspStatus.profile)
            return;
        if (isPreset) {
            getPresetBands(dspStatus.profile).then((res) => {
                if (res.bands) {
                    const g = {};
                    for (const b of res.bands)
                        g[String(b.freq)] = b.gain;
                    setBandGains(g);
                }
            }).catch(() => { });
        }
        else if (isCustom && customProfiles[dspStatus.profile]) {
            setBandGains({ ...customProfiles[dspStatus.profile] });
        }
    }, [dspStatus.profile, dspStatus.enabled, isPreset, isCustom, customProfiles]);
    // Cleanup debounce on unmount
    SP_REACT.useEffect(() => () => { if (debounceRef.current)
        clearTimeout(debounceRef.current); }, []);
    // Stop test sound on unmount
    SP_REACT.useEffect(() => () => { stopTestSound().catch(() => { }); }, []);
    const refreshCustomProfiles = async () => {
        try {
            const res = await getCustomProfiles();
            setCustomProfiles(res.profiles || {});
        }
        catch (_) { }
    };
    const refreshBypassState = async () => {
        try {
            const res = await isBypassedSpeakerDSP();
            setBypassed(res.bypassed);
            setBypassError("");
        }
        catch (_) { }
    };
    const handleToggle = async (enabled) => {
        setLoading({ active: "dsp", message: enabled ? "正在启用扬声器 DSP…" : "正在关闭扬声器 DSP…" });
        try {
            const res = enabled
                ? await enableSpeakerDSP(dspStatus.profile || "balanced")
                : await disableSpeakerDSP();
            if (res.success) {
                onStatusChange({ ...dspStatus, enabled });
                showResult("dsp", res.message || (enabled ? "已启用" : "已关闭"), "success");
                if (enabled)
                    await refreshBypassState();
                else
                    setBypassed(false);
            }
            else {
                showResult("dsp", res.error || "操作失败", "error");
            }
        }
        catch (e) {
            showResult("dsp", `错误：${e}`, "error");
        }
        finally {
            setLoading({ active: null, message: "" });
        }
    };
    const handleProfileChange = async (profile) => {
        if (profile === "__new_custom__") {
            setNamingMode(true);
            setNewName("");
            return;
        }
        setLoading({ active: "dsp", message: "正在切换均衡器配置…" });
        try {
            const res = await setDSPProfile(profile);
            if (res.success) {
                onStatusChange({ ...dspStatus, profile });
                showResult("dsp", res.message || `已切换到 ${profile}`, "success");
                await refreshBypassState();
            }
            else {
                showResult("dsp", res.error || "操作失败", "error");
            }
        }
        catch (e) {
            showResult("dsp", `错误：${e}`, "error");
        }
        finally {
            setLoading({ active: null, message: "" });
        }
    };
    const handleCopyToCustom = () => {
        setNamingMode(true);
        setNewName("");
    };
    const handleCreateCustom = async () => {
        const name = newName.trim();
        if (!name)
            return;
        setNamingMode(false);
        setLoading({ active: "dsp", message: "正在创建自定义配置…" });
        try {
            // Use current band gains as starting point
            const res = await saveCustomProfile(name, bandGains);
            if (res.success) {
                await refreshCustomProfiles();
                // Switch to the new profile
                const switchRes = await setDSPProfile(name);
                if (switchRes.success) {
                    onStatusChange({ ...dspStatus, profile: name });
                }
                showResult("dsp", `已创建“${name}”`, "success");
            }
            else {
                showResult("dsp", res.error || "操作失败", "error");
            }
        }
        catch (e) {
            showResult("dsp", `错误：${e}`, "error");
        }
        finally {
            setLoading({ active: null, message: "" });
        }
    };
    const handleBandChange = (freq, value) => {
        const updated = { ...bandGains, [freq]: value };
        setBandGains(updated);
        activeRef.current = true;
        if (debounceRef.current)
            clearTimeout(debounceRef.current);
        debounceRef.current = setTimeout(async () => {
            try {
                if (isCustom && dspStatus.profile) {
                    await saveCustomProfile(dspStatus.profile, updated);
                    await refreshCustomProfiles();
                    await refreshBypassState();
                }
            }
            finally {
                activeRef.current = false;
            }
        }, 500);
    };
    const handleDeleteProfile = async () => {
        if (!isCustom || !dspStatus.profile)
            return;
        setLoading({ active: "dsp", message: "正在删除配置…" });
        try {
            const res = await deleteCustomProfile(dspStatus.profile);
            if (res.success) {
                await refreshCustomProfiles();
                onStatusChange({ ...dspStatus, profile: "balanced" });
                showResult("dsp", "配置已删除", "success");
            }
            else {
                showResult("dsp", res.error || "操作失败", "error");
            }
        }
        catch (e) {
            showResult("dsp", `错误：${e}`, "error");
        }
        finally {
            setLoading({ active: null, message: "" });
        }
    };
    const handleTestSound = async () => {
        try {
            if (testPlaying) {
                await stopTestSound();
                setTestPlaying(false);
            }
            else {
                const res = await playTestSound();
                if (res.success)
                    setTestPlaying(true);
                else
                    showResult("dsp", res.error || "播放失败", "error");
            }
        }
        catch (e) {
            showResult("dsp", `错误：${e}`, "error");
        }
    };
    const handleBypass = async (on) => {
        setBypassError("");
        try {
            const res = on ? await bypassSpeakerDSP() : await unbypassSpeakerDSP();
            if (res.success) {
                await refreshBypassState();
            }
            else {
                setBypassError(res.error || "切换失败");
            }
        }
        catch (e) {
            setBypassError(`错误：${e}`);
        }
    };
    // Build dropdown options: presets + custom profiles + "New Custom..."
    const profileOptions = [
        { data: "balanced", label: "均衡" },
        { data: "bass_boost", label: "低音增强" },
        { data: "treble", label: "高音增强" },
        ...Object.keys(customProfiles).map((n) => ({ data: n, label: n })),
        { data: "__new_custom__", label: "新建自定义配置…" },
    ];
    return (SP_JSX.jsxs(DFL.PanelSection, { title: "扬声器 DSP", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "扬声器增强", description: dspStatus.enabled
                        ? `已增强：${dspStatus.profile || "balanced"} 配置`
                        : "已关闭：使用原始扬声器输出", checked: dspStatus.enabled, disabled: loading.active === "dsp", onChange: handleToggle }) }), SP_JSX.jsx(InlineStatus, { loading: loading, result: result, section: "dsp" }), dspStatus.enabled && (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.DropdownItem, { label: "均衡器配置", rgOptions: profileOptions.map((o) => ({ data: o.data, label: o.label })), selectedOption: dspStatus.profile || "balanced", onChange: (option) => handleProfileChange(option.data) }) }), namingMode && (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.TextField, { label: "配置名称", value: newName, onChange: (e) => setNewName(typeof e === "string" ? e : e?.target?.value ?? "") }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: handleCreateCustom, disabled: !newName.trim(), children: "创建配置" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: () => setNamingMode(false), children: "取消" }) })] })), !namingMode && (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(EQSliders, { gains: bandGains, disabled: isPreset, onChange: isCustom ? handleBandChange : undefined }), isPreset && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: handleCopyToCustom, children: "复制为自定义配置" }) })), isCustom && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: handleDeleteProfile, disabled: loading.active === "dsp", children: "删除配置" }) }))] })), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "原始声音", description: bypassError || (bypassed ? "原始扬声器输出：不使用均衡器" : "扬声器增强已启用"), checked: bypassed, onChange: handleBypass }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "测试声音", description: testPlaying ? "正在播放：关闭开关可停止" : "播放音乐以试听均衡器效果", checked: testPlaying, onChange: handleTestSound }) }), testPlaying && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: { fontSize: "10px", color: "#666", lineHeight: "1.3", padding: "0 0 4px 0" }, children: ["曲目：Extra Terra, Max Brhon - Cyberblade [NCS Release]", " · ", "音乐由 NoCopyrightSounds 提供"] }) }))] })), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: {
                        backgroundColor: "#1a2a3a",
                        border: "1px solid #2a4a6a",
                        borderRadius: "4px",
                        padding: "8px 12px",
                        fontSize: "11px",
                        lineHeight: "1.4",
                        color: "#88bbdd",
                    }, children: "均衡器只作用于内置扬声器，不影响耳机和外接音频设备。" }) })] }));
};

const FixesSection = ({ buttonFix, setButtonFix, lightSleep, setLightSleep, oxpec, setOxpec, resumeFix, setResumeFix, sleepEnable, setSleepEnable, loading, setLoading, showResult, result, statusLoaded, refresh }) => {
    const handleButtonFix = async (enabled) => {
        setLoading({
            active: "button",
            message: enabled
                ? "正在应用按键修复…（解锁文件系统最多可能需要 60 秒）"
                : "正在撤销按键修复…",
        });
        try {
            const res = enabled ? await applyButtonFix() : await revertButtonFix();
            if (res.success) {
                setButtonFix({ applied: enabled });
                showResult("button", res.message || (enabled ? "已应用" : "已撤销"), "success");
            }
            else {
                showResult("button", res.error || "操作失败", "error");
            }
        }
        catch (e) {
            showResult("button", `错误：${e}`, "error");
        }
        finally {
            setLoading({ active: null, message: "" });
            refresh();
        }
    };
    const handleLightSleep = async (enabled) => {
        setLoading({
            active: "lightSleep",
            message: enabled
                ? "正在应用轻度休眠内核参数（rpm-ostree）…"
                : "正在移除轻度休眠内核参数（rpm-ostree）…",
        });
        try {
            const res = enabled ? await applyLightSleep() : await revertLightSleep();
            if (res.success) {
                if (res.reboot_needed) {
                    showResult("lightSleep", res.message || "需要重启，重启后请重新应用按键修复。", "success");
                }
                else {
                    setLightSleep((prev) => ({ ...prev, applied: enabled }));
                    showResult("lightSleep", res.message || "已完成", "success");
                }
            }
            else {
                showResult("lightSleep", res.error || "操作失败", "error");
            }
        }
        catch (e) {
            showResult("lightSleep", `错误：${e}`, "error");
        }
        finally {
            setLoading({ active: null, message: "" });
            refresh();
        }
    };
    const handleOxpec = async (enabled) => {
        setLoading({
            active: "oxpec",
            message: enabled ? "正在安装 oxpec 驱动…" : "正在移除 oxpec 驱动…",
        });
        try {
            const res = enabled ? await applyOxpec() : await revertOxpec();
            if (res.success) {
                setOxpec((prev) => ({ ...prev, applied: enabled }));
                showResult("oxpec", res.message || (enabled ? "已安装" : "已移除"), "success");
            }
            else {
                showResult("oxpec", res.error || "操作失败", "error");
            }
        }
        catch (e) {
            showResult("oxpec", `错误：${e}`, "error");
        }
        finally {
            setLoading({ active: null, message: "" });
            refresh();
        }
    };
    const handleResumeFix = async (enabled) => {
        setLoading({
            active: "resume",
            message: enabled ? "正在安装唤醒恢复…" : "正在移除唤醒恢复…",
        });
        try {
            const res = enabled ? await applyResumeFix() : await revertResumeFix();
            if (res.success) {
                setResumeFix((prev) => ({ ...prev, applied: enabled }));
                showResult("resume", res.message || (enabled ? "已安装" : "已移除"), "success");
            }
            else {
                showResult("resume", res.error || "操作失败", "error");
            }
        }
        catch (e) {
            showResult("resume", `错误：${e}`, "error");
        }
        finally {
            setLoading({ active: null, message: "" });
            refresh();
        }
    };
    const handleRecoverGamepad = async () => {
        setLoading({ active: "recoverGamepad", message: "正在恢复手柄（重新绑定 USB）…" });
        try {
            const res = await recoverGamepad();
            if (res.success) {
                showResult("recoverGamepad", res.message || "已恢复", "success");
            }
            else {
                showResult("recoverGamepad", res.error || "操作失败", "error");
            }
        }
        catch (e) {
            showResult("recoverGamepad", `错误：${e}`, "error");
        }
        finally {
            setLoading({ active: null, message: "" });
            refresh();
        }
    };
    const handleSleepEnable = async (enabled) => {
        setLoading({
            active: "sleepEnable",
            message: enabled ? "正在应用休眠修复…" : "正在撤销休眠修复…",
        });
        try {
            const res = enabled ? await applySleepEnable() : await revertSleepEnable();
            if (res.success) {
                setSleepEnable((prev) => ({ ...prev, applied: enabled }));
                showResult("sleepEnable", res.message || (enabled ? "已应用" : "已撤销"), "success");
            }
            else {
                showResult("sleepEnable", res.error || "操作失败", "error");
            }
        }
        catch (e) {
            showResult("sleepEnable", `错误：${e}`, "error");
        }
        finally {
            setLoading({ active: null, message: "" });
            refresh();
        }
    };
    return (SP_JSX.jsx(DFL.PanelSection, { title: "修复工具", children: !statusLoaded ? (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: { display: "flex", alignItems: "center", gap: "8px", padding: "8px 0" }, children: [SP_JSX.jsx(DFL.Spinner, { style: { width: "16px", height: "16px" } }), SP_JSX.jsx("span", { style: { fontSize: "12px", color: "#aaa" }, children: "正在读取状态…" })] }) })) : (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "EC 传感器驱动（oxpec）", description: oxpec.applied
                            ? `已加载（${oxpec.load_method === "modprobe" ? "内核模块" : "插件内置模块"}）${oxpec.hwmon_path ? ` · hwmon 已启用` : ""}`
                            : oxpec.error && oxpec.error !== "module not loaded"
                                ? `错误：${oxpec.error}`
                                : "启用 HHD 风扇曲线与 hwmon 传感器", checked: oxpec.applied, disabled: loading.active === "oxpec", onChange: handleOxpec }) }), SP_JSX.jsx(InlineStatus, { loading: loading, result: result, section: "oxpec" }), oxpec.kernel_compatible === false && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: {
                            backgroundColor: "#4a3000",
                            border: "1px solid #7a5000",
                            borderRadius: "4px",
                            padding: "8px 12px",
                            fontSize: "11px",
                            lineHeight: "1.4",
                            color: "#ffcc00",
                        }, children: ["当前内核没有可用模块：", SP_JSX.jsx("strong", { children: oxpec.running_kernel }), "。", oxpec.bundled_kernels && oxpec.bundled_kernels.length > 0
                                ? SP_JSX.jsxs(SP_JSX.Fragment, { children: [" 可用版本：", oxpec.bundled_kernels.join(", "), "。"] })
                                : SP_JSX.jsx(SP_JSX.Fragment, { children: " 插件未内置任何可用模块。" }), " 请更新插件以支持新内核。"] }) })), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "按键与 RGB 修复", description: buttonFix.applied
                            ? `已应用${buttonFix.home_monitor_running ? " · Home 键监控已运行" : ""}（关闭开关可撤销）`
                            : buttonFix.error
                                ? `错误：${buttonFix.error}`
                                : "修复按键、背键与 RGB 灯光", checked: buttonFix.applied, disabled: loading.active === "button", onChange: handleButtonFix }) }), SP_JSX.jsx(InlineStatus, { loading: loading, result: result, section: "button" }), buttonFix.applied && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: {
                            backgroundColor: "#1a2a3a",
                            border: "1px solid #2a4a6a",
                            borderRadius: "4px",
                            padding: "8px 12px",
                            fontSize: "11px",
                            lineHeight: "1.4",
                            color: "#88bbdd",
                        }, children: buttonFix.paddle_monitor_running
                            ? "背键（L4/R4）已通过固件映射启用，支持完整震动；可在 Steam 输入设置中按游戏或全局重新映射。"
                            : "背键监控正在启动…" }) })), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "唤醒后手柄恢复", description: resumeFix.applied
                            ? "已启用：休眠唤醒后自动恢复手柄"
                            : "修复休眠唤醒后手柄无法使用", checked: resumeFix.applied, disabled: loading.active === "resume", onChange: handleResumeFix }) }), SP_JSX.jsx(InlineStatus, { loading: loading, result: result, section: "resume" }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", description: "手柄消失时重新绑定 USB 控制器并重启 HHD", disabled: loading.active === "recoverGamepad", onClick: handleRecoverGamepad, children: loading.active === "recoverGamepad" ? "正在恢复…" : "恢复手柄" }) }), SP_JSX.jsx(InlineStatus, { loading: loading, result: result, section: "recoverGamepad" }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "休眠风扇修复", description: sleepEnable.applied
                            ? "已应用：休眠时风扇停止"
                            : "修复休眠时风扇持续运转", checked: sleepEnable.applied, disabled: loading.active === "sleepEnable", onChange: handleSleepEnable }) }), SP_JSX.jsx(InlineStatus, { loading: loading, result: result, section: "sleepEnable" }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ToggleField, { label: "轻度休眠", description: lightSleep.applied
                            ? "已应用：已设置 s2idle 内核参数"
                            : lightSleep.has_problematic_kargs
                                ? `发现可能有问题的内核参数：${lightSleep.problematic_kargs.join(", ")}`
                                : "应用 s2idle 休眠内核参数", checked: lightSleep.applied, disabled: loading.active === "lightSleep", onChange: handleLightSleep }) }), SP_JSX.jsx(InlineStatus, { loading: loading, result: result, section: "lightSleep" }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: {
                            backgroundColor: "#1a2a3a",
                            border: "1px solid #2a4a6a",
                            borderRadius: "4px",
                            padding: "8px 12px",
                            fontSize: "11px",
                            lineHeight: "1.4",
                            color: "#88bbdd",
                        }, children: [SP_JSX.jsx("strong", { children: "需要 BIOS 设置：" }), "请在 BIOS 中启用“ACPI Auto configuration”，休眠才能正常工作。", !lightSleep.applied && " 应用内核参数后需要重启，重启后必须重新应用按键修复。", lightSleep.has_problematic_kargs && " 开启后还会移除可能有问题的旧内核参数。"] }) })] })) }));
};

const LogsSection = ({ loading, setLoading, showResult, result }) => {
    const [showLogs, setShowLogs] = SP_REACT.useState(false);
    const [logLines, setLogLines] = SP_REACT.useState([]);
    const logEndRef = SP_REACT.useRef(null);
    // Poll logs when expanded
    SP_REACT.useEffect(() => {
        if (!showLogs)
            return;
        const fetchLogs = async () => {
            try {
                const res = await getLogs(30);
                setLogLines(res.lines);
            }
            catch (_) {
                // Log fetch failed — will retry on next interval
            }
        };
        fetchLogs();
        const interval = setInterval(fetchLogs, 2000);
        return () => clearInterval(interval);
    }, [showLogs]);
    // Auto-scroll logs to bottom
    SP_REACT.useEffect(() => {
        logEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }, [logLines]);
    return (SP_JSX.jsxs(DFL.PanelSection, { title: "日志", children: [SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: () => setShowLogs((prev) => !prev), children: showLogs ? "隐藏日志" : "显示日志" }) }), SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx(DFL.ButtonItem, { layout: "below", onClick: async () => {
                        setLoading({ active: "saveLogs", message: "正在保存日志…" });
                        try {
                            const res = await saveLogs();
                            if (res.success) {
                                showResult("saveLogs", `已保存到 ${res.path}`, "success");
                            }
                            else {
                                showResult("saveLogs", res.error || "保存失败", "error");
                            }
                        }
                        catch (e) {
                            showResult("saveLogs", `错误：${e}`, "error");
                        }
                        finally {
                            setLoading({ active: null, message: "" });
                        }
                    }, disabled: loading.active === "saveLogs", children: "将日志保存到下载目录" }) }), SP_JSX.jsx(InlineStatus, { loading: loading, result: result, section: "saveLogs" }), showLogs && (SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: {
                        backgroundColor: "#1a1a1a",
                        border: "1px solid #333",
                        borderRadius: "4px",
                        padding: "8px",
                        maxHeight: "200px",
                        overflowY: "auto",
                        fontFamily: "monospace",
                        fontSize: "10px",
                        lineHeight: "1.4",
                        color: "#ccc",
                        whiteSpace: "pre-wrap",
                        wordBreak: "break-all",
                    }, children: [logLines.length === 0 ? (SP_JSX.jsx("span", { style: { color: "#666" }, children: "暂无日志记录" })) : (logLines.map((line, i) => (SP_JSX.jsx("div", { children: line }, i)))), SP_JSX.jsx("div", { ref: logEndRef })] }) }))] }));
};

const Content = () => {
    const [buttonFix, setButtonFix] = SP_REACT.useState({
        applied: false,
    });
    const [lightSleep, setLightSleep] = SP_REACT.useState({
        applied: false,
        light_sleep_present: [],
        light_sleep_missing: [],
        problematic_kargs: [],
        has_problematic_kargs: false,
    });
    const [speakerDSP, setSpeakerDSP] = SP_REACT.useState({ enabled: false });
    const [oxpec, setOxpec] = SP_REACT.useState({ applied: false });
    const [resumeFix, setResumeFix] = SP_REACT.useState({ applied: false });
    const [sleepEnable, setSleepEnable] = SP_REACT.useState({ applied: false });
    const [statusLoaded, setStatusLoaded] = SP_REACT.useState(false);
    const [loading, setLoading] = SP_REACT.useState({ active: null, message: "" });
    const [result, setResult] = SP_REACT.useState(null);
    const showResult = SP_REACT.useCallback((key, text, type) => {
        setResult({ key, text, type });
        setTimeout(() => setResult((prev) => (prev?.key === key ? null : prev)), 4000);
    }, []);
    const refresh = SP_REACT.useCallback(async () => {
        try {
            const status = await getStatus();
            setButtonFix(status.button_fix);
            setLightSleep(status.light_sleep);
            setSpeakerDSP(status.speaker_dsp);
            setOxpec(status.oxpec);
            setResumeFix(status.resume_fix);
            setSleepEnable(status.sleep_enable);
        }
        catch (e) {
            console.error("Failed to get status:", e);
        }
        finally {
            setStatusLoaded(true);
        }
    }, []);
    // Initial load
    SP_REACT.useEffect(() => {
        refresh();
    }, [refresh]);
    return (SP_JSX.jsxs(SP_JSX.Fragment, { children: [SP_JSX.jsx(DFL.PanelSection, { children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsx("div", { style: { backgroundColor: "#4a3b00", border: "1px solid #d9a441", borderRadius: "4px", color: "#ffd54a", fontSize: "13px", fontWeight: "bold", padding: "10px 12px", width: "100%" }, children: "中文汉化：RenAmamiya" }) }) }), SP_JSX.jsx(DFL.PanelSection, { children: SP_JSX.jsx(DFL.PanelSectionRow, { children: SP_JSX.jsxs("div", { style: {
                            backgroundColor: "#4a3000",
                            border: "1px solid #7a5000",
                            borderRadius: "4px",
                            padding: "8px 12px",
                            fontSize: "12px",
                            lineHeight: "1.4",
                            color: "#ffcc00",
                        }, children: [SP_JSX.jsx("strong", { children: "请自行承担使用风险。" }), "此插件会修改系统文件和硬件设置；系统更新后修复可能失效，需要重新应用。"] }) }) }), SP_JSX.jsx(FixesSection, { buttonFix: buttonFix, setButtonFix: setButtonFix, lightSleep: lightSleep, setLightSleep: setLightSleep, oxpec: oxpec, setOxpec: setOxpec, resumeFix: resumeFix, setResumeFix: setResumeFix, sleepEnable: sleepEnable, setSleepEnable: setSleepEnable, loading: loading, setLoading: setLoading, showResult: showResult, result: result, statusLoaded: statusLoaded, refresh: refresh }), SP_JSX.jsx(SpeakerDSPSection, { dspStatus: speakerDSP, onStatusChange: setSpeakerDSP, loading: loading, setLoading: setLoading, showResult: showResult, result: result }), SP_JSX.jsx(LogsSection, { loading: loading, setLoading: setLoading, showResult: showResult, result: result }), SP_JSX.jsx("div", { style: { textAlign: "center", fontSize: "10px", opacity: 0.3, padding: "4px 0" }, children: BUILD_ID })] }));
};
var index = definePlugin(() => ({
    name: "OneXPlayer Apex Tools",
    titleView: SP_JSX.jsx("div", { className: DFL.staticClasses.Title, children: "OXP Apex 工具" }),
    content: SP_JSX.jsx(Content, {}),
    icon: (SP_JSX.jsx("svg", { viewBox: "0 0 24 24", fill: "currentColor", width: "20", height: "20", children: SP_JSX.jsx("path", { d: "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z" }) })),
}));

export { index as default };
//# sourceMappingURL=index.js.map
