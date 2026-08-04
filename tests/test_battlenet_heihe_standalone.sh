#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

OUTPUT_DIR="$TMP_ROOT/output"
ZHOUKEER_STANDALONE_OUTPUT_DIR="$OUTPUT_DIR" \
    bash "$PROJECT_ROOT/scripts/package_battlenet_heihe.sh" >/dev/null

PACKAGE="$(ls "$OUTPUT_DIR"/zhoukeer-battlenet-heihe-*.tar.gz | head -n 1)"
[ -n "$PACKAGE" ] || {
    echo "FAIL: 没有生成独立工具包" >&2
    exit 1
}

for entry in \
    ./install.sh \
    ./README.md \
    ./VERSION \
    ./modules/game_launchers.sh \
    ./core/env.sh \
    ./core/platform.sh \
    ./core/logger.sh \
    ./core/download_policy.sh \
    ./utils/github_download.sh \
    ./utils/gitee_download.sh \
    ./scripts/steam_shortcut.py \
    ./scripts/steam_compat.py \
    ./scripts/open_steam_internal_browser.sh \
    ./assets/game-launchers/battlenet.png \
    ./assets/game-launchers/heihe.png; do
    tar -tzf "$PACKAGE" | grep -Fqx "$entry" || {
        echo "FAIL: 独立工具包缺少 $entry" >&2
        exit 1
    }
done

if tar -tzf "$PACKAGE" | grep -Eq '(^|/)\._'; then
    echo "FAIL: 独立工具包包含 AppleDouble 元数据" >&2
    exit 1
fi

PACKAGE_BYTES="$(stat -f '%z' "$PACKAGE" 2>/dev/null || stat -c '%s' "$PACKAGE" 2>/dev/null)"
[ "$PACKAGE_BYTES" -le 9437184 ] || {
    echo "FAIL: 独立工具包超过 9 MiB 上限" >&2
    exit 1
}

EXPECTED_SHA="$(awk '{print $1}' "$PACKAGE.sha256")"
ACTUAL_SHA="$(shasum -a 256 "$PACKAGE" | awk '{print $1}')"
[ "$EXPECTED_SHA" = "$ACTUAL_SHA" ] || {
    echo "FAIL: 独立工具包 SHA256 校验不一致" >&2
    exit 1
}

mkdir -p "$TMP_ROOT/extracted"
tar -xzf "$PACKAGE" -C "$TMP_ROOT/extracted"
bash -n "$TMP_ROOT/extracted/install.sh"

if bash "$TMP_ROOT/extracted/install.sh" > "$TMP_ROOT/package-run.out" 2>&1; then
    echo "FAIL: macOS 上独立工具包没有拒绝执行" >&2
    exit 1
fi
grep -Fq '仅支持 SteamOS' "$TMP_ROOT/package-run.out" || {
    echo "FAIL: macOS 上独立工具包没有给出平台提示" >&2
    exit 1
}

if bash "$PROJECT_ROOT/standalone/battlenet-heihe/install.sh" \
    > "$TMP_ROOT/repo-run.out" 2>&1; then
    echo "FAIL: 仓库内直接运行没有拒绝执行" >&2
    exit 1
fi
grep -Fq '仅支持 SteamOS' "$TMP_ROOT/repo-run.out" || {
    echo "FAIL: 仓库内直接运行没有给出平台提示" >&2
    exit 1
}

grep -Fq '战网启动器' "$TMP_ROOT/extracted/install.sh" || {
    echo "FAIL: 独立工具菜单缺少战网启动器" >&2
    exit 1
}
grep -Fq '黑盒工坊' "$TMP_ROOT/extracted/install.sh" || {
    echo "FAIL: 独立工具菜单缺少黑盒工坊" >&2
    exit 1
}

echo "PASS: 战网+黑盒工坊独立工具打包、平台保护和结构测试通过"
