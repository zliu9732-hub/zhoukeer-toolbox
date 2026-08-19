/**
 * Ally Center - Decky Loader Plugin for ROG Ally
 * Copyright (c) 2024 Keith Baker / Pixel Addict Games
 * Licensed under MIT
 */

import {
  definePlugin,
  PanelSection,
  PanelSectionRow,
  ButtonItem,
  SliderField,
  ToggleField,
  DropdownItem,
  staticClasses,
  Focusable,
  DialogButton,
  showModal,
  ModalRoot,
  ConfirmModal,
  Navigation,
} from "@decky/ui";
import { callable, toaster, routerHook } from "@decky/api";
const { useState, useEffect, useRef } = window.SP_REACT;
type VFC<P = {}> = (props: P) => JSX.Element | null;
type FC<P = {}> = (props: P) => JSX.Element | null;

// Simple event emitter for download mode state management
class DownloadModeState {
  private active: boolean = false;
  private callbacks: Set<(active: boolean) => void> = new Set();

  isActive(): boolean {
    return this.active;
  }

  setActive(value: boolean): void {
    this.active = value;
    this.callbacks.forEach((cb) => cb(value));
  }

  subscribe(callback: (active: boolean) => void): () => void {
    this.callbacks.add(callback);
    return () => this.callbacks.delete(callback);
  }
}

// Global state for download mode overlay
const downloadModeState = new DownloadModeState();

// Full-screen black overlay for download mode
// Uses high z-index and fixed positioning to cover the entire screen
const BlackScreenOverlay: FC<{ stateManager: DownloadModeState }> = ({
  stateManager,
}) => {
  const [isVisible, setIsVisible] = useState(stateManager.isActive());

  useEffect(() => {
    return stateManager.subscribe(setIsVisible);
  }, [stateManager]);

  if (!isVisible) {
    return null;
  }

  // Render a full-screen black div with maximum z-index to cover everything
  // On OLED screens, pure black (#000000) means pixels are completely off
  return (
    <div
      style={{
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
      }}
    />
  );
};

const getDeviceInfo = callable<[], DeviceInfo>("get_device_info");
const getBatteryInfo = callable<[], BatteryInfo>("get_battery_info");
const setChargeLimit = callable<[number], boolean>("set_charge_limit");
const getRgbState = callable<[], RgbState>("get_rgb_state");
const setRgbColor = callable<[string], boolean>("set_rgb_color");
const setRgbBrightness = callable<[number], boolean>("set_rgb_brightness");
const setRgbEffect = callable<[string], boolean>("set_rgb_effect");
const setRgbSpeed = callable<[number], boolean>("set_rgb_speed");
const setRgbEnabled = callable<[boolean], boolean>("set_rgb_enabled");
const getPerformanceProfiles = callable<[], ProfilesData>(
  "get_performance_profiles"
);
const setPerformanceProfile = callable<[string], boolean>(
  "set_performance_profile"
);
const getCurrentTdp = callable<[], TdpInfo>("get_current_tdp");
const getScreenState = callable<[], ScreenState>("get_screen_state");
const setScreenState = callable<[boolean], boolean>("set_screen_state");
const toggleScreen = callable<[], boolean>("toggle_screen");
const getFanInfo = callable<[], FanInfo>("get_fan_info");
const setFanMode = callable<[string], boolean>("set_fan_mode");
const getTdpSettings = callable<[], TdpSettings>("get_tdp_settings");
const setTdp = callable<[number], boolean>("set_tdp");
const getChargeLimit = callable<[], ChargeLimitInfo>("get_charge_limit");
const setTdpOverride = callable<[boolean], boolean>("set_tdp_override");
const getCpuSettings = callable<[], CpuSettings>("get_cpu_settings");
const setSmtEnabled = callable<[boolean], boolean>("set_smt_enabled");
const setCpuBoostEnabled = callable<[boolean], boolean>(
  "set_cpu_boost_enabled"
);
const getFanDiagnostics = callable<[], FanDiagnostics>("get_fan_diagnostics");
const setUseExternalTdp = callable<[boolean], boolean>("set_use_external_tdp");

interface DeviceInfo {
  model: string;
  bios_version: string;
  serial: string;
  cpu: string;
  gpu: string;
  kernel: string;
  memory_total: string;
}

