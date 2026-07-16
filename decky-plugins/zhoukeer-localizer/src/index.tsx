import {
  ButtonItem,
  PanelSection,
  PanelSectionRow,
  staticClasses
} from "@decky/ui";
import { definePlugin, executeInTab, toaster } from "@decky/api";
import { useState } from "react";
import { FaLanguage } from "react-icons/fa";
import { AUTHOR_NOTICE, TRANSLATIONS } from "./translations";

const ENABLED_KEY = "zhoukeer-localizer-enabled";
const HOST_ENGINE_KEY = "__zhoukeerLocalizerEngine";
const HOST_ENGINE_REVISION = "multi-tab-v1";
const DISCOVERY_INTERVAL_MS = 2000;
const HOST_TAB_NAMES = [
  "SP",
  "Steam",
  "SharedJSContext",
  "Steam Shared Context presented by Valve™"
];

function readEnabled(): boolean {
  return localStorage.getItem(ENABLED_KEY) !== "false";
}

function writeEnabled(enabled: boolean): void {
  localStorage.setItem(ENABLED_KEY, String(enabled));
}

function hostInstallCode(): string {
  const payload = {
    revision: HOST_ENGINE_REVISION,
    authorNotice: AUTHOR_NOTICE,
    entries: TRANSLATIONS.map((entry) => ({
      names: [entry.plugin, entry.chineseName, ...(entry.aliases ?? [])],
      chineseName: entry.chineseName,
      strings: entry.strings
    }))
  };

  return `(() => {
    const engineKey = ${JSON.stringify(HOST_ENGINE_KEY)};
    const payload = ${JSON.stringify(payload)};
    const footerAttribute = "data-zhoukeer-localizer-footer";
    if (!document.body) return -2;
    const existingEngine = window[engineKey];
    if (existingEngine?.revision === payload.revision && typeof existingEngine.scan === "function") {
      return existingEngine.scan();
    }
    existingEngine?.stop?.();
    const skipTags = new Set(["SCRIPT", "STYLE", "TEXTAREA"]);
    const normalize = (value) => String(value || "").replace(/\\s+/g, " ").trim();
    const entries = payload.entries;
    const strings = Object.assign({}, ...entries.map((entry) => {
      const names = Object.fromEntries(entry.names.map((name) => [name, entry.chineseName]));
      return Object.assign(names, entry.strings);
    }));
    const entryFor = (value) => {
      const text = normalize(value);
      return entries.find((entry) => entry.names.some((name) =>
        text === name || text.startsWith(name + " ")
      ));
    };
    const translateTextNode = (node) => {
      const original = node.nodeValue;
      if (!original || skipTags.has(node.parentElement?.tagName || "")) return 0;
      const trimmed = original.trim();
      const translated = strings[trimmed];
      if (!translated || translated === trimmed) return 0;
      const leading = original.match(/^\\s*/)?.[0] || "";
      const trailing = original.match(/\\s*$/)?.[0] || "";
      node.nodeValue = leading + translated + trailing;
      return 1;
    };
    const translateIn = (root) => {
      if (!root) return 0;
      if (root.nodeType === Node.TEXT_NODE) return translateTextNode(root);
      let count = 0;
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      while (walker.nextNode()) count += translateTextNode(walker.currentNode);
      return count;
    };
    const addFooter = (title) => {
      if (!title?.parentElement || title.parentElement.querySelector("[" + footerAttribute + "]")) return;
      const footer = document.createElement("div");
      footer.setAttribute(footerAttribute, "true");
      footer.textContent = payload.authorNotice;
      footer.style.cssText = "font-size:11px;opacity:.62;margin-top:2px;line-height:1.35;";
      title.insertAdjacentElement("afterend", footer);
    };
    const markTitles = (root) => {
      if (!(root instanceof Element)) return 0;
      let count = 0;
      const candidates = [root, ...root.querySelectorAll("*")];
      for (const element of candidates) {
        const entry = entryFor(element.textContent);
        if (!entry) continue;
        const childHasTitle = [...element.children].some((child) => entryFor(child.textContent));
        if (childHasTitle) continue;
        count += translateIn(element);
        addFooter(element);
      }
      return count;
    };
    const scan = (root = document.body) => markTitles(root) + translateIn(root);

    const observer = new MutationObserver((records) => {
      for (const record of records) {
        if (record.type === "characterData") scan(record.target.parentElement);
        for (const node of record.addedNodes) {
          scan(node.nodeType === Node.TEXT_NODE ? node.parentElement : node);
        }
      }
    });
    observer.observe(document.body, { childList: true, characterData: true, subtree: true });
    const timer = window.setInterval(() => scan(document.body), 1200);
    window[engineKey] = {
      revision: payload.revision,
      scan: () => scan(document.body),
      stop: () => {
        observer.disconnect();
        window.clearInterval(timer);
        document.querySelectorAll("[" + footerAttribute + "]").forEach((node) => node.remove());
        delete window[engineKey];
      }
    };
    return window[engineKey].scan();
  })()`;
}

function hostCommandCode(command: "scan" | "stop"): string {
  return `(() => {
    const engine = window[${JSON.stringify(HOST_ENGINE_KEY)}];
    if (!engine) return ${command === "scan" ? "-1" : "0"};
    const result = engine.${command}();
    return typeof result === "number" ? result : 0;
  })()`;
}

