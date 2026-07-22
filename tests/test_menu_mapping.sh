#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN_FILE="$PROJECT_ROOT/main.sh"
GUI_FILE="$PROJECT_ROOT/core/gui.sh"
UI_FILE="$PROJECT_ROOT/core/ui.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

function_source() {
    local file="$1"
    local name="$2"
    sed -n "/^${name}()/,/^}/p" "$file"
}

assert_contains() {
    local text="$1"
    local expected="$2"
    local label="$3"
    grep -Fq -- "$expected" <<< "$text" || fail "$label"
}

assert_not_contains() {
    local text="$1"
    local unexpected="$2"
    local label="$3"
    if grep -Fq -- "$unexpected" <<< "$text"; then
        fail "$label"
    fi
}

touch_nav="$(function_source "$MAIN_FILE" read_touch_menu)"
gui_home="$(function_source "$GUI_FILE" main_gui_menu)"
sidebar="$(function_source "$UI_FILE" draw_category_frame)"

for mapping in \
    'left:2-3:nav-init' \
    'left:5-6:nav-software' \
    'left:8-9:nav-games' \
    'left:11-12:nav-network' \
    'left:14-15:nav-help' \
    'left:17-18:nav-advanced' \
    'left:20-21:nav-uninstall' \
    'left:23-24:nav-exit'; do
    assert_contains "$touch_nav" "$mapping" "触控首页映射缺失：$mapping"
done

for action in nav-init nav-software nav-games nav-network nav-help nav-advanced nav-uninstall nav-exit; do
    assert_contains "$gui_home" "$action" "GUI 首页映射缺失：$action"
done

for old_action in nav-remote nav-plugins nav-settings nav-dual nav-optimize nav-guides nav-changelog nav-update; do
    assert_not_contains "$touch_nav" "$old_action" "旧导航仍显示在触控首页：$old_action"
    assert_not_contains "$gui_home" "$old_action" "旧导航仍显示在 GUI 首页：$old_action"
done

for selected in init software games network support advanced uninstall exit; do
    assert_contains "$sidebar" " $selected \"" "侧栏缺少分类：$selected"
done

touch_software="$(function_source "$MAIN_FILE" common_software_menu)"
touch_games="$(function_source "$MAIN_FILE" game_environment_menu)"
touch_network="$(function_source "$MAIN_FILE" network_store_menu)"
touch_maintenance="$(function_source "$MAIN_FILE" maintenance_menu)"
touch_advanced="$(function_source "$MAIN_FILE" advanced_tools_menu)"
touch_accelerator="$(function_source "$MAIN_FILE" steam_accelerator_touch_menu)"

assert_contains "$touch_software" 'right:14-15:todesk' "常用软件 ToDesk 坐标错误"
assert_contains "$touch_software" 'right:22-23:home' "常用软件返回首页坐标错误"
assert_contains "$touch_games" 'right:23-24:home' "游戏环境缺少返回首页"
assert_contains "$touch_network" 'right:20-21:home' "网络与应用商店缺少返回首页"
assert_contains "$touch_maintenance" 'right:22-23:home' "系统维护缺少返回首页"
assert_contains "$touch_advanced" 'right:11-12:memory-optimize' "系统设置缺少虚拟内存动作"
assert_contains "$touch_advanced" 'right:22-23:home' "系统设置缺少返回首页"
assert_not_contains "$touch_advanced" 'set-password' "系统设置仍显示首次设置密码入口"
assert_not_contains "$touch_advanced" 'decky-install' "系统设置仍显示插件商城入口"
touch_uninstall="$(function_source "$MAIN_FILE" uninstall_software_menu)"
assert_contains "$touch_uninstall" 'right:19-20:next' "卸载第一页缺少下一页"
assert_contains "$touch_uninstall" 'right:21-22:next' "卸载第二页缺少下一页"
assert_contains "$touch_uninstall" 'right:20-21:previous' "卸载第三页缺少上一页"
assert_contains "$touch_accelerator" 'right:22-23:home' "Steamcommunity 302 缺少返回首页"

for file in "$MAIN_FILE" "$GUI_FILE"; do
    source_text="$(cat "$file")"
    assert_contains "$source_text" 'modules/password.sh" set' "设置管理员密码动作错误：$file"
    assert_contains "$source_text" 'modules/password.sh" change' "修改管理员密码动作错误：$file"
    assert_contains "$source_text" 'modules/memory_tuning.sh" optimize' "虚拟内存优化动作错误：$file"
    assert_contains "$source_text" 'modules/domestic_source.sh" init' "国内软件源动作错误：$file"
    assert_contains "$source_text" 'modules/domestic_source.sh" restore' "恢复官方源动作错误：$file"
    assert_contains "$source_text" 'core/detect.sh" --health' "系统健康检查动作错误：$file"
    assert_contains "$source_text" 'modules/ge_proton.sh" install' "GE 游戏运行组件动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" epic' "Epic 动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" ubisoft' "Ubisoft Connect 动作错误：$file"
    assert_contains "$source_text" 'modules/steam_accelerator.sh" enable' "Steamcommunity 302 开启动作错误：$file"
    assert_contains "$source_text" 'modules/clover_boot.sh" install' "Clover 安装动作错误：$file"
    assert_contains "$source_text" 'modules/clover_boot.sh" delete' "Clover 删除动作错误：$file"
    assert_contains "$source_text" 'modules/dual_system_tools.sh" health' "双系统健康检查动作错误：$file"
    assert_contains "$source_text" 'modules/dual_system_tools.sh" windows-shortcut' "Windows 一键切换动作错误：$file"
done

echo "PASS: 八分类导航、关键动作和返回坐标映射一致"
