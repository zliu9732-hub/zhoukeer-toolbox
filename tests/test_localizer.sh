#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$PROJECT_ROOT/decky-plugins/zhoukeer-localizer/src/index.tsx"
TRANSLATIONS="$PROJECT_ROOT/decky-plugins/zhoukeer-localizer/src/translations.ts"
DIST="$PROJECT_ROOT/decky-plugins/zhoukeer-localizer/dist/index.js"

grep -Fq 'root instanceof Text ? root.parentElement : root' "$SOURCE"
grep -Fq 'window.setInterval(() => processNode(document.body)' "$SOURCE"
grep -Fq '立即扫描当前页面' "$SOURCE"
grep -Fq 'aliases: ["Decky LSFG-VK"]' "$TRANSLATIONS"
grep -Fq 'aliases: ["Decky Framegen"]' "$TRANSLATIONS"
grep -Fq 'const RESCAN_INTERVAL_MS = 1000' "$DIST"
grep -Fq 'export { index as default };' "$DIST"

echo "PASS: 周克儿汉化动态节点扫描、兼容重扫和构建产物检查通过"
