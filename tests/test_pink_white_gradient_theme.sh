#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/pink_white_gradient_theme.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pink-white-gradient-test.XXXXXX")"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

HOME_DIR="$TMP_ROOT/home"
HOMEBREW_DIR="$TMP_ROOT/homebrew"
PLUGIN_DIR="$HOMEBREW_DIR/plugins"

mkdir -p "$HOME_DIR" "$PLUGIN_DIR/SDH-CssLoader"

export HOME="$HOME_DIR"
export ZHOUKEER_DECKY_HOMEBREW_DIR="$HOMEBREW_DIR"
export DECKY_PLUGIN_DIR="$PLUGIN_DIR"
export ZHOUKEER_ALLOW_NON_STEAMOS=1

source "$MODULE"

[ -f "$PINK_WHITE_GRADIENT_SOURCE_DIR/theme.json" ] || fail "仓库缺少 Pink White Gradient theme.json"
[ -f "$PINK_WHITE_GRADIENT_SOURCE_DIR/shared.css" ] || fail "仓库缺少 Pink White Gradient shared.css"

rm -f "$PLUGIN_DIR/SDH-CssLoader/plugin.json"
if output="$(pink_white_gradient_install 2>&1)"; then
    fail "缺少 CSS Loader 时安装仍成功"
fi
printf '%s\n' "$output" | grep -Fq 'CSS Loader' || fail "缺少 CSS Loader 提示缺失"
[ ! -d "$(pink_white_gradient_theme_dir)" ] || fail "缺少 CSS Loader 时仍写入了主题"

printf '{"name":"主题美化"}\n' > "$PLUGIN_DIR/SDH-CssLoader/plugin.json"
pink_white_gradient_install >/dev/null || fail "Pink White Gradient 安装失败"
[ -f "$(pink_white_gradient_theme_dir)/theme.json" ] || fail "未写入 theme.json"
[ -f "$(pink_white_gradient_theme_dir)/shared.css" ] || fail "未写入 shared.css"
[ "$(pink_white_gradient_file_sha256 "$(pink_white_gradient_theme_dir)/theme.json")" = "$PINK_WHITE_GRADIENT_THEME_JSON_SHA256" ] || \
    fail "安装的 theme.json 校验失败"
[ "$(pink_white_gradient_file_sha256 "$(pink_white_gradient_theme_dir)/shared.css")" = "$PINK_WHITE_GRADIENT_SHARED_CSS_SHA256" ] || \
    fail "安装的 shared.css 校验失败"

output="$(pink_white_gradient_install 2>&1)"
printf '%s\n' "$output" | grep -Fq '无需重复安装' || fail "重复安装未跳过"

status_output="$(pink_white_gradient_print_status)"
printf '%s\n' "$status_output" | grep -Fq '已安装 v1.0.0' || fail "状态未显示已安装版本"
printf '%s\n' "$status_output" | grep -Fq 'CSS Loader：已安装' || fail "状态未显示 CSS Loader 已安装"

pink_white_gradient_uninstall >/dev/null || fail "Pink White Gradient 卸载失败"
[ ! -d "$(pink_white_gradient_theme_dir)" ] || fail "卸载后主题目录仍存在"
pink_white_gradient_uninstall >/dev/null || fail "重复卸载失败"

PINK_WHITE_GRADIENT_SOURCE_DIR="$TMP_ROOT/missing-source"
if output="$(pink_white_gradient_install 2>&1)"; then
    fail "源文件缺失时安装仍成功"
fi
printf '%s\n' "$output" | grep -Fq '缺失' || fail "源文件缺失提示缺失"

ZHOUKEER_ALLOW_NON_STEAMOS=0
ZHOUKEER_OS_RELEASE_FILE="$TMP_ROOT/not-os-release"
if output="$(pink_white_gradient_install 2>&1)"; then
    fail "非 SteamOS 平台安装仍成功"
fi
printf '%s\n' "$output" | grep -Fq '仅支持 SteamOS 或 Bazzite' || fail "平台保护提示缺失"

echo "PASS: Pink White Gradient 主题安装、幂等、状态、卸载和平台保护模拟测试通过"
