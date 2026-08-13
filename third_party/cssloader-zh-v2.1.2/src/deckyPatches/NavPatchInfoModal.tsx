import { DialogButton, Focusable, ConfirmModal } from "decky-frontend-lib";
import { Theme } from "../ThemeTypes";
import { setNavPatch } from "./NavPatch";
export function NavPatchInfoModalRoot({
  themeData,
  closeModal,
}: {
  themeData: Theme;
  closeModal?: any;
}) {
  function onButtonClick() {
    setNavPatch(true, true);
    closeModal();
  }
  return (
    <ConfirmModal
      strTitle="启用导航修复？"
      onOK={onButtonClick}
      strCancelButtonText="不启用"
      strOKButtonText="启用（推荐）"
      onCancel={closeModal}
      onEscKeypress={closeModal}
    >
      <span style={{ marginBottom: "10px" }}>
        {themeData.name} 会隐藏部分仍可被手柄选中的元素。为保证导航正确，主题美化需要修复手柄导航；
        如果不启用，视觉上已隐藏的元素仍可能被手柄选中。
      </span>
    </ConfirmModal>
  );
}
