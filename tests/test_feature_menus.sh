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
    printf '%s\n' "$text" | grep -Fq -- "$expected" || fail "$label"
}

assert_not_contains() {
    local text="$1"
    local unexpected="$2"
    local label="$3"
    if printf '%s\n' "$text" | grep -Fq -- "$unexpected"; then
        fail "$label"
    fi
}

touch_home="$(function_source "$MAIN_FILE" home_menu)"
gui_home="$(function_source "$GUI_FILE" main_gui_menu)"
sidebar="$(function_source "$UI_FILE" draw_category_frame)"

for item in \
    '新机必备｜第一次使用从这里开始' \
    '常用软件｜安装聊天、浏览器和远程工具' \
    '游戏与插件｜浏览插件商城和游戏组件' \
    '网络与应用商店｜检查网络和软件源状态' \
    '维护与帮助｜系统检查、清理、指南和日志' \
    '系统与密码｜设置密码和管理系统功能'; do
    assert_contains "$touch_home" "$item" "触控首页缺少：$item"
    assert_contains "$gui_home" "$item" "GUI 首页缺少：$item"
done

[ "$(printf '%s\n' "$sidebar" | grep -c 'ui_sidebar_item')" -eq 7 ] || fail "触控侧栏不是六分类加退出"

touch_software="$(function_source "$MAIN_FILE" common_software_menu)"
gui_software="$(function_source "$GUI_FILE" software_menu)"
for menu in "$touch_software" "$gui_software"; do
    for item in '微信' 'QQ' 'Firefox 浏览器' 'Chrome 浏览器' 'Edge 浏览器' 'RustDesk 远程协助' 'ToDesk 远程协助' 'Windows 软件工具' '游戏兼容设置' 'Epic 游戏启动器'; do
        assert_contains "$menu" "$item" "常用软件缺少：$item"
    done
    for hidden in '网易云音乐' '战网'; do
        assert_not_contains "$menu" "$hidden" "常用软件不应显示：$hidden"
    done
done
touch_software_buttons="$(printf '%s\n' "$touch_software" | grep 'ui_touch_button')"
gui_software_entries="$(printf '%s\n' "$gui_software" | sed -n '/choice="$(gui_dialog --menu/,/)" || return 0/p')"
for obsolete_hint in '安装适合 SteamOS 的微信' '安装适合 SteamOS 的 QQ' \
    '安装 Firefox 浏览器' '安装 Chrome 浏览器' '安装 Edge 浏览器'; do
    assert_not_contains "$touch_software_buttons" "$obsolete_hint" "触控常用软件仍显示多余说明：$obsolete_hint"
    assert_not_contains "$gui_software_entries" "$obsolete_hint" "GUI 常用软件仍显示多余说明：$obsolete_hint"
done

touch_games="$(function_source "$MAIN_FILE" game_environment_menu)"
gui_games="$(function_source "$GUI_FILE" game_environment_gui_menu)"
for menu in "$touch_games" "$gui_games"; do
    assert_contains "$menu" '游戏与插件｜插件商城' "插件商城页面标题不统一"
    assert_not_contains "$menu" '游戏与插件｜Decky 插件商城' "插件商城页面仍显示英文标题"
    for item in '常用插件组合' '插件环境与精选组合' '浏览官方插件' '游戏中文辅助' 'GE 游戏运行组件' 'Epic 游戏启动器' '安装插件商城'; do
        assert_contains "$menu" "$item" "游戏环境缺少：$item"
    done
    assert_contains "$menu" '实验功能' "游戏中文辅助缺少实验说明"
    assert_contains "$menu" '高级操作' "Decky Loader 缺少高级说明"
    assert_not_contains "$menu" '25 个精选插件' "plugin_store all 仍被错误描述为 25 个精选插件"
    assert_not_contains "$menu" '兼容层管理' "不存在的兼容层管理仍可见"
done

touch_network="$(function_source "$MAIN_FILE" network_store_menu)"
gui_network="$(function_source "$GUI_FILE" network_store_gui_menu)"
for menu in "$touch_network" "$gui_network"; do
    for item in '网络状态检查' '软件源状态' '管理国内源与加速'; do
        assert_contains "$menu" "$item" "网络与应用商店缺少：$item"
    done
    for hidden in '网络修复' 'Discover 应用商店修复' '恢复官方源'; do
        assert_not_contains "$menu" "$hidden" "普通网络页不应显示：$hidden"
    done
    assert_not_contains "$menu" 'domestic_source.sh" init' "普通网络页不应直接执行国内源初始化"
done

