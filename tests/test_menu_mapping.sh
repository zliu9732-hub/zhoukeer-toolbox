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
touch_console_accelerators="$(function_source "$MAIN_FILE" console_accelerator_touch_menu)"
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
assert_contains "$touch_decky_loader" 'right:7-8:test' "Decky Loader 子菜单缺少测试版动作"
assert_contains "$touch_decky_loader" 'right:9-10:auto' "Decky Loader 子菜单缺少自动安装动作"
assert_contains "$touch_decky_loader" 'modules/plugin_store.sh" store-test' "测试版 Decky Loader 动作错误"
assert_contains "$touch_decky_loader" '仅当 SteamOS 使用测试或预览通道' "测试版 Decky Loader 缺少适用范围说明"
assert_contains "$touch_games" 'right:9-10:browse' "浏览官方插件触控坐标错误"
assert_not_contains "$touch_games" 'right:9-10:deckrecall' "DeckRecall 仍显示在插件第一页"
assert_contains "$touch_games" 'NEXT_CATEGORY="freedeck_versions"' "Freedeck 未进入版本选择子菜单"
assert_contains "$touch_games" 'right:15-16:fsr4 right:17-18:freedeck' "FSR4 与 Freedeck 之间仍有空行"
assert_not_contains "$touch_games" 'right:9-10:all' "已删除的常用加精选插件入口仍显示"
official_plugin_names="$(sed -n '/^DECKY_OFFICIAL_PLUGIN_NAMES=(/,/^)/p' "$MAIN_FILE")"
assert_not_contains "$official_plugin_names" 'Freedeck' "官方插件最后一页仍显示 Freedeck"
touch_plugin_page_2="$(function_source "$MAIN_FILE" plugin_page_2_menu)"
assert_contains "$touch_plugin_page_2" 'right:5-6:deckrecall right:7-8:savepulse' "DeckRecall 与 SavePulse 未在插件第二页连续显示"
assert_contains "$touch_plugin_page_2" 'modules/plugin_store.sh" deckrecall' "DeckRecall 第二页动作错误"
assert_contains "$touch_plugin_page_2" 'modules/plugin_store.sh" savepulse' "SavePulse 第二页动作错误"
assert_contains "$touch_plugin_page_2" 'right:9-10:handheld-plugins' "插件第二页掌机控制子菜单坐标错误"
assert_contains "$touch_plugin_page_2" 'right:13-14:tomoon' "插件第二页 ToMoon 坐标错误"
assert_contains "$touch_plugin_page_2" 'right:17-18:launchers' "插件第二页缺少启动器子菜单坐标"
assert_contains "$touch_plugin_page_2" 'right:21-22:previous' "插件第二页缺少上一页坐标"
touch_handheld_plugins="$(function_source "$MAIN_FILE" handheld_plugins_menu)"
assert_contains "$touch_handheld_plugins" 'right:5-6:simpledeckytdp' "掌机控制子菜单缺少功耗控制坐标"
assert_contains "$touch_handheld_plugins" 'right:7-8:allycenter' "掌机控制子菜单缺少 Ally Center 坐标"
assert_contains "$touch_handheld_plugins" 'modules/plugin_store.sh" allycenter' "Ally Center 动作错误"
for mapping in 'right:9-10:huesync' 'right:11-12:legiongo-remapper' \
    'right:13-14:gpd-control' 'right:15-16:lego-vibe' 'right:17-18:lego2-fan'; do
    assert_contains "$touch_handheld_plugins" "$mapping" "掌机控制子菜单坐标错误：$mapping"
done
touch_repair="$(function_source "$MAIN_FILE" launcher_repair_menu)"
for mapping in 'right:5-6:epic' 'right:7-8:battlenet' 'right:9-10:ubisoft' 'right:11-12:heihe' 'right:19-20:back' 'right:22-23:home'; do
    assert_contains "$touch_repair" "$mapping" "修复封面菜单坐标错误：$mapping"
done
touch_battlenet="$(function_source "$MAIN_FILE" battlenet_submenu)"
assert_contains "$touch_battlenet" 'right:5-6:battlenet' "战网子菜单缺少战网动作"
assert_contains "$touch_battlenet" 'right:7-8:heihe' "战网子菜单缺少黑盒工坊坐标"
assert_contains "$touch_battlenet" 'modules/game_launchers.sh" heihe' "战网子菜单黑盒工坊动作错误"
touch_launcher_tools="$(function_source "$MAIN_FILE" launcher_tools_menu)"
assert_contains "$touch_launcher_tools" 'right:13-14:hmcl' "启动器与封面子菜单缺少 HMCL 启动器坐标"
assert_contains "$touch_launcher_tools" 'modules/game_launchers.sh" hmcl' "启动器与封面子菜单 HMCL 启动器动作错误"
touch_freedeck="$(function_source "$MAIN_FILE" freedeck_versions_menu)"
assert_contains "$touch_freedeck" 'right:5-6:stable' "Freedeck 子菜单缺少 0.6 稳定版动作"
assert_contains "$touch_freedeck" 'right:9-10:new' "Freedeck 子菜单缺少 NewFreedeck 动作"
assert_contains "$touch_freedeck" 'modules/plugin_store.sh" freedeck' "Freedeck 稳定版动作错误"
assert_contains "$touch_freedeck" 'modules/plugin_store.sh" newfreedeck' "NewFreedeck 动作错误"
assert_contains "$touch_freedeck" '部分功能尚未完成' "NewFreedeck 缺少上游状态提示"
touch_emulators="$(function_source "$MAIN_FILE" emulator_menu)"
for mapping in 'right:2-3:install-all' 'right:5-6:yuzu' 'right:7-8:cemu' 'right:9-10:duckstation' 'right:11-12:pcsx2' 'right:13-14:rpcs3' 'right:15-16:shadps4' 'right:17-18:ppsspp' 'right:19-20:mgba' 'right:21-22:azahar' 'right:23-24:home'; do
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
assert_contains "$touch_accelerator" 'right:17-18:console-accelerators' "Steamcommunity 302 缺少主机加速器入口"
for mapping in 'right:7-8:qiyou' 'right:10-11:xunyou' 'right:13-14:uu'; do
    assert_contains "$touch_console_accelerators" "$mapping" "主机加速器坐标错误：$mapping"