interface BatteryInfo {
  present: boolean;
  status: string;
  capacity: number;
  health: number;
  cycle_count: number;
  voltage: number;
  current: number;
  temperature: number;
  design_capacity: number;
  full_capacity: number;
  charge_limit: number;
}

interface RgbState {
  enabled: boolean;
  color: string;
  brightness: number;
  effect: string;
  speed: number;
  available: boolean;
}

interface PerformanceProfile {
  name: string;
  tdp: number;
  gpu_clock: number;
  fan_curve: string;
  description: string;
}

interface ProfilesData {
  profiles: Record<string, PerformanceProfile>;
  current: string;
}

interface TdpInfo {
  tdp: number;
  gpu_clock: number;
  cpu_temp: number;
  gpu_temp: number;
}

interface ScreenState {
  screen_off: boolean;
  brightness: number;
}

interface FanInfo {
  mode: string;
  speed: number;
  available: boolean;
  policy_path?: string;
  current_policy?: number;
}

interface FanDiagnostics {
  asus_wmi_exists: boolean;
  throttle_policy_path: string;
  throttle_policy_value: number;
  fan_boost_mode_path: string;
  fan_boost_mode_value: number;
  fan_curve_enable_path: string;
  available_files: string[];
}

interface TdpSettings {
  tdp: number;
  min: number;
  max: number;
  tdp_override: boolean;
  use_external_tdp: boolean;
  available: boolean;
}

interface ChargeLimitInfo {
  limit: number;
  available: boolean;
}

interface CpuSettings {
  smt_enabled: boolean;
  smt_available: boolean;
  boost_enabled: boolean;
  boost_available: boolean;
}

const COLOR_PRESETS = [
  { name: "ROG 红", color: "#FF0000" },
  { name: "青色", color: "#00FFFF" },
  { name: "紫色", color: "#8B00FF" },
  { name: "绿色", color: "#00FF00" },
  { name: "橙色", color: "#FF8000" },
  { name: "粉色", color: "#FF00FF" },
  { name: "白色", color: "#FFFFFF" },
  { name: "蓝色", color: "#0000FF" },
];

const RGB_EFFECTS = [
  { data: "static", label: "常亮" },
  { data: "pulse", label: "呼吸" },
  { data: "spectrum", label: "光谱" },
  { data: "wave", label: "波浪" },
  { data: "flash", label: "闪烁" },
  { data: "battery", label: "电量指示" },
  { data: "off", label: "关闭" },
];

const translateBatteryStatus = (status: string): string => {
  const labels: Record<string, string> = {
    Charging: "充电中",
    Discharging: "放电中",
    Full: "已充满",
    "Not charging": "未充电",
    Unknown: "未知",
  };
  return labels[status] || status;
};

const translateProfileName = (name: string): string => {
  const labels: Record<string, string> = {
    Download: "下载",
    Silent: "静音",
    Performance: "性能",
    Turbo: "极速",
    Unknown: "未知",
  };
  return labels[name] || name;
};

const sectionStyle: React.CSSProperties = {
  marginBottom: "10px",
};

const infoRowStyle: React.CSSProperties = {
  display: "flex",
  justifyContent: "space-between",
  padding: "4px 0",
  fontSize: "12px",
};

const labelStyle: React.CSSProperties = {
  color: "#8b929a",
};

const valueStyle: React.CSSProperties = {
  color: "#ffffff",
  fontWeight: "bold",
};

const colorSwatchStyle = (
  color: string,
  selected: boolean
): React.CSSProperties => ({
  width: "28px",
  height: "28px",
  borderRadius: "4px",
  backgroundColor: color,
  border: selected ? "2px solid #1a9fff" : "2px solid transparent",
  cursor: "pointer",
  margin: "2px",
});

const colorGridStyle: React.CSSProperties = {
  display: "flex",
  flexWrap: "wrap",
  gap: "4px",
  padding: "8px 0",
};

const batteryBarStyle = (health: number): React.CSSProperties => ({
  width: "100%",
  height: "8px",
  backgroundColor: "#2a2a2a",
  borderRadius: "4px",
  overflow: "hidden",
  marginTop: "4px",
});

const batteryFillStyle = (
  value: number,
  color: string
): React.CSSProperties => ({
  width: `${value}%`,
  height: "100%",
  backgroundColor: color,
  borderRadius: "4px",
  transition: "width 0.3s ease",
});

