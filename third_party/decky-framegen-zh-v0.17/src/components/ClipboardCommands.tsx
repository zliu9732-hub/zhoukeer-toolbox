import { SmartClipboardButton } from "./SmartClipboardButton";

interface ClipboardCommandsProps {
  pathExists: boolean | null;
  dllName: string;
  manualModeEnabled?: boolean;
  showLaunchOptions?: boolean;
}

export function ClipboardCommands({
  pathExists,
  dllName,
  manualModeEnabled = false,
  showLaunchOptions = true,
}: ClipboardCommandsProps) {
  if (pathExists !== true) return null;

  const launchCmd =
    dllName === "OptiScaler.asi"
      ? "SteamDeck=0 %command%"
      : `WINEDLLOVERRIDES=${dllName.replace(".dll", "")}=n,b SteamDeck=0 %command%`;

  return (
    <>
      {showLaunchOptions ? (
        <SmartClipboardButton
          command={launchCmd}
          buttonText="复制启动选项"
        />
      ) : null}
      {manualModeEnabled ? (
        <>
          <SmartClipboardButton
            command="~/fgmod/fgmod %command%"
            buttonText="复制修补命令"
          />
          <SmartClipboardButton
            command="~/fgmod/fgmod-uninstaller.sh %command%"
            buttonText="复制撤销修补命令"
          />
        </>
      ) : null}
    </>
  );
}
