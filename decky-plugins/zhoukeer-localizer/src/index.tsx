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

    window[engineKey]?.stop?.();
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
  private tabName?: string;
  private active = false;

  private async execute(code: string): Promise<number> {
    const candidates = this.tabName
      ? [this.tabName, ...HOST_TAB_NAMES.filter((name) => name !== this.tabName)]
      : HOST_TAB_NAMES;

    for (const tabName of candidates) {
      const response = await executeInTab(tabName, false, code);
      if (!response.success) continue;
      this.tabName = tabName;
      return typeof response.result === "number" ? response.result : 0;
    }
    throw new Error("未找到 Steam GamepadUI 标签页");
  }

  async start(): Promise<number> {
    if (!readEnabled()) return 0;
    if (this.active) return this.scan();
    const count = await this.execute(hostInstallCode());
    this.active = true;
    return count;
  }

  async stop(): Promise<void> {
    if (this.active) {
      try {
        await this.execute(hostCommandCode("stop"));
      } catch {
        // Steam may already be closing; local state still needs to be reset.
      }
    }
    this.active = false;
  }

  async refresh(enabled: boolean): Promise<number> {
    writeEnabled(enabled);
    await this.stop();
    return enabled ? this.start() : 0;
  }

  async scan(): Promise<number> {
    if (!readEnabled()) return 0;
    if (!this.active) return this.start();
    const result = await this.execute(hostCommandCode("scan"));
    if (result >= 0) return result;
    this.active = false;
    return this.start();
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
          已接入 {TRANSLATIONS.length} 个插件的基础词库，并注入 Steam 主界面持续扫描。
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
