import {
  ButtonItem,
  PanelSection,
  PanelSectionRow,
} from "@decky/ui";
import { callable, definePlugin, toaster } from "@decky/api";
import { FaWindows } from "react-icons/fa";
import { useEffect, useState } from "react";

type Status = {
  available: boolean;
  message: string;
  boot_number?: string;
  repairable?: boolean;
};

const getStatus = callable<[], Status>("get_status");
const rebootToWindows = callable<[], Status>("reboot_to_windows");

function SwitchPanel() {
  const [status, setStatus] = useState<Status>({
    available: false,
    message: "正在检查 Windows 启动项…",
  });
  const [busy, setBusy] = useState(false);

  const refresh = async () => {
    try {
      setStatus(await getStatus());
    } catch (error) {
      setStatus({ available: false, message: `检查失败：${String(error)}` });
    }
  };

  useEffect(() => { void refresh(); }, []);

  const reboot = async () => {
    if (busy) return;
    setBusy(true);
    try {
      const result = await rebootToWindows();
      toaster.toast({ title: "Switch to Windows", body: result.message });
    } catch (error) {
      const message = String(error);
      toaster.toast({ title: "无法重启进入 Windows", body: message });
      await refresh();
    } finally {
      setBusy(false);
    }
  };

  return (
    <PanelSection title="Switch to Windows">
      <PanelSectionRow>
        <div style={{ fontSize: "12px", lineHeight: "1.45", opacity: 0.75 }}>
          {status.message}
        </div>
      </PanelSectionRow>
      <PanelSectionRow>
        <div style={{ fontSize: "11px", lineHeight: "1.35", opacity: 0.62 }}>
          点击按钮将立即重启进入 Windows；启动项丢失时会安全补回，请先保存所有工作。
        </div>
      </PanelSectionRow>
      <PanelSectionRow>
        <ButtonItem
          layout="below"
          disabled={!status.available || busy}
          onClick={() => { void reboot(); }}
        >
          {busy
            ? "正在设置启动项…"
            : status.repairable
              ? "修复并重启进入 Windows"
              : "重启进入 Windows"}
        </ButtonItem>
      </PanelSectionRow>
      <PanelSectionRow>
        <div style={{ fontSize: "11px", lineHeight: "1.35", opacity: 0.62 }}>
          制作人 RenAmamiya
        </div>
      </PanelSectionRow>
    </PanelSection>
  );
}

export default definePlugin(() => ({
  name: "Switch to Windows",
  title: <div>Switch to Windows</div>,
  content: <SwitchPanel />,
  icon: <FaWindows />,
  onDismount() {},
}));