const profileCardStyle = (selected: boolean): React.CSSProperties => ({
  padding: "12px",
  marginBottom: "8px",
  backgroundColor: selected ? "#1a3a5c" : "#1a1a1a",
  borderRadius: "8px",
  border: selected ? "1px solid #1a9fff" : "1px solid #333",
  cursor: "pointer",
});

const screenOffButtonStyle = (isOff: boolean): React.CSSProperties => ({
  backgroundColor: isOff ? "#ff4444" : "#1a9fff",
  padding: "16px",
  borderRadius: "8px",
  textAlign: "center",
  cursor: "pointer",
});

let cachedDeviceInfo: DeviceInfo | null = null;

const DeviceInfoModal: VFC<{
  closeModal: () => void;
  deviceInfo: DeviceInfo | null;
}> = ({ closeModal, deviceInfo }) => {
  return (
    <ConfirmModal
      onEscKeypress={closeModal}
      onOK={closeModal}
      strOKButtonText="关闭"
      bHideCloseIcon={true}
      bAlertDialog={true}
    >
      <div style={{ textAlign: "center", marginBottom: "12px" }}>
        <div style={{ fontSize: "18px", fontWeight: "bold", color: "#fff" }}>设备信息</div>
        <div style={{ fontSize: "12px", color: "#1a9fff" }}>{deviceInfo?.model || "ROG Ally"}</div>
      </div>
      <div>
        <div style={{ color: "#8b929a", fontSize: "11px", marginBottom: "4px" }}>硬件</div>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "2px" }}>
          <span style={{ color: "#8b929a", fontSize: "12px" }}>CPU</span>
          <span style={{ color: "#fff", fontSize: "11px" }}>{deviceInfo?.cpu || "未知"}</span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "2px" }}>
          <span style={{ color: "#8b929a", fontSize: "12px" }}>GPU</span>
          <span style={{ color: "#fff", fontSize: "12px" }}>{deviceInfo?.gpu || "未知"}</span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "12px" }}>
          <span style={{ color: "#8b929a", fontSize: "12px" }}>内存</span>
          <span style={{ color: "#fff", fontSize: "12px" }}>{deviceInfo?.memory_total || "未知"}</span>
        </div>
        <div style={{ color: "#8b929a", fontSize: "11px", marginBottom: "4px" }}>系统</div>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "2px" }}>
          <span style={{ color: "#8b929a", fontSize: "12px" }}>BIOS</span>
          <span style={{ color: "#fff", fontSize: "12px" }}>{deviceInfo?.bios_version || "未知"}</span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between" }}>
          <span style={{ color: "#8b929a", fontSize: "12px" }}>内核</span>
          <span style={{ color: "#fff", fontSize: "11px" }}>{deviceInfo?.kernel || "未知"}</span>
        </div>
      </div>
    </ConfirmModal>
  );
};

// ==================== Device Info Section ====================
const DeviceInfoSection: VFC = () => {
  const [deviceInfo, setDeviceInfo] = useState<DeviceInfo | null>(
    cachedDeviceInfo
  );
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
      } catch (e) {
        console.error("Failed to get device info:", e);
      }
      setLoading(false);
    };
    fetchInfo();
  }, []);

  const showDeviceInfoModal = () => {
    showModal(
      <DeviceInfoModal closeModal={() => {}} deviceInfo={deviceInfo} />
    );
  };

  return (
    <PanelSection title="设备信息">
      <PanelSectionRow>
        <ButtonItem
          layout="below"
          onClick={showDeviceInfoModal}
          disabled={loading}
        >
          {loading ? "正在加载…" : "查看设备信息"}
        </ButtonItem>
      </PanelSectionRow>
    </PanelSection>
  );
};

