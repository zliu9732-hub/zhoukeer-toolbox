import { DropdownItem, Focusable, ToggleField } from "decky-frontend-lib";
import { useMemo, useState, useEffect } from "react";
import { useCssLoaderState } from "../../state";
import { toast } from "../../python";
import { setNavPatch } from "../../deckyPatches/NavPatch";
import {
  getWatchState,
  getServerState,
  enableServer,
  toggleWatchState,
  getBetaTranslationsState,
  fetchClassMappings,
} from "../../backend/pythonMethods/pluginSettingsMethods";
import { booleanStoreWrite, stringStoreWrite } from "../../backend/pythonMethods/storeUtils";
import { disableUnminifyMode, enableUnminifyMode } from "../../deckyPatches/UnminifyMode";

export function PluginSettings() {
  const { navPatchInstance, unminifyModeOn, setGlobalState } = useCssLoaderState();
  const [serverOn, setServerOn] = useState<boolean>(false);
  const [watchOn, setWatchOn] = useState<boolean>(false);
  const [betaTranslationsOn, setBetaTranslationsOn] = useState<string>("-1");

  const navPatchEnabled = useMemo(() => !!navPatchInstance, [navPatchInstance]);

  async function fetchServerState() {
    const value = await getServerState();
    setServerOn(value);
  }
  async function fetchWatchState() {
    const value = await getWatchState();
    setWatchOn(value);
  }
  async function fetchBetaTranslationsState() {
    const value = await getBetaTranslationsState();
    if (!["0", "1", "-1"].includes(value)) {
      setBetaTranslationsOn("-1");
      return;
    }
    setBetaTranslationsOn(value);
  }

  useEffect(() => {
    void fetchServerState();
    void fetchWatchState();
    void fetchBetaTranslationsState();
  }, []);

  function setUnminify(enabled: boolean) {
    setGlobalState("unminifyModeOn", enabled);
    if (enabled) {
      enableUnminifyMode();
      return;
    }
    disableUnminifyMode();
  }

  async function setWatch(enabled: boolean) {
    await toggleWatchState(enabled, false);
    await fetchWatchState();
  }

  async function setServer(enabled: boolean) {
    if (enabled) await enableServer();
    await booleanStoreWrite("server", enabled);
    await fetchServerState();
  }

  async function setBetaTranslations(value: string) {
    await stringStoreWrite("beta_translations", value);
    await fetchClassMappings();
    await fetchBetaTranslationsState();
  }

  return (
    <div>
      <Focusable>
        <DropdownItem
          rgOptions={[
            { data: "-1", label: "自动检测" },
            { data: "0", label: "强制稳定版" },
            { data: "1", label: "强制测试版" },
          ]}
          selectedOption={betaTranslationsOn}
          label="SteamOS 分支"
          description="选择当前使用的 SteamOS 版本，以便为系统加载正确的界面适配。"
          onChange={(data) => setBetaTranslations(data.data)}
        />
      </Focusable>
      <Focusable>
        <ToggleField
          checked={serverOn}
          label="启用独立后端"
          description="启用 Linux 桌面版 CSS Loader 支持"
          onChange={(value) => {
            setServer(value);
          }}
        />
      </Focusable>
      <Focusable>
        <ToggleField
          checked={navPatchEnabled}
          label="启用导航修复"
          description="修复主题隐藏界面元素时可能出现的问题"
          onChange={(value) => setNavPatch(value, true)}
        />
      </Focusable>
      <Focusable>
        <ToggleField
          checked={watchOn}
          label="实时编辑 CSS"
          description="监视 ~/homebrew/themes 的更改并自动重新注入 CSS"
          onChange={setWatch}
        />
      </Focusable>
      <Focusable>
        <ToggleField
          checked={unminifyModeOn}
          label="类名还原模式"
          description="在开发者工具中显示未压缩的类名，Steam 客户端重启后重置"
          onChange={setUnminify}
        />
      </Focusable>
    </div>
  );
}
