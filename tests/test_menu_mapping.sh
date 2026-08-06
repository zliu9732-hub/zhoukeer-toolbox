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
    'left:4-5:nav-software' \
    'left:6-7:nav-games' \
    'left:8-9:nav-emulators' \
    'left:10-11:nav-check' \
    'left:12-13:nav-advanced' \
    'left:14-15:nav-uninstall' \
    'left:16-17:nav-notice' \
    'left:18-19:nav-exit'; do
    assert_contains "$touch_nav" "$mapping" "触控首页映射缺失：$mapping"
done

for action in nav-init nav-software nav-games nav-emulators nav-check nav-advanced nav-uninstall nav-notice nav-exit; do
    assert_contains "$gui_home" "$action" "GUI 首页映射缺失：$action"
done

for old_action in nav-remote nav-plugins nav-settings nav-dual nav-optimize nav-guides nav-changelog nav-update nav-network nav-help; do
    assert_not_contains "$touch_nav" "$old_action" "旧导航仍显示在触控首页：$old_action"
    assert_not_contains "$gui_home" "$old_action" "旧导航仍显示在 GUI 首页：$old_action"
done

for selected in init software games emulators support advanced uninstall notice exit; do
    assert_contains "$sidebar" " $selected \"" "侧栏缺少分类：$selected"
done

touch_software="$(function_source "$MAIN_FILE" common_software_menu)"
touch_software_more="$(function_source "$MAIN_FILE" common_software_more_menu)"
touch_games="$(function_source "$MAIN_FILE" game_environment_menu)"
touch_decky_loader="$(function_source "$MAIN_FILE" decky_loader_menu)"
touch_support="$(function_source "$MAIN_FILE" support_menu)"
touch_maintenance="$(function_source "$MAIN_FILE" maintenance_menu)"
touch_advanced="$(function_source "$MAIN_FILE" advanced_tools_menu)"
touch_memory="$(function_source "$MAIN_FILE" memory_touch_menu)"
touch_accelerator="$(function_source "$MAIN_FILE" steam_accelerator_touch_menu)"
touch_notice="$(function_source "$MAIN_FILE" usage_notice_menu)"

assert_contains "$touch_software" 'right:14-15:todesk' "常用软件 ToDesk 坐标错误"
assert_contains "$touch_software" 'right:20-21:anydesk' "常用软件 AnyDesk 坐标错误"
assert_contains "$touch_software" 'right:22-23:more' "常用软件更多页坐标错误"
assert_contains "$touch_software_more" 'right:16-17:fcitx5' "更多常用软件缺少中文输入法坐标"
assert_contains "$touch_software_more" 'right:18-19:next' "更多常用软件缺少下一页坐标"
assert_contains "$touch_software_more" 'right:20-21:back' "更多常用软件缺少返回坐标"
assert_contains "$touch_software_more" 'right:2-3:xbox-cloud' "更多常用软件缺少 Xbox 云游戏坐标"
assert_contains "$touch_software_more" 'right:16-17:media-downloader' "更多常用软件缺少 Media Downloader 坐标"
assert_contains "$touch_software_more" 'right:18-19:previous' "更多常用软件缺少上一页坐标"
assert_contains "$touch_software_more" 'right:14-15:parsec' "更多常用软件缺少 Parsec 坐标"
assert_contains "$touch_software_more" 'right:22-23:home' "更多常用软件缺少返回首页坐标"
assert_contains "$touch_games" 'right:23-24:home' "游戏环境缺少返回首页"
assert_contains "$touch_decky_loader" 'right:5-6:stable' "Decky Loader 子菜单缺少稳定版动作"
assert_contains "$touch_decky_loader" 'right:9-10:test' "Decky Loader 子菜单缺少测试版动作"
assert_contains "$touch_decky_loader" 'modules/plugin_store.sh" store-test' "测试版 Decky Loader 动作错误"
assert_contains "$touch_decky_loader" '仅当 SteamOS 使用测试或预览通道' "测试版 Decky Loader 缺少适用范围说明"
assert_contains "$touch_games" 'right:9-10:deckrecall' "DeckRecall 触控坐标错误"
assert_contains "$touch_games" 'modules/plugin_store.sh" deckrecall' "DeckRecall 动作错误"
assert_not_contains "$touch_games" 'right:9-10:all' "已删除的常用加精选插件入口仍显示"
official_plugin_names="$(sed -n '/^DECKY_OFFICIAL_PLUGIN_NAMES=(/,/^)/p' "$MAIN_FILE")"
assert_not_contains "$official_plugin_names" 'Freedeck' "官方插件最后一页仍显示 Freedeck"
touch_plugin_page_2="$(function_source "$MAIN_FILE" plugin_page_2_menu)"
assert_contains "$touch_plugin_page_2" 'right:9-10:tomoon' "插件第二页 ToMoon 坐标错误"
assert_contains "$touch_plugin_page_2" 'right:19-20:repair' "插件第二页缺少修复封面坐标"
assert_contains "$touch_plugin_page_2" 'right:21-22:previous' "插件第二页缺少上一页坐标"
touch_repair="$(function_source "$MAIN_FILE" launcher_repair_menu)"
for mapping in 'right:5-6:epic' 'right:7-8:battlenet' 'right:9-10:ubisoft' 'right:11-12:heihe' 'right:19-20:back' 'right:22-23:home'; do
    assert_contains "$touch_repair" "$mapping" "修复封面菜单坐标错误：$mapping"
