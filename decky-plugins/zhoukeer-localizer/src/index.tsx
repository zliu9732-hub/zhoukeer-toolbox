import {
  ButtonItem,
  PanelSection,
  PanelSectionRow,
  staticClasses
} from "@decky/ui";
import { definePlugin, toaster } from "@decky/api";
import { useState } from "react";
import { FaLanguage } from "react-icons/fa";
import { AUTHOR_NOTICE, TRANSLATIONS, type TranslationEntry } from "./translations";

const ENABLED_KEY = "zhoukeer-localizer-enabled";
const FOOTER_ATTRIBUTE = "data-zhoukeer-localizer-footer";
const PLUGIN_ROOT_ATTRIBUTE = "data-zhoukeer-localizer-plugin";
const SKIP_TAGS = new Set(["SCRIPT", "STYLE", "TEXTAREA"]);
const RESCAN_INTERVAL_MS = 1000;

function readEnabled(): boolean {
  return localStorage.getItem(ENABLED_KEY) !== "false";
}

function writeEnabled(enabled: boolean): void {
  localStorage.setItem(ENABLED_KEY, String(enabled));
}

function translationEntryFor(value: string): TranslationEntry | undefined {
  const normalized = value.trim();
  return TRANSLATIONS.find((entry) =>
    normalized === entry.plugin ||
    normalized === entry.chineseName ||
    (entry.aliases ?? []).includes(normalized)
  );
}

function pluginNameStrings(entry: TranslationEntry): Record<string, string> {
  return Object.fromEntries(
    [entry.plugin, ...(entry.aliases ?? [])].map((name) => [name, entry.chineseName])
  );
}

function translateTextNode(node: Text, strings: Record<string, string>): number {
  const original = node.nodeValue;
  if (!original) return 0;

  const leading = original.match(/^\s*/)?.[0] ?? "";
  const trailing = original.match(/\s*$/)?.[0] ?? "";
  const translated = strings[original.trim()];
  if (!translated || translated === original.trim()) return 0;
  node.nodeValue = `${leading}${translated}${trailing}`;
  return 1;
}

function addAuthorFooter(title: HTMLElement): void {
  if (title.parentElement?.querySelector(`[${FOOTER_ATTRIBUTE}]`)) return;

  const footer = document.createElement("div");
  footer.setAttribute(FOOTER_ATTRIBUTE, "true");
  footer.textContent = AUTHOR_NOTICE;
  footer.style.cssText = "font-size:11px;opacity:.62;margin-top:2px;line-height:1.35;";
  title.insertAdjacentElement("afterend", footer);
}

function translateTextIn(root: Node, strings: Record<string, string>): number {
  let translatedCount = 0;
  if (root instanceof Text) {
    if (!SKIP_TAGS.has(root.parentElement?.tagName ?? "")) {
      translatedCount += translateTextNode(root, strings);
    }
    return translatedCount;
  }
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  while (walker.nextNode()) {
    const node = walker.currentNode as Text;
    if (!SKIP_TAGS.has(node.parentElement?.tagName ?? "")) {
      translatedCount += translateTextNode(node, strings);
    }
  }
  return translatedCount;
}

function findPluginRoot(title: HTMLElement): HTMLElement | undefined {
  let candidate: HTMLElement | null = title.parentElement;
  for (let level = 0; candidate && level < 6; level += 1, candidate = candidate.parentElement) {
    if (candidate.querySelector('[class*="PanelSectionRow"]')) return candidate;
  }
  return undefined;
}

function activatePluginTitle(title: HTMLElement, entry: TranslationEntry): number {
  let translatedCount = translateTextIn(title, pluginNameStrings(entry));
  const pluginRoot = findPluginRoot(title);
  if (!pluginRoot) return translatedCount;

  pluginRoot.setAttribute(PLUGIN_ROOT_ATTRIBUTE, entry.plugin);
  translatedCount += translateTextIn(pluginRoot, {
    ...pluginNameStrings(entry),
    ...entry.strings
  });
  addAuthorFooter(title);
  return translatedCount;
}

