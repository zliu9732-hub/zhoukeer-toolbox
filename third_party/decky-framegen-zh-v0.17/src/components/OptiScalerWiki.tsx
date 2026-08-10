import { PanelSectionRow, ButtonItem } from "@decky/ui";
import { FaBook } from "react-icons/fa";

interface OptiScalerWikiProps {
  pathExists: boolean | null;
}

export function OptiScalerWiki({ pathExists }: OptiScalerWikiProps) {
  if (pathExists !== true) return null;

  const handleWikiClick = () => {
    window.open("https://github.com/optiscaler/OptiScaler/wiki", "_blank");
  };

  return (
    <PanelSectionRow>
      <ButtonItem
        layout="below"
        onClick={handleWikiClick}
      >
        <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
          <FaBook />
          <div>打开 OptiScaler 使用说明</div>
        </div>
      </ButtonItem>
    </PanelSectionRow>
  );
}
