#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN_FILE="$PROJECT_ROOT/main.sh"
GUI_FILE="$PROJECT_ROOT/core/gui.sh"
SOFTWARE_FILE="$PROJECT_ROOT/modules/software.sh"
NEW_MACHINE_FILE="$PROJECT_ROOT/modules/new_machine.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local text="$1"
    local expected="$2"
    local label="$3"

    printf '%s\n' "$text" | grep -Fq -- "$expected" || fail "$label"
}

assert_not_contains() {
    local text="$1"
    local unexpected="$2"
    local label="$3"

    if printf '%s\n' "$text" | grep -Fiq -- "$unexpected"; then
        fail "$label"
    fi
}

assert_matches() {
    local text="$1"
    local pattern="$2"
    local label="$3"

    printf '%s\n' "$text" | grep -Eq -- "$pattern" || fail "$label"
}

touch_software_menu="$(sed -n '/^common_software_menu()/,/^}/p' "$MAIN_FILE")"
gui_software_menu="$(sed -n '/^software_menu()/,/^}/p' "$GUI_FILE")"
touch_settings_menu="$(sed -n '/^system_settings_menu()/,/^}/p' "$MAIN_FILE")"
gui_settings_menu="$(sed -n '/^settings_menu()/,/^}/p' "$GUI_FILE")"
touch_optimization_menu="$(sed -n '/^system_optimization_menu()/,/^}/p' "$MAIN_FILE")"
gui_optimization_menu="$(sed -n '/^optimization_menu()/,/^}/p' "$GUI_FILE")"
touch_game_tools_menu="$(sed -n '/^game_tools_touch_menu()/,/^}/p' "$MAIN_FILE")"
gui_game_tools_menu="$(sed -n '/^game_tools_gui_menu()/,/^}/p' "$GUI_FILE")"
touch_support_center_menu="$(sed -n '/^support_center_touch_menu()/,/^}/p' "$MAIN_FILE")"
gui_support_center_menu="$(sed -n '/^support_center_gui_menu()/,/^}/p' "$GUI_FILE")"
touch_plugin_menu="$(sed -n '/^plugin_store_menu()/,/^}/p' "$MAIN_FILE")"
gui_plugin_menu="$(sed -n '/^plugin_menu()/,/^}/p' "$GUI_FILE")"
touch_plugin_preflight="$(sed -n '/^plugin_store_preflight()/,/^}/p' "$MAIN_FILE")"
touch_dual_menu="$(sed -n '/^dual_system_menu()/,/^}/p' "$MAIN_FILE")"
gui_dual_menu="$(sed -n '/^dual_system_menu()/,/^}/p' "$GUI_FILE")"

assert_contains "$touch_software_menu" 'Firefox 浏览器' "触控常用软件菜单缺少 Firefox"
assert_contains "$touch_software_menu" 'modules/software.sh" browser' "触控菜单未调用 Firefox 安装"
assert_contains "$gui_software_menu" 'Firefox 浏览器' "图形常用软件菜单缺少 Firefox"
assert_contains "$gui_software_menu" 'modules/software.sh" browser' "图形菜单未调用 Firefox 安装"
assert_contains "$touch_software_menu" 'GE-Proton 兼容层' "触控常用软件菜单缺少GE-Proton"
assert_contains "$touch_software_menu" 'modules/ge_proton.sh" install' "触控菜单未调用GE-Proton安装"
assert_contains "$gui_software_menu" 'GE-Proton 兼容层' "图形常用软件菜单缺少GE-Proton"
assert_contains "$gui_software_menu" 'modules/ge_proton.sh" install' "图形菜单未调用GE-Proton安装"
assert_not_contains "$touch_software_menu" 'protonup' "触控菜单仍包含 ProtonUp-Qt"
assert_not_contains "$gui_software_menu" 'protonup' "图形菜单仍包含 ProtonUp-Qt"
assert_not_contains "$(cat "$SOFTWARE_FILE")" 'protonup' "软件安装模块仍接受 ProtonUp-Qt"

