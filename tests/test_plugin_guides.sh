#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/plugin_store.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

HOME_DIR="$TMP_ROOT/home"
DESKTOP_DIR="$HOME_DIR/Desktop"
PLUGIN_ROOT="$HOME_DIR/homebrew/plugins"
mkdir -p "$PLUGIN_ROOT/Decky-Framegen/dist"
printf '{"name":"Decky-Framegen(FSR4)"}\n' > "$PLUGIN_ROOT/Decky-Framegen/plugin.json"
printf 'bundle\n' > "$PLUGIN_ROOT/Decky-Framegen/dist/index.js"

HOME="$HOME_DIR" DECKY_PLUGIN_DIR="$PLUGIN_ROOT" ZHOUKEER_DESKTOP_DIR="$DESKTOP_DIR" \
    bash -c 'source "$1"; refresh_feature_usage_guides' _ "$MODULE"

COMMON_GUIDE="$DESKTOP_DIR/风灵月影，小黄鸭，FSR4使用教程.txt"
FSR4_GUIDE="$DESKTOP_DIR/FSR4支持游戏名单.txt"
[ -f "$COMMON_GUIDE" ] && [ -f "$FSR4_GUIDE" ] || {
    echo "FAIL: 检测到 FSR4 后没有创建两个桌面教程" >&2
    exit 1
}
for text in 'FSR/FSR4 不适合所有游戏' 'BV1ew411J7ab' '35 秒' '败家君的游戏屋' \
    'LSFG-VK' 'OptiScaler' '齿轮 → CheatDeck → “高级”'; do
    grep -Fq "$text" "$COMMON_GUIDE" || {
        echo "FAIL: 总教程缺少：$text" >&2
        exit 1
    }
done
grep -Fq 'SILENT HILL 2 (2024)' "$FSR4_GUIDE"
grep -Fq 'FSR/FSR4 不适合所有游戏' "$FSR4_GUIDE"
grep -Fq 'OptiScaler 官方 Wiki' "$FSR4_GUIDE"
grep -Fq '上游统计为 685 个可工作条目' "$FSR4_GUIDE"
grep -Fq 'Steam Deck 是 RDNA2' "$FSR4_GUIDE"
grep -Fq 'Black Myth: Wukong' "$FSR4_GUIDE"
grep -Fq 'EA Sports WRC' "$FSR4_GUIDE"
[ "$(grep -vc '^#' "$PROJECT_ROOT/data/fsr4_optiscaler_tested_games_2026-08-07.txt")" -eq 683 ] || {
    echo "FAIL: FSR4 官方 Wiki 游戏清单条目数不正确" >&2
    exit 1
}
if grep -Fq 'Monster Hunter Wilds' "$FSR4_GUIDE"; then
    echo "FAIL: FSR4 官方清单没有按既有要求排除 Monster Hunter Wilds" >&2
    exit 1
fi

# 重复检测应更新Renkit管理的文件；同名用户文件和符号链接不得被覆盖。
HOME="$HOME_DIR" DECKY_PLUGIN_DIR="$PLUGIN_ROOT" ZHOUKEER_DESKTOP_DIR="$DESKTOP_DIR" \
    bash -c 'source "$1"; refresh_feature_usage_guides' _ "$MODULE" >/dev/null
rm -f -- "$COMMON_GUIDE"
printf '用户自己的内容\n' > "$COMMON_GUIDE"
HOME="$HOME_DIR" DECKY_PLUGIN_DIR="$PLUGIN_ROOT" ZHOUKEER_DESKTOP_DIR="$DESKTOP_DIR" \
    bash -c 'source "$1"; refresh_feature_usage_guides || true' _ "$MODULE" >/dev/null 2>&1
grep -Fxq '用户自己的内容' "$COMMON_GUIDE" || {
    echo "FAIL: 同名用户文件被覆盖" >&2
    exit 1
}

echo "PASS: 插件检测、桌面教程、FSR4名单和防覆盖测试通过"
