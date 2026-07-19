import { useCallback, useEffect, useMemo, useState } from "react";
import { ButtonItem, Field, PanelSectionRow, ToggleField } from "@decky/ui";
import { FileSelectionType, openFilePicker } from "@decky/api";
import { getPathDefaults, runManualPatch, runManualUnpatch } from "../api";
import type { ApiResponse } from "../types/index";
import { SmartClipboardButton } from "./SmartClipboardButton";

interface PathDefaults {
  home: string;
  steamCommon: string;
}

const DEFAULT_HOME = "/home";
const DEFAULT_STEAM_COMMON = "/home/deck/.local/share/Steam/steamapps/common";

const INITIAL_DEFAULTS: PathDefaults = {
  home: DEFAULT_HOME,
  steamCommon: DEFAULT_STEAM_COMMON,
};

const normalizePath = (value: string) => value.replace(/\\/g, "/");

const stripTrailingSlash = (value: string) =>
  value.length > 1 && value.endsWith("/") ? value.slice(0, -1) : value;

const ensureDirectory = (value: string) => {
  const normalized = normalizePath(value);
  const lastSegment = normalized.substring(normalized.lastIndexOf("/") + 1);
  if (!lastSegment || !lastSegment.includes(".")) {
    return stripTrailingSlash(normalized);
  }
  const parent = normalized.slice(0, normalized.lastIndexOf("/"));
  return parent || "/";
};

interface ManualPatchControlsProps {
  isAvailable: boolean;
  onManualModeChange?: (enabled: boolean) => void;
  dllName: string;
  fsr4Variant: string;
}

interface PickerState {
  selectedPath: string | null;
  lastError: string | null;
}

const INITIAL_PICKER_STATE: PickerState = {
  selectedPath: null,
  lastError: null,
};

const formatResultMessage = (result: ApiResponse | null) => {
  if (!result) return null;
  if (result.status === "success") {
    return result.message || result.output || "Operation completed successfully.";
  }
  return result.message || result.output || "Operation failed.";
};

