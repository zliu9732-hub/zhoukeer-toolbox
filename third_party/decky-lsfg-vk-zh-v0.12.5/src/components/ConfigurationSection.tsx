import { PanelSectionRow, ToggleField, SliderField, ButtonItem } from "@decky/ui";
import { useState, useEffect } from "react";
import { RiArrowDownSFill, RiArrowUpSFill } from "react-icons/ri";
import { ConfigurationData } from "../config/configSchema";
import {
  FLOW_SCALE, PERFORMANCE_MODE, HDR_MODE,
  EXPERIMENTAL_PRESENT_MODE, DXVK_FRAME_RATE, DISABLE_STEAMDECK_MODE,
  MANGOHUD_WORKAROUND, DISABLE_VKBASALT, FORCE_ENABLE_VKBASALT, ENABLE_WSI, ENABLE_ZINK
} from "../config/generatedConfigSchema";

interface ConfigurationSectionProps {
  config: ConfigurationData;
  onConfigChange: (fieldName: keyof ConfigurationData, value: boolean | number | string) => Promise<void>;
}

const WORKAROUNDS_COLLAPSED_KEY = "lsfg-workarounds-collapsed";
const CONFIG_COLLAPSED_KEY = "lsfg-config-collapsed";

export function ConfigurationSection({
  config,
  onConfigChange
}: ConfigurationSectionProps) {
  // Initialize with localStorage value, fallback to true if not found
  const [configCollapsed, setConfigCollapsed] = useState(() => {
    try {
      const saved = localStorage.getItem(CONFIG_COLLAPSED_KEY);
      return saved !== null ? JSON.parse(saved) : false;
    } catch {
      return false;
    }
  });

  const [workaroundsCollapsed, setWorkaroundsCollapsed] = useState(() => {
    try {
      const saved = localStorage.getItem(WORKAROUNDS_COLLAPSED_KEY);
      return saved !== null ? JSON.parse(saved) : true;
    } catch {
      return true;
    }
  });

  // Persist workarounds collapse state to localStorage
  useEffect(() => {
    try {
      localStorage.setItem(CONFIG_COLLAPSED_KEY, JSON.stringify(configCollapsed));
    } catch (error) {
      console.warn("Failed to save config collapse state:", error);
    }
  }, [configCollapsed]);

  useEffect(() => {
    try {
      localStorage.setItem(WORKAROUNDS_COLLAPSED_KEY, JSON.stringify(workaroundsCollapsed));
    } catch (error) {
      console.warn("Failed to save workarounds collapse state:", error);
    }
  }, [workaroundsCollapsed]);

  return (
    <>
      <style>
        {`
        .LSFG_ConfigCollapseButton_Container > div > div > div > button,
        .LSFG_ConfigCollapseButton_Container > div > div > div > div > button,
        .LSFG_WorkaroundsCollapseButton_Container > div > div > div > button {
          height: 10px !important;
        }
        .LSFG_WorkaroundsCollapseButton_Container > div > div > div > div > button {
          height: 10px !important;
        }
        `}
      </style>

      {/* Config Section */}
      <PanelSectionRow>
        <div
          style={{
            fontSize: "14px",
            fontWeight: "bold",
            marginTop: "8px",
            marginBottom: "6px",
            borderBottom: "1px solid rgba(255, 255, 255, 0.2)",
            paddingBottom: "3px",
            color: "white"
          }}
        >
          基础设置
        </div>
      </PanelSectionRow>

      <PanelSectionRow>
        <div
          className="LSFG_ConfigCollapseButton_Container"
          style={{ marginTop: "-2px", marginBottom: "4px" }}
        >
          <ButtonItem
            layout="below"
            bottomSeparator={configCollapsed ? "standard" : "none"}
            onClick={() => setConfigCollapsed(!configCollapsed)}
          >
            {configCollapsed ? (
              <RiArrowDownSFill
                style={{ transform: "translate(0, -13px)", fontSize: "1.5em" }}
              />
            ) : (
              <RiArrowUpSFill
                style={{ transform: "translate(0, -12px)", fontSize: "1.5em" }}
              />
            )}
          </ButtonItem>
        </div>
      </PanelSectionRow>

      {!configCollapsed && (
        <>
          <PanelSectionRow>
            <SliderField
              label={`运动估计精度 (${Math.round(config.flow_scale * 100)}%)`}
              description="降低内部运动估计分辨率，可略微提升性能"
              value={config.flow_scale}
              min={0.25}
              max={1.0}
              step={0.01}
              onChange={(value) => onConfigChange(FLOW_SCALE, value)}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <SliderField
              label={`基础帧率上限${config.dxvk_frame_rate > 0 ? `（${config.dxvk_frame_rate} FPS）` : "（关闭）"}`}
              description="DirectX 游戏在帧生成前的基础帧率上限；修改后需重启游戏"
              value={config.dxvk_frame_rate}
              min={0}
              max={60}
              step={1}
              onChange={(value) => onConfigChange(DXVK_FRAME_RATE, value)}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ToggleField
              label={`显示模式（${(config.experimental_present_mode || "fifo") === "fifo" ? "FIFO - 垂直同步" : "Mailbox"}）`}
              description="在 FIFO 垂直同步（默认）与 Mailbox 显示模式间切换，以改善性能或兼容性"
              checked={(config.experimental_present_mode || "fifo") === "fifo"}
              onChange={(value) => onConfigChange(EXPERIMENTAL_PRESENT_MODE, value ? "fifo" : "mailbox")}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ToggleField
              label="性能模式"
              description="帧生成使用更轻量的模型，推荐大多数游戏开启"
              checked={config.performance_mode}
              onChange={(value) => onConfigChange(PERFORMANCE_MODE, value)}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ToggleField
              label="HDR 模式"
              description="为支持 HDR 的游戏启用 HDR 模式"
              checked={config.hdr_mode}
              onChange={(value) => onConfigChange(HDR_MODE, value)}
            />
          </PanelSectionRow>
        </>
      )}

      {/* Workarounds Section */}
      <PanelSectionRow>
        <div
          style={{
            fontSize: "14px",
            fontWeight: "bold",
            marginTop: "8px",
            marginBottom: "6px",
            borderBottom: "1px solid rgba(255, 255, 255, 0.2)",
            paddingBottom: "3px",
            color: "white"
          }}
        >
          兼容性选项
        </div>
      </PanelSectionRow>

      <PanelSectionRow>
        <div
          className="LSFG_WorkaroundsCollapseButton_Container"
          style={{ marginTop: "-2px", marginBottom: "4px" }}
        >
          <ButtonItem
            layout="below"
            bottomSeparator={workaroundsCollapsed ? "standard" : "none"}
            onClick={() => setWorkaroundsCollapsed(!workaroundsCollapsed)}
          >
            {workaroundsCollapsed ? (
              <RiArrowDownSFill
                style={{ transform: "translate(0, -13px)", fontSize: "1.5em" }}
              />
            ) : (
              <RiArrowUpSFill
                style={{ transform: "translate(0, -12px)", fontSize: "1.5em" }}
              />
            )}
          </ButtonItem>
        </div>
      </PanelSectionRow>

      {!workaroundsCollapsed && (
        <>
        <PanelSectionRow>
            <ToggleField
              label="启用 WSI"
              description="重新启用 Gamescope WSI 层；修改后需重启游戏"
              checked={config.enable_wsi}
              onChange={(value) => onConfigChange(ENABLE_WSI, value)}
            />
          </PanelSectionRow>
          
          <PanelSectionRow>
            <ToggleField
              label="为 32 位游戏启用 WOW64"
              description="设置 PROTON_USE_WOW64=1；可配合 ProtonGE 处理部分崩溃"
              checked={config.enable_wow64}
              onChange={(value) => onConfigChange('enable_wow64', value)}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ToggleField
              label="关闭 Steam Deck 模式"
              description="关闭掌机模式，以显示部分游戏隐藏的设置"
              checked={config.disable_steamdeck_mode}
              onChange={(value) => onConfigChange(DISABLE_STEAMDECK_MODE, value)}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ToggleField
              label="MangoHud 兼容方案"
              description="启用透明 MangoHud 浮层，有时可修复游戏模式下 2 倍帧生成的问题"
              checked={config.mangohud_workaround}
              onChange={(value) => onConfigChange(MANGOHUD_WORKAROUND, value)}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ToggleField
              label="关闭 vkBasalt"
              description="关闭可能与 LSFG 冲突的 vkBasalt 层（Reshade 或部分 Decky 插件）"
              checked={config.disable_vkbasalt}
              disabled={config.force_enable_vkbasalt}
              onChange={(value) => {
                if (value && config.force_enable_vkbasalt) {
                  // Turn off force enable when enabling disable
                  onConfigChange(FORCE_ENABLE_VKBASALT, false);
                }
                onConfigChange(DISABLE_VKBASALT, value);
              }}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ToggleField
              label="强制启用 vkBasalt"
              description="强制启用 vkBasalt，以修复游戏模式下的帧时间问题"
              checked={config.force_enable_vkbasalt}
              disabled={config.disable_vkbasalt}
              onChange={(value) => {
                if (value && config.disable_vkbasalt) {
                  // Turn off disable when enabling force enable
                  onConfigChange(DISABLE_VKBASALT, false);
                }
                onConfigChange(FORCE_ENABLE_VKBASALT, value);
              }}
            />
          </PanelSectionRow>

          <PanelSectionRow>
            <ToggleField
              label="为 OpenGL 游戏启用 Zink"
              description="为 OpenGL 游戏使用基于 Vulkan 的实现；部分游戏可能崩溃或卡死"
              checked={config.enable_zink}
              onChange={(value) => onConfigChange(ENABLE_ZINK, value)}
            />
          </PanelSectionRow>
        </>
      )}
    </>
  );
}