const BatteryHealthSection: VFC = () => {
  const [batteryInfo, setBatteryInfo] = useState<BatteryInfo | null>(null);
  const [chargeLimit, setChargeLimitValue] = useState(100);
  const [expanded, setExpanded] = useState(false);
  const [loading, setLoading] = useState(true);

  const fetchBattery = async () => {
    try {
      const info = await getBatteryInfo();
      setBatteryInfo(info);
      setChargeLimitValue(info.charge_limit);
    } catch (e) {
      console.error("Failed to get battery info:", e);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchBattery();
    const interval = setInterval(fetchBattery, 10000);
    return () => clearInterval(interval);
  }, []);

  const handleChargeLimitChange = async (value: number) => {
    setChargeLimitValue(value);
    const success = await setChargeLimit(value);
    if (success) {
      toaster.toast({
        title: "Ally Center",
        body: `充电上限已设置为 ${value}%`,
      });
    }
  };

  const getHealthColor = (health: number): string => {
    if (health >= 80) return "#4caf50";
    if (health >= 60) return "#ff9800";
    return "#f44336";
  };

  const getStatusColor = (status: string): string => {
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
    return (
      <PanelSection title="电池">
        <PanelSectionRow>
          <div style={{ color: "#8b929a" }}>
            {loading ? "正在加载…" : "未检测到电池"}
          </div>
        </PanelSectionRow>
      </PanelSection>
    );
  }

  return (
    <PanelSection title="电池">
      <div style={sectionStyle}>
        <div style={infoRowStyle}>
          <span style={labelStyle}>电量</span>
          <span
            style={{ ...valueStyle, color: getStatusColor(batteryInfo.status) }}
          >
            {batteryInfo.capacity}%（{translateBatteryStatus(batteryInfo.status)}）
          </span>
        </div>
        <div style={batteryBarStyle(batteryInfo.capacity)}>
          <div style={batteryFillStyle(batteryInfo.capacity, "#1a9fff")} />
        </div>
        <div style={{ ...infoRowStyle, marginTop: "8px" }}>
          <span style={labelStyle}>健康度</span>
          <span
            style={{ ...valueStyle, color: getHealthColor(batteryInfo.health) }}
          >
            {batteryInfo.health}%
          </span>
        </div>
      </div>

      <PanelSectionRow>
        <ButtonItem layout="below" onClick={() => setExpanded(!expanded)}>
          {expanded ? "隐藏详情 ▲" : "显示详情 ▼"}
        </ButtonItem>
      </PanelSectionRow>

      {expanded && (
        <div>
          <div style={sectionStyle}>
            <div style={infoRowStyle}>
              <span style={labelStyle}>循环次数</span>
              <span style={valueStyle}>{batteryInfo.cycle_count}</span>
            </div>
            <div style={infoRowStyle}>
              <span style={labelStyle}>电压</span>
              <span style={valueStyle}>{batteryInfo.voltage.toFixed(2)}V</span>
            </div>
            <div style={infoRowStyle}>
              <span style={labelStyle}>设计容量</span>
              <span style={valueStyle}>
                {batteryInfo.design_capacity.toFixed(1)} Wh
              </span>
            </div>
            <div style={infoRowStyle}>
              <span style={labelStyle}>当前容量</span>
              <span style={valueStyle}>
                {batteryInfo.full_capacity.toFixed(1)} Wh
              </span>
            </div>
            {batteryInfo.temperature > 0 && (
              <div style={infoRowStyle}>
                <span style={labelStyle}>温度</span>
                <span style={valueStyle}>{batteryInfo.temperature}°C</span>
              </div>
            )}
          </div>

          <PanelSectionRow>
            <SliderField
              label={`充电上限：${chargeLimit}%`}
              value={chargeLimit}
              min={60}
              max={100}
              step={5}
              showValue={false}
              onChange={handleChargeLimitChange}
            />
          </PanelSectionRow>
        </div>
      )}
    </PanelSection>
  );
};

const hslToHex = (h: number): string => {
  const s = 100;
  const l = 50;
  const a = (s * Math.min(l, 100 - l)) / 100;
  const f = (n: number) => {
    const k = (n + h / 30) % 12;
    const color = l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
    return Math.round((255 * color) / 100)
      .toString(16)
      .padStart(2, "0");
  };
  return `#${f(0)}${f(8)}${f(4)}`.toUpperCase();
};