class TranslationEngine {
  private activeTabs = new Set<string>();
  private active = false;
  private discoveryTimer?: number;
  private discoveryTask?: Promise<number>;

  private async executeOnTab(tabName: string, code: string): Promise<number | undefined> {
    try {
      const response = await executeInTab(tabName, false, code);
      if (!response.success) {
        this.activeTabs.delete(tabName);
        return undefined;
      }
      this.activeTabs.add(tabName);
      const result = Number(response.result);
      return Number.isFinite(result) ? result : 0;
    } catch {
      this.activeTabs.delete(tabName);
      return undefined;
    }
  }

  private async discoverOnce(requireConnection: boolean): Promise<number> {
    let connectedTabs = 0;
    let translatedCount = 0;

    // Decky can remount a plugin panel in a different Steam tab. Always probe
    // every known context so a newly selected plugin receives its own observer.
    for (const tabName of HOST_TAB_NAMES) {
      let result = await this.executeOnTab(tabName, hostCommandCode("scan"));
      if (result === undefined) continue;
      if (result < 0) {
        result = await this.executeOnTab(tabName, hostInstallCode());
        if (result === undefined || result < 0) continue;
      }
      connectedTabs += 1;
      translatedCount += result;
    }

    if (requireConnection && connectedTabs === 0) {
      throw new Error("未找到可监听的 Steam / Decky 页面，请打开一次 Decky 插件菜单后重试。");
    }
    return translatedCount;
  }

  private discover(requireConnection: boolean): Promise<number> {
    if (this.discoveryTask) return this.discoveryTask;
    const task = this.discoverOnce(requireConnection);
    this.discoveryTask = task;
    void task.finally(() => {
      if (this.discoveryTask === task) this.discoveryTask = undefined;
    }).catch(() => undefined);
    return task;
  }

  private startDiscoveryTimer(): void {
    if (this.discoveryTimer !== undefined) return;
    this.discoveryTimer = window.setInterval(() => {
      if (!this.active || !readEnabled()) return;
      void this.discover(false).catch(() => undefined);
    }, DISCOVERY_INTERVAL_MS);
  }

  async start(): Promise<number> {
    if (!readEnabled()) return 0;
    if (this.active) return this.scan();
    this.active = true;
    this.startDiscoveryTimer();
    return this.discover(true);
  }

  async stop(): Promise<void> {
    this.active = false;
    if (this.discoveryTimer !== undefined) {
      window.clearInterval(this.discoveryTimer);
      this.discoveryTimer = undefined;
    }
    await Promise.all(HOST_TAB_NAMES.map(async (tabName) => {
      try {
        await executeInTab(tabName, false, hostCommandCode("stop"));
      } catch {
        // Steam may already be closing; local state still needs to be reset.
      }
    }));
    this.activeTabs.clear();
    this.discoveryTask = undefined;
  }

  async refresh(enabled: boolean): Promise<number> {
    writeEnabled(enabled);
    await this.stop();
    return enabled ? this.start() : 0;
  }

  async scan(): Promise<number> {
    if (!readEnabled()) return 0;
    if (!this.active) return this.start();
    return this.discover(true);
  }
}

const engine = new TranslationEngine();

function showEngineError(error: unknown): void {
  toaster.toast({
    title: "周克儿汉化",
    body: error instanceof Error ? error.message : "无法连接 Steam 主界面。"
  });
}

function Content() {
  const [enabled, setEnabled] = useState(readEnabled());

  const toggle = async () => {
    const next = !enabled;
    setEnabled(next);
    try {
      await engine.refresh(next);
      toaster.toast({
        title: "周克儿汉化",
        body: next ? "汉化层已注入 Steam 主界面。" : "汉化层已暂停。"
      });
    } catch (error) {
      showEngineError(error);
    }
  };

  const scanNow = async () => {
    try {
      const translatedCount = await engine.scan();
      toaster.toast({
        title: "周克儿汉化",
        body: translatedCount > 0
          ? `本次已处理 ${translatedCount} 处文字。`
          : "当前可见页面没有新的已知英文文案。"
      });
    } catch (error) {
      showEngineError(error);
    }
  };

  return (
    <PanelSection title="周克儿汉化">
      <PanelSectionRow>
        <ButtonItem layout="below" onClick={toggle}>
          {enabled ? "已启用，点击暂停" : "已暂停，点击启用"}
        </ButtonItem>
      </PanelSectionRow>
      <PanelSectionRow>
        <ButtonItem layout="below" onClick={scanNow}>
          立即扫描当前页面
        </ButtonItem>
      </PanelSectionRow>
      <PanelSectionRow>
        <div style={{ fontSize: "12px", lineHeight: "1.45", opacity: 0.75 }}>
          已接入 {TRANSLATIONS.length} 个插件的基础词库，会自动跟随插件切换并持续扫描。
          <br />
          {AUTHOR_NOTICE}
        </div>
      </PanelSectionRow>
    </PanelSection>
  );
}

export default definePlugin(() => {
  void engine.start().catch(showEngineError);

  return {
    name: "周克儿汉化",
    titleView: <div className={staticClasses.Title}>周克儿汉化</div>,
    content: <Content />,
    icon: <FaLanguage />,
    onDismount() {
      void engine.stop();
    }
  };
});
