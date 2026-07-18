#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
MARKER="$TMP_ROOT/executed"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

cat > "$TMP_ROOT/settings.conf" <<EOF
# 正常值必须保留
TOOLBOX_NAME="中文工具箱"
GE_PROTON_URL=https://example.invalid/GE-Proton.tar.gz
UNKNOWN_KEY=value
TOOLBOX_NAME=\$(touch "$MARKER")
TODESK_REPOSITORY_URL=\`id\`
GITHUB_MIRRORS=value; touch "$MARKER"
source other-file
EOF

# shellcheck disable=SC1090
source "$PROJECT_ROOT/core/env.sh"
CONFIG_FILE="$TMP_ROOT/settings.conf"
CONFIG_EXAMPLE_FILE="$TMP_ROOT/missing.conf"
load_config >/dev/null 2>&1

[ "$TOOLBOX_NAME" = "中文工具箱" ] || { echo "FAIL: 正常中文配置未保留" >&2; exit 1; }
[ "$GE_PROTON_URL" = "https://example.invalid/GE-Proton.tar.gz" ] || { echo "FAIL: 正常 URL 配置未保留" >&2; exit 1; }
[ ! -e "$MARKER" ] || { echo "FAIL: 恶意配置被执行" >&2; exit 1; }
grep -Fq 'source "$CONFIG_FILE"' "$PROJECT_ROOT/core/env.sh" && { echo "FAIL: 配置文件仍被 source" >&2; exit 1; }
grep -Fq 'eval ' "$PROJECT_ROOT/core/env.sh" && { echo "FAIL: 配置解析仍使用 eval" >&2; exit 1; }

echo "PASS: settings.conf 白名单解析不会执行恶意内容"