const hexToHue = (hex: string): number => {
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

const RgbLightingSection: VFC = () => {
  const [rgbState, setRgbState] = useState<RgbState | null>(null);
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
      } else {
        setCurrentEffect("static");
        await setRgbEffect("static");
      }
    } catch (e) {
      console.error("Failed to get RGB state:", e);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchRgb();
  }, []);

  const handleToggle = async (enabled: boolean) => {
    const success = await setRgbEnabled(enabled);
    if (success) {
      setRgbState((prev: RgbState | null) =>
        prev ? { ...prev, enabled } : null
      );
    }
  };

  const handleHueChange = async (newHue: number) => {
    setHue(newHue);
    const color = hslToHex(newHue);
    const success = await setRgbColor(color);
    if (success) {
      setRgbState((prev: RgbState | null) =>
        prev ? { ...prev, color } : null
      );
    }
  };

  const handlePresetColor = async (color: string) => {
    const success = await setRgbColor(color);
    if (success) {
      setRgbState((prev: RgbState | null) =>
        prev ? { ...prev, color } : null
      );
      setHue(hexToHue(color));
    }
  };

  const handleBrightnessChange = async (brightness: number) => {
    const success = await setRgbBrightness(brightness);
    if (success) {
      setRgbState((prev: RgbState | null) =>
        prev ? { ...prev, brightness } : null
      );
    }
  };

  const handleEffectChange = async (effect: {
    data: string;
    label: string;
  }) => {
    setCurrentEffect(effect.data);
    const success = await setRgbEffect(effect.data);
    if (success) {
      setRgbState((prev: RgbState | null) =>
        prev
          ? { ...prev, effect: effect.data, enabled: effect.data !== "off" }
          : null
      );
    }
  };

  const handleSpeedChange = async (speed: number) => {
    const success = await setRgbSpeed(speed);
    if (success) {
      setRgbState((prev: RgbState | null) =>
        prev ? { ...prev, speed } : null
      );
    }
  };

  // Effects that support speed control
  const animatedEffects = ["pulse", "spectrum", "wave", "flash"];

  if (loading) {
    return (
      <PanelSection title="RGB 灯光">
        <PanelSectionRow>
          <div style={{ color: "#8b929a" }}>正在加载…</div>
        </PanelSectionRow>
      </PanelSection>
    );
  }

  const currentColor = rgbState?.color || "#FF0000";

  return (
    <PanelSection title="RGB 灯光">
      <PanelSectionRow>
        <ToggleField
          label="启用 RGB"
          checked={rgbState?.enabled ?? false}
          onChange={handleToggle}
        />
      </PanelSectionRow>

      {rgbState?.enabled && (
        <div>
          {/* Color Slider with hue gradient */}
          <PanelSectionRow>
            <SliderField
              label="颜色"
              value={hue}
              min={0}
              max={360}
              step={5}
              onChange={handleHueChange}
              showValue={false}
            />
          </PanelSectionRow>
          <PanelSectionRow>
            <div
              style={{
                width: "100%",
                height: "12px",
                borderRadius: "6px",
                background:
                  "linear-gradient(to right, #ff0000, #ffff00, #00ff00, #00ffff, #0000ff, #ff00ff, #ff0000)",
                marginTop: "-8px",
              }}
            />
          </PanelSectionRow>

          {/* Brightness */}
          <PanelSectionRow>
            <SliderField
              label="亮度"
              value={rgbState?.brightness ?? 100}
              min={0}
              max={100}
              step={10}
              onChange={handleBrightnessChange}
            />
          </PanelSectionRow>

          {/* Effect */}
          <PanelSectionRow>
            <DropdownItem
              label="灯效"
              strDefaultLabel={
                RGB_EFFECTS.find((e) => e.data === currentEffect)?.label ||
                "常亮"
              }
              menuLabel={
                RGB_EFFECTS.find((e) => e.data === currentEffect)?.label ||
                "常亮"
              }
              rgOptions={RGB_EFFECTS}
              selectedOption={
                RGB_EFFECTS.find((e) => e.data === currentEffect) ||
                RGB_EFFECTS[0]
              }
              onChange={handleEffectChange}
            />
          </PanelSectionRow>

          {/* Speed - only show for animated effects */}
          {animatedEffects.includes(currentEffect) && (
            <PanelSectionRow>
              <SliderField
                label="速度"
                value={rgbState?.speed ?? 50}
                min={10}
                max={100}
                step={10}
                onChange={handleSpeedChange}
              />
            </PanelSectionRow>
          )}
        </div>
      )}
    </PanelSection>
  );
};

const FAN_MODES = [
  { data: "auto", label: "自动" },
  { data: "quiet", label: "安静" },
  { data: "balanced", label: "均衡" },
  { data: "performance", label: "性能" },
];

