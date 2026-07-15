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

function readEnabled(): boolean {
  return localStorage.getItem(ENABLED_KEY) !== "false";
}

function writeEnabled(enabled: boolean): void {
  localStorage.setItem(ENABLED_KEY, String(enabled));
}

function translateTextNode(node: Text, strings: Record<string, string>): void {
  const original = node.nodeValue;
  if (!original) return;

  const leading = original.match(/^\s*/)?.[0] ?? "";
  const trailing = original.match(/\s*$/)?.[0] ?? "";
  const translated = strings[original.trim()];
  if (translated) node.nodeValue = `${leading}${translated}${trailing}`;
}

function addAuthorFooter(title: HTMLElement): void {
  if (title.parentElement?.querySelector(`[${FOOTER_ATTRIBUTE}]`)) return;

  const footer = document.createElement("div");
  footer.setAttribute(FOOTER_ATTRIBUTE, "true");
  footer.textContent = AUTHOR_NOTICE;
  footer.style.cssText = "font-size:11px;opacity:.62;margin-top:2px;line-height:1.35;";
  title.insertAdjacentElement("afterend", footer);
}

function translateTextIn(root: Node, strings: Record<string, string>): void {
  if (root instanceof Text) {
    if (!SKIP_TAGS.has(root.parentElement?.tagName ?? "")) translateTextNode(root, strings);
    return;
  }
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  while (walker.nextNode()) {
    const node = walker.currentNode as Text;
    if (!SKIP_TAGS.has(node.parentElement?.tagName ?? "")) translateTextNode(node, strings);
  }
}

function findPluginRoot(title: HTMLElement): HTMLElement {
  let candidate: HTMLElement | null = title.parentElement;
  for (let level = 0; candidate && level < 6; level += 1, candidate = candidate.parentElement) {
    if (candidate.querySelector('[class*="PanelSectionRow"]')) return candidate;
  }
  return title.parentElement ?? title;
}

function activatePluginTitle(title: HTMLElement, entry: TranslationEntry): void {
  const pluginRoot = findPluginRoot(title);
  pluginRoot.setAttribute(PLUGIN_ROOT_ATTRIBUTE, entry.plugin);
  translateTextIn(pluginRoot, { [entry.plugin]: entry.chineseName, ...entry.strings });
  addAuthorFooter(title);
}

function findKnownPluginTitles(root: Node): HTMLElement[] {
  if (!(root instanceof HTMLElement)) return [];
  const candidates = [root, ...Array.from(root.querySelectorAll<HTMLElement>("*"))];
  return candidates.filter((element) => {
    const entry = TRANSLATIONS.find((item) => element.textContent?.trim() === item.plugin);
    return Boolean(entry) && !Array.from(element.children).some(
      (child) => child.textContent?.trim() === entry?.plugin
    );
  });
}

function processNode(root: Node): void {
  const parent = root instanceof Text ? root.parentElement : root.parentElement;
  const activeRoot = parent?.closest<HTMLElement>(`[${PLUGIN_ROOT_ATTRIBUTE}]`);
  if (activeRoot) {
    const plugin = activeRoot.getAttribute(PLUGIN_ROOT_ATTRIBUTE);
    const entry = TRANSLATIONS.find((item) => item.plugin === plugin);
    if (entry) translateTextIn(root, entry.strings);
  }

  for (const title of findKnownPluginTitles(root)) {
    const entry = TRANSLATIONS.find((item) => item.plugin === title.textContent?.trim());
    if (entry) activatePluginTitle(title, entry);
  }
}

class TranslationEngine {
  private observer?: MutationObserver;

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
  }

  stop(): void {
    this.observer?.disconnect();
    this.observer = undefined;
  }

  refresh(enabled: boolean): void {
    writeEnabled(enabled);
    this.stop();
    if (enabled) this.start();
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

  return (
    <PanelSection title="周克儿汉化">
      <PanelSectionRow>
        <ButtonItem layout="below" onClick={toggle}>
          {enabled ? "已启用，点击暂停" : "已暂停，点击启用"}
        </ButtonItem>
      </PanelSectionRow>
      <PanelSectionRow>
        <div style={{ fontSize: "12px", lineHeight: "1.45", opacity: 0.75 }}>
          首批已接入 {TRANSLATIONS.length} 个插件的基础词库。词库会随工具箱更新扩充，不会改写原插件文件。
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