done
touch_battlenet="$(function_source "$MAIN_FILE" battlenet_submenu)"
assert_contains "$touch_battlenet" 'right:5-6:battlenet' "战网子菜单缺少战网动作"
assert_contains "$touch_battlenet" 'right:7-8:heihe' "战网子菜单缺少黑盒工坊坐标"
assert_contains "$touch_battlenet" 'modules/game_launchers.sh" heihe' "战网子菜单黑盒工坊动作错误"
touch_emulators="$(function_source "$MAIN_FILE" emulator_menu)"
for mapping in 'right:5-6:yuzu' 'right:7-8:cemu' 'right:9-10:duckstation' 'right:11-12:pcsx2' 'right:13-14:rpcs3' 'right:15-16:shadps4' 'right:17-18:ppsspp' 'right:19-20:mgba' 'right:21-22:azahar' 'right:23-24:home'; do
    assert_contains "$touch_emulators" "$mapping" "模拟器触控坐标错误：$mapping"
done
touch_yuzu="$(function_source "$MAIN_FILE" yuzu_menu)"
assert_contains "$touch_yuzu" 'right:12-13:keys' "Yuzu 密钥导入坐标错误"
assert_contains "$touch_yuzu" 'modules/emulators.sh" yuzu-keys' "Yuzu 密钥导入动作缺失"
assert_contains "$touch_yuzu" '本人合法备份' "Yuzu 密钥入口缺少合法来源说明"
assert_contains "$touch_support" 'right:22-23:home' "检查与维护缺少返回首页"
assert_contains "$touch_maintenance" 'right:22-23:home' "系统维护缺少返回首页"
assert_contains "$touch_advanced" 'right:11-12:memory' "系统设置缺少虚拟内存子菜单动作"
assert_contains "$touch_memory" 'right:7-8:optimize' "虚拟内存菜单缺少优化动作"
assert_contains "$touch_memory" 'right:11-12:status' "虚拟内存菜单缺少状态动作"
assert_contains "$touch_memory" 'right:15-16:restore' "虚拟内存菜单缺少撤销动作"
assert_contains "$touch_advanced" 'right:22-23:home' "系统设置缺少返回首页"
assert_not_contains "$touch_advanced" 'set-password' "系统设置仍显示首次设置密码入口"
assert_not_contains "$touch_advanced" 'decky-install' "系统设置仍显示插件商城入口"
assert_contains "$touch_accelerator" 'right:9-10:launch' "Steamcommunity 302 缺少配置界面坐标"
assert_contains "$touch_accelerator" 'right:11-12:reset' "Steamcommunity 302 缺少重置坐标"
touch_ge_proton="$(function_source "$MAIN_FILE" ge_proton_menu)"
gui_ge_proton="$(function_source "$GUI_FILE" ge_proton_gui_menu)"
for menu in "$touch_ge_proton" "$gui_ge_proton"; do
    assert_contains "$menu" '安装最新 GE 兼容层' "GE 兼容层子菜单缺少最新版入口"
    assert_contains "$menu" '安装修改器所需常用兼容层' "GE 兼容层子菜单缺少修改器常用入口"
done
assert_contains "$touch_ge_proton" 'right:5-6:latest' "GE 兼容层最新版坐标错误"
assert_contains "$touch_ge_proton" 'right:9-10:trainer' "GE 兼容层修改器常用坐标错误"
touch_uninstall="$(function_source "$MAIN_FILE" uninstall_software_menu)"
assert_contains "$touch_uninstall" 'right:18-19:next' "卸载第一页缺少下一页"
assert_contains "$touch_uninstall" 'right:20-21:home' "卸载第一页缺少返回首页"
assert_contains "$touch_uninstall" 'right:18-19:previous' "卸载页缺少上一页"
assert_contains "$touch_uninstall" 'right:20-21:next' "卸载中间页缺少下一页"
assert_contains "$touch_uninstall" 'right:8-9:decky-plugins' "卸载最后一页缺少 Decky 插件坐标"
assert_contains "$touch_uninstall" 'right:23-24:home' "卸载最后一页缺少返回首页"
assert_contains "$touch_accelerator" 'right:22-23:home' "Steamcommunity 302 缺少返回首页"
assert_contains "$touch_notice" '我已阅读并知悉' "免责声明页面缺少真实确认按钮"
assert_contains "$touch_notice" 'right:18-19:acknowledge' "免责声明确认按钮坐标错误"
assert_contains "$touch_notice" 'right:21-22:home' "免责声明页面缺少返回首页"
assert_not_contains "$touch_notice" '--imgbox' "免责声明仍使用无法点击的静态图片窗口"
assert_contains "$gui_home" '--yes-label "我已阅读并知悉"' "GUI免责声明缺少真实确认按钮"