export const ManualPatchControls = ({ isAvailable, onManualModeChange, dllName, fsr4Variant }: ManualPatchControlsProps) => {
  const [isEnabled, setEnabled] = useState(false);
  const [defaults, setDefaults] = useState<PathDefaults>(INITIAL_DEFAULTS);
  const [pickerState, setPickerState] = useState<PickerState>(INITIAL_PICKER_STATE);
  const [isPatching, setIsPatching] = useState(false);
  const [isUnpatching, setIsUnpatching] = useState(false);
  const [operationResult, setOperationResult] = useState<ApiResponse | null>(null);
  const [lastOperation, setLastOperation] = useState<"patch" | "unpatch" | null>(null);

  useEffect(() => {
    let cancelled = false;

    (async () => {
      try {
        const response = await getPathDefaults();
        if (!response || cancelled) return;

        const home = response.home ? normalizePath(response.home) : DEFAULT_HOME;
        const steamCommon = response.steam_common
          ? normalizePath(response.steam_common)
          : normalizePath(`${stripTrailingSlash(home)}/.local/share/Steam/steamapps/common`);

        setDefaults({
          home,
          steamCommon: steamCommon || DEFAULT_STEAM_COMMON,
        });
      } catch (err) {
        console.error("ManualPatchControls -> getPathDefaults", err);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!isAvailable) {
      setEnabled(false);
      setPickerState(INITIAL_PICKER_STATE);
      setOperationResult(null);
      setLastOperation(null);
      onManualModeChange?.(false);
    }
  }, [isAvailable, onManualModeChange]);

  const canInteract = isAvailable && isEnabled;
  const selectedPath = pickerState.selectedPath;
  const statusMessage = useMemo(() => formatResultMessage(operationResult), [operationResult]);
  const wasSuccessful = operationResult?.status === "success";
  const statusLabel = useMemo(() => {
    if (!operationResult || !lastOperation) return null;
    if (operationResult.status === "success") {
      return lastOperation === "patch" ? "游戏已修补" : "游戏已撤销修补";
    }
    return lastOperation === "patch" ? "修补失败" : "撤销修补失败";
  }, [lastOperation, operationResult]);

  const openDirectoryPicker = useCallback(async () => {
    const candidates = [
      selectedPath,
      defaults.steamCommon,
      defaults.home,
    ];

    let lastError: string | null = null;

    for (const candidate of candidates) {
      if (!candidate) continue;

      const startPath = ensureDirectory(candidate);

      try {
        const result = await openFilePicker(
          FileSelectionType.FOLDER,
          startPath,
          true,
          true,
          undefined,
          undefined,
          true
        );

        if (result?.path) {
          setPickerState({ selectedPath: normalizePath(result.path), lastError: null });
          setOperationResult(null);
          return;
        }
      } catch (err) {
        console.error("ManualPatchControls -> openDirectoryPicker", err);
        lastError = err instanceof Error ? err.message : String(err);
      }
    }

    setPickerState((prev) => ({ ...prev, lastError }));
  }, [defaults.home, defaults.steamCommon, selectedPath]);

  const runOperation = useCallback(
    async (action: "patch" | "unpatch") => {
      if (!selectedPath) return;

      const setBusy = action === "patch" ? setIsPatching : setIsUnpatching;
  setLastOperation(action);
      setBusy(true);
      setOperationResult(null);

      try {
        const response =
          action === "patch"
            ? await runManualPatch(selectedPath, dllName, fsr4Variant)
            : await runManualUnpatch(selectedPath);
        setOperationResult(response ?? { status: "error", message: "No response from backend." });
      } catch (err) {
        setOperationResult({
          status: "error",
          message: err instanceof Error ? err.message : String(err),
        });
      } finally {
        setBusy(false);
      }
    },
    [selectedPath, dllName, fsr4Variant]
  );

  const handleToggle = (value: boolean) => {
    if (!isAvailable) {
      setEnabled(false);
      return;
    }

    setEnabled(value);
    onManualModeChange?.(value);
    if (!value) {
      setPickerState(INITIAL_PICKER_STATE);
      setOperationResult(null);
      setLastOperation(null);
    }
  };

  const busy = isPatching || isUnpatching;

  return (
    <>
      <PanelSectionRow>
        <ToggleField
          label="高级模式"
          description={
            isAvailable
              ? "手动将 OptiScaler 应用到指定游戏目录。"
              : "请先安装 OptiScaler，才能使用手动修补。"
          }
          checked={isEnabled && isAvailable}
          disabled={!isAvailable}
          onChange={handleToggle}
        />
      </PanelSectionRow>

      {canInteract && (
        <>
          <SmartClipboardButton
            command={
              dllName === "OptiScaler.asi"
                ? "SteamDeck=0 %command%"
                : `WINEDLLOVERRIDES="${dllName.replace(".dll", "")}=n,b" SteamDeck=0 %command%`
            }
            buttonText="复制手动启动命令"
          />
          <PanelSectionRow>
            <ButtonItem
              layout="below"
              onClick={openDirectoryPicker}
              description="选择游戏安装目录（EXE 文件所在位置）。"
            >
              Select directory
            </ButtonItem>
          </PanelSectionRow>

          {pickerState.lastError && (
            <PanelSectionRow>
              <Field
                label="选择器错误"
                description={pickerState.lastError}
              />
            </PanelSectionRow>
          )}

          {selectedPath && (
            <>
              <PanelSectionRow>
                <Field
                  label="目标目录"
                  description="OptiScaler 文件将复制到这里。"
                >
                  <div
                    style={{
                      fontFamily: "monospace",
                      backgroundColor: "rgba(255, 255, 255, 0.05)",
                      border: "1px solid rgba(255, 255, 255, 0.1)",
                      borderRadius: "4px",
                      padding: "6px 8px",
                      width: "100%",
                      boxSizing: "border-box",
                      whiteSpace: "pre-wrap",
                      wordBreak: "break-word",
                    }}
                  >
                    {selectedPath}
                  </div>
                </Field>
              </PanelSectionRow>

              <PanelSectionRow>
                <ButtonItem
                  layout="below"
                  disabled={busy}
                  onClick={() => runOperation("patch")}
                >
                  {isPatching ? "正在修补…" : "修补目录"}
                </ButtonItem>
              </PanelSectionRow>

              <PanelSectionRow>
                <ButtonItem
                  layout="below"
                  disabled={busy}
                  onClick={() => runOperation("unpatch")}
                >
                  {isUnpatching ? "正在撤销…" : "撤销修补目录"}
                </ButtonItem>
              </PanelSectionRow>
            </>
          )}

          {operationResult && (
            <PanelSectionRow>
              <Field
                label={statusLabel ?? (wasSuccessful ? "上次操作成功" : "上次操作失败")}
              >
                {!wasSuccessful && statusMessage ? statusMessage : null}
              </Field>
            </PanelSectionRow>
          )}
        </>
      )}
    </>
  );
};