touch_maintenance="$(function_source "$MAIN_FILE" maintenance_menu)"
gui_maintenance="$(function_source "$GUI_FILE" maintenance_gui_menu)"
for menu in "$touch_maintenance" "$gui_maintenance"; do
    for item in '系统健康检查' '游戏启动检查' '清理下载残留' '清理着色器缓存' '清理用户缓存' '查看性能建议' '常见问题处理'; do
        assert_contains "$menu" "$item" "系统维护缺少：$item"
    done
    [ "$(printf '%s\n' "$menu" | grep -o '会删除缓存' | wc -l | tr -d ' ')" -ge 4 ] || fail "缓存删除风险说明不足"
    assert_not_contains "$menu" '权限修复' "不存在的权限修复仍可见"
    assert_not_contains "$menu" '一键修复模式' "旧的一键修复名称仍可见"
done

touch_help="$(function_source "$MAIN_FILE" help_menu)"
gui_help="$(function_source "$GUI_FILE" help_gui_menu)"
for menu in "$touch_help" "$gui_help"; do
    for item in '查看系统信息' '导出诊断报告' '新手使用指南' '游戏兼容指南' '掌机常用快捷键' '外接设备检查' '操作记录' '更新日志' '检查并更新工具箱'; do
        assert_contains "$menu" "$item" "检测与帮助缺少：$item"
    done
    assert_contains "$menu" '会联网并更新' "工具箱更新缺少联网更新说明"
done

touch_advanced="$(function_source "$MAIN_FILE" advanced_tools_menu)"
gui_advanced="$(function_source "$GUI_FILE" advanced_tools_gui_menu)"
for menu in "$touch_advanced" "$gui_advanced"; do
    assert_contains "$menu" '以下功能会修改系统、网络、软件源、密码或磁盘设置' "系统与密码缺少固定警告"
    for item in '国内软件源' 'Steamcommunity 302' '设置管理员密码' '修改管理员密码' '安装插件商城' '双系统与互通盘'; do
        assert_contains "$menu" "$item" "系统与密码缺少：$item"
    done
    assert_not_contains "$menu" '安装 ToDesk' "系统与密码不应重复显示 ToDesk"
    for risk_text in 'Flatpak 软件源' '修改 DNS' '管理密码' '使用管理员权限' '管理磁盘和开机菜单'; do
        assert_contains "$menu" "$risk_text" "系统与密码缺少风险说明：$risk_text"
    done
done

for gui_menu_name in software_menu game_environment_gui_menu plugin_official_gui_pages dual_system_menu network_store_gui_menu steam_accelerator_gui_menu maintenance_gui_menu help_gui_menu new_machine_gui_menu advanced_tools_gui_menu; do
    gui_menu="$(function_source "$GUI_FILE" "$gui_menu_name")"
    assert_contains "$gui_menu" 'home "返回首页"' "GUI 页面缺少返回首页：$gui_menu_name"
    assert_contains "$gui_menu" 'nav-exit "退出工具箱"' "GUI 页面缺少退出工具箱：$gui_menu_name"
done

touch_source="$(function_source "$MAIN_FILE" domestic_source_preflight)"
gui_source="$(function_source "$GUI_FILE" domestic_source_gui_preflight)"
for menu in "$touch_source" "$gui_source"; do
    for detail in 'flathub-cn' 'https://mirror.sjtu.edu.cn/flathub' 'flathub-ustc' 'https://mirrors.ustc.edu.cn/flathub' 'GPG' 'pacman' '只读' '恢复官方源功能尚未完成'; do
        assert_contains "$menu" "$detail" "国内源风险页缺少：$detail"
    done
done

for visible in "$MAIN_FILE" "$GUI_FILE"; do
    if grep -Eiq 'refind' "$visible"; then
        fail "可见菜单文件仍出现 rEFInd：$visible"
    fi
    if grep -Eq '\[(只读|只读检查|会安装软件|会安装插件|会安装组件|会创建文件|普通|普通检查|引导|只读为主|部分会删除缓存)\]' "$visible"; then
        fail "普通菜单仍包含冗余状态标签：$visible"
    fi
    if grep -Eq '\[(会删除缓存|会联网并更新|实验功能|高级操作|高风险|安装软件/修改软件源|会修改软件源|会修改网络设置|会修改系统密码|会修改只读系统|会使用管理员权限|磁盘/启动高级操作)\]' "$visible"; then
        fail "菜单风险说明仍使用方括号：$visible"
    fi
done

echo "PASS: 触控与 GUI 的名称、说明、风险标签和功能集合一致"
