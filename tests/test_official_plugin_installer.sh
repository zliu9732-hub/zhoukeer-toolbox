#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$PROJECT_ROOT/scripts/install-decky-plugin.sh"

bash -n "$INSTALLER"
if bash "$INSTALLER" unknown >/dev/null 2>&1; then
    echo "FAIL: 未知插件代号不应成功"
    exit 1
fi

grep -Fq 'decky-lsfg-vk/releases/download/v0.12.5/Decky.LSFG-VK.zip' "$INSTALLER"
grep -Fq 'Decky-Framegen/releases/download/v0.17/Decky-Framegen.zip' "$INSTALLER"
grep -Fq 'SheffeyG/CheatDeck/releases/download/v1.2.1/CheatDeck.zip' "$INSTALLER"
grep -Fq 'PLUGIN_SHA256' "$INSTALLER"
grep -Fq 'source "$PROJECT_ROOT/core/env.sh"' "$INSTALLER"
grep -Fq 'load_config' "$INSTALLER"
grep -Fq 'download_with_gitee_mirror_fallback' "$INSTALLER"
if grep -Fq -- '--output "$ARCHIVE" "$PLUGIN_URL"' "$INSTALLER"; then
    echo "FAIL: 官方插件安装器不应绕过统一 GitHub 下载器"
    exit 1
fi
grep -Fq '压缩包包含不安全路径' "$INSTALLER"
grep -Fq '请支持插件原作者' "$INSTALLER"
grep -Fq 'remove_legacy_lsfg_directories' "$INSTALLER"
grep -Fq 'systemctl restart plugin_loader.service' "$INSTALLER"

echo "PASS: 三款官方Decky插件独立安装脚本检查通过"