function findKnownPluginTitles(root: Node): HTMLElement[] {
  const scanRoot = root instanceof Text ? root.parentElement : root;
  if (!(scanRoot instanceof HTMLElement)) return [];
  const candidates = [scanRoot, ...Array.from(scanRoot.querySelectorAll<HTMLElement>("*"))];
  return candidates.filter((element) => {
    const entry = translationEntryFor(element.textContent ?? "");
    return Boolean(entry) && !Array.from(element.children).some(
      (child) => Boolean(translationEntryFor(child.textContent ?? ""))
    );
  });
}

function processNode(root: Node): number {
  const scanRoot = root instanceof Text ? root.parentElement : root;
  if (!scanRoot) return 0;

  let translatedCount = 0;
  const activeRoot = scanRoot instanceof HTMLElement
    ? scanRoot.closest<HTMLElement>(`[${PLUGIN_ROOT_ATTRIBUTE}]`)
    : undefined;
  if (activeRoot) {
    const plugin = activeRoot.getAttribute(PLUGIN_ROOT_ATTRIBUTE);
    const entry = TRANSLATIONS.find((item) => item.plugin === plugin);
    if (entry) translatedCount += translateTextIn(scanRoot, entry.strings);
  }

  for (const title of findKnownPluginTitles(scanRoot)) {
    const entry = translationEntryFor(title.textContent ?? "");
    if (entry) translatedCount += activatePluginTitle(title, entry);
  }
  return translatedCount;
}

class TranslationEngine {
  private observer?: MutationObserver;
  private rescanTimer?: number;

  start(): void {
    if (this.observer || !readEnabled()) return;
    processNode(document.body);
    this.observer = new MutationObserver((records) => {
      for (const record of records) {
        if (record.type === "characterData") processNode(record.target);
        for (const node of record.addedNodes) processNode(node);
      }
    });
    this.observer.observe(document.body, { childList: true, characterData: true, subtree: true });
    this.rescanTimer = window.setInterval(() => processNode(document.body), RESCAN_INTERVAL_MS);
  }

  stop(): void {
    this.observer?.disconnect();
    this.observer = undefined;
    if (this.rescanTimer !== undefined) window.clearInterval(this.rescanTimer);
    this.rescanTimer = undefined;
  }

  refresh(enabled: boolean): void {
    writeEnabled(enabled);
    this.stop();
    if (enabled) this.start();
  }

  scan(): number {
    return readEnabled() ? processNode(document.body) : 0;
  }
}

const engine = new TranslationEngine();

function Content() {
  const [enabled, setEnabled] = useState(readEnabled());

  const toggle = () => {
    const next = !enabled;
    setEnabled(next);
    engine.refresh(next);
    toaster.toast({
      title: "周克儿汉化",
      body: next ? "汉化层已启用。重新打开插件页面即可生效。" : "汉化层已暂停。"
    });
  };

  const scanNow = () => {
    const translatedCount = engine.scan();
    toaster.toast({
      title: "周克儿汉化",
      body: translatedCount > 0
        ? `本次已处理 ${translatedCount} 处文字。`
        : "未发现可处理文字。请先打开目标插件页面，再点击扫描。"
    });
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
          已接入 {TRANSLATIONS.length} 个插件的基础词库，并会兼容扫描动态加载的 Decky 页面。
          <br />
          {AUTHOR_NOTICE}
        </div>
      </PanelSectionRow>
    </PanelSection>
  );
}

export default definePlugin(() => {
  engine.start();

  return {
    name: "周克儿汉化",
    titleView: <div className={staticClasses.Title}>周克儿汉化</div>,
    content: <Content />,
    icon: <FaLanguage />,
    onDismount() {
      engine.stop();
    }
  };
});
