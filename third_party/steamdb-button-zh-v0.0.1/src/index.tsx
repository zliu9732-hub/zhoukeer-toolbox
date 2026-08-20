import {
  PanelSection,
  PanelSectionRow,
  DropdownItem,
  ToggleField,
  staticClasses,
  findModuleExport,
} from "@decky/ui";
import {
  definePlugin,
  fetchNoCors,
  call,
} from "@decky/api";
import { FaDollarSign } from "react-icons/fa";
import { useEffect, useState } from "react";

type Settings = {
  enabled: boolean;
  storePosition: "tl" | "tc" | "tr" | "bc" | "bl" | "br";
};

const DEFAULT_SETTINGS: Settings = {
  enabled: true,
  storePosition: "bc",
};

let currentSettings: Settings = DEFAULT_SETTINGS;
const settingsListeners = new Set<(settings: Settings) => void>();

function setSettings(next: Settings) {
  currentSettings = next;
  settingsListeners.forEach((listener) => listener(next));
}

async function loadSettings() {
  const settings = await call<[string, Settings], Settings>("get_setting", "settings", DEFAULT_SETTINGS);
  setSettings({ ...DEFAULT_SETTINGS, ...settings });
}

async function saveSettings(next: Settings) {
  setSettings(next);
  await call<[string, Settings], Settings>("set_setting", "settings", next);

  if (storeMounted) {
    if (!next.enabled) {
      storeRemoveButton();
    } else if (storeAppId) {
      storeInjectButton(storeAppId);
    }
  }
}

function useSettingsState() {
  const [settings, setState] = useState(currentSettings);

  useEffect(() => {
    const listener = (next: Settings) => setState(next);
    settingsListeners.add(listener);
    return () => {
      settingsListeners.delete(listener);
    };
  }, []);

  return settings;
}

function getSteamDbUrl(appId: string, section: "pricehistory" | "charts"): string {
  const parsed = Number(appId);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error("Invalid appid");
  }
  return section === "pricehistory"
    ? `https://steamdb.info/app/${parsed}/#pricehistory`
    : `https://steamdb.info/app/${parsed}/charts/`;
}

function SettingsPanel() {
  const settings = useSettingsState();

  return (
    <PanelSection title="SteamDB 游戏数据">
      <PanelSectionRow>
        <ToggleField
          label="在商店页显示按钮"
          checked={settings.enabled}
          onChange={(enabled: boolean) => void saveSettings({ ...settings, enabled })}
        />
      </PanelSectionRow>
      <PanelSectionRow>
        <DropdownItem
          label="按钮位置"
          menuLabel="按钮位置"
          rgOptions={[
            { data: 0, label: "左上" },
            { data: 1, label: "顶部居中" },
            { data: 2, label: "右上" },
            { data: 3, label: "左下" },
            { data: 4, label: "底部居中" },
            { data: 5, label: "右下" },
          ]}
          selectedOption={{ tl: 0, tc: 1, tr: 2, bl: 3, bc: 4, br: 5 }[settings.storePosition]}
          onChange={(newVal: { data: number; label: string }) => {
            const storePosition = ({ 0: "tl", 1: "tc", 2: "tr", 3: "bl", 4: "bc", 5: "br" } as const)[newVal.data as 0 | 1 | 2 | 3 | 4 | 5];
            void saveSettings({ ...settings, storePosition });
          }}
        />
      </PanelSectionRow>
      <PanelSectionRow>
        <div style={{ fontSize: "12px", opacity: 0.72 }}>
          可打开 SteamDB 查看价格史低和在线人数峰值。汉化：RenAmamiya
        </div>
      </PanelSectionRow>
    </PanelSection>
  );
}

const STORE_HOST = "store.steampowered.com";
const STORE_BUTTON_ID = "steamdb-store-button";
const STORE_DEBUGGER_TABS_URL = "http://localhost:8080/json";

type DebugTab = { url: string; webSocketDebuggerUrl?: string };
type HistoryLike = {
  location?: { pathname?: string };
  listen: (listener: (location: unknown) => void) => () => void;
};

const StoreHistoryModule = findModuleExport((exp: any) => exp?.m_history !== undefined) as
  | { m_history?: HistoryLike }
  | undefined;
const StoreHistory = StoreHistoryModule?.m_history;

let storeMounted = false;
let storeAppId = "";
let storeRuntimeReady = false;
let storeWebSocket: WebSocket | null = null;
let storeMessageId = 1;

function storeEvaluate(script: string) {
  if (!storeWebSocket || storeWebSocket.readyState !== WebSocket.OPEN || !storeRuntimeReady) {
    return;
  }

  storeWebSocket.send(
    JSON.stringify({
      id: storeMessageId++,
      method: "Runtime.evaluate",
      params: { expression: script },
    }),
  );
}

function storeRemoveButton() {
  storeEvaluate(
    `(function(){const node=document.getElementById('${STORE_BUTTON_ID}');if(node){node.remove();}})();`,
  );
}

function storeGetPosition() {
  switch (currentSettings.storePosition) {
    case "tl": return "top: 60px; left: 20px;";
    case "tr": return "top: 60px; right: 20px;";
    case "bl": return "bottom: 20px; left: 20px;";
    case "br": return "bottom: 20px; right: 20px;";
    case "tc": return "top: 60px; left: 50%; transform: translateX(-50%);";
    default: return "bottom: 20px; left: 50%; transform: translateX(-50%);";
  }
}

