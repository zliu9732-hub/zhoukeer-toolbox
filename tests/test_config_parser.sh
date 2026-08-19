#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
MARKER="$TMP_ROOT/executed"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

cat > "$TMP_ROOT/settings.conf" <<EOF
# 正常值必须保留
TOOLBOX_NAME="中文工具名"
GE_PROTON_URL=https://example.invalid/GE-Proton.tar.gz
UNKNOWN_KEY=value
DECKY_LSFG_ZH_URL=https://retired.invalid/lsfg.zip
DECKY_LSFG_ZH_SHA256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
DECKY_FSR4_ZH_URL=https://retired.invalid/fsr4.zip
DECKY_FSR4_ZH_SHA256=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
TOOLBOX_NAME=\$(touch "$MARKER")
TODESK_REPOSITORY_URL=\`id\`
GITHUB_MIRRORS=value; touch "$MARKER"
source other-file
EOF

# shellcheck disable=SC1090
source "$PROJECT_ROOT/core/env.sh"
CONFIG_FILE="$TMP_ROOT/settings.conf"
CONFIG_EXAMPLE_FILE="$TMP_ROOT/missing.conf"
parser_stderr="$TMP_ROOT/parser.stderr"
load_config >/dev/null 2>"$parser_stderr"

[ "$TOOLBOX_NAME" = "中文工具名" ] || { echo "FAIL: 正常中文配置未保留" >&2; exit 1; }
[ "$GE_PROTON_URL" = "https://example.invalid/GE-Proton.tar.gz" ] || { echo "FAIL: 正常 URL 配置未保留" >&2; exit 1; }
[ ! -e "$MARKER" ] || { echo "FAIL: 恶意配置被执行" >&2; exit 1; }
if grep -Eq 'DECKY_(LSFG|FSR4)_ZH_(URL|SHA256)' "$parser_stderr"; then
    echo "FAIL: 已退役的汉化覆盖配置仍重复报警" >&2
    exit 1
fi
grep -Fq 'source "$CONFIG_FILE"' "$PROJECT_ROOT/core/env.sh" && { echo "FAIL: 配置文件仍被 source" >&2; exit 1; }
grep -Fq 'eval ' "$PROJECT_ROOT/core/env.sh" && { echo "FAIL: 配置解析仍使用 eval" >&2; exit 1; }

echo "PASS: settings.conf 白名单解析不会执行恶意内容"
