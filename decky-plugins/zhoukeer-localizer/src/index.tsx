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
const SKIP_TAGS = new Set(["SCRIPT", "STYLE", "TEXTAREA"]);
const RESCAN_INTERVAL_MS = 1000;

function readEnabled(): boolean {
  return localStorage.getItem(ENABLED_KEY) !== "false";
}

function writeEnabled(enabled: boolean): void {
  localStorage.setItem(ENABLED_KEY, String(enabled));
}

function normalizeText(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function translationEntryFor(value: string): TranslationEntry | undefined {
  const normalized = normalizeText(value);
  return TRANSLATIONS.find((entry) => {
    const names = [entry.plugin, entry.chineseName, ...(entry.aliases ?? [])];
    return names.some((name) =>
      normalized === name ||
      new RegExp(`^${escapeRegex(name)}(?:\\s|$)`).test(normalized)
    );
  });
}

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function pluginNameStrings(entry: TranslationEntry): Record<string, string> {
  return Object.fromEntries(
    [entry.plugin, ...(entry.aliases ?? [])].map((name) => [name, entry.chineseName])
  );
}

function allTranslationStrings(): Record<string, string> {
  const strings: Record<string, string> = {};
  for (const entry of TRANSLATIONS) {
    Object.assign(strings, pluginNameStrings(entry), entry.strings);
  }
  return strings;
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

function activatePluginTitle(title: HTMLElement, entry: TranslationEntry): number {
  const translatedCount = translateTextIn(title, pluginNameStrings(entry));
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
  // Decky 的插件页面会随版本更换组件类名，不能依赖某个固定卡片结构。
  // 先翻译所有已知可见文本，再额外标记插件标题并补上作者说明。
  for (const title of findKnownPluginTitles(scanRoot)) {
    const entry = translationEntryFor(title.textContent ?? "");
    if (entry) translatedCount += activatePluginTitle(title, entry);
  }
  translatedCount += translateTextIn(scanRoot, allTranslationStrings());
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
          已接入 {TRANSLATIONS.length} 个插件的基础词库，会持续扫描动态加载的 Decky 页面。
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