const PerformanceSection: VFC = () => {
  const [profilesData, setProfilesData] = useState<ProfilesData | null>(null);
  const [tdpInfo, setTdpInfo] = useState<TdpInfo | null>(null);
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
      } catch (e) {
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
      } catch (e) {
        console.error("Failed to update performance data:", e);
      }
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  const handleProfileSelect = async (profileId: string) => {
    const success = await setPerformanceProfile(profileId);
    if (success) {
      setProfilesData((prev: ProfilesData | null) =>
        prev ? { ...prev, current: profileId } : null
      );
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

  const handleTdpChange = async (tdp: number) => {
    setCurrentTdp(tdp);
    await setTdp(tdp);
  };

  const handleFanModeChange = async (mode: { data: string; label: string }) => {
    setCurrentFanMode(mode.data);
    await setFanMode(mode.data);
    toaster.toast({ title: "Ally Center", body: `风扇：${mode.label}` });
  };

  const handleTdpOverrideToggle = async (enabled: boolean) => {
    setTdpOverrideState(enabled);
    await setTdpOverride(enabled);
    if (enabled) {
      toaster.toast({
        title: "Ally Center",
        body: "已启用 TDP 覆盖：手动模式",
      });
    } else {
      if (profilesData?.current) {
        await setPerformanceProfile(profilesData.current);
        const profileName =
          profilesData.profiles[profilesData.current]?.name || "Unknown";
        toaster.toast({
          title: "Ally Center",
          body: `已恢复预设：${translateProfileName(profileName)}`,
        });
      }
    }
  };

  const handleExternalTdpToggle = async (enabled: boolean) => {
    setUseExternalTdpState(enabled);
    await setUseExternalTdp(enabled);
    if (enabled) {
      toaster.toast({
        title: "Ally Center",
        body: "TDP 已交由外部插件管理",
      });
    } else {
      toaster.toast({
        title: "Ally Center",
        body: "TDP 已交由 Ally Center 管理",
      });
    }
  };

  if (loading) {
    return (
      <PanelSection title="性能">
        <PanelSectionRow>
          <div style={{ color: "#8b929a" }}>正在加载…</div>
        </PanelSectionRow>
      </PanelSection>
    );
  }

  return (
    <PanelSection title="性能">
      {tdpInfo && (
        <div style={sectionStyle}>
          <div style={infoRowStyle}>
            <span style={labelStyle}>模式</span>
            <span
              style={{ ...valueStyle, color: useExternalTdp ? "#8b929a" : (tdpOverride ? "#ff9800" : "#fff") }}
            >
              {useExternalTdp
                ? "外部插件"
                : tdpOverride
                ? "手动"
                : translateProfileName(
                    profilesData?.profiles[profilesData.current]?.name ||
                      "Unknown"
                  )}
            </span>
          </div>
          <div style={infoRowStyle}>
            <span style={labelStyle}>温度</span>
            <span style={valueStyle}>
              {tdpInfo.cpu_temp.toFixed(0)}°C / {tdpInfo.gpu_temp.toFixed(0)}°C
            </span>
          </div>
        </div>
      )}

      <PanelSectionRow>
        <ToggleField
          label="使用外部 TDP 控制"
          description="由 SimpleDeckyTDP 或其他插件管理 TDP"
          checked={useExternalTdp}
          onChange={handleExternalTdpToggle}
        />
      </PanelSectionRow>

      {!useExternalTdp && (
        <div>
          <PanelSectionRow>
            <ToggleField
              label="TDP 手动覆盖"
              checked={tdpOverride}
              onChange={handleTdpOverrideToggle}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <SliderField
              label={`TDP: ${currentTdp}W`}
              value={currentTdp}
              min={5}
              max={30}
              step={1}
              disabled={!tdpOverride}
              showValue={false}
              onChange={handleTdpChange}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ButtonItem layout="below" onClick={() => setExpanded(!expanded)}>
              {expanded ? "收起性能预设 ▲" : "展开性能预设 ▼"}
            </ButtonItem>
          </PanelSectionRow>

          {expanded && profilesData && (
            <div>
              {Object.entries(profilesData.profiles).map(([id, profile]) => (
                <PanelSectionRow key={id}>
                  <ButtonItem
                    layout="below"
                    onClick={() => handleProfileSelect(id)}
                  >
                    <div
                      style={{
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                        width: "100%",
                      }}
                    >
                      <div>
                        <span
                          style={{
                            fontWeight:
                              profilesData.current === id ? "bold" : "normal",
                            color: profilesData.current === id ? "#1a9fff" : "#fff",
                          }}
                        >
                          {translateProfileName(profile.name)}
                        </span>
                        {profilesData.current === id && (
                          <span style={{ color: "#1a9fff", marginLeft: "8px" }}>
                            ✓
                          </span>
                        )}
                      </div>
                      <span style={{ color: "#8b929a" }}>{profile.tdp}W</span>
                    </div>
                  </ButtonItem>
                </PanelSectionRow>
              ))}
            </div>
          )}
        </div>
      )}

      <PanelSectionRow>
        <DropdownItem
          label="风扇模式"
          strDefaultLabel={
            FAN_MODES.find((m) => m.data === currentFanMode)?.label || "自动"
          }
          menuLabel={
            FAN_MODES.find((m) => m.data === currentFanMode)?.label || "自动"
          }
          rgOptions={FAN_MODES}
          selectedOption={
            FAN_MODES.find((m) => m.data === currentFanMode) || FAN_MODES[0]
          }
          onChange={handleFanModeChange}
        />
      </PanelSectionRow>
    </PanelSection>
  );
};

const CpuSettingsSection: VFC = () => {
  const [cpuSettings, setCpuSettings] = useState<CpuSettings | null>(null);
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
      } catch (e) {
        console.error("Failed to get CPU settings:", e);
      }
      setLoading(false);
    };
    fetchData();
  }, []);

  const handleSmtToggle = async (enabled: boolean) => {
    setSmtState(enabled);
    const success = await setSmtEnabled(enabled);
    if (success) {
      toaster.toast({
        title: "Ally Center",
        body: `SMT 已${enabled ? "启用" : "关闭"}`,
      });
    } else {
      setSmtState(!enabled);
      toaster.toast({
        title: "Ally Center",
        body: "SMT 设置修改失败",
      });
    }
  };

  const handleBoostToggle = async (enabled: boolean) => {
    setBoostState(enabled);
    const success = await setCpuBoostEnabled(enabled);
    if (success) {
      toaster.toast({
        title: "Ally Center",
        body: `CPU 加速已${enabled ? "启用" : "关闭"}`,
      });
    } else {
      setBoostState(!enabled);
      toaster.toast({
        title: "Ally Center",
        body: "CPU 加速设置修改失败",
      });
    }
  };

  if (loading) {
    return (
      <PanelSection title="CPU 设置">
        <PanelSectionRow>
          <div style={{ color: "#8b929a" }}>正在加载…</div>
        </PanelSectionRow>
      </PanelSection>
    );
  }

  return (
    <PanelSection title="CPU 设置">
      {cpuSettings?.smt_available && (
        <PanelSectionRow>
          <ToggleField
            label="SMT（超线程）"
            description="关闭后可提升部分场景的单线程性能"
            checked={smtEnabled}
            onChange={handleSmtToggle}
          />
        </PanelSectionRow>
      )}

      {cpuSettings?.boost_available && (
        <PanelSectionRow>
          <ToggleField
            label="CPU 加速"
            description="关闭后可降低温度和功耗"
            checked={boostEnabled}
            onChange={handleBoostToggle}
          />
        </PanelSectionRow>
      )}

      {!cpuSettings?.smt_available && !cpuSettings?.boost_available && (
        <PanelSectionRow>
          <div style={{ color: "#8b929a" }}>当前设备不支持 CPU 控制</div>
        </PanelSectionRow>
      )}
    </PanelSection>
  );
};

