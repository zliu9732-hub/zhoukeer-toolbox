import { PanelSectionRow } from "@decky/ui";
import { ConfigurationData } from "../config/configSchema";

interface UsageInstructionsProps {
  config: ConfigurationData;
}

export function UsageInstructions({ config: _config }: UsageInstructionsProps) {
  return (
    <>
      <PanelSectionRow>
        <div
          style={{
            fontSize: "14px",
            fontWeight: "bold",
            marginTop: "16px",
            marginBottom: "8px",
            borderBottom: "1px solid rgba(255, 255, 255, 0.2)",
            paddingBottom: "4px",
            color: "white"
          }}
        >
          使用说明
        </div>
      </PanelSectionRow>

      <PanelSectionRow>
        <div
          style={{
            fontSize: "12px",
            lineHeight: "1.4",
            opacity: "0.8",
            whiteSpace: "pre-wrap"
          }}
        >
          点击“复制启动选项”，再将内容粘贴到 Steam 游戏的启动选项中，即可启用帧生成。
        </div>
      </PanelSectionRow>

      <PanelSectionRow>
        <div
          style={{
        fontSize: "12px",
        lineHeight: "1.4",
        opacity: "0.8",
        backgroundColor: "rgba(255, 255, 255, 0.1)",
        padding: "8px",
        borderRadius: "4px",
        fontFamily: "monospace",
        marginTop: "8px",
        marginBottom: "8px",
        textAlign: "center"
          }}
        >
          <strong>~/lsfg %command%</strong>
        </div>
      </PanelSectionRow>

      <PanelSectionRow>
        <div
          style={{
            fontSize: "11px",
            lineHeight: "1.3",
            opacity: "0.6",
            marginTop: "8px"
          }}
        >
配置保存在 ~/.config/lsfg-vk/conf.toml；游戏运行时修改会自动生效。
        </div>
      </PanelSectionRow>
    </>
  );
}
