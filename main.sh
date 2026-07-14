#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/ui.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

ensure_runtime_dirs

pause_menu() {
    echo ""
    read -r -p "回车继续"
}

run_action() {
    local title="$1"
    shift

    print_header
    print_section_title "$title"
    echo ""
    if "$@"; then
        echo ""
        echo "✓ 操作完成"
    else
        echo ""
        echo "✗ 操作未完成，请查看上方提示"
    fi
    pause_menu
}

common_software_menu() {
    local choice

    while true; do
        draw_category_frame B "常用软件" "常用桌面应用与游戏兼容层管理工具"
        ui_panel_line 9 '\033[97m' "1. 微信"
        ui_panel_line 11 '\033[97m' "2. QQ"
        ui_panel_line 13 '\033[97m' "3. ProtonUp-Qt 兼容层管理器"
        ui_panel_line 16 '\033[38;5;244m' "0. 返回主菜单"
        ui_prompt
        read -r choice

        case "$choice" in
            1) run_action "安装微信" bash "$PROJECT_ROOT/modules/software.sh" wechat ;;
            2) run_action "安装QQ" bash "$PROJECT_ROOT/modules/software.sh" qq ;;
            3) run_action "安装ProtonUp-Qt" bash "$PROJECT_ROOT/modules/software.sh" protonup ;;
            0) return 0 ;;
            *) echo "输入错误"; pause_menu ;;
        esac
    done
}

remote_assistance_menu() {
    local choice

    while true; do
        draw_category_frame C "远程协助" "安装远程协助工具，便于售后和故障处理"
        ui_panel_line 9 '\033[97m' "1. ToDesk"
        ui_panel_line 11 '\033[97m' "2. RustDesk（已配置自建服务器）"
        ui_panel_line 14 '\033[38;5;244m' "0. 返回主菜单"
        ui_prompt
        read -r choice

        case "$choice" in
            1) run_action "ToDesk远程工具" bash "$PROJECT_ROOT/modules/todesk.sh" ;;
            2) run_action "RustDesk远程工具" bash "$PROJECT_ROOT/modules/rustdesk.sh" ;;
            0) return 0 ;;
            *) echo "输入错误"; pause_menu ;;
        esac
    done
}

plugin_store_menu() {
    local choice

    while true; do
        draw_category_frame D "插件商城" "管理 Steam Deck 的 Decky Loader 插件环境"
        ui_panel_line 9 '\033[97m' "1. 安装或更新 Decky Loader"
        ui_panel_line 12 '\033[38;5;244m' "0. 返回主菜单"
        ui_prompt
        read -r choice

        case "$choice" in
            1) run_action "Decky Loader插件商城" bash "$PROJECT_ROOT/modules/plugin_store.sh" ;;
            0) return 0 ;;
            *) echo "输入错误"; pause_menu ;;
        esac
    done
}

system_settings_menu() {
    local choice

    while true; do
        draw_category_frame E "系统设置" "查看设备状态并处理基础网络问题"
        ui_panel_line 9 '\033[97m' "1. 查看系统信息"
        ui_panel_line 11 '\033[97m' "2. 网络检测与修复"
        ui_panel_line 14 '\033[38;5;244m' "0. 返回主菜单"
        ui_prompt
        read -r choice

        case "$choice" in
            1) run_action "系统信息" bash "$PROJECT_ROOT/core/detect.sh" ;;
            2) run_action "网络检测与修复" bash "$PROJECT_ROOT/modules/network.sh" ;;
            0) return 0 ;;
            *) echo "输入错误"; pause_menu ;;
        esac
    done
}

system_optimization_menu() {
    local choice

    while true; do
        draw_category_frame F "系统优化" "缓存清理、性能建议与常见问题修复"
        ui_panel_line 9 '\033[97m' "1. Steam Deck优化"
        ui_panel_line 11 '\033[97m' "2. 系统清理"
        ui_panel_line 13 '\033[97m' "3. 一键修复模式"
        ui_panel_line 16 '\033[38;5;244m' "0. 返回主菜单"
        ui_prompt
        read -r choice

        case "$choice" in
            1) run_action "Steam Deck优化" bash "$PROJECT_ROOT/modules/steam.sh" ;;
            2) run_action "系统清理" bash "$PROJECT_ROOT/modules/clean.sh" ;;
            3) run_action "一键修复模式" bash "$PROJECT_ROOT/modules/fixall.sh" ;;
            0) return 0 ;;
            *) echo "输入错误"; pause_menu ;;
        esac
    done
}

while true; do
    draw_category_frame "" "欢迎使用" "输入左侧字母进入对应分类"
    ui_panel_line 9 '\033[1;38;5;220m' "⭐ A：第一次使用推荐运行新机初始化"
    ui_panel_line 11 '\033[38;5;250m' "B：微信、QQ、ProtonUp-Qt"
    ui_panel_line 12 '\033[38;5;250m' "C：ToDesk、RustDesk"
    ui_panel_line 13 '\033[38;5;250m' "D：Decky Loader 插件商城"
    ui_panel_line 14 '\033[38;5;250m' "E：系统信息、网络检测"
    ui_panel_line 15 '\033[38;5;250m' "F：优化、清理、一键修复"
    ui_panel_line 17 '\033[38;5;114m' "G：检查并更新周克儿工具箱"
    ui_prompt
    read -r num

    case "$num" in
        A|a|1) run_action "一键新机初始化" bash "$PROJECT_ROOT/modules/new_machine.sh" ;;
        B|b|2) common_software_menu ;;
        C|c|3) remote_assistance_menu ;;
        D|d|4) plugin_store_menu ;;
        E|e|5) system_settings_menu ;;
        F|f|6) system_optimization_menu ;;
        G|g|7) run_action "更新工具箱" bash "$PROJECT_ROOT/update.sh" ;;
        X|x|0)
            log "用户退出工具箱"
            exit 0
            ;;
        *)
            echo "输入错误"
            pause_menu
            ;;
    esac
done
