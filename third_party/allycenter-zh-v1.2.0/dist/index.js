const manifest = {"name":"Ally Center"};
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
const routerHook = api.routerHook;
const toaster = api.toaster;

/**
 * Ally Center - Decky Loader Plugin for ROG Ally
 * Copyright (c) 2024 Keith Baker / Pixel Addict Games
 * Licensed under MIT
 */

const { useState, useEffect} = window.SP_REACT;
// Simple event emitter for download mode state management
class DownloadModeState {
    active = false;
    callbacks = new Set();
    isActive() {
        return this.active;
    }
    setActive(value) {
        this.active = value;
        this.callbacks.forEach((cb) => cb(value));
    }
    subscribe(callback) {
        this.callbacks.add(callback);
        return () => this.callbacks.delete(callback);
    }
}
// Global state for download mode overlay
const downloadModeState = new DownloadModeState();
// Full-screen black overlay for download mode
// Uses high z-index and fixed positioning to cover the entire screen
const BlackScreenOverlay = ({ stateManager, }) => {
    const [isVisible, setIsVisible] = useState(stateManager.isActive());
    useEffect(() => {
        return stateManager.subscribe(setIsVisible);
    }, [stateManager]);
    if (!isVisible) {
        return null;
    }
    // Render a full-screen black div with maximum z-index to cover everything
    // On OLED screens, pure black (#000000) means pixels are completely off
    return (window.SP_REACT.createElement("div", { style: {
            position: "fixed",
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            width: "100vw",
            height: "100vh",
            backgroundColor: "#000000",
            zIndex: 99999,
            pointerEvents: "none",
        } }));
};
const getDeviceInfo = callable("get_device_info");
const getBatteryInfo = callable("get_battery_info");
const setChargeLimit = callable("set_charge_limit");
const getRgbState = callable("get_rgb_state");
const setRgbColor = callable("set_rgb_color");
const setRgbBrightness = callable("set_rgb_brightness");
const setRgbEffect = callable("set_rgb_effect");
const setRgbSpeed = callable("set_rgb_speed");
const setRgbEnabled = callable("set_rgb_enabled");
const getPerformanceProfiles = callable("get_performance_profiles");
const setPerformanceProfile = callable("set_performance_profile");
const getCurrentTdp = callable("get_current_tdp");
callable("get_screen_state");
const setScreenState = callable("set_screen_state");
callable("toggle_screen");
const getFanInfo = callable("get_fan_info");
const setFanMode = callable("set_fan_mode");
const getTdpSettings = callable("get_tdp_settings");
const setTdp = callable("set_tdp");
callable("get_charge_limit");
const setTdpOverride = callable("set_tdp_override");
const getCpuSettings = callable("get_cpu_settings");
const setSmtEnabled = callable("set_smt_enabled");
const setCpuBoostEnabled = callable("set_cpu_boost_enabled");
callable("get_fan_diagnostics");
const setUseExternalTdp = callable("set_use_external_tdp");
const RGB_EFFECTS = [
    { data: "static", label: "常亮" },
    { data: "pulse", label: "呼吸" },
    { data: "spectrum", label: "光谱" },
    { data: "wave", label: "波浪" },
    { data: "flash", label: "闪烁" },
    { data: "battery", label: "电量指示" },
    { data: "off", label: "关闭" },
];
const translateBatteryStatus = (status) => {
    const labels = {
        Charging: "充电中",
        Discharging: "放电中",
        Full: "已充满",
        "Not charging": "未充电",
        Unknown: "未知",
    };
    return labels[status] || status;
};
const translateProfileName = (name) => {
    const labels = {
        Download: "下载",
        Silent: "静音",
        Performance: "性能",
        Turbo: "极速",
        Unknown: "未知",
    };
    return labels[name] || name;
};
const sectionStyle = {
    marginBottom: "10px",
};
const infoRowStyle = {
    display: "flex",
    justifyContent: "space-between",
    padding: "4px 0",
    fontSize: "12px",
};
const labelStyle = {
    color: "#8b929a",
};
const valueStyle = {
    color: "#ffffff",
    fontWeight: "bold",
};
const batteryBarStyle = (health) => ({
    width: "100%",
    height: "8px",
    backgroundColor: "#2a2a2a",
    borderRadius: "4px",
    overflow: "hidden",
    marginTop: "4px",
});
const batteryFillStyle = (value, color) => ({
    width: `${value}%`,
    height: "100%",
    backgroundColor: color,
    borderRadius: "4px",
    transition: "width 0.3s ease",
});
let cachedDeviceInfo = null;
const DeviceInfoModal = ({ closeModal, deviceInfo }) => {
    return (window.SP_REACT.createElement(DFL.ConfirmModal, { onEscKeypress: closeModal, onOK: closeModal, strOKButtonText: "\u5173\u95ED", bHideCloseIcon: true, bAlertDialog: true },
        window.SP_REACT.createElement("div", { style: { textAlign: "center", marginBottom: "12px" } },
            window.SP_REACT.createElement("div", { style: { fontSize: "18px", fontWeight: "bold", color: "#fff" } }, "\u8BBE\u5907\u4FE1\u606F"),
            window.SP_REACT.createElement("div", { style: { fontSize: "12px", color: "#1a9fff" } }, deviceInfo?.model || "ROG Ally")),
        window.SP_REACT.createElement("div", null,
            window.SP_REACT.createElement("div", { style: { color: "#8b929a", fontSize: "11px", marginBottom: "4px" } }, "\u786C\u4EF6"),
            window.SP_REACT.createElement("div", { style: { display: "flex", justifyContent: "space-between", marginBottom: "2px" } },
                window.SP_REACT.createElement("span", { style: { color: "#8b929a", fontSize: "12px" } }, "CPU"),
                window.SP_REACT.createElement("span", { style: { color: "#fff", fontSize: "11px" } }, deviceInfo?.cpu || "未知")),
            window.SP_REACT.createElement("div", { style: { display: "flex", justifyContent: "space-between", marginBottom: "2px" } },
                window.SP_REACT.createElement("span", { style: { color: "#8b929a", fontSize: "12px" } }, "GPU"),
                window.SP_REACT.createElement("span", { style: { color: "#fff", fontSize: "12px" } }, deviceInfo?.gpu || "未知")),
            window.SP_REACT.createElement("div", { style: { display: "flex", justifyContent: "space-between", marginBottom: "12px" } },
                window.SP_REACT.createElement("span", { style: { color: "#8b929a", fontSize: "12px" } }, "\u5185\u5B58"),
                window.SP_REACT.createElement("span", { style: { color: "#fff", fontSize: "12px" } }, deviceInfo?.memory_total || "未知")),
            window.SP_REACT.createElement("div", { style: { color: "#8b929a", fontSize: "11px", marginBottom: "4px" } }, "\u7CFB\u7EDF"),
            window.SP_REACT.createElement("div", { style: { display: "flex", justifyContent: "space-between", marginBottom: "2px" } },
                window.SP_REACT.createElement("span", { style: { color: "#8b929a", fontSize: "12px" } }, "BIOS"),
                window.SP_REACT.createElement("span", { style: { color: "#fff", fontSize: "12px" } }, deviceInfo?.bios_version || "未知")),
            window.SP_REACT.createElement("div", { style: { display: "flex", justifyContent: "space-between" } },
                window.SP_REACT.createElement("span", { style: { color: "#8b929a", fontSize: "12px" } }, "\u5185\u6838"),
                window.SP_REACT.createElement("span", { style: { color: "#fff", fontSize: "11px" } }, deviceInfo?.kernel || "未知")))));
};
// ==================== Device Info Section ====================
const DeviceInfoSection = () => {
    const [deviceInfo, setDeviceInfo] = useState(cachedDeviceInfo);
    const [loading, setLoading] = useState(!cachedDeviceInfo);
    useEffect(() => {
        if (cachedDeviceInfo) {
            setDeviceInfo(cachedDeviceInfo);
            setLoading(false);
            return;
        }
        const fetchInfo = async () => {
            try {
                const info = await getDeviceInfo();
                cachedDeviceInfo = info;
                setDeviceInfo(info);
            }
            catch (e) {
                console.error("Failed to get device info:", e);
            }
            setLoading(false);
        };
        fetchInfo();
    }, []);
    const showDeviceInfoModal = () => {
        DFL.showModal(window.SP_REACT.createElement(DeviceInfoModal, { closeModal: () => { }, deviceInfo: deviceInfo }));
    };
    return (window.SP_REACT.createElement(DFL.PanelSection, { title: "\u8BBE\u5907\u4FE1\u606F" },
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: showDeviceInfoModal, disabled: loading }, loading ? "正在加载…" : "查看设备信息"))));
};
const BatteryHealthSection = () => {
    const [batteryInfo, setBatteryInfo] = useState(null);
    const [chargeLimit, setChargeLimitValue] = useState(100);
    const [expanded, setExpanded] = useState(false);
    const [loading, setLoading] = useState(true);
    const fetchBattery = async () => {
        try {
            const info = await getBatteryInfo();
            setBatteryInfo(info);
            setChargeLimitValue(info.charge_limit);
        }
        catch (e) {
            console.error("Failed to get battery info:", e);
        }
        setLoading(false);
    };
    useEffect(() => {
        fetchBattery();
        const interval = setInterval(fetchBattery, 10000);
        return () => clearInterval(interval);
    }, []);
    const handleChargeLimitChange = async (value) => {
        setChargeLimitValue(value);
        const success = await setChargeLimit(value);
        if (success) {
            toaster.toast({
                title: "Ally Center",
                body: `充电上限已设置为 ${value}%`,
            });
        }
    };
    const getHealthColor = (health) => {
        if (health >= 80)
            return "#4caf50";
        if (health >= 60)
            return "#ff9800";
        return "#f44336";
    };
    const getStatusColor = (status) => {
        switch (status) {
            case "Charging":
                return "#4caf50";
            case "Discharging":
                return "#ff9800";
            case "Full":
                return "#2196f3";
            default:
                return "#8b929a";
        }
    };
    if (loading || !batteryInfo?.present) {
        return (window.SP_REACT.createElement(DFL.PanelSection, { title: "\u7535\u6C60" },
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", { style: { color: "#8b929a" } }, loading ? "正在加载…" : "未检测到电池"))));
    }
    return (window.SP_REACT.createElement(DFL.PanelSection, { title: "\u7535\u6C60" },
        window.SP_REACT.createElement("div", { style: sectionStyle },
            window.SP_REACT.createElement("div", { style: infoRowStyle },
                window.SP_REACT.createElement("span", { style: labelStyle }, "\u7535\u91CF"),
                window.SP_REACT.createElement("span", { style: { ...valueStyle, color: getStatusColor(batteryInfo.status) } },
                    batteryInfo.capacity,
                    "%\uFF08",
                    translateBatteryStatus(batteryInfo.status),
                    "\uFF09")),
            window.SP_REACT.createElement("div", { style: batteryBarStyle() },
                window.SP_REACT.createElement("div", { style: batteryFillStyle(batteryInfo.capacity, "#1a9fff") })),
            window.SP_REACT.createElement("div", { style: { ...infoRowStyle, marginTop: "8px" } },
                window.SP_REACT.createElement("span", { style: labelStyle }, "\u5065\u5EB7\u5EA6"),
                window.SP_REACT.createElement("span", { style: { ...valueStyle, color: getHealthColor(batteryInfo.health) } },
                    batteryInfo.health,
                    "%"))),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: () => setExpanded(!expanded) }, expanded ? "隐藏详情 ▲" : "显示详情 ▼")),
        expanded && (window.SP_REACT.createElement("div", null,
            window.SP_REACT.createElement("div", { style: sectionStyle },
                window.SP_REACT.createElement("div", { style: infoRowStyle },
                    window.SP_REACT.createElement("span", { style: labelStyle }, "\u5FAA\u73AF\u6B21\u6570"),
                    window.SP_REACT.createElement("span", { style: valueStyle }, batteryInfo.cycle_count)),
                window.SP_REACT.createElement("div", { style: infoRowStyle },
                    window.SP_REACT.createElement("span", { style: labelStyle }, "\u7535\u538B"),
                    window.SP_REACT.createElement("span", { style: valueStyle },
                        batteryInfo.voltage.toFixed(2),
                        "V")),
                window.SP_REACT.createElement("div", { style: infoRowStyle },
                    window.SP_REACT.createElement("span", { style: labelStyle }, "\u8BBE\u8BA1\u5BB9\u91CF"),
                    window.SP_REACT.createElement("span", { style: valueStyle },
                        batteryInfo.design_capacity.toFixed(1),
                        " Wh")),
                window.SP_REACT.createElement("div", { style: infoRowStyle },
                    window.SP_REACT.createElement("span", { style: labelStyle }, "\u5F53\u524D\u5BB9\u91CF"),
                    window.SP_REACT.createElement("span", { style: valueStyle },
                        batteryInfo.full_capacity.toFixed(1),
                        " Wh")),
                batteryInfo.temperature > 0 && (window.SP_REACT.createElement("div", { style: infoRowStyle },
                    window.SP_REACT.createElement("span", { style: labelStyle }, "\u6E29\u5EA6"),
                    window.SP_REACT.createElement("span", { style: valueStyle },
                        batteryInfo.temperature,
                        "\u00B0C")))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { label: `充电上限：${chargeLimit}%`, value: chargeLimit, min: 60, max: 100, step: 5, showValue: false, onChange: handleChargeLimitChange }))))));
};
const hslToHex = (h) => {
    const s = 100;
    const l = 50;
    const a = (s * Math.min(l, 100 - l)) / 100;
    const f = (n) => {
        const k = (n + h / 30) % 12;
        const color = l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
        return Math.round((255 * color) / 100)
            .toString(16)
            .padStart(2, "0");
    };
    return `#${f(0)}${f(8)}${f(4)}`.toUpperCase();
};
const hexToHue = (hex) => {
    const rgb = hex.replace("#", "");
    const r = parseInt(rgb.substring(0, 2), 16) / 255;
    const g = parseInt(rgb.substring(2, 4), 16) / 255;
    const b = parseInt(rgb.substring(4, 6), 16) / 255;
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    let h = 0;
    if (max !== min) {
        const d = max - min;
        switch (max) {
            case r:
                h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
                break;
            case g:
                h = ((b - r) / d + 2) / 6;
                break;
            case b:
                h = ((r - g) / d + 4) / 6;
                break;
        }
    }
    return Math.round(h * 360);
};
const RgbLightingSection = () => {
    const [rgbState, setRgbState] = useState(null);
    const [hue, setHue] = useState(0);
    const [currentEffect, setCurrentEffect] = useState("static");
    const [loading, setLoading] = useState(true);
    const fetchRgb = async () => {
        try {
            const state = await getRgbState();
            setRgbState(state);
            // Convert saved color to hue for slider position
            if (state.color) {
                const savedHue = hexToHue(state.color);
                setHue(savedHue);
            }
            // Set effect state
            if (state.effect && state.effect !== "") {
                setCurrentEffect(state.effect);
            }
            else {
                setCurrentEffect("static");
                await setRgbEffect("static");
            }
        }
        catch (e) {
            console.error("Failed to get RGB state:", e);
        }
        setLoading(false);
    };
    useEffect(() => {
        fetchRgb();
    }, []);
    const handleToggle = async (enabled) => {
        const success = await setRgbEnabled(enabled);
        if (success) {
            setRgbState((prev) => prev ? { ...prev, enabled } : null);
        }
    };
    const handleHueChange = async (newHue) => {
        setHue(newHue);
        const color = hslToHex(newHue);
        const success = await setRgbColor(color);
        if (success) {
            setRgbState((prev) => prev ? { ...prev, color } : null);
        }
    };
    const handleBrightnessChange = async (brightness) => {
        const success = await setRgbBrightness(brightness);
        if (success) {
            setRgbState((prev) => prev ? { ...prev, brightness } : null);
        }
    };
    const handleEffectChange = async (effect) => {
        setCurrentEffect(effect.data);
        const success = await setRgbEffect(effect.data);
        if (success) {
            setRgbState((prev) => prev
                ? { ...prev, effect: effect.data, enabled: effect.data !== "off" }
                : null);
        }
    };
    const handleSpeedChange = async (speed) => {
        const success = await setRgbSpeed(speed);
        if (success) {
            setRgbState((prev) => prev ? { ...prev, speed } : null);
        }
    };
    // Effects that support speed control
    const animatedEffects = ["pulse", "spectrum", "wave", "flash"];
    if (loading) {
        return (window.SP_REACT.createElement(DFL.PanelSection, { title: "RGB \u706F\u5149" },
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", { style: { color: "#8b929a" } }, "\u6B63\u5728\u52A0\u8F7D\u2026"))));
    }
    return (window.SP_REACT.createElement(DFL.PanelSection, { title: "RGB \u706F\u5149" },
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ToggleField, { label: "\u542F\u7528 RGB", checked: rgbState?.enabled ?? false, onChange: handleToggle })),
        rgbState?.enabled && (window.SP_REACT.createElement("div", null,
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { label: "\u989C\u8272", value: hue, min: 0, max: 360, step: 5, onChange: handleHueChange, showValue: false })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", { style: {
                        width: "100%",
                        height: "12px",
                        borderRadius: "6px",
                        background: "linear-gradient(to right, #ff0000, #ffff00, #00ff00, #00ffff, #0000ff, #ff00ff, #ff0000)",
                        marginTop: "-8px",
                    } })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { label: "\u4EAE\u5EA6", value: rgbState?.brightness ?? 100, min: 0, max: 100, step: 10, onChange: handleBrightnessChange })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.DropdownItem, { label: "\u706F\u6548", strDefaultLabel: RGB_EFFECTS.find((e) => e.data === currentEffect)?.label ||
                        "常亮", menuLabel: RGB_EFFECTS.find((e) => e.data === currentEffect)?.label ||
                        "常亮", rgOptions: RGB_EFFECTS, selectedOption: RGB_EFFECTS.find((e) => e.data === currentEffect) ||
                        RGB_EFFECTS[0], onChange: handleEffectChange })),
            animatedEffects.includes(currentEffect) && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { label: "\u901F\u5EA6", value: rgbState?.speed ?? 50, min: 10, max: 100, step: 10, onChange: handleSpeedChange })))))));
};
const FAN_MODES = [
    { data: "auto", label: "自动" },
    { data: "quiet", label: "安静" },
    { data: "balanced", label: "均衡" },
    { data: "performance", label: "性能" },
];
const PerformanceSection = () => {
    const [profilesData, setProfilesData] = useState(null);
    const [tdpInfo, setTdpInfo] = useState(null);
    const [expanded, setExpanded] = useState(false);
    const [loading, setLoading] = useState(true);
    const [currentTdp, setCurrentTdp] = useState(15);
    const [currentFanMode, setCurrentFanMode] = useState("auto");
    const [tdpOverride, setTdpOverrideState] = useState(false);
    const [useExternalTdp, setUseExternalTdpState] = useState(false);
    useEffect(() => {
        const fetchData = async () => {
            try {
                const [profiles, tdp, fan, tdpSettings] = await Promise.all([
                    getPerformanceProfiles(),
                    getCurrentTdp(),
                    getFanInfo(),
                    getTdpSettings(),
                ]);
                setProfilesData(profiles);
                setTdpInfo(tdp);
                setCurrentFanMode(fan.mode);
                setCurrentTdp(tdpSettings.tdp);
                setTdpOverrideState(tdpSettings.tdp_override || false);
                setUseExternalTdpState(tdpSettings.use_external_tdp || false);
            }
            catch (e) {
                console.error("Failed to get performance data:", e);
            }
            setLoading(false);
        };
        fetchData();
        const interval = setInterval(async () => {
            try {
                const [profiles, tdp] = await Promise.all([
                    getPerformanceProfiles(),
                    getCurrentTdp(),
                ]);
                setProfilesData(profiles);
                setTdpInfo(tdp);
            }
            catch (e) {
                console.error("Failed to update performance data:", e);
            }
        }, 3000);
        return () => clearInterval(interval);
    }, []);
    const handleProfileSelect = async (profileId) => {
        const success = await setPerformanceProfile(profileId);
        if (success) {
            setProfilesData((prev) => prev ? { ...prev, current: profileId } : null);
            const profile = profilesData?.profiles[profileId];
            const profileName = profile?.name || profileId;
            // Update fan mode UI to match profile's fan_curve
            if (profile?.fan_curve) {
                setCurrentFanMode(profile.fan_curve);
            }
            toaster.toast({ title: "Ally Center", body: `预设：${translateProfileName(profileName)}` });
            // Disable TDP override when selecting a preset (backend already does this)
            setTdpOverrideState(false);
        }
    };
    const handleTdpChange = async (tdp) => {
        setCurrentTdp(tdp);
        await setTdp(tdp);
    };
    const handleFanModeChange = async (mode) => {
        setCurrentFanMode(mode.data);
        await setFanMode(mode.data);
        toaster.toast({ title: "Ally Center", body: `风扇：${mode.label}` });
    };
    const handleTdpOverrideToggle = async (enabled) => {
        setTdpOverrideState(enabled);
        await setTdpOverride(enabled);
        if (enabled) {
            toaster.toast({
                title: "Ally Center",
                body: "已启用 TDP 覆盖：手动模式",
            });
        }
        else {
            if (profilesData?.current) {
                await setPerformanceProfile(profilesData.current);
                const profileName = profilesData.profiles[profilesData.current]?.name || "Unknown";
                toaster.toast({
                    title: "Ally Center",
                    body: `已恢复预设：${translateProfileName(profileName)}`,
                });
            }
        }
    };
    const handleExternalTdpToggle = async (enabled) => {
        setUseExternalTdpState(enabled);
        await setUseExternalTdp(enabled);
        if (enabled) {
            toaster.toast({
                title: "Ally Center",
                body: "TDP 已交由外部插件管理",
            });
        }
        else {
            toaster.toast({
                title: "Ally Center",
                body: "TDP 已交由 Ally Center 管理",
            });
        }
    };
    if (loading) {
        return (window.SP_REACT.createElement(DFL.PanelSection, { title: "\u6027\u80FD" },
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", { style: { color: "#8b929a" } }, "\u6B63\u5728\u52A0\u8F7D\u2026"))));
    }
    return (window.SP_REACT.createElement(DFL.PanelSection, { title: "\u6027\u80FD" },
        tdpInfo && (window.SP_REACT.createElement("div", { style: sectionStyle },
            window.SP_REACT.createElement("div", { style: infoRowStyle },
                window.SP_REACT.createElement("span", { style: labelStyle }, "\u6A21\u5F0F"),
                window.SP_REACT.createElement("span", { style: { ...valueStyle, color: useExternalTdp ? "#8b929a" : (tdpOverride ? "#ff9800" : "#fff") } }, useExternalTdp
                    ? "外部插件"
                    : tdpOverride
                        ? "手动"
                        : translateProfileName(profilesData?.profiles[profilesData.current]?.name ||
                            "Unknown"))),
            window.SP_REACT.createElement("div", { style: infoRowStyle },
                window.SP_REACT.createElement("span", { style: labelStyle }, "\u6E29\u5EA6"),
                window.SP_REACT.createElement("span", { style: valueStyle },
                    tdpInfo.cpu_temp.toFixed(0),
                    "\u00B0C / ",
                    tdpInfo.gpu_temp.toFixed(0),
                    "\u00B0C")))),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ToggleField, { label: "\u4F7F\u7528\u5916\u90E8 TDP \u63A7\u5236", description: "\u7531 SimpleDeckyTDP \u6216\u5176\u4ED6\u63D2\u4EF6\u7BA1\u7406 TDP", checked: useExternalTdp, onChange: handleExternalTdpToggle })),
        !useExternalTdp && (window.SP_REACT.createElement("div", null,
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: "TDP \u624B\u52A8\u8986\u76D6", checked: tdpOverride, onChange: handleTdpOverrideToggle })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { label: `TDP: ${currentTdp}W`, value: currentTdp, min: 5, max: 30, step: 1, disabled: !tdpOverride, showValue: false, onChange: handleTdpChange })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: () => setExpanded(!expanded) }, expanded ? "收起性能预设 ▲" : "展开性能预设 ▼")),
            expanded && profilesData && (window.SP_REACT.createElement("div", null, Object.entries(profilesData.profiles).map(([id, profile]) => (window.SP_REACT.createElement(DFL.PanelSectionRow, { key: id },
                window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: () => handleProfileSelect(id) },
                    window.SP_REACT.createElement("div", { style: {
                            display: "flex",
                            justifyContent: "space-between",
                            alignItems: "center",
                            width: "100%",
                        } },
                        window.SP_REACT.createElement("div", null,
                            window.SP_REACT.createElement("span", { style: {
                                    fontWeight: profilesData.current === id ? "bold" : "normal",
                                    color: profilesData.current === id ? "#1a9fff" : "#fff",
                                } }, translateProfileName(profile.name)),
                            profilesData.current === id && (window.SP_REACT.createElement("span", { style: { color: "#1a9fff", marginLeft: "8px" } }, "\u2713"))),
                        window.SP_REACT.createElement("span", { style: { color: "#8b929a" } },
                            profile.tdp,
                            "W")))))))))),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.DropdownItem, { label: "\u98CE\u6247\u6A21\u5F0F", strDefaultLabel: FAN_MODES.find((m) => m.data === currentFanMode)?.label || "自动", menuLabel: FAN_MODES.find((m) => m.data === currentFanMode)?.label || "自动", rgOptions: FAN_MODES, selectedOption: FAN_MODES.find((m) => m.data === currentFanMode) || FAN_MODES[0], onChange: handleFanModeChange }))));
};
const CpuSettingsSection = () => {
    const [cpuSettings, setCpuSettings] = useState(null);
    const [smtEnabled, setSmtState] = useState(true);
    const [boostEnabled, setBoostState] = useState(true);
    const [loading, setLoading] = useState(true);
    useEffect(() => {
        const fetchData = async () => {
            try {
                const data = await getCpuSettings();
                setCpuSettings(data);
                setSmtState(data.smt_enabled);
                setBoostState(data.boost_enabled);
            }
            catch (e) {
                console.error("Failed to get CPU settings:", e);
            }
            setLoading(false);
        };
        fetchData();
    }, []);
    const handleSmtToggle = async (enabled) => {
        setSmtState(enabled);
        const success = await setSmtEnabled(enabled);
        if (success) {
            toaster.toast({
                title: "Ally Center",
                body: `SMT 已${enabled ? "启用" : "关闭"}`,
            });
        }
        else {
            setSmtState(!enabled);
            toaster.toast({
                title: "Ally Center",
                body: "SMT 设置修改失败",
            });
        }
    };
    const handleBoostToggle = async (enabled) => {
        setBoostState(enabled);
        const success = await setCpuBoostEnabled(enabled);
        if (success) {
            toaster.toast({
                title: "Ally Center",
                body: `CPU 加速已${enabled ? "启用" : "关闭"}`,
            });
        }
        else {
            setBoostState(!enabled);
            toaster.toast({
                title: "Ally Center",
                body: "CPU 加速设置修改失败",
            });
        }
    };
    if (loading) {
        return (window.SP_REACT.createElement(DFL.PanelSection, { title: "CPU \u8BBE\u7F6E" },
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", { style: { color: "#8b929a" } }, "\u6B63\u5728\u52A0\u8F7D\u2026"))));
    }
    return (window.SP_REACT.createElement(DFL.PanelSection, { title: "CPU \u8BBE\u7F6E" },
        cpuSettings?.smt_available && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ToggleField, { label: "SMT\uFF08\u8D85\u7EBF\u7A0B\uFF09", description: "\u5173\u95ED\u540E\u53EF\u63D0\u5347\u90E8\u5206\u573A\u666F\u7684\u5355\u7EBF\u7A0B\u6027\u80FD", checked: smtEnabled, onChange: handleSmtToggle }))),
        cpuSettings?.boost_available && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ToggleField, { label: "CPU \u52A0\u901F", description: "\u5173\u95ED\u540E\u53EF\u964D\u4F4E\u6E29\u5EA6\u548C\u529F\u8017", checked: boostEnabled, onChange: handleBoostToggle }))),
        !cpuSettings?.smt_available && !cpuSettings?.boost_available && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement("div", { style: { color: "#8b929a" } }, "\u5F53\u524D\u8BBE\u5907\u4E0D\u652F\u6301 CPU \u63A7\u5236")))));
};
let rgbWasEnabled = false;
const DownloadModeSection = () => {
    const [downloadMode, setDownloadMode] = useState(downloadModeState.isActive());
    useEffect(() => {
        return downloadModeState.subscribe(setDownloadMode);
    }, []);
    const exitDownloadMode = async () => {
        const success = await setScreenState(true);
        if (success) {
            if (rgbWasEnabled) {
                await setRgbEnabled(true);
            }
            downloadModeState.setActive(false);
            toaster.toast({ title: "Ally Center", body: "下载模式已关闭" });
        }
    };
    const handleToggle = async (enabled) => {
        if (enabled) {
            try {
                const rgbState = await getRgbState();
                rgbWasEnabled = rgbState.enabled;
            }
            catch (e) {
                rgbWasEnabled = false;
            }
            const success = await setScreenState(false);
            if (success) {
                await setRgbEnabled(false);
                downloadModeState.setActive(true);
                DFL.Navigation.CloseSideMenus();
                toaster.toast({
                    title: "Ally Center",
                    body: "下载模式已启用，打开快捷访问菜单即可退出",
                });
            }
        }
        else {
            await exitDownloadMode();
        }
    };
    return (window.SP_REACT.createElement(DFL.PanelSection, { title: "\u4E0B\u8F7D\u6A21\u5F0F" },
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ToggleField, { label: "\u542F\u7528", description: "\u9ED1\u5C4F + 5W \u529F\u8017 + \u5173\u95ED RGB", checked: downloadMode, onChange: handleToggle }))));
};
const AboutModal = ({ closeModal }) => {
    return (window.SP_REACT.createElement(DFL.ConfirmModal, { onEscKeypress: closeModal, onOK: closeModal, strOKButtonText: "\u5173\u95ED", bHideCloseIcon: true, bAlertDialog: true },
        window.SP_REACT.createElement("div", { style: { textAlign: "center", marginBottom: "12px" } },
            window.SP_REACT.createElement("div", { style: { fontSize: "18px", fontWeight: "bold", color: "#fff" } }, "Ally Center"),
            window.SP_REACT.createElement("div", { style: { fontSize: "12px", color: "#8b929a" } }, "\u7248\u672C 1.2.0")),
        window.SP_REACT.createElement("div", { style: { textAlign: "center" } },
            window.SP_REACT.createElement("div", { style: { color: "#8b929a", fontSize: "11px" } }, "\u539F\u4F5C\u8005"),
            window.SP_REACT.createElement("div", { style: { color: "#1a9fff", fontSize: "14px", fontWeight: "bold" } }, "Keith Baker"),
            window.SP_REACT.createElement("div", { style: { color: "#8b929a", fontSize: "11px", marginBottom: "12px" } }, "Pixel Addict Games"),
            window.SP_REACT.createElement("div", { style: { color: "#ffcc66", fontSize: "12px", marginBottom: "12px" } }, "\u4E2D\u6587\u6C49\u5316\uFF1ARen-Amamiya-pixie / zliu9732-hub\uFF08\u95F2\u9C7CRenAmamiya\uFF09"),
            window.SP_REACT.createElement("div", { style: { color: "#8b929a", fontSize: "11px", marginBottom: "4px", textAlign: "left" } }, "\u7279\u522B\u611F\u8C22"),
            window.SP_REACT.createElement("div", { style: { display: "flex", justifyContent: "space-between", marginBottom: "2px" } },
                window.SP_REACT.createElement("span", { style: { color: "#fff", fontSize: "12px" } }, "HueSync"),
                window.SP_REACT.createElement("span", { style: { color: "#8b929a", fontSize: "11px" } }, "honjow")),
            window.SP_REACT.createElement("div", { style: { display: "flex", justifyContent: "space-between", marginBottom: "2px" } },
                window.SP_REACT.createElement("span", { style: { color: "#fff", fontSize: "12px" } }, "Decky Loader"),
                window.SP_REACT.createElement("span", { style: { color: "#8b929a", fontSize: "11px" } }, "decky.xyz")),
            window.SP_REACT.createElement("div", { style: { display: "flex", justifyContent: "space-between", marginBottom: "2px" } },
                window.SP_REACT.createElement("span", { style: { color: "#fff", fontSize: "12px" } }, "ASUS Linux"),
                window.SP_REACT.createElement("span", { style: { color: "#8b929a", fontSize: "11px" } }, "asus-linux.org")),
            window.SP_REACT.createElement("div", { style: { display: "flex", justifyContent: "space-between" } },
                window.SP_REACT.createElement("span", { style: { color: "#fff", fontSize: "12px" } }, "Valve"),
                window.SP_REACT.createElement("span", { style: { color: "#8b929a", fontSize: "11px" } }, "SteamOS")))));
};
const AboutSection = () => {
    const showAboutModal = () => {
        DFL.showModal(window.SP_REACT.createElement(AboutModal, { closeModal: () => { } }));
    };
    return (window.SP_REACT.createElement(DFL.PanelSection, { title: "\u5173\u4E8E" },
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: showAboutModal }, "\u5173\u4E8E Ally Center"))));
};
const AllyCenterContent = () => {
    return (window.SP_REACT.createElement("div", null,
        window.SP_REACT.createElement("div", { style: { color: "#ffcc66", fontSize: "12px", textAlign: "center", padding: "6px 8px" } }, "\u4E2D\u6587\u6C49\u5316\uFF1ARen-Amamiya-pixie / zliu9732-hub\uFF08\u95F2\u9C7CRenAmamiya\uFF09"),
        window.SP_REACT.createElement(DownloadModeSection, null),
        window.SP_REACT.createElement(PerformanceSection, null),
        window.SP_REACT.createElement(CpuSettingsSection, null),
        window.SP_REACT.createElement(BatteryHealthSection, null),
        window.SP_REACT.createElement(RgbLightingSection, null),
        window.SP_REACT.createElement(DeviceInfoSection, null),
        window.SP_REACT.createElement(AboutSection, null)));
};
const AllyCenterIcon = () => (window.SP_REACT.createElement("svg", { viewBox: "0 0 24 24", fill: "currentColor", width: "1em", height: "1em" },
    window.SP_REACT.createElement("path", { d: "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" })));
var index = DFL.definePlugin(() => {
    console.log("Ally Center plugin loaded!");
    // Register the global black overlay component for download mode
    routerHook.addGlobalComponent("AllyCenterBlackOverlay", () => (window.SP_REACT.createElement(BlackScreenOverlay, { stateManager: downloadModeState })));
    return {
        name: "Ally Center",
        title: window.SP_REACT.createElement("div", { className: DFL.staticClasses.Title }, "Ally Center"),
        content: window.SP_REACT.createElement(AllyCenterContent, null),
        icon: window.SP_REACT.createElement(AllyCenterIcon, null),
        onDismount() {
            console.log("Ally Center plugin unloaded!");
            // Remove the global overlay component when plugin is unloaded
            routerHook.removeGlobalComponent("AllyCenterBlackOverlay");
            // Ensure download mode is disabled when plugin unloads
            downloadModeState.setActive(false);
        },
    };
});

export { index as default };
//# sourceMappingURL=index.js.map
