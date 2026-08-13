import { Focusable } from "decky-frontend-lib";
import { useCssLoaderState } from "../../state";
import { ThemeToggle } from "../ThemeToggle";
import { Flags } from "../../ThemeTypes";
import { ThemeErrorCard } from "../ThemeErrorCard";
import { BsArrowDown } from "react-icons/bs";
import { FaEyeSlash } from "react-icons/fa";

export function QAMThemeToggleList() {
  const { localThemeList, unpinnedThemes } = useCssLoaderState();

  if (localThemeList.length === 0) {
    return (
      <>
        <span>尚未安装主题。请选择上方下载图标开始安装！</span>
      </>
    );
  }

  return (
    <>
      {/* This styles the collapse buttons, putting it here just means it only needs to be rendered once instead of like 20 times */}
      <style>
        {`
        .CSSLoader_ThemeListContainer {
          display: flex;
          flex-direction: column;
          align-items: stretch;
          width: 100%;
        }
        /* PRE Aug 18th Beta */
        .CSSLoader_QAM_CollapseButton_Container > div > div > div > button {
          height: 10px !important;
        }
        /* POST Aug 18th Beta */
        .CSSLoader_QAM_CollapseButton_Container > div > div > div > div > button {
          height: 10px !important;
        }
        `}
      </style>
      <Focusable className="CSSLoader_ThemeListContainer">
        <>
          {localThemeList
            .filter((e) => !unpinnedThemes.includes(e.id) && !e.flags.includes(Flags.isPreset))
            .map((x) => (
              <ThemeToggle data={x} collapsible showModalButtonPrompt />
            ))}
        </>
      </Focusable>
      {unpinnedThemes.length > 0 && (
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: ".5em",
            fontSize: "0.8rem",
            padding: "8px 0",
          }}
        >
          <FaEyeSlash />
          <div>
            已隐藏 {unpinnedThemes.length} 个主题。
          </div>
        </div>
      )}
    </>
  );
}
