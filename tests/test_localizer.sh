#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$PROJECT_ROOT/decky-plugins/zhoukeer-localizer/src/index.tsx"
TRANSLATIONS="$PROJECT_ROOT/decky-plugins/zhoukeer-localizer/src/translations.ts"
DIST="$PROJECT_ROOT/decky-plugins/zhoukeer-localizer/dist/index.js"

grep -Fq 'executeInTab' "$SOURCE"
grep -Fq 'HOST_TAB_NAMES' "$SOURCE"
grep -Fq 'SharedJSContext' "$SOURCE"
grep -Fq 'window[engineKey]' "$SOURCE"
grep -Fq 'MutationObserver' "$SOURCE"
grep -Fq '立即扫描当前页面' "$SOURCE"
grep -Fq 'aliases: ["Decky LSFG-VK"]' "$TRANSLATIONS"
grep -Fq 'aliases: ["Decky Framegen"]' "$TRANSLATIONS"
grep -Fq '请支持插件原作者与汉化者' "$TRANSLATIONS"
grep -Fq 'SharedJSContext' "$DIST"
grep -Fq 'executeInTab' "$DIST"
grep -Fq '__zhoukeerLocalizerEngine' "$DIST"
grep -Fq 'export { index as default };' "$DIST"

echo "PASS: 周克儿汉化全局文案扫描、兼容重扫和构建产物检查通过"