for plugin_menu in "$touch_plugin_menu" "$gui_plugin_menu"; do
    assert_contains "$plugin_menu" '一键安装常用功能插件' "插件商城菜单缺少常用功能插件一键安装"
    assert_contains "$plugin_menu" 'modules/plugin_store.sh" features' "常用功能插件入口调用错误"
    assert_contains "$plugin_menu" '一键安装当前列表全部插件' "插件商城菜单缺少全部插件一键安装"
    assert_contains "$plugin_menu" 'modules/plugin_store.sh" all' "全部插件入口调用错误"
    assert_contains "$plugin_menu" '浏览官方插件' "插件商城菜单缺少官方插件分页入口"
    assert_contains "$plugin_menu" '安装周克儿汉化（测试版）' "插件商城菜单缺少周克儿汉化入口"
    assert_contains "$plugin_menu" 'modules/plugin_store.sh" localizer' "周克儿汉化入口调用错误"
    assert_contains "$plugin_menu" '一键清空已装插件' "插件商城菜单缺少插件清空入口"
    assert_contains "$plugin_menu" 'modules/plugin_store.sh" uninstall' "插件卸载入口调用错误"
    assert_contains "$plugin_menu" '清空已装 Decky 插件' "插件清空缺少触控确认页"
    assert_contains "$plugin_menu" '29款' "插件商城主菜单未显示当前插件总数"
    assert_contains "$plugin_menu" 'SimpleDeckyTDP' "插件商城描述缺少SimpleDeckyTDP"
    assert_contains "$plugin_menu" 'Unifideck' "插件商城描述缺少Unifideck"
    assert_not_contains "$plugin_menu" '123插件' "插件商城菜单不应按123插件单独分类"
    assert_contains "$plugin_menu" '启用开发者模式' "插件商城缺少开发者模式前置说明"
    assert_contains "$plugin_menu" 'CEF远程调试' "插件商城缺少CEF远程调试前置说明"
done

for optimization_menu in "$touch_optimization_menu" "$gui_optimization_menu"; do
    assert_contains "$optimization_menu" '游戏与掌机助手' "系统优化缺少游戏与掌机助手入口"
done

for game_tools_menu in "$touch_game_tools_menu" "$gui_game_tools_menu"; do
    assert_contains "$game_tools_menu" '安装 Epic 并 Add to Steam' "游戏助手缺少Epic安装入口"
    assert_contains "$game_tools_menu" 'modules/game_launchers.sh" epic' "Epic安装入口调用错误"
    assert_contains "$game_tools_menu" '安装战网并 Add to Steam' "游戏助手缺少战网安装入口"
    assert_contains "$game_tools_menu" 'modules/game_launchers.sh" battlenet' "战网安装入口调用错误"
    assert_contains "$game_tools_menu" '游戏启动诊断' "游戏助手缺少启动诊断入口"
    assert_contains "$game_tools_menu" 'modules/game_diagnose.sh" diagnose' "游戏启动诊断入口调用错误"
    assert_contains "$game_tools_menu" '攻略与安全中心' "游戏助手缺少攻略与安全中心入口"
done

for support_center_menu in "$touch_support_center_menu" "$gui_support_center_menu"; do
    assert_contains "$support_center_menu" '中文兼容攻略卡' "安全中心缺少中文兼容攻略"
    assert_contains "$support_center_menu" '掌机常用快捷键' "安全中心缺少掌机快捷键"
    assert_contains "$support_center_menu" '外接设备检查' "安全中心缺少外接设备检查"
    assert_contains "$support_center_menu" '操作记录' "安全中心缺少操作记录入口"
    assert_contains "$support_center_menu" 'modules/safety_center.sh" records' "操作记录入口调用错误"
done

assert_contains "$(cat "$PROJECT_ROOT/modules/game_diagnose.sh")" '不会删除游戏、兼容数据或缓存' \
    "游戏启动诊断缺少只读安全说明"
assert_contains "$(cat "$PROJECT_ROOT/modules/game_launchers.sh")" 'EpicGamesLauncherInstaller.msi' \
    "Epic安装器未使用官方MSI地址"
assert_contains "$(cat "$PROJECT_ROOT/modules/game_launchers.sh")" 'Battle.net-Setup.exe' \
    "战网安装器未使用官方EXE地址"
assert_contains "$(cat "$PROJECT_ROOT/modules/todesk.sh")" 'git clone --depth 1' \
    "ToDesk未改用固定提交拉取"
assert_not_contains "$(cat "$PROJECT_ROOT/modules/todesk.sh")" 'repository/archive/' \
    "ToDesk仍使用失效的Gitee归档接口"

assert_contains "$touch_plugin_preflight" '启用开发者模式' "插件商城打开前缺少开发者模式说明"
assert_contains "$touch_plugin_preflight" 'CEF 远程调试' "插件商城打开前缺少CEF远程调试说明"
assert_contains "$touch_plugin_preflight" '以上设置已完成，进入插件商城' "插件商城打开前缺少继续按钮"

touch_plugin_pages="$(sed -n '/^plugin_official_touch_pages()/,/^}/p' "$MAIN_FILE")"
gui_plugin_pages="$(sed -n '/^plugin_official_gui_pages()/,/^}/p' "$GUI_FILE")"
for plugin_pages in "$touch_plugin_pages" "$gui_plugin_pages"; do
    assert_contains "$plugin_pages" 'modules/decky_bundle.sh" plugin' "官方插件分页未调用单插件安装"
    assert_contains "$plugin_pages" 'DECKY_OFFICIAL_PLUGIN_DESCRIPTIONS' "官方插件分页缺少中文功能说明"
