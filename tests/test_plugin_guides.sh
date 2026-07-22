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
grep -Fq '寂静岭 2' "$FSR4_GUIDE"
grep -Fq '界外狂潮' "$FSR4_GUIDE"
grep -Fq 'FSR/FSR4 不适合所有游戏' "$FSR4_GUIDE"
if grep -Fq '怪物猎人：荒野' "$FSR4_GUIDE"; then
    echo "FAIL: FSR4 名单没有按要求去除怪物猎人：荒野" >&2
    exit 1
fi

# 重复检测应更新工具箱管理的文件；同名用户文件和符号链接不得被覆盖。
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