let rgbWasEnabled = false;

const DownloadModeSection: VFC = () => {
  const [downloadMode, setDownloadMode] = useState(
    downloadModeState.isActive()
  );

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

  const handleToggle = async (enabled: boolean) => {
    if (enabled) {
      try {
        const rgbState = await getRgbState();
        rgbWasEnabled = rgbState.enabled;
      } catch (e) {
        rgbWasEnabled = false;
      }

      const success = await setScreenState(false);
      if (success) {
        await setRgbEnabled(false);
        downloadModeState.setActive(true);
        Navigation.CloseSideMenus();
        toaster.toast({
          title: "Ally Center",
          body: "下载模式已启用，打开快捷访问菜单即可退出",
        });
      }
    } else {
      await exitDownloadMode();
    }
  };

  return (
    <PanelSection title="下载模式">
      <PanelSectionRow>
        <ToggleField
          label="启用"
          description="黑屏 + 5W 功耗 + 关闭 RGB"
          checked={downloadMode}
          onChange={handleToggle}
        />
      </PanelSectionRow>
    </PanelSection>
  );
};

const AboutModal: VFC<{ closeModal: () => void }> = ({ closeModal }) => {
  return (
    <ConfirmModal
      onEscKeypress={closeModal}
      onOK={closeModal}
      strOKButtonText="关闭"
      bHideCloseIcon={true}
      bAlertDialog={true}
    >
      <div style={{ textAlign: "center", marginBottom: "12px" }}>
        <div style={{ fontSize: "18px", fontWeight: "bold", color: "#fff" }}>Ally 控制中心</div>
        <div style={{ fontSize: "12px", color: "#8b929a" }}>版本 1.2.0</div>
      </div>
      <div style={{ textAlign: "center" }}>
        <div style={{ color: "#8b929a", fontSize: "11px" }}>原作者</div>
        <div style={{ color: "#1a9fff", fontSize: "14px", fontWeight: "bold" }}>Keith Baker</div>
        <div style={{ color: "#8b929a", fontSize: "11px", marginBottom: "12px" }}>Pixel Addict Games</div>

        <div style={{ color: "#ffcc66", fontSize: "12px", marginBottom: "12px" }}>
          中文汉化：RenAmamiya
        </div>

        <div style={{ color: "#8b929a", fontSize: "11px", marginBottom: "4px", textAlign: "left" }}>特别感谢</div>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "2px" }}>
          <span style={{ color: "#fff", fontSize: "12px" }}>HueSync</span>
          <span style={{ color: "#8b929a", fontSize: "11px" }}>honjow</span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "2px" }}>
          <span style={{ color: "#fff", fontSize: "12px" }}>Decky Loader</span>
          <span style={{ color: "#8b929a", fontSize: "11px" }}>decky.xyz</span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "2px" }}>
          <span style={{ color: "#fff", fontSize: "12px" }}>ASUS Linux</span>
          <span style={{ color: "#8b929a", fontSize: "11px" }}>asus-linux.org</span>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between" }}>
          <span style={{ color: "#fff", fontSize: "12px" }}>Valve</span>
          <span style={{ color: "#8b929a", fontSize: "11px" }}>SteamOS</span>
        </div>
      </div>
    </ConfirmModal>
  );
};

