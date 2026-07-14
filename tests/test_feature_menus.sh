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

assert_contains "$touch_software_menu" 'Chrome 浏览器' "触控常用软件菜单缺少 Chrome"
assert_contains "$touch_software_menu" 'modules/software.sh" browser' "触控菜单未调用 Chrome 安装"
assert_contains "$gui_software_menu" 'Chrome 浏览器' "图形常用软件菜单缺少 Chrome"
assert_contains "$gui_software_menu" 'modules/software.sh" browser' "图形菜单未调用 Chrome 安装"
assert_not_contains "$touch_software_menu" 'protonup' "触控菜单仍包含 ProtonUp-Qt"
assert_not_contains "$gui_software_menu" 'protonup' "图形菜单仍包含 ProtonUp-Qt"
assert_not_contains "$(cat "$SOFTWARE_FILE")" 'protonup' "软件安装模块仍接受 ProtonUp-Qt"

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
    "新机初始化未安装 Chrome"
assert_not_contains "$(cat "$NEW_MACHINE_FILE")" 'protonup' \
    "新机初始化仍包含 ProtonUp-Qt"

echo "PASS: Chrome和系统设置新入口菜单契约测试通过"
