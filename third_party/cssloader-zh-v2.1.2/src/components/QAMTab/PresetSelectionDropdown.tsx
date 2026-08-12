import { DropdownItem, PanelSectionRow, showModal } from "decky-frontend-lib";
import { useCssLoaderState } from "../../state";
import { Flags } from "../../ThemeTypes";
import { useMemo } from "react";
import { changePreset, getInstalledThemes } from "../../python";
import { CreatePresetModalRoot } from "../Modals/CreatePresetModal";
import { FiPlusCircle } from "react-icons/fi";
import { useRerender } from "../../hooks";

export function PresetSelectionDropdown() {
  const { localThemeList, selectedPreset } = useCssLoaderState();
  const presets = useMemo(
    () => localThemeList.filter((e) => e.flags.includes(Flags.isPreset)),
    [localThemeList]
  );
  const [render, rerender] = useRerender();
  return (
    <>
      {render && (
        <PanelSectionRow>
          <DropdownItem
            label="当前配置方案"
            selectedOption={
              localThemeList.filter((e) => e.enabled && e.flags.includes(Flags.isPreset)).length > 1
                ? "状态无效"
                : selectedPreset?.name || "无"
            }
            rgOptions={[
              ...(localThemeList.filter((e) => e.enabled && e.flags.includes(Flags.isPreset))
                .length > 1
                ? [{ data: "Invalid State", label: "状态无效" }]
                : []),
              { data: "None", label: "无" },
              ...presets.map((e) => ({ label: e.display_name, data: e.name })),
              // This is a jank way of only adding it if creatingNewProfile = false
              {
                data: "New Profile",
                label: (
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "start",
                      gap: "1em",
                    }}
                  >
                    <FiPlusCircle />
                    <span>新建配置方案</span>
                  </div>
                ),
              },
            ]}
            onChange={async ({ data }) => {
              if (data === "New Profile") {
                showModal(
                  // @ts-ignore
                  <CreatePresetModalRoot />
                );
                rerender();
                return;
              }
              await changePreset(data, localThemeList);
              getInstalledThemes();
            }}
          />
        </PanelSectionRow>
      )}
    </>
  );
}