const AboutSection: VFC = () => {
  const showAboutModal = () => {
    showModal(<AboutModal closeModal={() => {}} />);
  };

  return (
    <PanelSection title="关于">
      <PanelSectionRow>
        <ButtonItem layout="below" onClick={showAboutModal}>
          关于 Ally 控制中心
        </ButtonItem>
      </PanelSectionRow>
    </PanelSection>
  );
};

const AllyCenterContent: VFC = () => {
  return (
    <div>
      <div style={{ color: "#ffcc66", fontSize: "12px", textAlign: "center", padding: "6px 8px" }}>
        中文汉化：RenAmamiya
      </div>
      <DownloadModeSection />
      <PerformanceSection />
      <CpuSettingsSection />
      <BatteryHealthSection />
      <RgbLightingSection />
      <DeviceInfoSection />
      <AboutSection />
    </div>
  );
};

const AllyCenterIcon: VFC = () => (
  <svg viewBox="0 0 24 24" fill="currentColor" width="1em" height="1em">
    <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
  </svg>
);

export default definePlugin(() => {
  console.log("Ally Center plugin loaded!");

  // Register the global black overlay component for download mode
  routerHook.addGlobalComponent("AllyCenterBlackOverlay", () => (
    <BlackScreenOverlay stateManager={downloadModeState} />
  ));

  return {
    name: "Ally 控制中心",
    title: <div className={staticClasses.Title}>Ally 控制中心</div>,
    content: <AllyCenterContent />,
    icon: <AllyCenterIcon />,
    onDismount() {
      console.log("Ally Center plugin unloaded!");
      // Remove the global overlay component when plugin is unloaded
      routerHook.removeGlobalComponent("AllyCenterBlackOverlay");
      // Ensure download mode is disabled when plugin unloads
      downloadModeState.setActive(false);
    },
  };
});