for file in "$MAIN_FILE" "$GUI_FILE"; do
    source_text="$(cat "$file")"
    assert_contains "$source_text" 'modules/password.sh" set' "设置管理员密码动作错误：$file"
    assert_contains "$source_text" 'modules/password.sh" change' "修改管理员密码动作错误：$file"
    assert_contains "$source_text" 'modules/memory_tuning.sh" optimize' "虚拟内存优化动作错误：$file"
    assert_contains "$source_text" 'modules/memory_tuning.sh" restore' "虚拟内存撤销动作错误：$file"
    assert_contains "$source_text" 'modules/domestic_source.sh" init' "国内软件源动作错误：$file"
    assert_contains "$source_text" 'modules/domestic_source.sh" restore' "恢复官方源动作错误：$file"
    assert_contains "$source_text" 'core/detect.sh" --health' "系统健康检查动作错误：$file"
    assert_contains "$source_text" 'modules/ge_proton.sh" install' "安装 GE 兼容层动作错误：$file"
    assert_contains "$source_text" 'modules/ge_proton.sh" install-trainer' "安装修改器常用兼容层动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" epic' "Epic 动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" heihe' "黑盒工坊动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" ubisoft' "Ubisoft Connect 动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" apply-artwork' "启动器封面修复动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" uninstall' "启动器卸载动作错误：$file"
    assert_contains "$source_text" 'modules/emulators.sh" uninstall' "模拟器卸载动作错误：$file"
    assert_contains "$source_text" 'modules/emulators.sh"' "模拟器动作错误：$file"
    assert_contains "$source_text" 'modules/plugin_store.sh" tomoon' "ToMoon GitHub Release 动作错误：$file"
    assert_contains "$source_text" 'modules/plugin_store.sh" store-test' "测试版 Decky Loader 动作错误：$file"
    assert_contains "$source_text" 'modules/plugin_store.sh" lsfg-zh-gitee' "小黄鸭 Gitee 动作错误：$file"
    assert_contains "$source_text" 'modules/plugin_store.sh" fsr4-zh-gitee' "FSR4 Gitee 动作错误：$file"
    assert_contains "$source_text" 'modules/steam_accelerator.sh" enable' "Steamcommunity 302 开启动作错误：$file"
    assert_contains "$source_text" 'modules/steam_accelerator.sh" launch' "Steamcommunity 302 配置界面动作错误：$file"
    assert_contains "$source_text" 'modules/steam_accelerator.sh" reset' "Steamcommunity 302 重置动作错误：$file"
    assert_not_contains "$source_text" 'ZHOUKEER_START_STEAM_AFTER_302' "Steamcommunity 302 仍会自动启动 Steam：$file"
    assert_contains "$source_text" 'modules/diagnostics.sh" bundle' "安全诊断包动作错误：$file"
    assert_contains "$source_text" 'modules/settings_backup.sh" backup' "设置备份动作错误：$file"
    assert_contains "$source_text" 'modules/settings_backup.sh" restore' "设置恢复动作错误：$file"
    assert_contains "$source_text" 'modules/network.sh" --details' "详细网络状态动作错误：$file"
    assert_not_contains "$source_text" 'modules/clover_boot.sh" install' "已移除的 Clover 安装动作仍可执行：$file"
    assert_not_contains "$source_text" 'modules/clover_boot.sh" delete' "已移除的 Clover 删除动作仍可执行：$file"
    assert_contains "$source_text" 'modules/dual_system_tools.sh" health' "双系统健康检查动作错误：$file"
    assert_not_contains "$source_text" 'modules/dual_system_tools.sh" windows-shortcut' "已移除的 Windows 一键切换仍可从菜单执行：$file"
    assert_not_contains "$source_text" 'modules/dual_system_tools.sh" windows-next' "已移除的 Windows 立即切换仍可从菜单执行：$file"
done

echo "PASS: 九分类导航、关键动作和返回坐标映射一致"