done

for dual_menu in "$touch_dual_menu" "$gui_dual_menu"; do
    assert_contains "$dual_menu" '双系统设置' "缺少双系统设置菜单"
    assert_contains "$dual_menu" 'modules/dual_system.sh" mount' "双系统菜单未接入互通盘挂载"
    assert_contains "$dual_menu" 'modules/dual_system.sh" add' "双系统菜单未接入双引导添加"
    assert_contains "$dual_menu" 'modules/dual_system.sh" remove' "双系统菜单未接入双引导隐藏"
    assert_contains "$dual_menu" 'modules/dual_system.sh" protect' "双系统菜单未接入互通盘保护"
done

for settings_menu in "$touch_settings_menu" "$gui_settings_menu"; do
    assert_contains "$settings_menu" '添加国内下载源' "系统设置缺少国内下载源"
    assert_contains "$settings_menu" 'modules/domestic_source.sh" enable' "国内下载源入口调用错误"
    assert_matches "$settings_menu" '加速器|Steamcommunity 302' "系统设置缺少 Steam 加速器"
    if [ "$settings_menu" = "$touch_settings_menu" ]; then
        assert_contains "$settings_menu" 'steam_accelerator_touch_menu' "触控Steam加速器入口调用错误"
    else
        assert_contains "$settings_menu" 'steam_accelerator_gui_menu' "图形Steam加速器入口调用错误"
    fi
    assert_contains "$settings_menu" '设置系统密码' "系统设置缺少设置密码"
    assert_contains "$settings_menu" 'modules/password.sh" set' "设置密码入口调用错误"
    assert_contains "$settings_menu" '修改系统密码' "系统设置缺少修改密码"
    assert_contains "$settings_menu" 'modules/password.sh" change' "修改密码入口调用错误"
    assert_contains "$settings_menu" '所有以当前用户身份运行的软件都可能读取' \
        "密码入口缺少明文可读风险确认"
    assert_not_contains "$settings_menu" 'modules/network.sh' "系统设置仍调用网络检测/修复模块"
    assert_not_contains "$settings_menu" '网络检测与修复' "系统设置仍显示网络检测/修复"
done

touch_accelerator_menu="$(sed -n '/^steam_accelerator_touch_menu()/,/^}/p' "$MAIN_FILE")"
gui_accelerator_menu="$(sed -n '/^steam_accelerator_gui_menu()/,/^}/p' "$GUI_FILE")"
for accelerator_menu in "$touch_accelerator_menu" "$gui_accelerator_menu"; do
    assert_contains "$accelerator_menu" 'modules/steam_accelerator.sh" install' "加速器子菜单缺少安装"
    assert_contains "$accelerator_menu" 'modules/steam_accelerator.sh" status' "加速器子菜单缺少状态"
    assert_contains "$accelerator_menu" 'modules/steam_accelerator.sh" uninstall' "加速器子菜单缺少安全卸载"
done

todesk_preflight="$(sed -n '/^todesk_preflight()/,/^}/p' "$MAIN_FILE")"
assert_contains "$todesk_preflight" '启用开发者模式' "ToDesk安装前缺少开发者模式说明"
assert_contains "$todesk_preflight" '使用旧版 X11 桌面模式' "ToDesk安装前缺少旧版X11说明"
assert_contains "$todesk_preflight" '杂项' "ToDesk安装前没有说明旧版X11开关所在区域"
assert_contains "$todesk_preflight" '以上设置已完成，继续安装' "ToDesk安装前缺少强制确认按钮"
new_machine_preflight="$(sed -n '/^new_machine_preflight()/,/^}/p' "$MAIN_FILE")"
assert_contains "$new_machine_preflight" '启用开发者模式' "新机初始化没有提醒开启开发者模式"
assert_contains "$new_machine_preflight" '使用旧版 X11 桌面模式' "新机初始化没有提醒开启旧版X11"

assert_contains "$(cat "$NEW_MACHINE_FILE")" 'modules/domestic_source.sh" enable' \
    "新机初始化未启用国内源"
assert_contains "$(cat "$NEW_MACHINE_FILE")" 'modules/software.sh" browser' \
    "新机初始化未安装 Firefox"
assert_not_contains "$(cat "$NEW_MACHINE_FILE")" 'protonup' \
    "新机初始化仍包含 ProtonUp-Qt"

echo "PASS: Firefox和系统设置新入口菜单契约测试通过"
