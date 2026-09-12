#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
PLUGIN_ROOT="$TMP_ROOT/plugins"
CALLS="$TMP_ROOT/calls"

cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "$PLUGIN_ROOT"

# shellcheck disable=SC1090
source "$PROJECT_ROOT/modules/plugin_store.sh"

detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; }
prepare_plugin_root() { PLUGIN_NEEDS_SUDO=0; [ -d "$1" ]; }
reload_decky_plugins() { printf '%s\n' "$1" >> "$CALLS"; }
log() { :; }

export DECKY_PLUGIN_DIR="$PLUGIN_ROOT"
install_lego2_brightness_fix >/dev/null || fail "X2 Mini Pro 亮度修复模拟安装失败"

[ -f "$PLUGIN_ROOT/LeGo2BrightnessFix/plugin.json" ] || fail "插件清单未安装"
[ -s "$PLUGIN_ROOT/LeGo2BrightnessFix/dist/index.js" ] || fail "前端未安装"
[ -s "$PLUGIN_ROOT/LeGo2BrightnessFix/main.py" ] || fail "后端未安装"
[ -s "$PLUGIN_ROOT/LeGo2BrightnessFix/lego_updater.py" ] || fail "更新模块未安装"
[ -s "$PLUGIN_ROOT/LeGo2BrightnessFix/gamescope/lenovo.legiongo2.oled.gamma22.lua" ] || fail "Gamma 显示脚本未安装"
[ -s "$PLUGIN_ROOT/LeGo2BrightnessFix/gamescope/lenovo.legiongo2.oled.pq.lua" ] || fail "PQ 显示脚本未安装"
[ "$(decky_plugin_version "$PLUGIN_ROOT/LeGo2BrightnessFix")" = "2.0.0" ] || fail "插件版本不正确"
grep -Fq 'errors="replace"' "$PLUGIN_ROOT/LeGo2BrightnessFix/main.py" || \
    fail "未包含非 UTF-8 进程名兼容修正"
grep -Fq 'ONEXPLAYER X2 Mini Pro' "$PROJECT_ROOT/modules/plugin_store.sh" || \
    fail "安装器缺少 X2 Mini Pro 实测标注"
grep -Fq 'lego2-brightness-fix) install_lego2_brightness_fix' "$PROJECT_ROOT/modules/plugin_store.sh" || \
    fail "安装器缺少独立命令入口"
grep -Fq 'copy_lego2_brightness_fix' "$PROJECT_ROOT/install.sh" || \
    fail "主安装器未携带亮度修复组件"
grep -Fq 'lego2-brightness-fix-zh-v2.0.0/main.py' "$PROJECT_ROOT/scripts/package_release.sh" || \
    fail "发布包未校验亮度修复后端"

repeat_output="$(install_lego2_brightness_fix)" || fail "同版重复执行失败"
printf '%s\n' "$repeat_output" | grep -Fq '[已安装] LeGo2 亮度修复 v2.0.0 已存在且文件校验通过。' || \
    fail "同版重复执行未进入幂等路径"
[ "$(wc -l < "$CALLS")" -eq 1 ] || fail "同版重复执行仍重载 Decky"

echo "PASS: X2 Mini Pro 亮度修复的完整组件、校验、原子安装与幂等测试通过"
