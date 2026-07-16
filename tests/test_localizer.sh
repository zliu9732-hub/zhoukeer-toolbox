#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$PROJECT_ROOT/decky-plugins/zhoukeer-localizer/src/index.tsx"
TRANSLATIONS="$PROJECT_ROOT/decky-plugins/zhoukeer-localizer/src/translations.ts"
DIST="$PROJECT_ROOT/decky-plugins/zhoukeer-localizer/dist/index.js"

grep -Fq 'root instanceof Text ? root.parentElement : root' "$SOURCE"
grep -Fq 'window.setInterval(() => processNode(document.body)' "$SOURCE"
grep -Fq '立即扫描当前页面' "$SOURCE"
grep -Fq 'allTranslationStrings()' "$SOURCE"
grep -Fq 'translateTextIn(scanRoot, allTranslationStrings())' "$SOURCE"
grep -Fq 'Decky 的插件页面会随版本更换组件类名' "$SOURCE"
grep -Fq 'aliases: ["Decky LSFG-VK"]' "$TRANSLATIONS"
grep -Fq 'aliases: ["Decky Framegen"]' "$TRANSLATIONS"
grep -Fq '请支持插件原作者与汉化者' "$TRANSLATIONS"
grep -Fq 'const RESCAN_INTERVAL_MS = 1000' "$DIST"
grep -Fq 'allTranslationStrings' "$DIST"
grep -Fq 'export { index as default };' "$DIST"

echo "PASS: 周克儿汉化全局文案扫描、兼容重扫和构建产物检查通过"