function storeInjectButton(appId: string) {
  if (!currentSettings.enabled) {
    storeRemoveButton();
    return;
  }

  let priceUrl: string;
  let chartsUrl: string;
  try {
    priceUrl = getSteamDbUrl(appId, "pricehistory");
    chartsUrl = getSteamDbUrl(appId, "charts");
  } catch {
    storeRemoveButton();
    return;
  }

  const script = `
    (function(){
      const existing=document.getElementById('${STORE_BUTTON_ID}');
      if(existing){existing.remove();}
      const wrapper=document.createElement('div');
      wrapper.id='${STORE_BUTTON_ID}';
      wrapper.style.cssText='position:fixed;z-index:999999;display:flex;gap:8px;${storeGetPosition()}';
      const addButton=function(label,url,symbol){
        const button=document.createElement('div');
        button.tabIndex=-1;
        button.setAttribute('role','presentation');
        button.setAttribute('aria-hidden','true');
        button.innerHTML='<span style="display:inline-flex;align-items:center;gap:6px;padding:6px 12px;border-radius:6px;background:#5ba32b;border:1px solid #5ba32b;color:#ffffff;font-weight:600;font-size:14px;cursor:pointer;"><span>'+symbol+'</span><span>'+label+'</span><span style="font-size:12px;opacity:0.5;">↗</span></span>';
        button.style.cssText='display:inline-block;cursor:pointer;';
        button.onclick=function(){window.open(url,'_blank');};
        wrapper.appendChild(button);
      };
      addButton('价格史低','${priceUrl}','$');
      addButton('在线峰值','${chartsUrl}','●');
      document.body.appendChild(wrapper);
    })();
  `;

  storeEvaluate(script);
}

function storeSyncButtonWithUrl(url: string) {
  const appId = url.includes(STORE_HOST) ? url.match(/\/app\/(\d+)(?:\/|$)/)?.[1] ?? "" : "";
  storeAppId = appId;

  if (!appId) {
    storeRemoveButton();
    return;
  }

  storeInjectButton(appId);
}

async function storeConnectToDebugger(retries = 3): Promise<void> {
  if (!storeMounted || retries <= 0) return;

  try {
    const response = await fetchNoCors(STORE_DEBUGGER_TABS_URL);
    if (!response.ok) throw new Error("debugger tabs unavailable");

    const tabs = (await response.json()) as DebugTab[];
    const storeTab = tabs.find((tab) => tab.url.includes(STORE_HOST) && tab.webSocketDebuggerUrl);
    if (!storeTab?.webSocketDebuggerUrl) {
      setTimeout(() => void storeConnectToDebugger(retries - 1), 1000);
      return;
    }

    storeSyncButtonWithUrl(storeTab.url);

    storeWebSocket = new WebSocket(storeTab.webSocketDebuggerUrl);
    storeWebSocket.onopen = (event: Event) => {
      const socket = event.target;
      if (!(socket instanceof WebSocket)) return;

      socket.send(JSON.stringify({ id: storeMessageId++, method: "Page.enable" }));
      socket.send(JSON.stringify({ id: storeMessageId++, method: "Runtime.enable" }));

      setTimeout(() => {
        storeRuntimeReady = true;
        if (storeAppId) storeInjectButton(storeAppId);
      }, 250);
    };

    storeWebSocket.onmessage = (event: MessageEvent<string>) => {
      if (!storeMounted) return;

      try {
        const payload = JSON.parse(event.data) as Record<string, unknown>;
        if (payload.method !== "Page.frameNavigated") return;

        const params = payload.params as Record<string, unknown> | undefined;
        const frame = params?.frame as Record<string, unknown> | undefined;
        const frameUrl = typeof frame?.url === "string" ? frame.url : "";
        if (!frameUrl) return;

        setTimeout(() => storeSyncButtonWithUrl(frameUrl), 350);
      } catch {
        // ignore
      }
    };

    storeWebSocket.onclose = () => {
      storeRuntimeReady = false;
      storeWebSocket = null;
      if (storeMounted) setTimeout(() => void storeConnectToDebugger(), 1000);
    };

    storeWebSocket.onerror = () => {
      if (storeMounted) setTimeout(() => void storeConnectToDebugger(), 1000);
    };
  } catch {
    if (storeMounted) setTimeout(() => void storeConnectToDebugger(retries - 1), 1000);
  }
}

function storeDisconnectDebugger() {
  storeRemoveButton();
  storeMounted = false;
  storeAppId = "";
  storeRuntimeReady = false;
  if (storeWebSocket) {
    storeWebSocket.close();
    storeWebSocket = null;
  }
}

function storeHandlePathChange(pathname: string) {
  if (pathname === "/steamweb") {
    if (!storeMounted) {
      storeMounted = true;
      void storeConnectToDebugger();
    } else if (!storeWebSocket || storeWebSocket.readyState !== WebSocket.OPEN) {
      void storeConnectToDebugger();
    }
    return;
  }

  if (storeMounted) {
    storeDisconnectDebugger();
  }
}

export default definePlugin(() => {
  void loadSettings();
  let stopStoreWatcher = () => {};
  if (StoreHistory) {
    storeHandlePathChange(StoreHistory.location?.pathname || window.location.pathname);
    const unlisten = StoreHistory.listen((location: unknown) => {
      const pathname =
        typeof location === "object" && location !== null && "pathname" in location
          ? String((location as { pathname?: unknown }).pathname ?? "")
          : "";
      if (pathname) storeHandlePathChange(pathname);
    });

    setTimeout(() => storeHandlePathChange(window.location.pathname), 250);

    stopStoreWatcher = () => {
      unlisten();
      storeDisconnectDebugger();
    };
  }

  return {
    name: "steamdbDeckyPlugin",
    title: <div className={staticClasses.Title}>SteamDB 游戏数据</div>,
    icon: <FaDollarSign />,
    content: <SettingsPanel />,
    onDismount() {
      stopStoreWatcher();
    },
  };
});
