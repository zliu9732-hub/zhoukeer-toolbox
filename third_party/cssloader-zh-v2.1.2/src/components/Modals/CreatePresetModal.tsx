import { ConfirmModal, TextField } from "decky-frontend-lib";
import { useState } from "react";
import * as python from "../../python";
import { CssLoaderContextProvider, useCssLoaderState } from "../../state";

export function CreatePresetModalRoot({ closeModal }: { closeModal: any }) {
  return (
    <>
      {/* @ts-ignore */}
      <CssLoaderContextProvider cssLoaderStateClass={python.globalState}>
        <CreatePresetModal closeModal={closeModal} />
      </CssLoaderContextProvider>
    </>
  );
}

function CreatePresetModal({ closeModal }: { closeModal: () => void }) {
  const { localThemeList, selectedPreset } = useCssLoaderState();
  const [presetName, setPresetName] = useState<string>("");
  const enabledNumber = localThemeList.filter((e) => e.enabled).length;

  return (
    <ConfirmModal
      strTitle="新建配置方案"
      strDescription={`This profile will combine all ${enabledNumber} themes you currently have enabled. Enabling/disabling it will toggle them all at once.`}
      strOKButtonText="创建"
      onCancel={closeModal}
      onOK={async () => {
        if (presetName.length === 0) {
          python.toast("未填写名称！", "请为配置方案填写名称。");
          return;
        }
        // TODO: Potentially dont need 2 reloads here, not entirely sure
        await python.generatePreset(presetName);
        await python.reloadBackend();
        if (selectedPreset) {
          await python.setThemeState(selectedPreset?.name, false);
        }
        await python.setThemeState(presetName + ".profile", true);
        await python.getInstalledThemes();
        closeModal();
      }}
    >
      <div style={{ marginBottom: "20px" }} />
      <TextField
        label="配置方案名称"
        value={presetName}
        onChange={(e) => {
          setPresetName(e.target.value);
        }}
      />
    </ConfirmModal>
  );
}