done
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
    assert_contains "$source_text" 'modules/f1_screen_fix.sh" install' "飞行家 F1 修复安装动作错误：$file"
    assert_contains "$source_text" 'modules/f1_screen_fix.sh" status' "飞行家 F1 修复状态动作错误：$file"
    assert_contains "$source_text" 'modules/f1_screen_fix.sh" uninstall' "飞行家 F1 修复卸载动作错误：$file"
    assert_contains "$source_text" 'modules/f1_screen_fix.sh" reboot' "飞行家 F1 立即重启动作错误：$file"
    assert_contains "$source_text" 'modules/domestic_source.sh" init' "国内软件源动作错误：$file"
    assert_contains "$source_text" 'modules/domestic_source.sh" restore' "恢复官方源动作错误：$file"
    assert_contains "$source_text" 'core/detect.sh" --health' "系统健康检查动作错误：$file"
    assert_contains "$source_text" 'modules/ge_proton.sh" install' "安装 GE 兼容层动作错误：$file"
    assert_contains "$source_text" 'modules/ge_proton.sh" install-trainer' "安装修改器常用兼容层动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" epic' "Epic 动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" heihe' "黑盒工坊动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" ubisoft' "Ubisoft Connect 动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" hmcl' "HMCL 启动器动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" apply-artwork' "启动器封面修复动作错误：$file"
    assert_contains "$source_text" 'modules/game_launchers.sh" uninstall' "启动器卸载动作错误：$file"
    assert_contains "$source_text" 'modules/emulators.sh" uninstall' "模拟器卸载动作错误：$file"
    assert_contains "$source_text" 'modules/emulators.sh"' "模拟器动作错误：$file"
    assert_contains "$source_text" 'modules/plugin_store.sh" tomoon' "ToMoon GitHub Release 动作错误：$file"
    assert_contains "$source_text" 'modules/plugin_store.sh" deckrecall' "DeckRecall GitHub Release 动作错误：$file"
    assert_contains "$source_text" 'modules/plugin_store.sh" savepulse' "SavePulse GitHub Release 动作错误：$file"
    assert_contains "$source_text" 'modules/plugin_store.sh" store-test' "测试版 Decky Loader 动作错误：$file"
    assert_contains "$source_text" 'modules/plugin_store.sh" store-auto' "自动安装 Decky Loader 动作错误：$file"
    assert_contains "$source_text" 'modules/plugin_store.sh" lsfg-zh-gitee' "小黄鸭 Gitee 动作错误：$file"
    assert_contains "$source_text" 'modules/plugin_store.sh" fsr4-zh-gitee' "FSR4 Gitee 动作错误：$file"
    assert_contains "$source_text" 'modules/plugin_store.sh" simpledeckytdp-zh-gitee' "SimpleDeckyTDP 中文 Gitee 动作错误：$file"
    assert_contains "$source_text" 'modules/steam_accelerator.sh" enable' "Steamcommunity 302 开启动作错误：$file"
    assert_contains "$source_text" 'modules/steam_accelerator.sh" launch' "Steamcommunity 302 配置界面动作错误：$file"
    assert_contains "$source_text" 'modules/steam_accelerator.sh" reset' "Steamcommunity 302 重置动作错误：$file"
    assert_contains "$source_text" 'modules/console_accelerators.sh"' "主机加速器官方入口动作错误：$file"
    assert_not_contains "$source_text" 'ZHOUKEER_START_STEAM_AFTER_302' "Steamcommunity 302 仍会自动启动 Steam：$file"
    assert_contains "$source_text" 'modules/diagnostics.sh" bundle' "安全诊断包动作错误：$file"
    assert_contains "$source_text" 'modules/settings_backup.sh" backup' "设置备份动作错误：$file"
    assert_contains "$source_text" 'modules/settings_backup.sh" restore' "设置恢复动作错误：$file"
    assert_contains "$source_text" 'modules/network.sh" --details' "详细网络状态动作错误：$file"
    assert_contains "$source_text" 'modules/clover_boot.sh" install' "Clover 安装/修复动作错误：$file"
    assert_not_contains "$source_text" 'modules/clover_boot.sh" delete' "Clover 删除动作不应直接暴露：$file"
    assert_contains "$source_text" 'modules/dual_system_tools.sh" health' "双系统健康检查动作错误：$file"
    assert_contains "$source_text" 'modules/dual_system_tools.sh" windows-shortcut' "Windows 桌面快捷方式动作错误：$file"
    assert_not_contains "$source_text" 'modules/dual_system_tools.sh" switch-to-windows' "工具箱菜单仍会立即切换 Windows：$file"
    assert_not_contains "$source_text" 'modules/dual_system_tools.sh" windows-next' "已移除的 Windows 立即切换仍可从菜单执行：$file"
done

bazzite_clover="$(function_source "$PROJECT_ROOT/main-bazzite.sh" bazzite_clover_menu)"
assert_contains "$bazzite_clover" '备份清理旧 SteamOS 引导' "Bazzite Clover 安装入口未说明自动清理"
assert_not_contains "$bazzite_clover" 'cleanup-steamos' "旧 SteamOS 清理不应暴露为独立菜单动作"

echo "PASS: 九分类导航、关键动作和返回坐标映射一致"
